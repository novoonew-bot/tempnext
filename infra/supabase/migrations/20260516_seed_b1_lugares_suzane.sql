-- ============================================================
-- F1.B.B1 SEED — Lugares de teste pra Suzane Krewer
-- ============================================================
--
-- Aplicado em: (preencher ao executar)
-- Aplicado por: Josemar (via Supabase Dashboard SQL Editor)
-- Reversível: SIM (DELETE no fim do arquivo)
--
-- Status: SEED DE TESTE. Não é migration de schema — popula dados
-- pra validar a Sessão B1 (refator de leituras de PerfilOutroFiltrado).
--
-- Contexto:
--   B1 migrou as leituras de lugares do perfil-de-outro pra place_profiles.
--   Validação no caminho vazio passou (Suzane sem lugares → "0 lugares").
--   Pra validar o caminho COM dado + o cruzamento, Suzane precisa de
--   lugares — sendo um deles sobreposto temporalmente com o Tempnext
--   técnico (que tem Primavera do Leste).
--
-- Dados inseridos pra Suzane (fa5654f1-f68a-4ea3-8a80-62fc17d2e531):
--   - Primavera do Leste (2e423547...) 2008-2014  → cruza c/ Tempnext técnico
--   - Campo Verde       (2467494f...) 2015-2020  → lugar só dela
--
-- ============================================================

BEGIN;

-- Verificação prévia
DO $$
DECLARE
  pp_suzane INT;
BEGIN
  SELECT COUNT(*) INTO pp_suzane
  FROM place_profiles
  WHERE profile_id = 'fa5654f1-f68a-4ea3-8a80-62fc17d2e531';

  RAISE NOTICE 'F1.B.B1 seed: Suzane tem % place_profiles antes do seed.', pp_suzane;
END $$;

-- Insere os 2 lugares de teste
INSERT INTO place_profiles
  (place_id, profile_id, year_start, year_end, place_type, era, display_order)
VALUES
  ('2e423547-e272-4a6e-b39d-8f270719585d', 'fa5654f1-f68a-4ea3-8a80-62fc17d2e531',
   2008, 2014, 'cidade', 'passado', 0),
  ('2467494f-1b56-4cc9-8f84-32d786f90f20', 'fa5654f1-f68a-4ea3-8a80-62fc17d2e531',
   2015, 2020, 'cidade', 'passado', 1)
ON CONFLICT (place_id, profile_id, year_start) DO NOTHING;

-- Validação pós
DO $$
DECLARE
  pp_suzane INT;
BEGIN
  SELECT COUNT(*) INTO pp_suzane
  FROM place_profiles
  WHERE profile_id = 'fa5654f1-f68a-4ea3-8a80-62fc17d2e531';

  RAISE NOTICE 'F1.B.B1 seed aplicado: Suzane agora tem % place_profiles.', pp_suzane;
END $$;

COMMIT;

-- ============================================================
-- ROLLBACK (remover o seed quando não precisar mais)
-- ============================================================
-- DELETE FROM place_profiles
-- WHERE profile_id = 'fa5654f1-f68a-4ea3-8a80-62fc17d2e531'
--   AND place_id IN (
--     '2e423547-e272-4a6e-b39d-8f270719585d',
--     '2467494f-1b56-4cc9-8f84-32d786f90f20'
--   );
-- ============================================================
