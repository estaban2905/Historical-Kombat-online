import { test } from "node:test";
import assert from "node:assert/strict";
import { loadConfig } from "../../src/config/env.js";

test("valores por defecto", () => {
  const c = loadConfig({});
  assert.equal(c.port, 8787);
  assert.equal(c.docsEnabled, true);
  assert.equal(c.maxMessagesPerSecond, 120);
});

test("lee variables de entorno y descarta valores inválidos", () => {
  const c = loadConfig({ PORT: "3000", DOCS_ENABLED: "false", MAX_PAYLOAD: "abc", LOG: "false" });
  assert.equal(c.port, 3000);
  assert.equal(c.docsEnabled, false);
  assert.equal(c.maxPayload, 1024);
  assert.equal(c.logger, false);
});
