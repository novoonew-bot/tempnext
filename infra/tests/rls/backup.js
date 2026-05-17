#!/usr/bin/env node
/**
 * backup.js v2 — corrigido pra Windows
 *
 * - Nome de pasta sem caracteres especiais
 * - Verifica cada escrita imediatamente
 * - Falha ruidoso se algo der errado
 * - Resolve path absoluto antes de escrever
 */

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

const { SUPABASE_URL, SUPABASE_ANON_KEY } = process.env;
if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('ERROR: missing SUPABASE_URL or SUPABASE_ANON_KEY');
  process.exit(3);
}

const supa = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});

const C = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  green: '\x1b[32m', yellow: '\x1b[33m', red: '\x1b[31m', cyan: '\x1b[36m', gray: '\x1b[90m',
};

// Timestamp simples: YYYYMMDD-HHMMSS (sem pontos, sem dois-pontos)
const now = new Date();
const pad = n => String(n).padStart(2, '0');
const ts = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;

const backupDirRel = path.join('backups', `backup-${ts}`);
const backupDir = path.resolve(backupDirRel);

console.log(`\n${C.bold}--- Tempnext Backup v2 ---${C.reset}`);
console.log(`  ${C.gray}Target: ${SUPABASE_URL}${C.reset}`);
console.log(`  ${C.gray}Dest:   ${backupDir}${C.reset}`);

// Cria pasta com verificacao
try {
  fs.mkdirSync(backupDir, { recursive: true });
  if (!fs.existsSync(backupDir)) {
    throw new Error(`Pasta nao foi criada apos mkdirSync: ${backupDir}`);
  }
  console.log(`  ${C.green}OK pasta criada${C.reset}\n`);
} catch (e) {
  console.error(`${C.red}FATAL: nao consegui criar pasta de backup: ${e.message}${C.reset}`);
  process.exit(1);
}

const tables = [
  'profiles', 'momentos', 'notificacoes', 'capsula_aguardando',
  'messages', 'respostas_afinidade', 'contacts', 'followed_places',
  'olhando_momentos', 'registrando_agora', 'places', 'place_profiles',
  'interacoes', 'comentarios_momentos', 'likes', 'videos', 'place_suggestions_cache',
];

const manifest = {
  timestamp: now.toISOString(),
  target: SUPABASE_URL,
  tables: {},
};

let totalRows = 0;
let totalErrors = 0;

for (const t of tables) {
  process.stdout.write(`  ${C.dim}${t.padEnd(30)}${C.reset} `);

  try {
    // Pagina pra pegar tudo
    let allRows = [];
    let from = 0;
    const pageSize = 1000;
    let done = false;

    while (!done) {
      const { data, error } = await supa
        .from(t)
        .select('*')
        .range(from, from + pageSize - 1);

      if (error) {
        process.stdout.write(`${C.red}ERRO QUERY: ${error.message}${C.reset}\n`);
        manifest.tables[t] = { error: error.message, count: 0 };
        totalErrors++;
        done = true;
        break;
      }

      if (!data || data.length === 0) {
        done = true;
      } else {
        allRows = allRows.concat(data);
        if (data.length < pageSize) done = true;
        else from += pageSize;
      }
    }

    if (manifest.tables[t]?.error) continue;

    // Escreve e verifica
    const fileName = `${t}.json`;
    const filePath = path.join(backupDir, fileName);
    const content = JSON.stringify(allRows, null, 2);

    fs.writeFileSync(filePath, content, 'utf8');

    // VERIFICA que o arquivo realmente existe e tem o tamanho esperado
    if (!fs.existsSync(filePath)) {
      throw new Error(`writeFileSync executou mas arquivo nao existe: ${filePath}`);
    }
    const stat = fs.statSync(filePath);
    if (stat.size === 0 && allRows.length > 0) {
      throw new Error(`Arquivo escrito com tamanho 0 mas havia ${allRows.length} linhas`);
    }

    manifest.tables[t] = {
      count: allRows.length,
      file: fileName,
      bytes: stat.size,
    };
    totalRows += allRows.length;

    process.stdout.write(`${C.green}OK${C.reset} ${C.bold}${allRows.length}${C.reset} ${C.gray}linhas (${stat.size} bytes)${C.reset}\n`);
  } catch (e) {
    process.stdout.write(`${C.red}FALHA: ${e.message}${C.reset}\n`);
    manifest.tables[t] = { error: e.message, count: 0 };
    totalErrors++;
  }
}

// Salva e verifica manifest
manifest.total_rows = totalRows;
manifest.total_errors = totalErrors;

try {
  const manifestPath = path.join(backupDir, 'manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2), 'utf8');
  if (!fs.existsSync(manifestPath)) {
    throw new Error('manifest.json nao foi criado');
  }
  console.log(`\n  ${C.green}OK manifest.json criado${C.reset}`);
} catch (e) {
  console.error(`\n${C.red}FALHA AO SALVAR MANIFEST: ${e.message}${C.reset}`);
}

// LISTA o conteudo da pasta pra confirmar visualmente
console.log(`\n${C.bold}--- Verificacao final ---${C.reset}`);
try {
  const files = fs.readdirSync(backupDir);
  console.log(`  ${C.green}Arquivos na pasta de backup:${C.reset} ${files.length}`);
  files.forEach(f => {
    const fp = path.join(backupDir, f);
    const s = fs.statSync(fp);
    console.log(`    ${C.dim}${f.padEnd(35)} ${s.size} bytes${C.reset}`);
  });
} catch (e) {
  console.error(`  ${C.red}Erro lendo pasta: ${e.message}${C.reset}`);
}

console.log(`\n${C.bold}--- Sumario ---${C.reset}`);
console.log(`  ${C.green}Tabelas OK:${C.reset}    ${tables.length - totalErrors}/${tables.length}`);
console.log(`  ${C.bold}Total de linhas:${C.reset} ${totalRows}`);
if (totalErrors > 0) {
  console.log(`  ${C.red}Erros:${C.reset}        ${totalErrors}`);
  process.exit(1);
}
console.log(`  ${C.gray}Backup em:${C.reset} ${backupDir}\n`);