import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { brotliCompressSync } from "node:zlib";
import { buildApp, loadConfig } from "../src/app.js";

/** Carpeta con un "juego web" mínimo, con el .wasm ya comprimido como lo deja precompress.mjs. */
function fakeGame(): string {
  const dir = mkdtempSync(join(tmpdir(), "hc-game-"));
  writeFileSync(join(dir, "index.html"), "<html>HISTORY COMBAT</html>");
  const wasm = Buffer.alloc(4096, 7);
  writeFileSync(join(dir, "index.wasm"), wasm);
  writeFileSync(join(dir, "index.wasm.br"), brotliCompressSync(wasm));
  return dir;
}

const base = { logger: false, serverUrl: "wss://server.example.com/ws" };

test("sirve la página del juego en /", async (t) => {
  const app = await buildApp({ ...base, staticDir: fakeGame() });
  t.after(() => app.close());
  const res = await app.inject({ method: "GET", url: "/" });
  assert.equal(res.statusCode, 200);
  assert.match(res.body, /HISTORY COMBAT/);
  assert.equal(res.headers["cache-control"], "no-cache");
});

test("/config.js entrega al juego la dirección del servidor, sin caché", async (t) => {
  const app = await buildApp({ ...base, staticDir: fakeGame() });
  t.after(() => app.close());
  const res = await app.inject({ method: "GET", url: "/config.js" });
  assert.equal(res.statusCode, 200);
  assert.match(String(res.headers["content-type"]), /javascript/);
  assert.equal(res.headers["cache-control"], "no-store");
  assert.equal(res.body, 'window.HC_SERVER_URL = "wss://server.example.com/ws";\n');
});

test("/config.js escapa el valor (no se puede inyectar código)", async (t) => {
  const app = await buildApp({ ...base, serverUrl: '";alert(1);"', staticDir: fakeGame() });
  t.after(() => app.close());
  const res = await app.inject({ method: "GET", url: "/config.js" });
  assert.equal(res.body, 'window.HC_SERVER_URL = "\\";alert(1);\\"";\n');
});

test("/health responde ok", async (t) => {
  const app = await buildApp({ ...base, staticDir: fakeGame() });
  t.after(() => app.close());
  assert.deepEqual((await app.inject({ method: "GET", url: "/health" })).json(), { ok: true });
});

test("el .wasm se entrega con su tipo y precomprimido si el navegador lo admite", async (t) => {
  const app = await buildApp({ ...base, staticDir: fakeGame() });
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
  const app = await buildApp({ ...base, staticDir: fakeGame() });
  t.after(() => app.close());
  assert.equal((await app.inject({ method: "GET", url: "/nada.js" })).statusCode, 404);
});

test("sin juego exportado, / da 404 pero /health y /config.js siguen respondiendo", async (t) => {
  const app = await buildApp({ ...base, staticDir: join(tmpdir(), "no-existe-hc") });
  t.after(() => app.close());
  assert.equal((await app.inject({ method: "GET", url: "/" })).statusCode, 404);
  assert.equal((await app.inject({ method: "GET", url: "/health" })).statusCode, 200);
  assert.equal((await app.inject({ method: "GET", url: "/config.js" })).statusCode, 200);
});

test("loadConfig: valores por defecto y variables de entorno", () => {
  assert.deepEqual(loadConfig({}), { staticDir: "public", serverUrl: "", logger: true });
  assert.deepEqual(loadConfig({ STATIC_DIR: "x", SERVER_URL: "wss://a/ws", LOG: "false" }),
    { staticDir: "x", serverUrl: "wss://a/ws", logger: false });
});
