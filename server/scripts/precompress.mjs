// Comprime con Brotli y gzip los archivos del juego web (public/) para que
// el servidor los entregue ya comprimidos: el .wasm y el .pck pesan decenas de MB.
// Uso: node scripts/precompress.mjs [carpeta]   (por defecto: public)
import { readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { extname, join } from "node:path";
import { brotliCompressSync, constants, gzipSync } from "node:zlib";

const COMPRESSIBLE = new Set([".html", ".js", ".wasm", ".pck", ".json", ".css", ".svg"]);
const MIN_BYTES = 1024;

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) yield* walk(path);
    else yield path;
  }
}

const root = process.argv[2] ?? "public";
let files = 0;
let before = 0;
let after = 0;
for (const path of walk(root)) {
  if (!COMPRESSIBLE.has(extname(path)) || statSync(path).size < MIN_BYTES) continue;
  const data = readFileSync(path);
  const br = brotliCompressSync(data, {
    params: {
      [constants.BROTLI_PARAM_QUALITY]: 9,
      [constants.BROTLI_PARAM_SIZE_HINT]: data.length,
    },
  });
  writeFileSync(`${path}.br`, br);
  writeFileSync(`${path}.gz`, gzipSync(data, { level: 9 }));
  files++;
  before += data.length;
  after += br.length;
}
console.log(`${files} archivos comprimidos: ${(before / 1e6).toFixed(1)} MB → ${(after / 1e6).toFixed(1)} MB (brotli)`);
