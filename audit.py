#!/usr/bin/env python3
# audit.py — auditoria reproduzivel do Tempnext index.html
# Uso: python audit.py [caminho_index.html]   (default: ./index.html)
# Nao estima nada: mede contra o arquivo vivo. Rode antes de qualquer decisao.

import re, sys
from collections import Counter

path = sys.argv[1] if len(sys.argv) > 1 else "index.html"
h = open(path, encoding="utf-8").read()

def sec(t): print("\n" + "=" * 4, t)

# --- baseline ---
sec("BASELINE")
print("linhas:", h.count("\n") + 1)
print("MB:", round(len(h.encode("utf-8")) / 1048576, 2))
print("React.createElement:", len(re.findall(r"React\.createElement", h)))
mk = re.findall(r"Tempnext v\d+", h)
print("marker versao:", mk[0] if mk else "NAO ENCONTRADO")

# --- 1. orfaos: componentes PascalCase declarados sem nenhum createElement ---
sec("1. ORFAOS (componente sem createElement)")
RUNTIME = {"Generator", "GeneratorFunction", "GeneratorFunctionPrototype"}
defs = sorted(set(re.findall(r"\bfunction\s+([A-Z][A-Za-z0-9_]+)\s*\(", h)))
orf = [n for n in defs
       if not re.search(r"createElement\(\s*" + re.escape(n) + r"\b", h)
       and n not in RUNTIME]
print("componentes PascalCase:", len(defs), "| orfaos reais:", len(orf))
for n in orf: print("  -", n)

# --- 2. vocab banido user-facing ---
sec("2. VOCAB BANIDO (cruz*/alma*) user-facing")
strings = re.findall(r'"([^"\\]{0,120})"', h) + re.findall(r"'([^'\\]{0,120})'", h)
pat = re.compile(r"\b(cruz\w*|alma\w*)\b", re.I)
bad = ["[", "]", "concat", "void 0", "React", "===", "//", "erro", "Erro",
       "log", "console", ".tipo", "periodo", ".anos"]
def uf(s):
    s = s.strip()
    return (pat.search(s) and " " in s and s[:1].isalpha()
            and not any(b in s for b in bad))
hits = sorted({s.strip() for s in strings if uf(s)})
for s in hits: print("  |", s)
print("total:", len(hits))

# --- 3. gate dev ---
sec("3. GATE DEV")
for k in ["dev=1", "popularTeste", "limparTeste", "ehDev"]:
    print(f"  {k}: {len(re.findall(re.escape(k), h))}")

# --- 4. duplicidade ---
sec("4. DUPLICIDADE")
half = len(h) // 2
print("arquivo dobrado (1a==2a metade):", h[:half] == h[half:half + half])
comp = [n for n in re.findall(r"\bfunction\s+([A-Z][A-Za-z0-9_]+)\s*\(", h)]
dupc = [(n, q) for n, q in Counter(comp).items() if q > 1]
print("componentes PascalCase repetidos:", dupc if dupc else "nenhum")
print("<head>:", h.count("<head"), "| <body>:", h.count("<body"),
      "| root:", h.count('id="root"'))

# --- 5. tabelas escritas pelo client ---
sec("5. TABELAS escritas pelo client")
ops = {}
for m in re.finditer(r"\.from\(\s*[\"']([a-z_]+)[\"']\s*\)([^;]{0,400})", h):
    for op in ["insert", "update", "upsert", "delete"]:
        if re.search(r"\." + op + r"\(", m.group(2)):
            ops.setdefault(m.group(1), set()).add(op)
PRIV = {"notificacoes", "messages", "interacoes", "likes"}
for t in sorted(ops):
    flag = "  <-- PRIVILEGIADA (usar RPC security definer/Edge Function)" if t in PRIV else ""
    print(f"  {t}: {','.join(sorted(ops[t]))}{flag}")
print("total tabelas com escrita:", len(ops))

# --- 6. higiene ---
sec("6. HIGIENE")
print("alert():", len(re.findall(r"\balert\(", h)))
print("console.warn:", len(re.findall(r"console\.warn", h)))
print("console.error:", len(re.findall(r"console\.error", h)))
print("catch vazio {}:", len(re.findall(r"catch\s*\([^)]*\)\s*\{\s*\}", h)))
print("unsplash hardcoded:", len(re.findall(r"images\.unsplash\.com", h)))

print("\n== FIM ==")
