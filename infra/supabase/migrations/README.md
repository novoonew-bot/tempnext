# Migrations — Tempnext

Migrations SQL versionadas pro Supabase. Aplicação manual via Dashboard SQL Editor (Supabase Free não tem CLI ainda).

---

## Convenção de nome

`YYYYMMDD_NNN_descricao.sql`

- `YYYYMMDD`: data de criação
- `NNN`: ordem dentro do dia (001, 002, ...)
- `descricao`: snake_case curto

---

## Fluxo de aplicação

1. **Ler a migration** inteira antes de executar
2. **Backup** prévio (já temos snapshot em `C:\tempnext\infra\backups\backup-20260511-143434\`)
3. **Abrir Supabase Dashboard** → SQL Editor
4. **Colar conteúdo** da migration
5. **Executar** (botão Run)
6. **Verificar NOTICE** retornado — cada migration tem bloco de validação
7. **Anotar data de execução** no cabeçalho da migration neste repo
8. **Commit** o arquivo SQL no Git (versionamento)

---

## Migrations aplicadas

Lista cronológica. Marcar como aplicada após execução bem-sucedida.

| Arquivo | Data planejada | Aplicada em | Observações |
|---|---|---|---|
| `20260513_000_dedupe_primavera_do_leste.sql` | 13/mai/2026 | 13/mai/2026 ✅ | Dedup pré-hardening: 3 entradas "Primavera do Leste" → 1 (mantém created_by NULL) |
| `20260513_000_5_normalize_place_types.sql` | 13/mai/2026 | 13/mai/2026 ✅ | Normaliza 3 lugares mal classificados (CEP→outro, Campo Verde→cidade, Catedral de Pedra→monumento) |
| `20260513_001_places_hardening.sql` | 13/mai/2026 | 13/mai/2026 ✅ | UNIQUE INDEX (com COALESCE pra NULL) + CHECK em type (lista expandida com trabalho/casa) |
| `20260513_002_place_profiles_label.sql` | 13/mai/2026 | 13/mai/2026 ✅ | place_label + label_visibilidade |

---

## Rollback

Cada migration tem bloco `ROLLBACK` comentado no final. Executar **só se** necessário reverter.

NUNCA usar `DROP TABLE` num rollback — só desfazer ALTER/CREATE.

---

## Padrão de migration big-tech

Toda migration nova deve seguir este formato:

```sql
-- Cabeçalho com objetivo, pré-requisitos, reversibilidade

BEGIN;

-- Passo 1: Verificação prévia (DO $$ ... $$)
-- Aborta se condições não forem seguras

-- Passo 2: Mudanças idempotentes (IF NOT EXISTS, IF EXISTS)
-- Pode rodar 2x sem quebrar

-- Passo 3: Validação pós-aplicação (DO $$ ... $$)
-- Confirma estado esperado

COMMIT;

-- Rollback comentado no final
```

---

## Relacionado

- [[Lugares como entidade]] — fundamenta as migrations 001 e 002
- [[Schema notas]] — documenta o schema vivo no banco
- [[Privacy Overhaul (10 fases)]] — migrations futuras de RLS (fase 2A)
