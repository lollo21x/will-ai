#!/usr/bin/env bash
# Prepara ios/www: copia la PWA, include le librerie in locale (niente CDN) e prepara l'icona.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WWW="$ROOT/ios/www"; TMP="$(mktemp -d)"
rm -rf "$WWW"; mkdir -p "$WWW/vendor/pdfjs"
cp "$ROOT/index.html" "$ROOT/manifest.webmanifest" "$WWW/"
for f in "$ROOT"/*.png "$ROOT"/*.svg; do [ -f "$f" ] && cp "$f" "$WWW/"; done
( cd "$TMP" && npm init -y >/dev/null && npm i --silent @mlc-ai/web-llm@0.2.88 @wllama/wllama@3.13.0 pdfjs-dist@4.10.38 esbuild )
"$TMP/node_modules/.bin/esbuild" "$TMP/node_modules/@mlc-ai/web-llm/lib/index.js" --bundle --format=esm --minify --outfile="$WWW/vendor/web-llm.js"
cp -R "$TMP/node_modules/@wllama/wllama/esm" "$WWW/vendor/wllama"
cp "$TMP/node_modules/pdfjs-dist/build/pdf.min.mjs" "$TMP/node_modules/pdfjs-dist/build/pdf.worker.min.mjs" "$WWW/vendor/pdfjs/"
python3 - "$WWW/index.html" <<'PY'
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
R=[("'https://cdn.jsdelivr.net/npm/@mlc-ai/web-llm@0.2.88/+esm'","'./vendor/web-llm.js'"),
("'https://cdn.jsdelivr.net/npm/@wllama/wllama@'+WLV+'/esm/index.js'","'./vendor/wllama/index.js'"),
("'https://cdn.jsdelivr.net/npm/@wllama/wllama@'+WLV+'/esm/wasm/wllama.wasm'","'./vendor/wllama/wasm/wllama.wasm'"),
("'https://cdn.jsdelivr.net/npm/pdfjs-dist@'+V+'/build/pdf.min.mjs'","'./vendor/pdfjs/pdf.min.mjs'"),
("'https://cdn.jsdelivr.net/npm/pdfjs-dist@'+V+'/build/pdf.worker.min.mjs'","'./vendor/pdfjs/pdf.worker.min.mjs'")]
for a,b in R:
    if a not in s: sys.exit('Pattern non trovato in index.html: '+a)
    s=s.replace(a,b)
open(p,'w',encoding='utf-8').write(s)
PY
ICON="$ROOT/icon-512.png"
if [ -f "$ICON" ] && command -v sips >/dev/null; then
  sips -z 1024 1024 "$ICON" --out "$ROOT/ios/WillAI/Assets.xcassets/AppIcon.appiconset/AppIcon.png" >/dev/null
fi
echo "ios/www pronto"
