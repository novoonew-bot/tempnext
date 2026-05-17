#!/usr/bin/env node
/**
 * inventory.js
 *
 * Inventário read-only do estado do banco antes da migração de RLS.
 * Apenas SELECT. Nenhuma escrita.
 */

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const { SUPABASE_URL, SUPABASE_ANON_KEY } = process.env;
if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('ERROR: missing SUPABASE_URL or SUPABASE_ANON_KEY');
  process.exit(3);
}

const anon = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});

const C = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  green: '\x1b[32m', yellow: '\x1b[33m', red: '\x1b[31m', cyan: '\x1b[36m', gray: '\x1b[90m',
};

const print = {
  title: t => console.log(`\n${C.bold}${C.cyan}=== ${t} ===${C.reset}`),
  line: (k, v, hint) => {
    const key = `${C.dim}${k.padEnd(40)}${C.reset}`;
    const val = typeof v === 'number' ? `${C.bold}${v}${C.reset}` : v;
    const h = hint ? ` ${C.gray}(${hint})${C.reset}` : '';
    console.log(`  ${key} ${val}${h}`);
  },
  warn: t => console.log(`  ${C.yellow}! ${t}${C.reset}`),
  ok: t => console.log(`  ${C.green}OK ${t}${C.reset}`),
  err: t => console.log(`  ${C.red}X ${t}${C.reset}`),
};

async function countTable(table) {
  try {
    const { count, error } = await anon.from(table).select('*', { count: 'exact', head: true });
    if (error) return { error: error.message };
    return { count };
  } catch (e) {
    return { error: e.message };
  }
}

async function sampleColumns(table) {
  try {
    const { data, error } = await anon.from(table).select('*').limit(1);
    if (error) return { error: error.message };
    if (!data || data.length === 0) return { columns: [], empty: true };
    return { columns: Object.keys(data[0]), sample: data[0] };
  } catch (e) {
    return { error: e.message };
  }
}

async function countByFilter(table, filter) {
  try {
    let q = anon.from(table).select('*', { count: 'exact', head: true });
    for (const [op, col, val] of filter) {
      q = q[op](col, val);
    }
    const { count, error } = await q;
    if (error) return { error: error.message };
    return { count };
  } catch (e) {
    return { error: e.message };
  }
}

console.log(`${C.bold}\n--- Tempnext DB Inventory ---${C.reset}`);
console.log(`  ${C.gray}Target: ${SUPABASE_URL}${C.reset}`);
console.log(`  ${C.gray}Mode:   anon role (read-only)${C.reset}\n`);

// 1. Volume das tabelas
print.title('1. Volume das tabelas');

const tables = [
  'profiles', 'momentos', 'notificacoes', 'capsula_aguardando',
  'messages', 'respostas_afinidade', 'contacts', 'followed_places',
  'olhando_momentos', 'registrando_agora', 'places', 'place_profiles',
  'interacoes', 'comentarios_momentos', 'likes', 'videos', 'place_suggestions_cache',
];

const counts = {};
for (const t of tables) {
  const r = await countTable(t);
  counts[t] = r.count ?? null;
  if (r.error) {
    print.err(`${t.padEnd(30)} -> erro: ${r.error}`);
  } else {
    const vol = r.count;
    const tag = vol === null ? C.gray + 'null' : vol === 0 ? C.gray + '0' : C.bold + vol;
    console.log(`  ${C.dim}${t.padEnd(30)}${C.reset} ${tag}${C.reset}`);
  }
}

// 2. profiles.auth_id
print.title('2. Saude de profiles.auth_id (CRITICO pra RLS)');

print.line('total profiles', counts.profiles ?? '?');

const withAuthId = await countByFilter('profiles', [['not', 'auth_id', 'is.null']]);
print.line('profiles com auth_id populado', withAuthId.count ?? withAuthId.error ?? '?');

const withoutAuthId = await countByFilter('profiles', [['is', 'auth_id', null]]);
print.line('profiles SEM auth_id (legado)', withoutAuthId.count ?? withoutAuthId.error ?? '?');

if (withoutAuthId.count > 0) {
  print.warn(`${withoutAuthId.count} profile(s) sem auth_id - esses NAO leem nada apos RLS fechada`);
} else if (withoutAuthId.count === 0) {
  print.ok('Todos os profiles tem auth_id - RLS por auth.uid() vai funcionar');
}

// 3. Estrutura de momentos
print.title('3. Estrutura real de momentos');

const mCols = await sampleColumns('momentos');
if (mCols.error) {
  print.err(`erro: ${mCols.error}`);
} else if (mCols.empty) {
  print.warn('tabela vazia');
} else {
  print.line('colunas observadas', mCols.columns.length);
  console.log(`  ${C.gray}${mCols.columns.join(', ')}${C.reset}`);

  const has = c => mCols.columns.includes(c);
  if (has('capsula_visibilidade')) print.ok('capsula_visibilidade existe');
  else print.err('capsula_visibilidade NAO existe');
  if (has('user_id')) print.ok('user_id existe');
  else print.err('user_id NAO existe');
  if (has('visibilidade_pessoas')) print.ok('visibilidade_pessoas existe');
  else print.warn('visibilidade_pessoas nao vista');
}

// 4. Distribuicao de visibilidade
print.title('4. Distribuicao de capsula_visibilidade');

for (const vis of ['publico', 'contatos', 'familia', 'privado']) {
  const r = await countByFilter('momentos', [['eq', 'capsula_visibilidade', vis]]);
  print.line(`visibilidade=${vis}`, r.count ?? r.error ?? '?');
}
const semVis = await countByFilter('momentos', [['is', 'capsula_visibilidade', null]]);
print.line('visibilidade NULA', semVis.count ?? semVis.error ?? '?');

// 5. Colunas de outras tabelas
print.title('5. Colunas de tabelas-chave');

for (const t of ['notificacoes', 'contacts', 'capsula_aguardando', 'respostas_afinidade', 'messages', 'olhando_momentos', 'followed_places']) {
  const r = await sampleColumns(t);
  if (r.error) {
    print.err(`${t}: ${r.error}`);
  } else if (r.empty) {
    console.log(`  ${C.dim}${t.padEnd(25)}${C.reset} ${C.gray}(vazia)${C.reset}`);
  } else {
    console.log(`  ${C.dim}${t.padEnd(25)}${C.reset} ${C.gray}${r.columns.join(', ')}${C.reset}`);
  }
}

// 6. Sample de contacts
print.title('6. Sample de contacts');

try {
  const { data } = await anon.from('contacts').select('*').limit(1);
  if (data && data.length > 0) {
    console.log(`  ${C.gray}${JSON.stringify(data[0], null, 2).split('\n').join('\n  ')}${C.reset}`);
  } else {
    console.log(`  ${C.gray}(sem dados ou bloqueado)${C.reset}`);
  }
} catch (e) {
  print.err(e.message);
}

console.log(`\n${C.bold}${C.green}Inventario concluido.${C.reset}\n`);