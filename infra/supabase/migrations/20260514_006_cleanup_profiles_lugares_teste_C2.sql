-- ============================================================
-- ABORTADA — não aplicada
-- ============================================================
-- Esta migration foi escrita em 14/mai/2026 durante a Sessão C.2 mas
-- nunca chegou a ser aplicada. Quando rodou, a verificação prévia
-- abortou porque o banco já tinha sido limpo por outro caminho
-- (provavelmente botão lixeira na UI da tela "meus lugares", que
-- chama `db.update({lugares: filtered})`).
--
-- Mantida no repo como histórico do iterar da Sessão C.
-- Não tem mais função no roadmap. Sessão D removerá tudo legacy.
-- ============================================================

-- (corpo original esvaziado intencionalmente)
SELECT 'abortada-20260514' AS status;
