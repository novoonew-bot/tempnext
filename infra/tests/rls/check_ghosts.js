#!/usr/bin/env node
/**
 * check_ghosts.js
 *
 * Procura por "fantasmas": dados que apontam pra user_ids que nao
 * existem mais em public.profiles. Tipico apos delete sem cascata.
 * READ-ONLY.
 */

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const { SUPABASE_URL, SUPABASE_ANON_KEY } = process.env;
const supa = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
});

const C = {
  reset: '\x1b[0m', bold: '\x1b[1m', dim: '\x1b[2m',
  green: '\x1b[32m', yellow: '\x1b[33m', red: '\x1b[31m', gray: '\x1b[90m',
};

console.log(`\n${C.bold}--- Checagem de fantasmas (dados orfaos sem profile) ---${C.reset}\n`);

// 1. Pega todos os IDs de profile existentes hoje
const { data: profiles, error: e0 } = await supa
  .from('profiles')
  .select('id');

if (e0) {
  console.error(`Erro lendo profiles: ${e0.message}`);
  process.exit(1);
}

const existingProfileIds = new Set(profiles.map(p => p.id));
console.log(`${C.bold}Profiles existentes hoje: ${existingProfileIds.size}${C.reset}\n`);

// 2. Pra cada tabela com user_id, checa se aponta pra profile inexistente
const tablesWithUserId = [
  { name: 'momentos', col: 'user_id' },
  { name: 'notificacoes', col: 'user_id' },
  { name: 'messages', col: 'from_id' },
  { name: 'contacts', col: 'user_id' },
  { name: 'contacts', col: 'contact_id' },
  { name: 'capsula_aguardando', col: 'user_id' },
  { name: 'respostas_afinidade', col: 'user_id' },
  { name: 'followed_places', col: 'user_id' },
  { name: 'olhando_momentos', col: 'user_id' },
  { name: 'interacoes', col: 'user_id' },
  { name: 'comentarios_momentos', col: 'user_id' },
  { name: 'likes', col: 'user_id' },
  { name: 'videos', col: 'user_id' },
  { name: 'registrando_agora', col: 'user_id' },
  { name: 'place_profiles', col: 'profile_id' },
];

let totalGhosts = 0;
const ghostsByTable = {};

for (const { name: table, col } of tablesWithUserId) {
  const { data, error } = await supa
    .from(table)
    .select(col);

  if (error) {
    console.log(`  ${C.red}${table}.${col}: erro: ${error.message}${C.reset}`);
    continue;
  }

  if (!data || data.length === 0) {
    console.log(`  ${C.gray}${table}.${col}: tabela vazia${C.reset}`);
    continue;
  }

  // Conjunto unico de IDs nessa coluna
  const idsUsed = new Set(data.map(r => r[col]).filter(Boolean));
  const ghostIds = [...idsUsed].filter(id => !existingProfileIds.has(id));

  if (ghostIds.length === 0) {
    console.log(`  ${C.green}${table}.${col}:${C.reset} ${C.dim}${idsUsed.size} ids unicos, todos validos${C.reset}`);
  } else {
    // Conta linhas afetadas
    const ghostRowCount = data.filter(r => ghostIds.includes(r[col])).length;
    console.log(`  ${C.yellow}${table}.${col}:${C.reset} ${C.bold}${ghostIds.length}${C.reset} ids fantasmas, ${C.bold}${ghostRowCount}${C.reset} linhas afetadas`);
    totalGhosts += ghostRowCount;
    ghostsByTable[`${table}.${col}`] = { ghostIds: ghostIds.slice(0, 5), count: ghostRowCount };
  }
}

console.log(`\n${C.bold}--- Sumario ---${C.reset}`);
if (totalGhosts === 0) {
  console.log(`  ${C.green}Nenhum fantasma. Schema integro.${C.reset}`);
} else {
  console.log(`  ${C.yellow}${totalGhosts} linhas apontam pra profiles que nao existem.${C.reset}`);
  console.log(`  ${C.dim}Isso eh resultado de deletes anteriores sem cascata.${C.reset}`);
  console.log(`  ${C.dim}O SQL final precisa limpar essas referencias tambem.${C.reset}\n`);

  console.log(`${C.bold}Top fantasmas por tabela:${C.reset}`);
  for (const [key, info] of Object.entries(ghostsByTable)) {
    console.log(`  ${key}: ${info.count} linhas; sample ids: ${info.ghostIds.join(', ')}`);
  }
}

console.log();