#!/usr/bin/env node
/**
 * check_interactions.js
 *
 * Verifica se profiles REAIS interagiram com conteudo dos orfaos.
 * Se houver interacao, ela vai sumir na cascata do DELETE.
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

// IDs reais
const REAL_PROFILE_IDS = [
  '8e858623-46d0-427d-932e-37bb5ab36cb7', // josemar8623@
  '22863c75-4739-4ab7-b45d-009e543df4d8', // novoonew@
  'fa5654f1-f68a-4ea3-8a80-62fc17d2e531', // suzane1302@
];

// IDs dos orfaos (que serao deletados)
const ORPHAN_PROFILE_IDS = [
  '0a42f1bd-5fad-4e0f-899c-dcc8c399b545', // Josemar Primavera do Leste
  'c2c5bf56-8f56-44c8-b797-dfe67ca2fda9', // Josemar Campo Verde 17/abr
  'ec7e970c-9dd4-405b-ad0c-a94f7d7c1183', // Mariana Costa
];

console.log(`\n${C.bold}--- Checagem: interacoes de profiles REAIS em conteudo de ORFAOS ---${C.reset}\n`);

// 1. Pega os momentos dos orfaos
const { data: momentosOrfaos, error: e1 } = await supa
  .from('momentos')
  .select('id, user_id, texto, lugar, tipo, capsula_dimensao, ts')
  .in('user_id', ORPHAN_PROFILE_IDS);

if (e1) {
  console.error(`Erro: ${e1.message}`);
  process.exit(1);
}

console.log(`${C.bold}Momentos pertencentes a orfaos: ${momentosOrfaos.length}${C.reset}`);
for (const m of momentosOrfaos) {
  const owner = m.user_id === ORPHAN_PROFILE_IDS[0] ? 'Josemar PdL' :
                m.user_id === ORPHAN_PROFILE_IDS[1] ? 'Josemar CV-17abr' :
                'Mariana Costa';
  const tag = m.tipo === 'capsula' ? `capsula-${m.capsula_dimensao}` : 'momento';
  console.log(`  ${C.dim}[${owner}]${C.reset} ${tag} em "${m.lugar || '(sem lugar)'}" — ${(m.texto || '').slice(0, 60)}...`);
}

if (momentosOrfaos.length === 0) {
  console.log(`  ${C.gray}(nenhum)${C.reset}`);
}

const orphanMomentoIds = momentosOrfaos.map(m => m.id);

// 2. Likes/comentarios de REAIS em momentos de ORFAOS (via interacoes)
console.log(`\n${C.bold}Interacoes de profiles REAIS em momentos de orfaos:${C.reset}`);

if (orphanMomentoIds.length > 0) {
  const { data: interacoes, error: e2 } = await supa
    .from('interacoes')
    .select('id, user_id, tipo, alvo_id, texto, criado_em')
    .in('user_id', REAL_PROFILE_IDS)
    .in('alvo_id', orphanMomentoIds);

  if (e2) {
    console.error(`  ${C.red}Erro: ${e2.message}${C.reset}`);
  } else if (interacoes.length === 0) {
    console.log(`  ${C.gray}(nenhuma — nada se perde)${C.reset}`);
  } else {
    console.log(`  ${C.yellow}${interacoes.length} interacao(oes) encontrada(s) — vao sumir na cascata:${C.reset}`);
    for (const i of interacoes) {
      const who = i.user_id === REAL_PROFILE_IDS[0] ? 'josemar8623' :
                  i.user_id === REAL_PROFILE_IDS[1] ? 'novoonew' :
                  'suzane';
      console.log(`    [${who}] ${i.tipo}${i.texto ? `: "${i.texto.slice(0, 60)}"` : ''} (${i.criado_em})`);
    }
  }

  // 3. comentarios_momentos
  const { data: comentarios, error: e3 } = await supa
    .from('comentarios_momentos')
    .select('id, user_id, momento_id, texto, created_at')
    .in('user_id', REAL_PROFILE_IDS)
    .in('momento_id', orphanMomentoIds);

  console.log(`\n${C.bold}Comentarios em comentarios_momentos:${C.reset}`);
  if (e3) {
    console.error(`  ${C.red}Erro: ${e3.message}${C.reset}`);
  } else if (comentarios.length === 0) {
    console.log(`  ${C.gray}(nenhum)${C.reset}`);
  } else {
    console.log(`  ${C.yellow}${comentarios.length} comentario(s) — vao sumir na cascata:${C.reset}`);
    for (const c of comentarios) {
      const who = c.user_id === REAL_PROFILE_IDS[0] ? 'josemar8623' :
                  c.user_id === REAL_PROFILE_IDS[1] ? 'novoonew' :
                  'suzane';
      console.log(`    [${who}]: "${(c.texto || '').slice(0, 60)}" (${c.created_at})`);
    }
  }

  // 4. likes (tabela legada)
  const { data: likes, error: e4 } = await supa
    .from('likes')
    .select('id, user_id, target_id, target_type')
    .in('user_id', REAL_PROFILE_IDS)
    .in('target_id', orphanMomentoIds);

  console.log(`\n${C.bold}Likes (tabela legada):${C.reset}`);
  if (e4) {
    console.error(`  ${C.red}Erro: ${e4.message}${C.reset}`);
  } else if (likes.length === 0) {
    console.log(`  ${C.gray}(nenhum)${C.reset}`);
  } else {
    console.log(`  ${C.yellow}${likes.length} like(s) — vao sumir:${C.reset}`);
    for (const l of likes) {
      const who = l.user_id === REAL_PROFILE_IDS[0] ? 'josemar8623' :
                  l.user_id === REAL_PROFILE_IDS[1] ? 'novoonew' :
                  'suzane';
      console.log(`    [${who}] target_type=${l.target_type}`);
    }
  }
}

// 5. Capsulas aguardando dos reais relacionadas a capsulas de orfaos
console.log(`\n${C.bold}Reais aguardando capsulas de orfaos:${C.reset}`);
const orphanCapsulas = momentosOrfaos.filter(m => m.tipo === 'capsula').map(m => m.id);
if (orphanCapsulas.length === 0) {
  console.log(`  ${C.gray}(orfaos nao tem capsulas)${C.reset}`);
} else {
  const { data: aguardando, error: e5 } = await supa
    .from('capsula_aguardando')
    .select('capsula_id, user_id, revelada_em')
    .in('capsula_id', orphanCapsulas)
    .in('user_id', REAL_PROFILE_IDS);
  if (e5) {
    console.error(`  ${C.red}Erro: ${e5.message}${C.reset}`);
  } else if (aguardando.length === 0) {
    console.log(`  ${C.gray}(nenhum real aguardava capsula de orfao)${C.reset}`);
  } else {
    console.log(`  ${C.yellow}${aguardando.length} inscricao(oes) sera(o) perdida(s):${C.reset}`);
    for (const a of aguardando) {
      const who = a.user_id === REAL_PROFILE_IDS[0] ? 'josemar8623' :
                  a.user_id === REAL_PROFILE_IDS[1] ? 'novoonew' :
                  'suzane';
      console.log(`    [${who}] aguardava capsula ${a.capsula_id} (revelada_em: ${a.revelada_em || 'nao'})`);
    }
  }
}

// 6. Contacts entre reais e orfaos (relacao social)
console.log(`\n${C.bold}Contatos entre reais e orfaos:${C.reset}`);
const { data: contatos, error: e6 } = await supa
  .from('contacts')
  .select('user_id, contact_id, is_family, rel')
  .or(`and(user_id.in.(${REAL_PROFILE_IDS.join(',')}),contact_id.in.(${ORPHAN_PROFILE_IDS.join(',')})),and(user_id.in.(${ORPHAN_PROFILE_IDS.join(',')}),contact_id.in.(${REAL_PROFILE_IDS.join(',')}))`);
if (e6) {
  console.error(`  ${C.red}Erro: ${e6.message}${C.reset}`);
} else if (contatos.length === 0) {
  console.log(`  ${C.gray}(nenhuma relacao de contato entre reais e orfaos)${C.reset}`);
} else {
  console.log(`  ${C.yellow}${contatos.length} relacao(oes) de contato sera(o) afetada(s):${C.reset}`);
  for (const c of contatos) {
    console.log(`    ${c.user_id} -> ${c.contact_id} (rel: ${c.rel || 'null'}, is_family: ${c.is_family})`);
  }
}

console.log(`\n${C.bold}--- Fim da checagem ---${C.reset}\n`);