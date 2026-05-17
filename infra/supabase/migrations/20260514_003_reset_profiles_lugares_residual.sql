-- ============================================================
-- F1.B.A1 — Limpeza de profiles.lugares residual pós-reset F0
-- ============================================================
--
-- Aplicado em: (preencher data ao executar)
-- Aplicado por: Josemar (via Supabase Dashboard SQL Editor)
-- Reversível: SIM (backup disponível em C:\tempnext\infra\backups\backup-20260511-143434\profiles.json)
--
-- Contexto:
--   Descoberto em 13/mai/2026 durante F1.B Sessão A1 (inventário de profiles.lugares).
--
--   Histórico:
--   - 11/mai/2026: F0 zerou conteúdo do banco (momentos, capsula_aguardando, notificações,
--     messages, contacts, place_profiles, etc) preservando 3 profiles reais.
--   - A migration `20260511_001_reset_to_3_real_profiles.sql` NÃO tocou a coluna
--     `profiles.lugares` (JSONB), deixando 15 itens de teste sujos lá dentro:
--       Josemar Nunes dos Reis (8e858623): 6 itens
--       Josemar Tempnext técnico (22863c75): 6 itens
--       Suzane Krewer (fa5654f1): 3 itens
--
--   Conteúdo residual analisado (sessão A1):
--   - Mistura de lugares legítimos (Primavera, Campo Verde, Canela) e de teste
--     (Casa em NY/Vegas, CEP "78850-000" como bairro, Lagoa Vó Pedro etc).
--   - placeType errados em vários itens (ex: "Catedral de Pedra" como cidade —
--     a F1.A.0.5 já corrigiu o canônico em `places`, mas o JSON dentro do profile
--     manteve o type velho).
--   - Schemas inconsistentes no JSON: alguns itens com y1/y2 como string, outros como int.
--
-- Decisão (Josemar, 14/mai/2026):
--   A intenção original do reset F0 era "começar do zero". Migrar dado de teste
--   pra `place_profiles` seria carregar lixo arquitetural pra frente. Big-tech:
--   completar o reset que ficou pela metade, antes de seguir com a deprecação.
--
-- Causa-raiz registrada:
--   Schemas relacionais com coluna JSON precisam de reset explícito da coluna —
--   não basta deletar de tabelas relacionadas. Lição pra futuros resets.
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: Verificação prévia — confirma cenário esperado
-- ──────────────────────────────────────────────────────────
-- Aborta se o cenário divergiu do diagnóstico de 14/mai.

DO $$
DECLARE
  total_profiles_com_lugares INT;
  total_itens_residuais INT;
  total_place_profiles INT;
BEGIN
  -- Conta profiles com lugares não-vazio
  SELECT COUNT(*) INTO total_profiles_com_lugares
  FROM profiles
  WHERE lugares IS NOT NULL
    AND jsonb_array_length(lugares) > 0;

  -- Soma total de itens dentro dos JSONs
  SELECT COALESCE(SUM(jsonb_array_length(lugares)), 0) INTO total_itens_residuais
  FROM profiles
  WHERE lugares IS NOT NULL;

  -- Confirma que place_profiles está vazio (pré-condição da decisão)
  SELECT COUNT(*) INTO total_place_profiles FROM place_profiles;

  IF total_profiles_com_lugares <> 3 THEN
    RAISE EXCEPTION 'F1.B.A1 ABORTADO: esperado 3 profiles com lugares não-vazio, encontrou %.', total_profiles_com_lugares;
  END IF;

  IF total_itens_residuais <> 15 THEN
    RAISE EXCEPTION 'F1.B.A1 ABORTADO: esperado 15 itens residuais em profiles.lugares, encontrou %. Banco mudou desde o diagnóstico — re-auditar.', total_itens_residuais;
  END IF;

  IF total_place_profiles <> 0 THEN
    RAISE EXCEPTION 'F1.B.A1 ABORTADO: place_profiles tem % rows, esperado 0. Algum save em produção entre o diagnóstico e agora? Investigar antes de prosseguir.', total_place_profiles;
  END IF;

  RAISE NOTICE 'F1.B.A1 verificação OK: 3 profiles com 15 itens residuais, place_profiles vazio.';
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 2: Limpeza — reset de profiles.lugares para array vazio
-- ──────────────────────────────────────────────────────────
-- Aplica apenas aos 3 profiles reais explicitamente.
-- Não usa "WHERE lugares IS NOT NULL" amplo por segurança defensiva.

UPDATE profiles
SET lugares = '[]'::jsonb
WHERE id IN (
  '8e858623-46d0-427d-932e-37bb5ab36cb7',  -- Josemar Nunes dos Reis
  '22863c75-4739-4ab7-b45d-009e543df4d8',  -- Josemar Tempnext técnico
  'fa5654f1-f68a-4ea3-8a80-62fc17d2e531'   -- Suzane Krewer
);

-- ──────────────────────────────────────────────────────────
-- Passo 3: Validação pós-aplicação
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  total_profiles INT;
  total_itens_pos INT;
  profiles_nao_vazios INT;
BEGIN
  SELECT COUNT(*) INTO total_profiles FROM profiles;

  SELECT COALESCE(SUM(jsonb_array_length(lugares)), 0) INTO total_itens_pos
  FROM profiles
  WHERE lugares IS NOT NULL;

  SELECT COUNT(*) INTO profiles_nao_vazios
  FROM profiles
  WHERE lugares IS NOT NULL
    AND jsonb_array_length(lugares) > 0;

  IF total_itens_pos <> 0 THEN
    RAISE EXCEPTION 'F1.B.A1 FALHOU: esperado 0 itens em profiles.lugares pós-limpeza, encontrou %.', total_itens_pos;
  END IF;

  IF profiles_nao_vazios <> 0 THEN
    RAISE EXCEPTION 'F1.B.A1 FALHOU: esperado 0 profiles com lugares não-vazio, encontrou %.', profiles_nao_vazios;
  END IF;

  RAISE NOTICE 'F1.B.A1 aplicado. profiles.lugares limpos. Total profiles: %, itens residuais: 0.', total_profiles;
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK (se necessário)
-- ============================================================
-- Restaurar `profiles.lugares` dos 3 IDs a partir de:
-- `C:\tempnext\infra\backups\backup-20260511-143434\profiles.json`
--
-- Snippet de rollback manual (executar profile por profile):
--   UPDATE profiles SET lugares = '<JSON_DO_BACKUP>'::jsonb WHERE id = '<UUID>';
--
-- Conteúdo residual também documentado em:
-- `06_Sessões/2026-05-13c - F1.B Sessão A1 Inventário lugares.md`
-- ============================================================
