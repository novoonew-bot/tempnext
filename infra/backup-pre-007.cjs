// backup-pre-007.cjs — backup das tabelas tocadas pela migration 007
//
// Baixa profiles, places, place_profiles do Supabase e salva como JSON
// em C:\tempnext\infra\backups\ E em D:\ (HD externo).
//
// Uso (no cmd, dentro de C:\tempnext\infra):
//   node backup-pre-007.cjs
//
// Pré-requisito: .env com SUPABASE_URL e a chave de service_role.
// A chave service_role bypassa RLS — backup fica COMPLETO (todas as linhas).
// Com anon key o backup sai parcial (só o que a RLS permite). O script
// detecta e avisa.
//
// .env precisa de UMA destas linhas (service_role de preferência):
//   SUPABASE_SERVICE_ROLE_KEY=eyJ...
//   (ou SUPABASE_SERVICE_KEY / SERVICE_ROLE_KEY — o script aceita os 3 nomes)

const fs = require('fs');
const path = require('path');
const https = require('https');

// ── 1. Lê .env ───────────────────────────────────────────────
function lerEnv() {
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) {
    console.error('[ERRO] .env não encontrado em ' + envPath);
    process.exit(1);
  }
  const env = {};
  for (const linha of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const m = linha.match(/^\s*([A-Z_]+)\s*=\s*(.+?)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return env;
}

const env = lerEnv();
const URL = env.SUPABASE_URL;
const SERVICE_KEY = env.SUPABASE_SERVICE_ROLE_KEY || env.SUPABASE_SERVICE_KEY || env.SERVICE_ROLE_KEY;
const ANON_KEY = env.SUPABASE_ANON_KEY;
const KEY = SERVICE_KEY || ANON_KEY;

if (!URL || !KEY) {
  console.error('[ERRO] .env precisa de SUPABASE_URL e uma chave (service_role ou anon).');
  process.exit(1);
}
if (!SERVICE_KEY) {
  console.warn('[AVISO] service_role não encontrada — usando anon key.');
  console.warn('        Backup pode sair PARCIAL (RLS filtra linhas). Para backup');
  console.warn('        completo, adicione SUPABASE_SERVICE_ROLE_KEY no .env.');
}

// ── 2. Busca uma tabela inteira (paginado) ───────────────────
function fetchTabela(tabela) {
  return new Promise((resolve, reject) => {
    const todas = [];
    const PAGE = 1000;
    function pagina(offset) {
      const host = URL.replace('https://', '');
      const opts = {
        host,
        path: `/rest/v1/${tabela}?select=*&limit=${PAGE}&offset=${offset}`,
        headers: {
          apikey: KEY,
          Authorization: 'Bearer ' + KEY,
        },
      };
      https.get(opts, (res) => {
        let body = '';
        res.on('data', (c) => (body += c));
        res.on('end', () => {
          if (res.statusCode !== 200) {
            return reject(new Error(`${tabela}: HTTP ${res.statusCode} — ${body.slice(0, 200)}`));
          }
          let lote;
          try { lote = JSON.parse(body); } catch (e) { return reject(new Error(`${tabela}: JSON inválido`)); }
          todas.push(...lote);
          if (lote.length === PAGE) pagina(offset + PAGE);
          else resolve(todas);
        });
      }).on('error', reject);
    }
    pagina(0);
  });
}

// ── 3. Executa ───────────────────────────────────────────────
(async () => {
  const TABELAS = ['profiles', 'places', 'place_profiles'];
  const ts = new Date().toISOString().slice(0, 19).replace(/[-:T]/g, '').replace(/(\d{8})(\d{6})/, '$1-$2');
  const nomePasta = `backup-${ts}-pre007`;

  const dados = {};
  for (const t of TABELAS) {
    process.stdout.write(`  baixando ${t}... `);
    try {
      dados[t] = await fetchTabela(t);
      console.log(`${dados[t].length} linhas`);
    } catch (e) {
      console.error(`FALHOU — ${e.message}`);
      process.exit(1);
    }
  }

  // Destinos: C: e D:
  const destinos = [
    path.join('C:', 'tempnext', 'infra', 'backups', nomePasta),
    path.join('D:', nomePasta),
  ];

  let salvos = 0;
  for (const destino of destinos) {
    try {
      fs.mkdirSync(destino, { recursive: true });
      for (const t of TABELAS) {
        fs.writeFileSync(
          path.join(destino, `${t}.json`),
          JSON.stringify(dados[t], null, 2),
          'utf8'
        );
      }
      // manifest
      fs.writeFileSync(
        path.join(destino, '_manifest.txt'),
        [
          'Backup pré-migration 007 — F1.B',
          'Data: ' + new Date().toISOString(),
          'Modo: ' + (SERVICE_KEY ? 'service_role (COMPLETO)' : 'anon (PARCIAL — RLS filtra)'),
          ...TABELAS.map((t) => `${t}: ${dados[t].length} linhas`),
        ].join('\n'),
        'utf8'
      );
      console.log(`  salvo em ${destino}`);
      salvos++;
    } catch (e) {
      console.warn(`  [AVISO] não salvou em ${destino} — ${e.message}`);
    }
  }

  if (salvos === 0) {
    console.error('[ERRO] não salvou em nenhum destino.');
    process.exit(1);
  }
  console.log(`\nBackup concluído em ${salvos}/${destinos.length} destino(s).`);
  if (salvos < destinos.length) {
    console.log('(D: pode não estar conectado — verifique o HD externo.)');
  }
})();
