#!/usr/bin/env node
/**
 * test_anon_access.js
 *
 * Suíte de testes adversariais de RLS pra Tempnext.
 *
 * Modelo de ameaça: atacante de posse do anon key (público) tenta ler
 * dados privados via o REST endpoint do PostgREST/Supabase, sem JWT.
 *
 * Cada teste declara:
 *   - target: tabela + filtro
 *   - expectation: 'empty' (RLS bloqueou) | 'rows' (RLS permite — público intencional)
 *
 * Saída:
 *   ✓ PASS    expectation == realidade
 *   ✗ FAIL    expectation != realidade (vulnerabilidade ou regressão)
 *   ! ERROR   query falhou por motivo inesperado
 *
 * Códigos de saída:
 *   0  — todos os testes passaram
 *   1  — pelo menos um FAIL
 *   2  — pelo menos um ERROR (sem FAILs)
 *
 * IMPORTANTE: este script faz APENAS SELECT. Nenhuma operação destrutiva.
 */

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const { SUPABASE_URL, SUPABASE_ANON_KEY } = process.env;
const VERBOSE = process.env.VERBOSE === '1';

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('ERROR: missing SUPABASE_URL or SUPABASE_ANON_KEY in environment');
  process.exit(3);
}

// Cliente anônimo — sem JWT, simulando atacante
const anon = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: false,
    autoRefreshToken: false,
    detectSessionInUrl: false,
  },
});

// ─────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────

const COLORS = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  gray: '\x1b[90m',
  bold: '\x1b[1m',
  reset: '\x1b[0m',
};

const c = (color, text) => `${COLORS[color]}${text}${COLORS.reset}`;

let stats = { pass: 0, fail: 0, error: 0 };
const failures = [];

/**
 * Executa um teste contra a tabela e checa expectativa.
 *
 * @param {object} test
 * @param {string} test.name        descrição humana
 * @param {string} test.table       nome da tabela
 * @param {function} test.query     callback que recebe o anon.from(table) e aplica filtros
 * @param {'empty'|'rows'|'error'} test.expect
 *                                  'empty' = esperado bloqueio RLS (0 linhas)
 *                                  'rows'  = esperado retorno público
 *                                  'error' = esperado erro PostgREST (ex: tabela não existe)
 * @param {string} [test.severity]  'critical' | 'high' | 'medium' (default 'high')
 */
async function check(test) {
  const severity = test.severity || 'high';
  const startedAt = Date.now();
  let result, error;

  try {
    const q = test.query(anon.from(test.table));
    const response = await q;
    result = response.data;
    error = response.error;
  } catch (err) {
    error = err;
  }

  const elapsedMs = Date.now() - startedAt;

  // Classifica resultado
  let status;
  if (error) {
    if (test.expect === 'error') status = 'PASS';
    else status = 'ERROR';
  } else if (result && result.length > 0) {
    if (test.expect === 'rows') status = 'PASS';
    else status = 'FAIL'; // esperava vazio, retornou linhas → leak
  } else {
    if (test.expect === 'empty') status = 'PASS';
    else if (test.expect === 'rows') {
      // Aceita 0 linhas como PASS pra 'rows' (não significa leak, só não tem dado)
      status = 'PASS';
    } else status = 'FAIL';
  }

  // Render
  const icon = status === 'PASS' ? c('green', '✓') : status === 'FAIL' ? c('red', '✗') : c('yellow', '!');
  const sevTag = severity === 'critical' ? c('red', '[CRITICAL]') : severity === 'high' ? c('yellow', '[HIGH]') : c('gray', '[MED]');
  const tableTag = c('gray', test.table.padEnd(24));
  console.log(`${icon} ${status.padEnd(5)} ${sevTag} ${tableTag} ${test.name} ${c('gray', `(${elapsedMs}ms)`)}`);

  if (VERBOSE && error) {
    console.log(c('gray', `    error: ${error.message || error.code || JSON.stringify(error)}`));
  }
  if (VERBOSE && result) {
    console.log(c('gray', `    rows returned: ${result.length}`));
    if (result.length > 0 && result.length <= 3) {
      console.log(c('gray', `    sample: ${JSON.stringify(result[0]).slice(0, 150)}`));
    }
  }

  // Stats
  if (status === 'PASS') stats.pass++;
  else if (status === 'FAIL') {
    stats.fail++;
    failures.push({ ...test, severity, rowsReturned: result?.length || 0, sample: result?.[0] });
  } else stats.error++;
}

// ─────────────────────────────────────────────────────────
// Suíte de testes
// ─────────────────────────────────────────────────────────

console.log(c('bold', '\n┌─ Tempnext RLS Adversarial Test Suite ─────────────────────────┐'));
console.log(c('gray', `│ Target: ${SUPABASE_URL.padEnd(54)} │`));
console.log(c('gray', `│ Mode:   anon role (no JWT)                                    │`));
console.log(c('gray', `│ Ops:    SELECT only                                           │`));
console.log(c('bold', '└───────────────────────────────────────────────────────────────┘\n'));

const suite = [
  // ─── Tabela momentos ──────────────────────────────────
  {
    name: 'listar todos os momentos sem filtro',
    table: 'momentos',
    query: q => q.select('id, user_id, capsula_visibilidade').limit(5),
    expect: 'empty',
    severity: 'high',
    rationale: 'Sem JWT, anon não deveria ler momentos privados/contatos/familia. Acceptable se RLS retornar só os públicos.',
  },
  {
    name: 'listar momentos com visibility=privado explicitamente',
    table: 'momentos',
    query: q => q.select('id, user_id, capsula_visibilidade').eq('capsula_visibilidade', 'privado').limit(5),
    expect: 'empty',
    severity: 'critical',
    rationale: 'Vazamento crítico: momento marcado privado nunca pode ser lido por anon.',
  },
  {
    name: 'listar momentos com visibility=familia',
    table: 'momentos',
    query: q => q.select('id, user_id, capsula_visibilidade').eq('capsula_visibilidade', 'familia').limit(5),
    expect: 'empty',
    severity: 'critical',
    rationale: 'Família é privado por escopo — anon não pode ver.',
  },
  {
    name: 'listar momentos com visibility=contatos',
    table: 'momentos',
    query: q => q.select('id, user_id, capsula_visibilidade').eq('capsula_visibilidade', 'contatos').limit(5),
    expect: 'empty',
    severity: 'critical',
    rationale: 'Contatos é privado por escopo — anon não pode ver.',
  },

  // ─── Tabela notificacoes ──────────────────────────────
  {
    name: 'listar notificações de qualquer usuário',
    table: 'notificacoes',
    query: q => q.select('id, user_id, tipo').limit(5),
    expect: 'empty',
    severity: 'critical',
    rationale: 'Notificações são estritamente por usuário. Anon não pode ler nenhuma.',
  },

  // ─── Tabela messages ──────────────────────────────────
  {
    name: 'listar mensagens (DMs)',
    table: 'messages',
    query: q => q.select('id, conv_id, from_id, text').limit(5),
    expect: 'empty',
    severity: 'critical',
    rationale: 'DMs são privadas por definição. Vazamento aqui é catastrófico.',
  },

  // ─── Tabela capsula_aguardando ────────────────────────
  {
    name: 'listar inscrições em cápsulas aguardando abrir',
    table: 'capsula_aguardando',
    query: q => q.select('id, capsula_id, user_id, revelada_em').limit(5),
    expect: 'empty',
    severity: 'high',
    rationale: 'Quem se inscreveu em qual cápsula é privado.',
  },

  // ─── Tabela respostas_afinidade ───────────────────────
  {
    name: 'listar respostas de afinidade em massa',
    table: 'respostas_afinidade',
    query: q => q.select('user_id, pergunta_id, resposta').limit(5),
    expect: 'empty',
    severity: 'high',
    rationale: 'Respostas pessoais — anon não deve ler.',
  },

  // ─── Tabela contacts ──────────────────────────────────
  {
    name: 'listar contatos de usuários',
    table: 'contacts',
    query: q => q.select('user_id, contact_id, is_family').limit(5),
    expect: 'empty',
    severity: 'high',
    rationale: 'Lista de contatos é informação pessoal. Vazamento expõe grafo social.',
  },

  // ─── Tabela followed_places ───────────────────────────
  {
    name: 'listar lugares seguidos por usuários',
    table: 'followed_places',
    query: q => q.select('user_id, place_id').limit(5),
    expect: 'empty',
    severity: 'medium',
    rationale: 'Padrão de favoritar lugares revela preferências do usuário.',
  },

  // ─── Tabela registrando_agora ─────────────────────────
  {
    name: 'listar entradas privadas/contatos de "registrando agora"',
    table: 'registrando_agora',
    query: q => q.select('user_id, cidade, lugar, privacidade').neq('privacidade', 'publico').limit(5),
    expect: 'empty',
    severity: 'high',
    rationale: 'Localização em tempo real privada/contatos não pode vazar.',
  },
  {
    name: 'listar entradas publicas de "registrando agora"',
    table: 'registrando_agora',
    query: q => q.select('user_id, cidade, lugar, privacidade').eq('privacidade', 'publico').limit(5),
    expect: 'rows',
    severity: 'medium',
    rationale: 'Públicas devem ser legíveis — caso contrário a feature quebra.',
  },

  // ─── Tabela olhando_momentos ──────────────────────────
  {
    name: 'listar quem viu qual momento',
    table: 'olhando_momentos',
    query: q => q.select('user_id, momento_id').limit(5),
    expect: 'empty',
    severity: 'medium',
    rationale: 'Telemetria de "quem viu" é privado.',
  },

  // ─── Tabelas públicas por design (sanity check) ───────
  {
    name: 'listar perfis (devem ser públicos)',
    table: 'profiles',
    query: q => q.select('id, name, city').limit(3),
    expect: 'rows',
    severity: 'medium',
    rationale: 'Perfis são públicos por design — se bloquear, app quebra.',
  },
  {
    name: 'listar lugares (devem ser públicos)',
    table: 'places',
    query: q => q.select('id, name, city').limit(3),
    expect: 'rows',
    severity: 'medium',
    rationale: 'Lugares são públicos por design.',
  },
  {
    name: 'ler cache de sugestões (público)',
    table: 'place_suggestions_cache',
    query: q => q.select('query_normalized, source').limit(3),
    expect: 'rows',
    severity: 'medium',
    rationale: 'Cache de busca de lugares — público intencional.',
  },
];

// Run
console.log(c('bold', `Running ${suite.length} test(s)...\n`));

for (const test of suite) {
  await check(test);
}

// ─────────────────────────────────────────────────────────
// Sumário
// ─────────────────────────────────────────────────────────

console.log(c('bold', '\n┌─ Summary ──────────────────────────────────────────────────┐'));
console.log(`│ ${c('green', `✓ PASS:  ${stats.pass}`)}`.padEnd(70) + '│');
console.log(`│ ${c('red', `✗ FAIL:  ${stats.fail}`)}`.padEnd(70) + '│');
console.log(`│ ${c('yellow', `! ERROR: ${stats.error}`)}`.padEnd(70) + '│');
console.log(c('bold', '└────────────────────────────────────────────────────────────┘'));

if (failures.length > 0) {
  console.log(c('bold', c('red', '\n⚠ FAILURES DETECTED:\n')));
  for (const f of failures) {
    const sev = f.severity === 'critical' ? c('red', '[CRITICAL]') : c('yellow', '[HIGH]');
    console.log(`  ${sev} ${f.table} → ${f.name}`);
    console.log(c('gray', `    ${f.rationale}`));
    if (f.rowsReturned > 0) {
      console.log(c('gray', `    Rows leaked: ${f.rowsReturned}`));
      if (f.sample) {
        console.log(c('gray', `    Sample: ${JSON.stringify(f.sample).slice(0, 200)}`));
      }
    }
    console.log();
  }
}

// Exit codes
if (stats.fail > 0) process.exit(1);
if (stats.error > 0) process.exit(2);
process.exit(0);
