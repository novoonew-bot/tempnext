# F2 — E4 (shell/rotas) + E5 (test harness) — brief para Claude Code v1

> Repo: `C:\tempnext-app` (chip = **tempnext**, confirmar antes de rodar — cai no Indrecom por padrão).
> Decisões FECHADAS, não reabrir: react-router v7 · @fontsource self-hosted · Opção 1 (legacy v496 perde escrita direta) · portões nativos TS (não audit.py).
> Vocabulário banido em qualquer string user-facing: `cruz*`, `alma*`.

---

## E4 — Shell + rotas

**Objetivo:** casca navegável do app novo. Nada de telas reais ainda — placeholders honestos por bloco.

1. **react-router v7**, app raso. Rotas por tela + compat com deep links do legacy via search params (`?perfil=`, `?livro=`, `?cap=`, `?id=`). Um resolver único de search params → rota interna; sem caminho duplo.
2. **Rotas placeholder (7 blocos):** `/` (home) · `/onboarding` · `/perfil` · `/registro` · `/buscar` · `/lugar/:id` · `/conexoes`. Mínimo convidável = onboarding + home + perfil + registro (os outros 3 ficam de stub).
3. **Fontes @fontsource self-hosted:** Fraunces (títulos/nomes) + Cormorant Garamond italic (camada contemplativa). Sem CDN — offline/Capacitor.
4. **Shell:** layout raiz consumindo `core/tokens` (nunca hex solto), error boundary global já existente no main.tsx envolve o router.
5. **Proibido recriar:** gate `?dev=1`, `popularTeste`, `limparTeste`, e o client `dbRead` sem sessão (morto por decisão, E2).
6. `.claude/` do legacy → `.gitignore` (útil local, não commitar).

**DoD E4:** `pnpm dev` abre, as 7 rotas renderizam placeholder, deep link `?perfil=X` resolve para `/perfil` com o id disponível, fontes carregam sem rede externa, CI verde.

---

## E5 — Test harness (PROVA a F1)

**Objetivo:** Vitest + testes de integração contra o Supabase real (projeto `ahvmyhxromworlysqsam`). O 1º teste é a regressão RLS 2 contas + storage — é o que fecha a prova da F1.

**Setup:**
- `.env.test` (gitignored) com credenciais de 2 contas de teste **email+senha** (A e B). Se as contas atuais são só Google OAuth, Jo cria 2 usuários de teste email+senha no dashboard Auth antes de rodar (ver "Ação do Jo" abaixo).
- Suite marcada como integração (não roda no CI público por padrão; roda local com `pnpm test:rls`).

**Teste 1 — regressão RLS (2 contas):**
| Superfície | Asserção |
|---|---|
| `profiles` | A não faz UPDATE no profile de B (0 rows / erro). A edita o próprio. |
| `contacts` | INSERT/UPDATE/DELETE só por parte; leitura por-parte (triangulação ok). |
| `likes`, `interacoes` | INSERT direto NEGADO. Escrita só via RPC `toggle_like` / `registrar_interacao`. |
| `messages` | INSERT direto NEGADO; `enviar_mensagem` funciona; leitura só participante. |
| `notificacoes` | actor não forjável (A não insere notificação com actor=B). |
| RPCs | `anon` sem EXECUTE em nenhuma das 3. |
| `momentos` SELECT | cápsula privada de A não aparece para B não-conectado. |

**Teste 2 — storage (cross-user negado):**
- A faz upload em `avatars/<A>/x.jpg` → OK (convenção `<profile_id>/arquivo.ext`).
- A tenta `avatars/<B>/x.jpg` → NEGADO. Repetir para `photos`, `videos`, `covers`.
- Leitura pública funciona onde discovery exige.

**DoD E5:** suite verde com as 2 contas; qualquer afrouxamento futuro de policy quebra teste.

---

## Higiene junto (mesma sessão de Code)

- `supabase db pull` → versionar as migrações da F1 em `tempnext-app/supabase/migrations/` (hoje estão só no dashboard = resíduo fora do git).
- CI portões nativos, se ainda não ativos: eslint `no-empty` · knip (órfãos) · check unsplash hardcoded · `gen:tokens` sync.

---

## Ação do Jo (antes/durante)

1. Confirmar chip do Code = **tempnext**.
2. Criar 2 usuários de teste email+senha no Supabase Auth (dashboard) e preencher `.env.test` — necessário só para o E5.

Commits: ASCII puro, um por etapa (E4, E5, higiene).
