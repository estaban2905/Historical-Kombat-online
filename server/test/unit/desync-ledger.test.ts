import { test } from "node:test";
import assert from "node:assert/strict";
import { DesyncLedger } from "../../src/services/desync-ledger.js";

const HOUR = 60 * 60 * 1000;

test("cuenta las anulaciones de cada cuenta por separado", async () => {
  const ledger = new DesyncLedger(24 * HOUR);
  assert.equal(await ledger.record("a"), 1);
  assert.equal(await ledger.record("a"), 2);
  assert.equal(await ledger.record("b"), 1);
  assert.equal(await ledger.count("a"), 2);
  assert.equal(await ledger.count("nadie"), 0);
});

test("las anulaciones caducan al salir de la ventana", async () => {
  let now = 0;
  const ledger = new DesyncLedger(24 * HOUR, () => now);
  await ledger.record("a");
  now = 10 * HOUR;
  await ledger.record("a");
  now = 24 * HOUR + 1; // la primera ya salió; la segunda sigue
  assert.equal(await ledger.count("a"), 1);
  now = 40 * HOUR;
  assert.equal(await ledger.count("a"), 0);
  assert.equal(await ledger.record("a"), 1, "una cuenta vuelve a empezar de cero");
});

test("la memoria está acotada: las cuentas caducadas se barren al crecer demasiado", async () => {
  let now = 0;
  const ledger = new DesyncLedger(HOUR, () => now);
  for (let i = 0; i < 10_000; i++) await ledger.record(`viejo-${i}`);
  now = 2 * HOUR;
  await ledger.record("nuevo"); // pasa del tope: barre las 10.000 caducadas
  assert.equal(await ledger.count("viejo-0"), 0);
  assert.equal(await ledger.count("nuevo"), 1);
});
