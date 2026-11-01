import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../../src/app.js";

test("/health responde ok con las estadísticas", async (t) => {
  const app = await buildApp({ config: { logger: false } });
  t.after(() => app.close());
  const res = await app.inject({ method: "GET", url: "/health" });
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.json(), { ok: true, queued: 0, rooms: 0 });
});

test("/protocol lista los mensajes del cliente y del servidor", async (t) => {
  const app = await buildApp({ config: { logger: false } });
  t.after(() => app.close());
  const body = (await app.inject({ method: "GET", url: "/protocol" })).json();
  assert.equal(body.endpoint, "/ws");
  assert.deepEqual(Object.keys(body.client).sort(), ["cancel", "find", "input", "leave"]);
  assert.deepEqual(Object.keys(body.server).sort(), ["error", "input", "matched", "opponent_left", "queued"]);
});

test("Swagger publica el OpenAPI con /health y /protocol (y oculta /ws)", async (t) => {
  const app = await buildApp({ config: { logger: false } });
  t.after(() => app.close());
  const spec = (await app.inject({ method: "GET", url: "/docs/json" })).json();
  assert.equal(spec.info.title, "History Combat · Servidor online");
  assert.ok(spec.paths["/health"]);
  assert.ok(spec.paths["/protocol"]);
  assert.equal(spec.paths["/ws"], undefined);

  const ui = await app.inject({ method: "GET", url: "/docs/" });
  assert.equal(ui.statusCode, 200);
});

test("con DOCS_ENABLED=false no existe /docs", async (t) => {
  const app = await buildApp({ config: { logger: false, docsEnabled: false } });
  t.after(() => app.close());
  assert.equal((await app.inject({ method: "GET", url: "/docs/json" })).statusCode, 404);
});
