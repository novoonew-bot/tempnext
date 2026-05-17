#!/usr/bin/env node
/**
 * confirm_whitelist.js
 *
 * Confirma que os 3 user_ids reais do Auth correspondem
 * a profiles existentes em public.profiles.
 *
 * Lista TODOS os profiles e mostra status de cada um.
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
  green: '\x1b[32m', yellow: '\x1b[33m', red: '\x1b[31m', cyan: '\x1b[36m', gray: '\x1b[90m',
};

// Whitelist final dos 3 auth_id reais
const WHITELIST_AUTH_IDS = [
  '4d514ba9-ee0a-4cd9-bb69-b08cce9375d1', // josemar8623@gmail.com (Josemar Reis)
  '3e0a4dc0-495e-4e08-8633-ea1e5127ff04', // novoonew@gmail.com (Jota)
  'ab0d3eeb-c6f8-42c1-bafb-1eaca74fc029', // suzane1302@gmail.com (Suzane Krewer)
];

// Auth users que vamos eliminar
const DELETE_AUTH_IDS = [
  '69bd93dd-a29e-49c5-830a-3e6177b07cff', // Josemar Matriz (teste)
  '3e867af9-6147-444b-868e-194814161301', // Amanda Krewer (teste)
];

console.log(`\n${C.bold}--- Confirmacao de Whitelist ---${C.reset}\n`);

// 1. Lista TODOS os profiles e classifica
const { data: profiles, error } = await supa
  .from('profiles')
  .select('id, auth_id, name, first_name, last_name, city, created_at');

if (error) {
  console.error(`${C.red}Erro lendo profiles: ${error.message}${C.reset}`);
  process.exit(1);
}

console.log(`${C.bold}Total de profiles em public.profiles: ${profiles.length}${C.reset}\n`);

const preservar = [];
const eliminarPorAuthRemovido = [];
const eliminarPorOrfao = [];
const naoClassificado = [];

for (const p of profiles) {
  if (p.auth_id === null) {
    eliminarPorOrfao.push(p);
  } else if (WHITELIST_AUTH_IDS.includes(p.auth_id)) {
    preservar.push(p);
  } else if (DELETE_AUTH_IDS.includes(p.auth_id)) {
    eliminarPorAuthRemovido.push(p);
  } else {
    naoClassificado.push(p);
  }
}

// 2. Mostra resultado
console.log(`${C.green}${C.bold}=== PRESERVAR (${preservar.length}) ===${C.reset}`);
for (const p of preservar) {
  console.log(`  ${C.green}OK${C.reset} profile.id=${p.id}`);
  console.log(`     auth_id:    ${p.auth_id}`);
  console.log(`     name:       ${p.name || `${p.first_name || ''} ${p.last_name || ''}`.trim() || '(sem nome)'}`);
  console.log(`     city:       ${p.city || '(null)'}`);
  console.log(`     created:    ${p.created_at}`);
  console.log();
}

console.log(`${C.yellow}${C.bold}=== ELIMINAR — Auth removido (${eliminarPorAuthRemovido.length}) ===${C.reset}`);
for (const p of eliminarPorAuthRemovido) {
  console.log(`  ${C.yellow}X${C.reset} profile.id=${p.id}`);
  console.log(`     auth_id:    ${p.auth_id}`);
  console.log(`     name:       ${p.name || '(sem nome)'}`);
  console.log();
}

console.log(`${C.yellow}${C.bold}=== ELIMINAR — Orfaos sem auth_id (${eliminarPorOrfao.length}) ===${C.reset}`);
for (const p of eliminarPorOrfao) {
  console.log(`  ${C.yellow}X${C.reset} profile.id=${p.id}`);
  console.log(`     name:       ${p.name || '(sem nome)'}`);
  console.log(`     city:       ${p.city || '(null)'}`);
  console.log();
}

if (naoClassificado.length > 0) {
  console.log(`${C.red}${C.bold}=== NAO CLASSIFICADO (${naoClassificado.length}) — ATENCAO ===${C.reset}`);
  for (const p of naoClassificado) {
    console.log(`  ${C.red}?${C.reset} profile.id=${p.id}`);
    console.log(`     auth_id:    ${p.auth_id}`);
    console.log(`     name:       ${p.name || '(sem nome)'}`);
    console.log(`     Esse profile tem auth_id que NAO esta na whitelist nem na lista de exclusao.`);
    console.log(`     Investigar antes de qualquer DELETE.`);
    console.log();
  }
}

// 3. Sumario
console.log(`${C.bold}--- Sumario ---${C.reset}`);
console.log(`  ${C.green}Preservar:${C.reset}                       ${preservar.length}`);
console.log(`  ${C.yellow}Eliminar (Auth removido):${C.reset}        ${eliminarPorAuthRemovido.length}`);
console.log(`  ${C.yellow}Eliminar (orfaos):${C.reset}               ${eliminarPorOrfao.length}`);
if (naoClassificado.length > 0) {
  console.log(`  ${C.red}Nao classificado (investigar!):${C.reset}  ${naoClassificado.length}`);
}
console.log(`  ${C.dim}Total:${C.reset}                           ${profiles.length}`);

if (preservar.length !== 3) {
  console.log(`\n${C.red}${C.bold}⚠ ATENCAO: esperava 3 profiles preservados, encontrei ${preservar.length}.${C.reset}`);
  console.log(`${C.red}Isso indica que pelo menos um dos 3 auth_id reais NAO tem profile correspondente.${C.reset}`);
  console.log(`${C.red}Nao prosseguir com DELETE ate investigar.${C.reset}`);
  process.exit(1);
}

if (naoClassificado.length > 0) {
  console.log(`\n${C.red}${C.bold}⚠ Ha profiles nao classificados. Nao prosseguir com DELETE.${C.reset}`);
  process.exit(1);
}

console.log(`\n${C.green}${C.bold}✓ Whitelist valida. Pronto para escrever SQL.${C.reset}\n`);