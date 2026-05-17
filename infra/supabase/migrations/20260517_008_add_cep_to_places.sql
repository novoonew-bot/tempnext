-- ============================================================
-- F1.B.D9 — Adiciona `cep` à tabela places + backfill do JSONB legado
-- ============================================================
--
-- Aplicado em: (preencher data ao executar)
-- Aplicado por: Josemar (via Supabase Dashboard SQL Editor)
-- Reversível: SIM (rollback no final — DROP COLUMN)
--
-- Contexto:
--   A busca por CEP (Sessão D, auditoria 17/mai) ainda lê `profiles.lugares`
--   (JSONB legado) porque o CEP nunca existiu no schema canônico. Para a
--   Sessão D poder dropar `profiles.lugares`, o CEP precisa de uma casa nova.
--
-- Decisão de design (Josemar, 17/mai):
--   O CEP é propriedade FÍSICA do lugar, não da relação pessoa-lugar — duas
--   pessoas no mesmo lugar têm o mesmo CEP. Logo a coluna `cep` vai em
--   `places`, NÃO em `place_profiles`. Os helpers tnLugaresDoProfile /
--   tnLugaresDeProfiles passam a expor `cep: places.cep`.
--
-- O que faz:
--   1. Adiciona places.cep (TEXT, nullable — nem todo lugar tem/precisa).
--   2. Backfill: varre profiles.lugares (JSONB), e para cada entrada com cep,
--      casa o lugar correspondente em places (por nome+cidade) e grava o cep
--      lá, se places.cep ainda estiver vazio.
--
-- Idempotência:
--   - ADD COLUMN IF NOT EXISTS — rodar 2x não dói.
--   - Backfill só escreve onde places.cep IS NULL — não sobrescreve.
--
-- Pré-requisitos:
--   - F1.A (places existe), F1.B.D9.007 (cidade-âncora migrada) aplicadas.
--   - profiles.lugares ainda existe (esta migration roda ANTES do drop).
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: Adiciona a coluna
-- ──────────────────────────────────────────────────────────

ALTER TABLE places ADD COLUMN IF NOT EXISTS cep TEXT;

COMMENT ON COLUMN places.cep IS
  'CEP do lugar (8 dígitos, pode ter máscara). Propriedade física do lugar. F1.B.D9.';

-- ──────────────────────────────────────────────────────────
-- Passo 2: Verificação prévia
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  profiles_com_lugares INT;
  places_pre INT;
BEGIN
  SELECT COUNT(*) INTO profiles_com_lugares
  FROM profiles
  WHERE lugares IS NOT NULL AND jsonb_array_length(lugares) > 0;

  SELECT COUNT(*) INTO places_pre FROM places WHERE cep IS NOT NULL;

  RAISE NOTICE 'F1.B.D9.008 pré-estado: % profiles com lugares JSONB, % places já com cep.',
    profiles_com_lugares, places_pre;
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 3: Backfill do CEP a partir do JSONB legado
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  prof_row RECORD;
  lugar JSONB;
  v_cep TEXT;
  v_nome TEXT;
  v_city TEXT;
  c_lugares_vistos INT := 0;
  c_com_cep INT := 0;
  c_places_atualizados INT := 0;
  c_sem_match INT := 0;
BEGIN
  FOR prof_row IN
    SELECT id, name, lugares
    FROM profiles
    WHERE lugares IS NOT NULL AND jsonb_array_length(lugares) > 0
  LOOP
    FOR lugar IN SELECT * FROM jsonb_array_elements(prof_row.lugares)
    LOOP
      c_lugares_vistos := c_lugares_vistos + 1;

      v_cep := NULLIF(TRIM(COALESCE(lugar->>'cep', '')), '');
      IF v_cep IS NULL THEN
        CONTINUE;  -- sem cep nesse lugar, pula
      END IF;
      c_com_cep := c_com_cep + 1;

      -- nome do lugar: placeName, senão city
      v_nome := NULLIF(TRIM(COALESCE(lugar->>'placeName', '')), '');
      v_city := NULLIF(TRIM(COALESCE(lugar->>'city', '')), '');
      IF v_nome IS NULL THEN v_nome := v_city; END IF;
      IF v_nome IS NULL THEN
        c_sem_match := c_sem_match + 1;
        CONTINUE;
      END IF;

      -- Casa em places por nome+cidade (case-insensitive). Atualiza só se cep vazio.
      UPDATE places p
      SET cep = v_cep
      WHERE LOWER(p.name) = LOWER(v_nome)
        AND LOWER(COALESCE(p.city, '')) = LOWER(COALESCE(v_city, ''))
        AND p.cep IS NULL;

      IF FOUND THEN
        c_places_atualizados := c_places_atualizados + 1;
        RAISE NOTICE 'F1.B.D9.008 [%]: cep % -> place "%" / %',
          prof_row.name, v_cep, v_nome, v_city;
      ELSE
        c_sem_match := c_sem_match + 1;
      END IF;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'F1.B.D9.008 RESUMO:';
  RAISE NOTICE '  Lugares JSONB vistos:    %', c_lugares_vistos;
  RAISE NOTICE '  Com cep no JSONB:        %', c_com_cep;
  RAISE NOTICE '  Places atualizados:      %', c_places_atualizados;
  RAISE NOTICE '  Sem match / já tinha cep: %', c_sem_match;
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 4: Validação pós
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  places_com_cep INT;
BEGIN
  SELECT COUNT(*) INTO places_com_cep FROM places WHERE cep IS NOT NULL;
  RAISE NOTICE 'F1.B.D9.008 pós-estado: % places com cep.', places_com_cep;
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK (se necessário)
-- ============================================================
-- BEGIN;
--   ALTER TABLE places DROP COLUMN IF EXISTS cep;
-- COMMIT;
--
-- Backup: C:\tempnext\infra\backups\backup-20260517-040956-pre007\
-- ============================================================
