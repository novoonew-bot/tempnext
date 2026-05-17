-- ============================================================
-- F1.B.D — Drop da coluna profiles.lugares (JSONB legado)
-- ============================================================
--
-- Aplicado em: (preencher ao executar)
-- Aplicado por: Josemar (Supabase Dashboard SQL Editor)
-- Reversível: PARCIALMENTE — ver rollback no final.
--
-- Contexto:
--   Última peça da F1.B. O JSONB profiles.lugares foi a fonte legada de
--   lugares. F1.A criou places + place_profiles (canônico); F1.B migrou
--   TODAS as leituras (B1/B2/B3 + calcularCruzamento + Sessão D) e parou
--   todas as escritas. As migrations 004 e 007 moveram os dados para
--   place_profiles. A coluna agora é peso morto.
--
-- Pré-requisitos (TODOS já cumpridos):
--   - Migrations 004, 007, 008 aplicadas.
--   - Código da Sessão D em produção / validado: zero leitura e zero
--     escrita viva de profiles.lugares (auditoria 17/mai).
--   - Backup: backup-20260517-040956-pre007.
--
-- Segurança:
--   Passo 1 é uma verificação que ABORTA se encontrar algum lugar no JSONB
--   que NÃO tenha correspondente em place_profiles. Só dropa se a migração
--   estiver 100% completa. Se abortar, NÃO dropa nada — investigar antes.
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: Verificação de segurança — todo lugar do JSONB tem
--          correspondente em place_profiles?
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  col_existe BOOL;
  profiles_com_jsonb INT;
  lugares_jsonb_total INT;
  orfaos INT := 0;
  prof_row RECORD;
  lugar JSONB;
  v_nome TEXT;
  v_city TEXT;
  v_y1 INT;
  achou INT;
BEGIN
  -- A coluna ainda existe?
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='lugares'
  ) INTO col_existe;

  IF NOT col_existe THEN
    RAISE NOTICE 'F1.B.D: coluna profiles.lugares já não existe. Nada a fazer.';
    RETURN;
  END IF;

  SELECT COUNT(*) INTO profiles_com_jsonb
  FROM profiles
  WHERE lugares IS NOT NULL AND jsonb_array_length(lugares) > 0;

  RAISE NOTICE 'F1.B.D verificação: % profiles ainda têm lugares no JSONB.', profiles_com_jsonb;

  -- Para cada lugar no JSONB, confere se existe linha equivalente em place_profiles
  -- (match por profile + ano de início; nome do lugar é tolerante).
  lugares_jsonb_total := 0;
  FOR prof_row IN
    SELECT id, name, lugares FROM profiles
    WHERE lugares IS NOT NULL AND jsonb_array_length(lugares) > 0
  LOOP
    FOR lugar IN SELECT * FROM jsonb_array_elements(prof_row.lugares)
    LOOP
      lugares_jsonb_total := lugares_jsonb_total + 1;
      v_y1 := NULLIF(TRIM(COALESCE(lugar->>'y1','')), '')::INT;
      v_city := LOWER(NULLIF(TRIM(COALESCE(lugar->>'city','')), ''));

      -- Procura em place_profiles uma linha do mesmo profile com mesmo ano de início
      SELECT COUNT(*) INTO achou
      FROM place_profiles pp
      JOIN places p ON p.id = pp.place_id
      WHERE pp.profile_id = prof_row.id
        AND (
          pp.year_start = v_y1
          OR (v_y1 IS NULL AND pp.year_start IS NULL)
        );

      IF achou = 0 THEN
        orfaos := orfaos + 1;
        RAISE NOTICE 'F1.B.D ÓRFÃO: [%] lugar "%" (city=%, y1=%) sem correspondente em place_profiles.',
          prof_row.name, COALESCE(lugar->>'placeName', lugar->>'city', '?'), v_city, v_y1;
      END IF;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'F1.B.D verificação: % lugares no JSONB, % órfãos (sem correspondente no canônico).',
    lugares_jsonb_total, orfaos;

  IF orfaos > 0 THEN
    RAISE EXCEPTION 'F1.B.D ABORTADO: % lugar(es) do JSONB não foram migrados para place_profiles. NADA foi dropado. Investigar os ÓRFÃOS acima antes de tentar de novo.', orfaos;
  END IF;

  RAISE NOTICE 'F1.B.D verificação OK: todo lugar do JSONB tem correspondente. Seguro dropar.';
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 2: Drop da coluna
-- ──────────────────────────────────────────────────────────

ALTER TABLE profiles DROP COLUMN IF EXISTS lugares;

DO $$
BEGIN
  RAISE NOTICE 'F1.B.D: coluna profiles.lugares removida. F1.B FECHADA.';
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK
-- ============================================================
-- O DROP COLUMN remove a coluna E os dados nela. Recriar a coluna é
-- trivial, mas os dados JSONB só voltam restaurando o backup:
--   backup-20260517-040956-pre007  (profiles.json)
--
-- Recriar a coluna vazia (estrutura apenas):
--   BEGIN;
--     ALTER TABLE profiles ADD COLUMN IF NOT EXISTS lugares JSONB;
--   COMMIT;
--
-- Restaurar os dados: reimportar profiles.json do backup pré-007.
-- Mas note: a verificação do Passo 1 garante que o dado já está em
-- place_profiles — então restaurar o JSONB normalmente não é necessário.
-- ============================================================
