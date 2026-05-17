-- ============================================================
-- F1.A.0.5 — Normalização de types em `places` pré-hardening
-- ============================================================
--
-- Aplicado em: (preencher data ao executar)
-- Aplicado por: Josemar (via Supabase Dashboard SQL Editor)
-- Reversível: SIM (rollback documentado no final)
--
-- Contexto:
--   Descoberto em 13/mai/2026 ao tentar aplicar F1.A.1.
--   CHECK constraint em `type` falhou porque 3 lugares estavam mal classificados:
--
--     1. "78850-000" (CEP de Primavera do Leste) marcado como `bairro`
--        → na verdade é um CEP, não bairro. Mover pra `outro`.
--
--     2. "Campo Verde" marcado como `escola`
--        → Campo Verde é cidade (município de MT, vizinha de Primavera).
--          Foi mal classificado. Mover pra `cidade`.
--
--     3. "Catedral de Pedra" marcado como `cidade`
--        → atração turística de Canela-RS. Não é cidade.
--          Mover pra `monumento`.
--
--   + 1 lugar com type `trabalho` (Cotrimac):
--     → será aceito como categoria válida (lista expandida em F1.A.1).
--        Não precisa normalizar aqui.
--
-- Pré-requisitos:
--   - F1.A.0 aplicada (dedup de Primavera do Leste)
--   - Banco com 11 places hoje
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: Verificação prévia
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  esperado_cep INT;
  esperado_campo_verde INT;
  esperado_catedral INT;
BEGIN
  SELECT COUNT(*) INTO esperado_cep
  FROM places WHERE name = '78850-000' AND type = 'bairro';

  SELECT COUNT(*) INTO esperado_campo_verde
  FROM places WHERE name = 'Campo Verde' AND type = 'escola';

  SELECT COUNT(*) INTO esperado_catedral
  FROM places WHERE name = 'Catedral de Pedra' AND type = 'cidade';

  IF esperado_cep <> 1 THEN
    RAISE EXCEPTION 'F1.A.0.5 ABORTADO: esperado 1 place "78850-000" com type=bairro, encontrou %.', esperado_cep;
  END IF;

  IF esperado_campo_verde <> 1 THEN
    RAISE EXCEPTION 'F1.A.0.5 ABORTADO: esperado 1 place "Campo Verde" com type=escola, encontrou %.', esperado_campo_verde;
  END IF;

  IF esperado_catedral <> 1 THEN
    RAISE EXCEPTION 'F1.A.0.5 ABORTADO: esperado 1 place "Catedral de Pedra" com type=cidade, encontrou %.', esperado_catedral;
  END IF;

  RAISE NOTICE 'F1.A.0.5 verificação: 3 lugares mal classificados confirmados. OK pra normalizar.';
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 2: Normalização
-- ──────────────────────────────────────────────────────────

-- "78850-000" (CEP) bairro → outro
UPDATE places
SET type = 'outro'
WHERE name = '78850-000' AND type = 'bairro';

-- "Campo Verde" escola → cidade
UPDATE places
SET type = 'cidade'
WHERE name = 'Campo Verde' AND type = 'escola';

-- "Catedral de Pedra" cidade → monumento
UPDATE places
SET type = 'monumento'
WHERE name = 'Catedral de Pedra' AND type = 'cidade';

-- ──────────────────────────────────────────────────────────
-- Passo 3: Validação pós-aplicação
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  agora_cep_outro INT;
  agora_campo_verde_cidade INT;
  agora_catedral_monumento INT;
  total_places INT;
BEGIN
  SELECT COUNT(*) INTO agora_cep_outro
  FROM places WHERE name = '78850-000' AND type = 'outro';

  SELECT COUNT(*) INTO agora_campo_verde_cidade
  FROM places WHERE name = 'Campo Verde' AND type = 'cidade';

  SELECT COUNT(*) INTO agora_catedral_monumento
  FROM places WHERE name = 'Catedral de Pedra' AND type = 'monumento';

  SELECT COUNT(*) INTO total_places FROM places;

  IF agora_cep_outro <> 1 OR agora_campo_verde_cidade <> 1 OR agora_catedral_monumento <> 1 THEN
    RAISE EXCEPTION 'F1.A.0.5 FALHOU: validação não bateu (cep_outro=%, campo_verde_cidade=%, catedral_monumento=%).',
      agora_cep_outro, agora_campo_verde_cidade, agora_catedral_monumento;
  END IF;

  RAISE NOTICE 'F1.A.0.5 aplicado. 3 lugares normalizados. Total places: % (não mudou).', total_places;
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK (se necessário)
-- ============================================================
--
-- BEGIN;
--   UPDATE places SET type = 'bairro' WHERE name = '78850-000' AND type = 'outro';
--   UPDATE places SET type = 'escola' WHERE name = 'Campo Verde' AND type = 'cidade';
--   UPDATE places SET type = 'cidade' WHERE name = 'Catedral de Pedra' AND type = 'monumento';
-- COMMIT;
--
-- ============================================================
