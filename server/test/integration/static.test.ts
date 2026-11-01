import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { brotliCompressSync } from "node:zlib";
import { buildApp } from "../../src/app.js";

/** Carpeta con un "juego web" mínimo, con el .wasm ya comprimido como lo deja precompress.mjs. */
function fakeGame(): string {
  const dir = mkdtempSync(join(tmpdir(), "hc-game-"));
  writeFileSync(join(dir, "index.html"), "<html>HISTORY COMBAT</html>");
  const wasm = Buffer.alloc(4096, 7);
  writeFileSync(join(dir, "index.wasm"), wasm);
  writeFileSync(join(dir, "index.wasm.br"), brotliCompressSync(wasm));
  return dir;
}

test("sirve la página del juego en /", async (t) => {
  const app = await buildApp({ config: { logger: false, staticDir: fakeGame() } });
  t.after(() => app.close());
  const res = await app.inject({ method: "GET", url: "/" });
  assert.equal(res.statusCode, 200);
  assert.match(res.body, /HISTORY COMBAT/);
  assert.equal(res.headers["cache-control"], "no-cache");
});

test("las rutas del servidor tienen prioridad sobre los archivos", async (t) => {
  const app = await buildApp({ config: { logger: false, staticDir: fakeGame() } });
  t.after(() => app.close());
  assert.equal((await app.inject({ method: "GET", url: "/health" })).json().ok, true);
  assert.equal((await app.inject({ method: "GET", url: "/protocol" })).json().endpoint, "/ws");
  assert.equal((await app.inject({ method: "GET", url: "/docs/json" })).statusCode, 200);
});

test("el .wasm se entrega con su tipo y precomprimido si el navegador lo admite", async (t) => {
  const app = await buildApp({ config: { logger: false, staticDir: fakeGame() } });
  t.after(() => app.close());
  const res = await app.inject({ method: "GET", url: "/index.wasm", headers: { "accept-encoding": "br" } });
  assert.equal(res.statusCode, 200);
  assert.equal(res.headers["content-type"], "application/wasm");
  assert.equal(res.headers["content-encoding"], "br");
  const plain = await app.inject({ method: "GET", url: "/index.wasm", headers: { "accept-encoding": "identity" } });
  assert.equal(plain.headers["content-encoding"], undefined);
  assert.equal(plain.rawPayload.length, 4096);
});

test("un archivo que no existe da 404", async (t) => {
  const app = await buildApp({ config: { logger: false, staticDir: fakeGame() } });
  t.after(() => app.close());
  assert.equal((await app.inject({ method: "GET", url: "/nada.js" })).statusCode, 404);
});

test("sin carpeta del juego, / no existe y el servidor sigue funcionando", async (t) => {
  const app = await buildApp({ config: { logger: false, staticDir: join(tmpdir(), "no-existe-hc") } });
  t.after(() => app.close());
  assert.equal((await app.inject({ method: "GET", url: "/" })).statusCode, 404);
  assert.equal((await app.inject({ method: "GET", url: "/health" })).statusCode, 200);
});
