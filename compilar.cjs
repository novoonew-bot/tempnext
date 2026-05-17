// compilar.cjs — compilador de produção do Tempnext
// Renomeado de compilar.js → .cjs: package.json tem "type":"module",
// então .js seria tratado como ESM e require() quebraria. .cjs força CommonJS.
//
// Uso: node compilar.cjs
// Lê index.html (orig com Babel) → gera index_compiled.html (JS puro).
//
// Dependências: @babel/core, @babel/preset-react, @babel/preset-env
// (declaradas em package.json devDependencies — npm install as mantém).

const fs = require('fs');
const babel = require('@babel/core');

// 1. Lê o index.html
const html = fs.readFileSync('index.html', 'utf8');

// 2. Garante que NÃO é um arquivo já compilado (proteção do Compile workflow)
if (html.indexOf('<script type="text/babel"') === -1) {
  console.error('[ERRO] index.html não tem <script type="text/babel">.');
  console.error('       Provavelmente é um arquivo JÁ COMPILADO. Restaure o orig antes de compilar.');
  process.exit(1);
}

// 3. Extrai APENAS o código JSX
const babelTag = '<script type="text/babel"';
const start = html.indexOf(babelTag);
const scriptStart = html.indexOf('>', start) + 1;
const scriptEnd = html.indexOf('</script>', scriptStart);
if (scriptEnd === -1) {
  console.error('[ERRO] Tag </script> de fechamento não encontrada.');
  process.exit(1);
}

const jsxCode = html.substring(scriptStart, scriptEnd);
console.log('JSX extraído: ' + jsxCode.length + ' chars');

// 4. Compila com Babel
let compiled;
try {
  const result = babel.transformSync(jsxCode, {
    presets: ['@babel/preset-react', '@babel/preset-env'],
    sourceMaps: false,
    compact: false,
  });
  compiled = result.code;
  console.log('Compilado com sucesso: ' + compiled.length + ' chars');
} catch (e) {
  console.error('[ERRO] Falha na compilação Babel:', e.message);
  console.error('       Linha no script:', e.loc ? e.loc.line : 'desconhecida');
  process.exit(1);
}

// 5. Monta o HTML final
const beforeScript = html.substring(0, start);
const afterScript = html.substring(scriptEnd + '</script>'.length);

const htmlFinal = beforeScript
    .replace('<script src="https://cdnjs.cloudflare.com/ajax/libs/babel-standalone/7.23.2/babel.min.js"></script>', '')
  + '<script type="text/javascript">\n' + compiled + '\n</script>'
  + afterScript;

// 6. Sanidade: o arquivo final NÃO pode mais conter a tag babel nem o CDN do Babel
if (htmlFinal.indexOf('<script type="text/babel"') !== -1) {
  console.error('[ERRO] HTML final ainda contém tag text/babel — compilação inconsistente. Abortado.');
  process.exit(1);
}
if (htmlFinal.indexOf('babel-standalone') !== -1) {
  console.error('[AVISO] HTML final ainda referencia babel-standalone CDN.');
}

fs.writeFileSync('index_compiled.html', htmlFinal, 'utf8');
console.log('Arquivo gerado: index_compiled.html');
console.log('Tamanho final: ' + (htmlFinal.length / 1024).toFixed(0) + 'KB');
