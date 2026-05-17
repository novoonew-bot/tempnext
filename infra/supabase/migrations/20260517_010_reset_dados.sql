-- ============================================================
-- 010 — RESET DE DADOS (zera conteúdo, preserva schema)
-- ============================================================
--
-- Aplicado em: (preencher ao executar)
-- Aplicado por: Josemar (Supabase Dashboard SQL Editor)
-- Reversível: NÃO automaticamente — ver rollback no final.
--
-- ⚠️ AÇÃO DESTRUTIVA E IRREVERSÍVEL ⚠️
--
-- Contexto:
--   Todo o conteúdo do banco até aqui foi material de teste/desenvolvimento
--   (profiles do Josemar e da Suzane, lugares, momentos, etc.). Decisão de
--   Jo (17/mai/2026): zerar 100% para recomeçar com dados reais a partir do
--   primeiro usuário público.
--
-- O que esta migration FAZ:
--   - Esvazia as 17 tabelas de conteúdo gerado por usuários.
--   - Usa TRUNCATE ... CASCADE: ignora ordem de FK e zera tudo de uma vez.
--   - RESTART IDENTITY: zera contadores de colunas serial/identity.
--
-- O que esta migration NÃO toca (preservado de propósito):
--   - Schema: tabelas, colunas, constraints, índices — intactos.
--   - RLS: policies de segurança — intactas.
--   - Migrations anteriores (000–009) — intactas.
--   - Caches de infraestrutura: place_suggestions_cache, cep_index —
--     não são dados de usuário, ficam.
--   - auth.users (contas de login Google) — ver nota crítica abaixo.
--
-- ⚠️ NOTA CRÍTICA — auth.users:
--   Esta migration NÃO apaga auth.users (a tabela de autenticação do
--   Supabase). Isso significa que as contas Google que já fizeram login
--   continuam existindo. Consequência: se o Josemar logar de novo com a
--   mesma conta Google, o app NÃO vai achar um profile (a linha em
--   'profiles' foi apagada) e deve tratá-lo como usuário novo (onboarding).
--   Se o objetivo é apagar TAMBÉM as contas de autenticação, isso é feito
--   SEPARADAMENTE no painel: Authentication > Users > deletar manualmente.
--   O SQL Editor normalmente não tem permissão de apagar auth.users.
--
-- Pré-requisito OBRIGATÓRIO:
--   - Backup completo feito: rodar `node backup-completo.cjs` ANTES.
--     (gera backup-<ts>-pre010-completo em C:\tempnext\infra\backups\ e D:\)
--
-- ============================================================

BEGIN;

-- ──────────────────────────────────────────────────────────
-- Passo 1: aviso no log
-- ──────────────────────────────────────────────────────────
DO $$
BEGIN
  RAISE NOTICE '010 reset: iniciando TRUNCATE de 17 tabelas de conteúdo.';
END $$;

-- ──────────────────────────────────────────────────────────
-- Passo 2: TRUNCATE das 17 tabelas de conteúdo
-- ──────────────────────────────────────────────────────────
-- CASCADE resolve as dependências de FK automaticamente.
-- RESTART IDENTITY zera os contadores de identity/serial.
-- As 17 tabelas estão todas no mesmo comando: ou tudo, ou nada.

TRUNCATE TABLE
  public.profiles,
  public.places,
  public.place_profiles,
  public.place_aliases,
  public.momentos,
  public.comentarios_momentos,
  public.contacts,
  public.messages,
  public.notificacoes,
  public.likes,
  public.interacoes,
  public.olhando_momentos,
  public.capsula_aguardando,
  public.registrando_agora,
  public.respostas_afinidade,
  public.followed_places,
  public.videos
RESTART IDENTITY CASCADE;

-- ──────────────────────────────────────────────────────────
-- Passo 3: verificação — todas as 17 devem estar em 0
-- ──────────────────────────────────────────────────────────
DO $$
DECLARE
  t TEXT;
  n BIGINT;
  total BIGINT := 0;
  tabelas TEXT[] := ARRAY[
    'profiles','places','place_profiles','place_aliases','momentos',
    'comentarios_momentos','contacts','messages','notificacoes','likes',
    'interacoes','olhando_momentos','capsula_aguardando','registrando_agora',
    'respostas_afinidade','followed_places','videos'
  ];
BEGIN
  FOREACH t IN ARRAY tabelas LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', t) INTO n;
    total := total + n;
    IF n > 0 THEN
      RAISE NOTICE '010 reset: ATENÇÃO — %  ainda tem % linha(s).', t, n;
    END IF;
  END LOOP;

  IF total = 0 THEN
    RAISE NOTICE '010 reset: OK — todas as 17 tabelas estão vazias. Banco limpo.';
  ELSE
    RAISE EXCEPTION '010 reset: FALHOU — % linha(s) restante(s) no total. Transação será revertida.', total;
  END IF;
END $$;

COMMIT;

-- ============================================================
-- VERIFICAÇÃO PÓS-RESET (rodar separado, opcional)
-- ============================================================
-- SELECT 'profiles' AS tabela, count(*) FROM profiles
-- UNION ALL SELECT 'places', count(*) FROM places
-- UNION ALL SELECT 'place_profiles', count(*) FROM place_profiles
-- UNION ALL SELECT 'momentos', count(*) FROM momentos
-- UNION ALL SELECT 'contacts', count(*) FROM contacts;
-- (todos devem retornar 0)
--
-- Caches preservados (devem manter suas linhas):
-- SELECT 'place_suggestions_cache', count(*) FROM place_suggestions_cache
-- UNION ALL SELECT 'cep_index', count(*) FROM cep_index;

-- ============================================================
-- ROLLBACK
-- ============================================================
-- TRUNCATE é IRREVERSÍVEL dentro de uma transação já commitada.
-- A única forma de voltar é reimportar o backup:
--   backup-<ts>-pre010-completo  (17 arquivos .json)
--
-- Reimportação não é trivial (respeitar ordem de FK na hora de inserir:
-- profiles → places → place_profiles → momentos → resto). Se precisar
-- reverter, peça ajuda para montar o script de restore na ordem certa.
--
-- auth.users NÃO é afetado por esta migration nem pelo rollback.
-- ============================================================
