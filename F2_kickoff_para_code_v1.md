# F2 kickoff — para o Claude Code (v1)

> Ler junto com `C:\tempnext\CLAUDE.md` (secao "Reescrita F1+"). Este e o work order da F2.
> Regra: o que estiver fora deste brief, perguntar antes. Nao improvisar arquitetura.

## Estado (nao assumir de memoria)
- F1 banco: Faixa A + B **commitadas** no Supabase `ahvmyhxromworlysqsam`. Faixa C (RPCs + 4 privilegiadas) **em fila**.
- Legacy vivo: `C:\tempnext\index.html` (blob compilado, v496) — **congelado como especificacao**, nao e fonte. Nao editar pra F2.
- Repo novo `tempnext-app` **ainda nao existe** — a F2 e cria-lo.

## Objetivo da F2
Fundacao do app novo. Nada de tela de produto ainda (isso e F3). Entregar o esqueleto onde os blocos vao encaixar, com seguranca, telemetria e teste desde o osso.

## Stack e base
- Vite + React 18 + TypeScript (strict). pnpm. Node 22.
- Capacitor **preparado, nao ativado** (web-first; pluga na F5). Sem plugin nativo agora.
- Sem `create-react-app`, sem Next. SPA Vite.

## Estrutura (modular por blocos)
```
tempnext-app/
  src/
    core/
      tokens/       # identidade como codigo (fonte unica)
      supabase/     # client tipado + tipos gerados
      auth/         # sessao, PKCE, perfil atual
      telemetry/    # Sentry + error boundary global
      test/         # setup vitest + playwright
    blocks/         # onboarding|home|perfil|registro (F3, vazio agora)
    app/            # shell, rotas, providers
  audit/            # gates de codigo (ver secao Portoes)
```

## core/tokens (fazer primeiro — fonte unica de verdade)
Extrair a identidade travada do `CLAUDE.md` para tokens TS + CSS vars. Nada de cor/fonte hardcoded fora daqui.
- Fontes: Fraunces (display), Cormorant Garamond italic 500 (frases), Inter (UI).
- Paleta: ouro `#a8853f`/`#c89a4b`, navy `#0d1b2a`, terra `#c06a3e`, creme `#f7f3ee`, hairline `#ece6db`, fio do tempo azul `#6f9fd6`.
- Exportar como CSS custom properties + objeto TS tipado.

## core/supabase
- **Um** client autenticado (sessao). **Matar o padrao `dbRead` sem sessao** do legacy — nao recriar.
- Escrita privilegiada **so via RPC** (F1 Faixa C): `toggle_like`, `registrar_interacao`, `enviar_mensagem`. Nunca insert direto de `user_id`/`from_id` do payload.
- Tipos: rodar `supabase gen types typescript` **depois** do C commitar. Ate la, deixar o modulo com TODO e nao inventar tipos.

## core/auth
Sessao Supabase, login PKCE (sem token na URL), helper `currentProfileId()`. Espelhar o `current_profile_id()` do banco.

## core/telemetry (nasce aqui, nao e fase final)
- Sentry (client) + Error Boundary global no shell.
- Regra herdada (DoD): **zero `catch{}` mudo** — todo catch trata (UI de fallback) ou `captureException`.

## core/test (harness antes do 1o bloco)
- vitest (unit) + playwright (e2e).
- **Primeiro teste = regressao de RLS da F1** (2 contas): provar que apos A/B/C um usuario NAO consegue: escrever linha de outro (momentos/comentarios/videos/places), ler DM alheia, forjar notificacao/like/interacao com actor de terceiro, ver capsula privada de nao-contato. Isso **fecha a prova da F1** — ela deixa de ser "parece ok" e vira testada.

## Portoes (CI, limiar = 0 — REAVALIADO)
No repo TS os gates sao nativos, nao o `audit.py` (que fica pro legacy):
- **eslint**: regra `no-empty` (catch mudo) + regra de strings banidas `cruz*`/`alma*` user-facing (custom rule ou grep no CI).
- **knip** (ou ts-prune): 0 exports/arquivos orfaos.
- check de `unsplash` hardcoded = 0 (script simples no CI).
- `tsc --noEmit` limpo. Build verde.
CI quebra se qualquer um passar de 0.

## Definition of Done da F2
1. `pnpm build` verde, `tsc` sem erro, eslint/knip limpos (gates em 0).
2. Sentry captura um erro de teste; error boundary renderiza fallback.
3. Harness roda; 1 teste de RLS verde (depende do C commitado).
4. CI (GitHub Actions) rodando os portoes no push.
5. Repo `tempnext-app` no GitHub, README com o mapa de pastas.

## Nao-negociaveis (herdados)
- Separar dados de HTML (sem `DB={}` inline). Paineis servidos, nunca `file://`.
- Sem dado falso, sem gambiarra (sem setTimeout pra timing de DOM, sem filtro silencioso).
- Analise/decisao = codigo, nunca IA decidindo.
- Vocabulario banido em string user-facing: `cruz*`, `alma*`.
- Web-first, fronteiras limpas: nada dependente de API so-web sem fallback (Capacitor pluga depois).

## Ordem sugerida de execucao
tokens -> auth -> telemetry -> shell/rotas -> test harness -> (apos C) supabase types + teste RLS -> CI. Parar e reportar ao fim de cada, nao emendar tudo cego.
