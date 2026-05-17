-- ============================================================
-- F1.A.1 — Hardening da tabela `places`
-- ============================================================
--
-- Aplicado em: (preencher data ao executar)
-- Aplicado por: Josemar (via Supabase Dashboard SQL Editor)
-- Reversível: SIM (rollback documentado no final)
--
-- Objetivo:
--   1. Prevenir duplicatas em `places` via UNIQUE INDEX (tolerante a NULL)
--   2. Restringir `places.type` a uma lista controlada de valores
--
-- Pré-requisitos:
--   - Banco em estado virgem após reset de 11/mai/2026 (places=13, todos únicos)
--   - Verificar duplicatas existentes com bloco de verificação abaixo
--
-- Por que UNIQUE INDEX e não UNIQUE CONSTRAINT:
--   PostgreSQL trata NULL como "diferente" em UNIQUE CONSTRAINT, então
--   "Cuiabá / MT" e "Cuiabá / NULL" passariam como entradas válidas.
--   COALESCE no INDEX trata NULL como string vazia, fechando esse vetor.
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: Verificação prévia (não modifica nada)
-- ──────────────────────────────────────────────────────────
-- Se retornar alguma linha, ABORTA antes de criar a constraint.
-- Espera-se: nenhuma linha.

DO $$
DECLARE
  duplicatas INT;
BEGIN
  SELECT COUNT(*) INTO duplicatas FROM (
    SELECT name, city, COALESCE(state, '') AS state_norm, COUNT(*) AS qtd
    FROM places
    GROUP BY name, city, COALESCE(state, '')
    HAVING COUNT(*) > 1
  ) dups;

  IF duplicatas > 0 THEN
    RAISE EXCEPTION 'F1.A.1 ABORTADO: % grupo(s) de duplicatas encontrado(s) em places. Resolver antes de aplicar.', duplicatas;
  END IF;

  RAISE NOTICE 'F1.A.1 verificação: 0 duplicatas. OK pra prosseguir.';
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 2: UNIQUE INDEX tolerante a NULL
-- ──────────────────────────────────────────────────────────

CREATE UNIQUE INDEX IF NOT EXISTS places_unique_name_city_state
  ON places (name, city, COALESCE(state, ''));

COMMENT ON INDEX places_unique_name_city_state IS
  'F1.A.1 - Previne duplicatas em places. COALESCE trata state NULL como string vazia.';

-- ──────────────────────────────────────────────────────────
-- Passo 3: CHECK constraint pra type controlado
-- ──────────────────────────────────────────────────────────
-- Lista alinhada com [[Lugares como entidade]].
-- Note: tabela vazia hoje, sem registros pra invalidar.

ALTER TABLE places
  ADD CONSTRAINT places_type_check
  CHECK (type IS NULL OR type IN (
    'cidade',
    'bairro',
    'parque',
    'escola',
    'monumento',
    'mercado',
    'igreja',
    'trabalho',
    'casa',
    'outro'
  ));

COMMENT ON CONSTRAINT places_type_check ON places IS
  'F1.A.1 - Restringe places.type a lista controlada. NULL permitido pra legado.';

-- ──────────────────────────────────────────────────────────
-- Passo 4: Validação pós-aplicação
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  total_places INT;
BEGIN
  SELECT COUNT(*) INTO total_places FROM places;
  RAISE NOTICE 'F1.A.1 aplicado. Total de places: %', total_places;
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK (se necessário)
-- ============================================================
-- Não executar abaixo no apply. Só em caso de reverter.
--
-- BEGIN;
--   ALTER TABLE places DROP CONSTRAINT IF EXISTS places_type_check;
--   DROP INDEX IF EXISTS places_unique_name_city_state;
-- COMMIT;
--
-- ============================================================
