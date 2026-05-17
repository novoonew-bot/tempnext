-- ============================================================
-- F1.A.0 — Dedup pré-hardening: consolidar Primavera do Leste
-- ============================================================
--
-- Aplicado em: (preencher data ao executar)
-- Aplicado por: Josemar (via Supabase Dashboard SQL Editor)
-- Reversível: PARCIAL (delete não é reversível sem backup)
--
-- Contexto:
--   Descoberto em 13/mai/2026 ao tentar aplicar F1.A.1.
--   Tabela `places` tem 3 entradas idênticas pra "Primavera do Leste":
--     - 07eff635-aa3d-4fd4-a742-fcc1bd8db58e (created_by = Suzane)
--     - 2e423547-e272-4a6e-b39d-8f270719585d (created_by = NULL)         ← canônico
--     - 925df453-c221-4d30-ad73-6bcde8571cbf (created_by = Josemar dev)
--
--   Banco zerado em 11/mai (place_profiles=0, momentos=0, followed_places=0)
--   então nenhuma dependência aponta pra esses IDs.
--
-- Estratégia:
--   Manter o de `created_by NULL` como canônico (semântica de lugar público
--   sem dono específico) e deletar os outros 2.
--
-- Backup disponível:
--   `C:\tempnext\infra\backups\backup-20260511-143434\` (snapshot pré-reset)
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: Verificação prévia — confirma cenário esperado
-- ──────────────────────────────────────────────────────────
-- Aborta se algo divergiu desde o diagnóstico.

DO $$
DECLARE
  total_primavera INT;
  vinculos_pp INT;
BEGIN
  SELECT COUNT(*) INTO total_primavera
  FROM places
  WHERE name = 'Primavera do Leste'
    AND city = 'Primavera do Leste'
    AND state = 'MT';

  IF total_primavera <> 3 THEN
    RAISE EXCEPTION 'F1.A.0 ABORTADO: esperado 3 places "Primavera do Leste / MT", encontrou %.', total_primavera;
  END IF;

  SELECT COUNT(*) INTO vinculos_pp
  FROM place_profiles
  WHERE place_id IN (
    '07eff635-aa3d-4fd4-a742-fcc1bd8db58e',
    '925df453-c221-4d30-ad73-6bcde8571cbf'
  );

  IF vinculos_pp > 0 THEN
    RAISE EXCEPTION 'F1.A.0 ABORTADO: % vínculo(s) em place_profiles apontam para IDs a deletar. Reapontar primeiro.', vinculos_pp;
  END IF;

  RAISE NOTICE 'F1.A.0 verificação: 3 places "Primavera do Leste", 0 vínculos. OK pra prosseguir.';
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 2: Delete dos 2 IDs redundantes
-- ──────────────────────────────────────────────────────────
-- Mantém: 2e423547-e272-4a6e-b39d-8f270719585d (created_by NULL, canônico)

DELETE FROM places
WHERE id IN (
  '07eff635-aa3d-4fd4-a742-fcc1bd8db58e',
  '925df453-c221-4d30-ad73-6bcde8571cbf'
);

-- ──────────────────────────────────────────────────────────
-- Passo 3: Validação pós-aplicação
-- ──────────────────────────────────────────────────────────

DO $$
DECLARE
  total_primavera INT;
  total_places INT;
BEGIN
  SELECT COUNT(*) INTO total_primavera
  FROM places
  WHERE name = 'Primavera do Leste'
    AND city = 'Primavera do Leste'
    AND state = 'MT';

  SELECT COUNT(*) INTO total_places FROM places;

  IF total_primavera <> 1 THEN
    RAISE EXCEPTION 'F1.A.0 FALHOU: esperado 1 place "Primavera do Leste" após delete, encontrou %.', total_primavera;
  END IF;

  RAISE NOTICE 'F1.A.0 aplicado. Places "Primavera do Leste": % (era 3). Total places: % (era 13).', total_primavera, total_places;
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK (se necessário, manual via backup)
-- ============================================================
-- Os 2 IDs deletados estavam idênticos ao canônico (mesma name/city/state).
-- Reconstituir só faria sentido se algum vínculo externo tivesse o ID exato,
-- o que NÃO é o caso (place_profiles=0, momentos=0, followed_places=0).
--
-- Em caso de necessidade futura, restaurar de:
-- `C:\tempnext\infra\backups\backup-20260511-143434\places.json`
--
-- ============================================================
