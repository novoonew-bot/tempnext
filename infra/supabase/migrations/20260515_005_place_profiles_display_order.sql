-- ============================================================
-- F1.B.C.0 — place_profiles ganha display_order
-- ============================================================
--
-- Aplicado em: (preencher data ao executar)
-- Aplicado por: Josemar (via Supabase Dashboard SQL Editor)
-- Reversível: SIM (ALTER TABLE place_profiles DROP COLUMN display_order;)
--
-- Contexto:
--   Sessão C da F1.B vai migrar a escrita de "reordenação manual de lugares
--   no perfil" do legado `profiles.lugares` (array JSON com ordem implícita
--   pela posição) pra `place_profiles` (linhas relacionais sem ordem definida).
--
--   Sem coluna explícita de ordem, o usuário perde o controle manual de
--   "qual lugar aparece primeiro no meu perfil". Big-tech: schema deve
--   expressar a intenção do usuário, não inferir por timestamp.
--
-- Decisão (Josemar, 15/mai/2026):
--   Adicionar `display_order INT` em `place_profiles`:
--   - NOT NULL
--   - DEFAULT 0
--   - Pode ser negativo (futuros usos: "fixar no topo" = order = -1)
--   - Ordenação canônica: ORDER BY display_order ASC, year_start ASC, created_at ASC
--     (display_order primeiro; tie-break por year_start; tie-break final por created_at)
--   - Não tem UNIQUE constraint — múltiplos lugares podem compartilhar a mesma
--     ordem (ex: vários novos lugares chegam com 0 antes do usuário reordenar)
--
-- Pré-requisitos:
--   - F1.A.1, F1.A.2 aplicadas (place_profiles existe com place_label e label_visibilidade)
--   - F1.B.A1 aplicada (profiles.lugares zerado)
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: Verificação prévia
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  col_exists BOOL;
  total_rows INT;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'place_profiles'
      AND column_name = 'display_order'
  ) INTO col_exists;

  SELECT COUNT(*) INTO total_rows FROM place_profiles;

  IF col_exists THEN
    RAISE EXCEPTION 'F1.B.C.0 ABORTADO: place_profiles.display_order já existe.';
  END IF;

  RAISE NOTICE 'F1.B.C.0 verificação OK: column ainda não existe. % rows em place_profiles.', total_rows;
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 2: ALTER TABLE adicionando display_order
-- ──────────────────────────────────────────────────────────
-- DEFAULT 0 garante que rows novos entrem ordenados naturalmente.
-- NOT NULL impede esquecimento em escritas futuras.

ALTER TABLE place_profiles
  ADD COLUMN display_order INT NOT NULL DEFAULT 0;

-- ──────────────────────────────────────────────────────────
-- Passo 3: Índice pra ordenação rápida
-- ──────────────────────────────────────────────────────────
-- Suporta o padrão de query `WHERE profile_id = X ORDER BY display_order`.
-- Índice composto (profile_id, display_order) cobre o caso mais comum.

CREATE INDEX IF NOT EXISTS idx_place_profiles_profile_order
  ON place_profiles (profile_id, display_order);

-- ──────────────────────────────────────────────────────────
-- Passo 4: Validação pós
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  col_data_type TEXT;
  col_default TEXT;
  col_nullable TEXT;
  idx_exists BOOL;
BEGIN
  SELECT data_type, column_default, is_nullable
    INTO col_data_type, col_default, col_nullable
  FROM information_schema.columns
  WHERE table_schema = 'public'
    AND table_name = 'place_profiles'
    AND column_name = 'display_order';

  SELECT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename = 'place_profiles'
      AND indexname = 'idx_place_profiles_profile_order'
  ) INTO idx_exists;

  IF col_data_type IS NULL THEN
    RAISE EXCEPTION 'F1.B.C.0 FALHOU: column display_order não foi criada.';
  END IF;

  IF col_data_type <> 'integer' THEN
    RAISE EXCEPTION 'F1.B.C.0 FALHOU: tipo esperado integer, recebido %.', col_data_type;
  END IF;

  IF col_nullable <> 'NO' THEN
    RAISE EXCEPTION 'F1.B.C.0 FALHOU: column não está NOT NULL.';
  END IF;

  IF NOT idx_exists THEN
    RAISE EXCEPTION 'F1.B.C.0 FALHOU: índice idx_place_profiles_profile_order não foi criado.';
  END IF;

  RAISE NOTICE 'F1.B.C.0 aplicado. display_order INT NOT NULL DEFAULT 0 + índice (profile_id, display_order).';
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK (se necessário)
-- ============================================================
-- BEGIN;
--   DROP INDEX IF EXISTS idx_place_profiles_profile_order;
--   ALTER TABLE place_profiles DROP COLUMN display_order;
-- COMMIT;
--
-- Seguro de aplicar enquanto place_profiles estiver vazio. Após uso,
-- rollback faz perder ordenação manual existente (mas dado principal preservado).
-- ============================================================
