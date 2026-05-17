-- ============================================================
-- F1.B.A2 — Backfill profiles.lugares → place_profiles (GUARDRAIL)
-- ============================================================
--
-- Aplicado em: (NÃO APLICAR AINDA — guardrail no repo)
-- Aplicado por: (futuro Josemar, se necessário)
-- Reversível: SIM (DELETE em place_profiles dos rows criados; backup disponível)
--
-- Status: GUARDRAIL. NÃO aplicar nesta sessão.
--
-- Contexto:
--   Sessão A1 (13/mai/2026 → 14/mai/2026) descobriu 15 itens residuais em
--   `profiles.lugares` pós-reset F0. Migration `20260514_003` limpou tudo
--   pra estado vazio.
--
--   Esta migration (A2) existe como guardrail: o app ainda tem 4 escritas
--   ativas que populam `profiles.lugares` (ModalAdicionarLugar, MeusLugares,
--   Perfil, validarTextoUsuario). Se alguma delas rodar entre agora e a
--   Sessão C (que vai refatorar essas escritas pra escrever direto em
--   `place_profiles`), `profiles.lugares` vai voltar a ter dado órfão.
--
--   Quando isso acontecer, rodar esta migration reconcilia: copia o JSON
--   pra `place_profiles`, criando `places` canônicos quando necessário.
--
-- Idempotência:
--   - Pode rodar 1, 10 ou 100 vezes sem dano
--   - UNIQUE em place_profiles(place_id, profile_id, year_start) impede
--     duplicação via ON CONFLICT DO NOTHING
--   - Match em places via (lower(name), lower(city), COALESCE(state,'')) —
--     case-insensitive porque dados de teste mostraram inconsistências
--   - Se places existe → reusa o id; se não → cria com created_by do profile
--
-- O que NÃO faz:
--   - Não migra `place_label` (não existe no JSON, é feature F1.A.2 que só
--     ganha valor na Sessão C com `<CampoLugar>`)
--   - Não toca `profiles.lugares` depois de ler (drop column é da Sessão D)
--   - Não corrige `placeType` inválidos do JSON — apenas faz fallback pra
--     'outro' (lista controlada da F1.A.1)
--
-- Pré-requisitos:
--   - F1.A.0, 0.5, 1, 2 aplicadas (places hardened, place_profiles ganhou
--     place_label e label_visibilidade)
--   - F1.B.A1 aplicada (20260514_003_reset_profiles_lugares_residual.sql)
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: Verificação prévia
-- ──────────────────────────────────────────────────────────
-- Não aborta se vazio — só registra. Migration é guardrail.

DO $$
DECLARE
  profiles_com_dado INT;
  total_itens_pre INT;
  pp_pre INT;
  places_pre INT;
BEGIN
  SELECT COUNT(*) INTO profiles_com_dado
  FROM profiles
  WHERE lugares IS NOT NULL AND jsonb_array_length(lugares) > 0;

  SELECT COALESCE(SUM(jsonb_array_length(lugares)), 0) INTO total_itens_pre
  FROM profiles
  WHERE lugares IS NOT NULL;

  SELECT COUNT(*) INTO pp_pre FROM place_profiles;
  SELECT COUNT(*) INTO places_pre FROM places;

  RAISE NOTICE 'F1.B.A2 pré-estado: % profiles com lugares (% itens), % place_profiles, % places.',
    profiles_com_dado, total_itens_pre, pp_pre, places_pre;

  IF total_itens_pre = 0 THEN
    RAISE NOTICE 'F1.B.A2: nada pra migrar. Migration aplicada como no-op idempotente.';
  END IF;
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 2: Backfill (idempotente)
-- ──────────────────────────────────────────────────────────
-- Estratégia: CTE expansiva → match em places → insert/upsert.

DO $$
DECLARE
  prof_row RECORD;
  lugar_item JSONB;
  -- Campos extraídos
  v_name TEXT;
  v_city TEXT;
  v_state TEXT;
  v_country TEXT;
  v_lat DOUBLE PRECISION;
  v_lng DOUBLE PRECISION;
  v_type TEXT;
  v_y1 INT;
  v_y2 INT;
  v_era TEXT;
  -- Trabalho
  v_place_id UUID;
  -- Tipos permitidos (mantém em sincronia com F1.A.1)
  v_tipos_validos TEXT[] := ARRAY[
    'cidade', 'bairro', 'parque', 'escola', 'monumento',
    'mercado', 'igreja', 'trabalho', 'casa', 'outro'
  ];
  -- Contadores
  c_processados INT := 0;
  c_skipped_invalidos INT := 0;
  c_places_criados INT := 0;
  c_places_reusados INT := 0;
  c_pp_inseridos INT := 0;
  c_pp_ignorados INT := 0;
BEGIN
  -- Loop pelos profiles que têm lugares não-vazio
  FOR prof_row IN
    SELECT id, name, lugares
    FROM profiles
    WHERE lugares IS NOT NULL AND jsonb_array_length(lugares) > 0
  LOOP
    -- Loop pelos itens dentro do JSON
    FOR lugar_item IN SELECT * FROM jsonb_array_elements(prof_row.lugares)
    LOOP
      c_processados := c_processados + 1;

      -- Extrai campos com fallbacks defensivos
      v_name := NULLIF(TRIM(COALESCE(
        lugar_item ->> 'placeName',
        lugar_item ->> 'place_name',
        lugar_item ->> 'name',
        ''
      )), '');

      v_city := NULLIF(TRIM(COALESCE(lugar_item ->> 'city', '')), '');
      v_state := NULLIF(TRIM(COALESCE(
        lugar_item ->> 'uf',
        lugar_item ->> 'state',
        ''
      )), '');
      v_country := NULLIF(TRIM(COALESCE(
        lugar_item ->> 'pais',
        lugar_item ->> 'country',
        'Brasil'
      )), '');

      -- lat/lng: pode vir number ou ausente
      BEGIN
        v_lat := (lugar_item ->> 'lat')::DOUBLE PRECISION;
      EXCEPTION WHEN OTHERS THEN v_lat := NULL;
      END;
      BEGIN
        v_lng := (lugar_item ->> 'lng')::DOUBLE PRECISION;
      EXCEPTION WHEN OTHERS THEN v_lng := NULL;
      END;

      -- type: sanitiza pra lista controlada
      v_type := LOWER(TRIM(COALESCE(
        lugar_item ->> 'placeType',
        lugar_item ->> 'place_type',
        lugar_item ->> 'type',
        'outro'
      )));
      IF NOT (v_type = ANY (v_tipos_validos)) THEN
        v_type := 'outro';
      END IF;

      -- y1/y2: pode vir string ou int
      BEGIN
        v_y1 := (lugar_item ->> 'y1')::INT;
      EXCEPTION WHEN OTHERS THEN v_y1 := NULL;
      END;
      BEGIN
        v_y2 := (lugar_item ->> 'y2')::INT;
      EXCEPTION WHEN OTHERS THEN v_y2 := NULL;
      END;

      -- era: defaultando pra 'passado' se inválido
      v_era := LOWER(TRIM(COALESCE(lugar_item ->> 'era', 'passado')));
      IF v_era NOT IN ('passado', 'presente', 'futuro') THEN
        v_era := 'passado';
      END IF;

      -- Sanity check: precisa ter pelo menos name OU city pra valer
      IF v_name IS NULL AND v_city IS NULL THEN
        c_skipped_invalidos := c_skipped_invalidos + 1;
        RAISE NOTICE 'F1.B.A2 [profile=%, item=%]: SKIP (sem name e sem city)', prof_row.name, c_processados;
        CONTINUE;
      END IF;

      -- Se name vazio, usa city como fallback (cidade canônica)
      IF v_name IS NULL THEN
        v_name := v_city;
      END IF;

      -- ──────────────────────────────────────────
      -- Match em places (case-insensitive)
      -- ──────────────────────────────────────────
      SELECT id INTO v_place_id
      FROM places
      WHERE LOWER(name) = LOWER(v_name)
        AND LOWER(COALESCE(city, '')) = LOWER(COALESCE(v_city, ''))
        AND COALESCE(state, '') = COALESCE(v_state, '')
      LIMIT 1;

      IF v_place_id IS NOT NULL THEN
        c_places_reusados := c_places_reusados + 1;
      ELSE
        -- Cria places novo
        BEGIN
          INSERT INTO places (name, city, state, country, lat, lng, type, created_by)
          VALUES (v_name, v_city, v_state, v_country, v_lat, v_lng, v_type, prof_row.id)
          RETURNING id INTO v_place_id;
          c_places_criados := c_places_criados + 1;
          RAISE NOTICE 'F1.B.A2 [profile=%]: criou places "%" / % / % (id=%)',
            prof_row.name, v_name, v_city, v_state, v_place_id;
        EXCEPTION WHEN unique_violation THEN
          -- Race condition: alguém criou enquanto a gente buscava. Re-busca.
          SELECT id INTO v_place_id
          FROM places
          WHERE LOWER(name) = LOWER(v_name)
            AND LOWER(COALESCE(city, '')) = LOWER(COALESCE(v_city, ''))
            AND COALESCE(state, '') = COALESCE(v_state, '')
          LIMIT 1;
          c_places_reusados := c_places_reusados + 1;
        END;
      END IF;

      -- ──────────────────────────────────────────
      -- Upsert em place_profiles
      -- ──────────────────────────────────────────
      INSERT INTO place_profiles
        (place_id, profile_id, year_start, year_end, place_type, era)
      VALUES
        (v_place_id, prof_row.id, v_y1, v_y2, v_type, v_era)
      ON CONFLICT (place_id, profile_id, year_start) DO NOTHING;

      IF FOUND THEN
        c_pp_inseridos := c_pp_inseridos + 1;
      ELSE
        c_pp_ignorados := c_pp_ignorados + 1;
      END IF;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'F1.B.A2 RESUMO:';
  RAISE NOTICE '  Itens processados:       %', c_processados;
  RAISE NOTICE '  Skipped (inválidos):     %', c_skipped_invalidos;
  RAISE NOTICE '  Places reusados:         %', c_places_reusados;
  RAISE NOTICE '  Places criados:          %', c_places_criados;
  RAISE NOTICE '  place_profiles inseridos: %', c_pp_inseridos;
  RAISE NOTICE '  place_profiles ignorados (já existia): %', c_pp_ignorados;
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 3: Validação pós
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  pp_pos INT;
  places_pos INT;
BEGIN
  SELECT COUNT(*) INTO pp_pos FROM place_profiles;
  SELECT COUNT(*) INTO places_pos FROM places;
  RAISE NOTICE 'F1.B.A2 pós-estado: % place_profiles, % places.', pp_pos, places_pos;
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK (se necessário)
-- ============================================================
-- Esta migration é aditiva: só insere em places e place_profiles, nunca
-- modifica `profiles.lugares` ou outros dados existentes.
--
-- Rollback consiste em deletar os rows criados — mas como identifica?
-- Opção 1 (limpa todos os place_profiles criados desde uma timestamp):
--   DELETE FROM place_profiles WHERE created_at >= '<momento_do_apply>';
-- Opção 2 (reset completo, se F1.B Sessão C ainda não rodou):
--   TRUNCATE place_profiles;
--   DELETE FROM places WHERE created_by IS NOT NULL
--     AND created_at >= '<momento_do_apply>';
--
-- Backup completo disponível em:
-- `C:\tempnext\infra\backups\backup-20260511-143434\`
-- ============================================================
