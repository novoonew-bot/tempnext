-- ============================================================
-- F1.A.2 — Lugar pessoal em `place_profiles`
-- ============================================================
--
-- Aplicado em: (preencher data ao executar)
-- Aplicado por: Josemar (via Supabase Dashboard SQL Editor)
-- Reversível: SIM (rollback documentado no final)
--
-- Objetivo:
--   1. Adicionar `place_label` (rótulo afetivo) em place_profiles
--   2. Adicionar `label_visibilidade` pra controle de exposição do rótulo
--
-- Caso de uso:
--   Usuário vincula a "Cuiabá" (lugar canônico, público)
--   E adiciona rótulo pessoal "Casa da minha avó" (privado por padrão)
--   Outras pessoas que cruzam Cuiabá veem o rótulo conforme visibilidade
--
-- Pré-requisitos:
--   - F1.A.1 não é dependência (migrations são independentes)
--   - place_profiles existe (já existe no schema)
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: Adicionar place_label (TEXT, NULL permitido)
-- ──────────────────────────────────────────────────────────

ALTER TABLE place_profiles
  ADD COLUMN IF NOT EXISTS place_label TEXT;

COMMENT ON COLUMN place_profiles.place_label IS
  'F1.A.2 - Rótulo afetivo do usuário pro lugar (ex: "Casa da minha avó"). NULL = usa name canônico do places.';

-- ──────────────────────────────────────────────────────────
-- Passo 2: Adicionar label_visibilidade
-- ──────────────────────────────────────────────────────────
-- 4 níveis alinhados com capsula_visibilidade.

ALTER TABLE place_profiles
  ADD COLUMN IF NOT EXISTS label_visibilidade TEXT DEFAULT 'privado'
    CHECK (label_visibilidade IN (
      'publico',
      'contatos',
      'familia',
      'privado'
    ));

COMMENT ON COLUMN place_profiles.label_visibilidade IS
  'F1.A.2 - Quem pode ver o place_label. Default privado.';

-- ──────────────────────────────────────────────────────────
-- Passo 3: Validação pós-aplicação
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  total INT;
  com_label INT;
BEGIN
  SELECT COUNT(*) INTO total FROM place_profiles;
  SELECT COUNT(*) INTO com_label FROM place_profiles WHERE place_label IS NOT NULL;

  RAISE NOTICE 'F1.A.2 aplicado. Total place_profiles: %, com place_label: %', total, com_label;
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK (se necessário)
-- ============================================================
-- Não executar abaixo no apply. Só em caso de reverter.
--
-- BEGIN;
--   ALTER TABLE place_profiles DROP COLUMN IF EXISTS label_visibilidade;
--   ALTER TABLE place_profiles DROP COLUMN IF EXISTS place_label;
-- COMMIT;
--
-- ============================================================
