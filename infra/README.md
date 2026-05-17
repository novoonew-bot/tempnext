# tempnext-infra

Infraestrutura, migrações e testes pra Tempnext. Repositório irmão do `app/`.

## Estrutura

```
tempnext-infra/
├── supabase/
│   ├── migrations/    # Migrações SQL versionadas (timestamp_descricao.sql)
│   ├── tests/         # Testes pgTAP de policies (futuro)
│   └── functions/     # Edge Functions (moderar-texto, etc)
├── tests/
│   ├── rls/           # Testes adversariais via REST (Node)
│   └── e2e/           # Playwright (futuro)
└── .github/workflows/ # CI (futuro)
```

## Pré-requisitos

- Node ≥ 18
- Credenciais Supabase (URL + anon key) em `.env`

## Rodando a suíte de testes RLS

A suíte simula um atacante de posse do anon key tentando ler dados privados.
Faz **apenas SELECT** — nenhuma operação destrutiva.

```bash
# 1. Setup
cp .env.example .env
# Edite .env e preencha SUPABASE_URL e SUPABASE_ANON_KEY (valores públicos, embutidos no client)

npm install

# 2. Executar
npm run test:rls

# Modo verbose (mostra erros e amostras de linhas vazadas)
npm run test:rls:verbose
```

### Códigos de saída

- `0` — todos os testes passaram (nenhum leak detectado)
- `1` — pelo menos um FAIL (RLS está vazando dados privados)
- `2` — pelo menos um ERROR sem FAILs (problema técnico)
- `3` — configuração ausente (`.env` malformado)

### Interpretando o output

- `✓ PASS` — comportamento esperado (RLS bloqueou leak OU dado público é legível)
- `✗ FAIL` — **vulnerabilidade** ou regressão (dado privado vazou ou dado público bloqueou)
- `! ERROR` — query falhou por motivo inesperado (rede, schema, etc)

## Modelo de ameaça

Cada teste declara uma `expectation`:
- `'empty'` — RLS deve bloquear → resposta esperada é 0 linhas
- `'rows'` — público intencional → resposta esperada é ≥ 1 linha
- `'error'` — tabela/coluna não existe → resposta esperada é erro PostgREST

Severidades:
- `critical` — vazamento expõe PII (mensagens, notificações, momentos privados)
- `high` — vazamento expõe metadata sensível (contatos, inscrições, respostas)
- `medium` — vazamento expõe padrão de uso (favoritos, telemetria)

## Segurança

- `.env` está em `.gitignore`. **Nunca comitar.**
- Anon key é público por design — está embutido em qualquer cliente JS publicado.
- **Service role key nunca é usado** nestes testes. Service role bypassa RLS e mascara vulnerabilidades.
- Pra rodar migrations em produção, o operador usa a CLI Supabase autenticada, não esses scripts.
