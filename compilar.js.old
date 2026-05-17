const fs = require('fs');
const babel = require('@babel/core');

// 1. Lê o index.html
const html = fs.readFileSync('index.html', 'utf8');

// 2. Extrai APENAS o código JSX — busca a tag correta
const babelTag = '<script type="text/babel"';
const start = html.indexOf(babelTag);
if(start === -1){
  console.error('Tag <script type="text/babel"> não encontrada!');
  process.exit(1);
}

// Encontra o fechamento da tag de abertura
const scriptStart = html.indexOf('>', start) + 1;

// Encontra o </script> correspondente — busca a partir do início do script
const scriptEnd = html.indexOf('</script>', scriptStart);
if(scriptEnd === -1){
  console.error('Tag </script> não encontrada!');
  process.exit(1);
}

const jsxCode = html.substring(scriptStart, scriptEnd);
console.log('JSX extraído: ' + jsxCode.length + ' chars');
console.log('Primeiros 100 chars:', jsxCode.substring(0, 100));

// 3. Compila com Babel
let compiled;
try {
  const result = babel.transformSync(jsxCode, {
    presets: ['@babel/preset-react', '@babel/preset-env'],
    sourceMaps: false,
  });
  compiled = result.code;
  console.log('Compilado com sucesso: ' + compiled.length + ' chars');
} catch(e) {
  console.error('Erro na compilação:', e.message);
  console.error('Linha:', e.loc ? e.loc.line : 'desconhecida');
  process.exit(1);
}

// 4. Monta o HTML final
// Pega tudo ANTES da tag script babel
const beforeScript = html.substring(0, start);
// Pega tudo DEPOIS do </script> do babel
const afterScript = html.substring(scriptEnd + '</script>'.length);

// Remove Babel CDN
let htmlFinal = beforeScript
  .replace('<script src="https://cdnjs.cloudflare.com/ajax/libs/babel-standalone/7.23.2/babel.min.js"></script>', '')
  + '<script type="text/javascript">\n' + compiled + '\n</script>'
  + afterScript;

fs.writeFileSync('index_compiled.html', htmlFinal, 'utf8');
console.log('Arquivo gerado: index_compiled.html');
console.log('Tamanho final: ' + (htmlFinal.length / 1024).toFixed(0) + 'KB');
