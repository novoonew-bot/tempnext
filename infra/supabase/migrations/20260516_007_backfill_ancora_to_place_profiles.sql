-- ============================================================
-- F1.B.D9 — Backfill cidade-âncora (campos diretos do profile) → place_profiles
-- ============================================================
--
-- Aplicado em: (preencher data ao executar)
-- Aplicado por: Josemar (via Supabase Dashboard SQL Editor)
-- Reversível: SIM (rollback documentado no final)
--
-- Contexto:
--   Auditoria do pipeline de cruzamento (16/mai/2026) fechou a decisão de
--   produto "Opção B": a estadia principal de um profile NÃO é especial — é
--   apenas a primeira estadia. Hoje ela vive em campos diretos do profile
--   (profiles.city / state / place_name / year_start / year_end), texto livre,
--   SEM place_id. As estadias extras já vivem em place_profiles com place_id.
--
--   Essa assimetria quebra o cruzamento: tnMultGeo usa place_id como sinal
--   geográfico determinístico (P1/P2 da auditoria), mas a cidade-âncora — o
--   dado MAIS importante de cada perfil — não tem place_id e cai sempre nas
--   regras fracas de match por string.
--
--   Esta migration resolve definitivamente: copia a cidade-âncora de cada
--   profile para place_profiles como uma linha com display_order = 0 (a
--   primeira do perfil), criando o places canônico quando necessário. Depois
--   disso, TODA estadia tem place_id e o cruzamento é uniforme.
--
-- Decisão (Josemar, 16/mai/2026):
--   - Opção B sobre Opção A: não criar coluna place_id em profiles (seria 3a
--     fonte de verdade do mesmo dado). Centralizar tudo em place_profiles.
--   - A cidade-âncora entra com display_order = 0 (aparece no topo do perfil).
--   - place_type da linha-âncora: 'cidade' (a âncora é sempre a cidade onde
--     a pessoa mora/morou; não confundir com lugares específicos).
--   - era: detectada pelos anos (year_end no passado → 'passado', senão
--     'presente'); fallback 'presente' (a cidade-âncora costuma ser onde a
--     pessoa está agora).
--
-- Idempotência:
--   - Pode rodar 1, 10 ou 100 vezes sem dano.
--   - UNIQUE place_profiles(place_id, profile_id, year_start) + ON CONFLICT
--     DO NOTHING impede duplicação.
--   - Match em places via (lower(name), lower(city), COALESCE(state,'')) —
--     case-insensitive, mesmo critério da migration 004.
--
-- O que NÃO faz:
--   - Não toca os campos diretos do profile (profiles.city etc). O app
--     continua lendo eles até a Sessão D fazer o drop / parar de escrever.
--   - Não migra profiles.lugares (isso é a migration 004).
--
-- Pré-requisitos:
--   - F1.A.1, F1.A.2 aplicadas (places hardened; place_profiles com label)
--   - F1.B.C.0 aplicada (place_profiles tem display_order) — migration 005
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: Verificação prévia
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  col_display_order BOOL;
  profiles_com_ancora INT;
  pp_pre INT;
  places_pre INT;
BEGIN
  -- Garante que display_order existe (migration 005)
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'place_profiles'
      AND column_name = 'display_order'
  ) INTO col_display_order;

  IF NOT col_display_order THEN
    RAISE EXCEPTION 'F1.B.D9 ABORTADO: place_profiles.display_order não existe. Aplicar migration 005 primeiro.';
  END IF;

  SELECT COUNT(*) INTO profiles_com_ancora
  FROM profiles
  WHERE COALESCE(NULLIF(TRIM(city), ''), NULLIF(TRIM(place_name), '')) IS NOT NULL
    AND (year_start IS NOT NULL OR year_end IS NOT NULL);

  SELECT COUNT(*) INTO pp_pre FROM place_profiles;
  SELECT COUNT(*) INTO places_pre FROM places;

  RAISE NOTICE 'F1.B.D9 pré-estado: % profiles com cidade-âncora válida, % place_profiles, % places.',
    profiles_com_ancora, pp_pre, places_pre;
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 2: Backfill da cidade-âncora (idempotente)
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  prof_row RECORD;
  v_name TEXT;
  v_city TEXT;
  v_state TEXT;
  v_y1 INT;
  v_y2 INT;
  v_era TEXT;
  v_place_id UUID;
  c_processados INT := 0;
  c_skipped INT := 0;
  c_places_criados INT := 0;
  c_places_reusados INT := 0;
  c_pp_inseridos INT := 0;
  c_pp_ignorados INT := 0;
BEGIN
  FOR prof_row IN
    SELECT id, name, city, state, place_name, year_start, year_end
    FROM profiles
  LOOP
    c_processados := c_processados + 1;

    v_city  := NULLIF(TRIM(prof_row.city), '');
    v_state := NULLIF(TRIM(prof_row.state), '');
    -- Nome do places: place_name se existir, senão a própria cidade
    v_name  := COALESCE(NULLIF(TRIM(prof_row.place_name), ''), v_city);
    v_y1    := prof_row.year_start;
    v_y2    := prof_row.year_end;

    -- Precisa de referência geográfica E temporal pra valer como estadia
    IF v_name IS NULL OR (v_y1 IS NULL AND v_y2 IS NULL) THEN
      c_skipped := c_skipped + 1;
      CONTINUE;
    END IF;

    -- era: passado se year_end já passou; senão presente
    IF v_y2 IS NOT NULL AND v_y2 < EXTRACT(YEAR FROM CURRENT_DATE) THEN
      v_era := 'passado';
    ELSE
      v_era := 'presente';
    END IF;

    -- Match em places (case-insensitive, mesmo critério da migration 004)
    SELECT id INTO v_place_id
    FROM places
    WHERE LOWER(name) = LOWER(v_name)
      AND LOWER(COALESCE(city, '')) = LOWER(COALESCE(v_city, ''))
      AND COALESCE(state, '') = COALESCE(v_state, '')
    LIMIT 1;

    IF v_place_id IS NOT NULL THEN
      c_places_reusados := c_places_reusados + 1;
    ELSE
      BEGIN
        INSERT INTO places (name, city, state, country, type, created_by)
        VALUES (v_name, v_city, v_state, 'Brasil', 'cidade', prof_row.id)
        RETURNING id INTO v_place_id;
        c_places_criados := c_places_criados + 1;
        RAISE NOTICE 'F1.B.D9 [profile=%]: criou places "%" / % / % (id=%)',
          prof_row.name, v_name, v_city, v_state, v_place_id;
      EXCEPTION WHEN unique_violation THEN
        SELECT id INTO v_place_id
        FROM places
        WHERE LOWER(name) = LOWER(v_name)
          AND LOWER(COALESCE(city, '')) = LOWER(COALESCE(v_city, ''))
          AND COALESCE(state, '') = COALESCE(v_state, '')
        LIMIT 1;
        c_places_reusados := c_places_reusados + 1;
      END;
    END IF;

    -- Insert da linha-âncora em place_profiles com display_order = 0
    INSERT INTO place_profiles
      (place_id, profile_id, year_start, year_end, place_type, era, display_order)
    VALUES
      (v_place_id, prof_row.id, v_y1, v_y2, 'cidade', v_era, 0)
    ON CONFLICT (place_id, profile_id, year_start) DO NOTHING;

    IF FOUND THEN
      c_pp_inseridos := c_pp_inseridos + 1;
    ELSE
      c_pp_ignorados := c_pp_ignorados + 1;
    END IF;
  END LOOP;

  RAISE NOTICE 'F1.B.D9 RESUMO:';
  RAISE NOTICE '  Profiles processados:    %', c_processados;
  RAISE NOTICE '  Skipped (sem geo/tempo): %', c_skipped;
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
  ancoras INT;
BEGIN
  SELECT COUNT(*) INTO pp_pos FROM place_profiles;
  SELECT COUNT(*) INTO places_pos FROM places;
  SELECT COUNT(*) INTO ancoras FROM place_profiles WHERE display_order = 0;
  RAISE NOTICE 'F1.B.D9 pós-estado: % place_profiles (% com display_order=0), % places.',
    pp_pos, ancoras, places_pos;
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK (se necessário)
-- ============================================================
-- Esta migration é aditiva: só insere em places e place_profiles.
--
-- BEGIN;
--   -- Remove as linhas-âncora criadas (display_order = 0, type = 'cidade').
--   -- CUIDADO: se o usuário já reordenou lugares manualmente, outras linhas
--   -- podem ter display_order = 0 também. Filtrar por created_at é mais seguro:
--   DELETE FROM place_profiles
--     WHERE display_order = 0 AND place_type = 'cidade'
--       AND created_at >= '<momento_do_apply>';
--   -- Places órfãos criados aqui (sem outras place_profiles apontando):
--   DELETE FROM places p
--     WHERE p.type = 'cidade'
--       AND p.created_at >= '<momento_do_apply>'
--       AND NOT EXISTS (SELECT 1 FROM place_profiles pp WHERE pp.place_id = p.id);
-- COMMIT;
--
-- Backup completo: C:\tempnext\infra\backups\backup-20260511-143434\
-- ============================================================
