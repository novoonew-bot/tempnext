# CLAUDE.md — Tempnext (contexto permanente pro Claude Code)

> Este arquivo e lido automaticamente pelo Claude Code em toda sessao. Nao precisa colar caminho nem regra no prompt.

## O que e o Tempnext
PWA contemplativa brasileira. **NAO e rede social** — e descoberta no tempo ("o tempo conecta historias" / "o que o tempo revelou"). Dev solo: Josemar (Jo). Pre-publico: usuarios atuais sao so contas de teste (Suzane e a tester principal). Alvo: Play Store + convite por link.

## Estado atual (verificar sempre, nao confiar de memoria)
- **Arquivo vivo:** `C:\tempnext\index.html` — React.createElement compilado (ES5, sem fonte JSX), ~62.286 linhas, ~2,31 MB, um arquivo so.
- **Service worker:** `C:\tempnext\service-worker.js` — `SW_VERSION` bumpa junto com o app em todo deploy.
- **Versao no disco em 02/jul/2026: v496.** SEMPRE checar o marker real (`grep 'Tempnext v49' index.html`) no inicio — o disco anda na frente do vault.
- Backend: Supabase projeto `ahvmyhxromworlysqsam` (Sao Paulo). GitHub `novoonew-bot/tempnext`. Vercel `tempnext-brown.vercel.app` (auto-deploy no push).

## Vault Obsidian (FORA do repo — ler no inicio de toda sessao)
`C:\Users\Josemar\Documents\Tempnext\Tempnext_Atualizado\`
- `INICIAR_PROXIMA_SESSAO.md` — briefing de retomada (topo = estado mais recente). PODE estar defasado vs disco; disco vence.
- `05_Roadmap/` — plano de migracao e auditorias.
- `06_Sessoes/` — notas por sessao.
- `03_Decisoes firmes/` — decisoes travadas.
Ao terminar trabalho relevante: atualizar o topo do `INICIAR_PROXIMA_SESSAO.md` + criar nota em `06_Sessoes/`.

## Identidade travada (todo output passa por este filtro)
- Tom: direto, objetivo, big-tech, moderno, inteligente. Surpreender pela qualidade.
- Fontes: **Fraunces** (display), **Cormorant Garamond** italico 500 (frases), **Inter** (UI).
- Paleta: ouro `#a8853f`/`#c89a4b`, navy `#0d1b2a`, terra `#c06a3e`, creme `#f7f3ee`, hairline `#ece6db`, fio do tempo azul `#6f9fd6`.
- **Vocabulario BANIDO em strings user-facing:** `cruz*` (cruzar/cruzamento/etc.) e `alma/almas`. (Em v496 ainda ha 10 strings vivas — limpar.)
- Sem emoji. Sem dados falsos. Sem gambiarra (sem setTimeout pra timing de DOM, sem filtro silencioso, sem constante arbitraria, sem caminho de codigo duplicado).

## Regras de edicao do index.html (compilado — cirurgia)
1. NUNCA reformatar/refatorar o compilado em massa. So edicao cirurgica por anchor.
2. Fluxo obrigatorio: copiar -> extrair o maior `<script>` -> `node --check` ANTES e DEPOIS de editar. Nunca entregar sem `node --check` OK.
3. `oldText` byte-exato (inclui acentos, `·` U+00B7, em-dash como literais).
4. Tecnica de troca de tela: componente NOVO + swap de 1 linha de render, mantendo o antigo gatado (`false &&`) pra reverter.
5. **Codigo morto vs vivo:** sempre reavaliar. Substituir o morto, nao acumular. Rodar sweep de orfaos apos cada remocao (orfaos em cascata so aparecem depois que o consumidor sai).

## Deploy (Jo roda, credencial fica com ele)
```
cd C:\tempnext && git add -A && git commit -m "vXXX msg curta ASCII" && git push --force
```
Commit: **ASCII apenas** (sem acento, sem em-dash — quebra o CMD). App + SW_VERSION bumpam juntos. Versao sempre unica e incrementada — checar a ultima antes.

## Mudanca visual
Mockup com 2-4 variacoes ANTES de implementar. Jo escolhe -> so entao implementar. Nunca aplicar visual direto sem mockup.

## Auditoria
Rodar `python audit.py` (na raiz) pra numeros reais. Nunca estimar de memoria — medir contra o arquivo.

## Estilo de resposta
Direto ao ponto. Mostrar so o que Jo precisa decidir + o arquivo pronto (versionado). Nao narrar raciocinio, nao explicar codigo linha a linha, nao listar o que verificou.
