#!/usr/bin/env node
/**
 * inspect_orphans.js
 *
 * Lista profiles sem auth_id (orfaos) e verifica se tem dados associados.
 * READ-ONLY. So SELECT.
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
  green: '\x1b[32m', yellow: '\x1b[33m', red: '\x1b[31m', cyan: '\x1b[36m', gray: '\x1b[90m',
};

console.log(`\n${C.bold}--- Tempnext Orphan Profiles Inspector ---${C.reset}\n`);

// 1. Buscar os profiles sem auth_id
const { data: orphans, error } = await supa
  .from('profiles')
  .select('id, name, first_name, last_name, city, country, place_name, profissao, created_at, avatar_url')
  .is('auth_id', null);

if (error) {
  console.error(`${C.red}Erro:${C.reset}`, error.message);
  process.exit(1);
}

if (!orphans || orphans.length === 0) {
  console.log(`${C.green}Nenhum orfao encontrado. Tudo limpo.${C.reset}`);
  process.exit(0);
}

console.log(`${C.yellow}Encontrados ${orphans.length} profile(s) sem auth_id:${C.reset}\n`);

// 2. Pra cada orfao, contar dados associados
for (let i = 0; i < orphans.length; i++) {
  const o = orphans[i];
  console.log(`${C.bold}${C.cyan}--- Orfao #${i + 1} ---${C.reset}`);
  console.log(`  ${C.dim}id:${C.reset}         ${o.id}`);
  console.log(`  ${C.dim}name:${C.reset}       ${o.name || '(null)'}`);
  console.log(`  ${C.dim}first_name:${C.reset} ${o.first_name || '(null)'}`);
  console.log(`  ${C.dim}last_name:${C.reset}  ${o.last_name || '(null)'}`);
  console.log(`  ${C.dim}city:${C.reset}       ${o.city || '(null)'}`);
  console.log(`  ${C.dim}country:${C.reset}    ${o.country || '(null)'}`);
  console.log(`  ${C.dim}place_name:${C.reset} ${o.place_name || '(null)'}`);
  console.log(`  ${C.dim}profissao:${C.reset}  ${o.profissao || '(null)'}`);
  console.log(`  ${C.dim}avatar:${C.reset}     ${o.avatar_url ? 'sim' : 'nao'}`);
  console.log(`  ${C.dim}created:${C.reset}    ${o.created_at}`);

  // Conta dados associados
  console.log(`  ${C.dim}--- dados associados ---${C.reset}`);
  const tables = [
    { name: 'momentos', col: 'user_id' },
    { name: 'notificacoes', col: 'user_id' },
    { name: 'messages', col: 'from_id' },
    { name: 'contacts', col: 'user_id' },
    { name: 'capsula_aguardando', col: 'user_id' },
    { name: 'respostas_afinidade', col: 'user_id' },
    { name: 'followed_places', col: 'user_id' },
    { name: 'olhando_momentos', col: 'user_id' },
    { name: 'place_profiles', col: 'profile_id' },
    { name: 'interacoes', col: 'user_id' },
    { name: 'comentarios_momentos', col: 'user_id' },
    { name: 'likes', col: 'user_id' },
    { name: 'videos', col: 'user_id' },
    { name: 'registrando_agora', col: 'user_id' },
  ];

  for (const t of tables) {
    const { count, error } = await supa
      .from(t.name)
      .select('*', { count: 'exact', head: true })
      .eq(t.col, o.id);
    if (error) {
      console.log(`  ${C.red}${t.name.padEnd(25)}${C.reset} erro: ${error.message}`);
    } else {
      const tag = count > 0 ? `${C.yellow}${count}${C.reset}` : `${C.gray}0${C.reset}`;
      console.log(`  ${C.dim}${t.name.padEnd(25)}${C.reset} ${tag}`);
    }
  }
  console.log();
}

console.log(`${C.bold}Inspecao concluida.${C.reset}\n`);
console.log(`${C.dim}Proximo passo: olhar cada orfao, decidir destino (vincular / arquivar / deletar com cascata).${C.reset}\n`);