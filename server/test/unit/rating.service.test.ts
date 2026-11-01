import { test } from "node:test";
import assert from "node:assert/strict";
import { applyDelta, eloDelta } from "../../src/services/rating.service.js";

test("entre iguales, el ganador sube 16 y el perdedor baja 16", () => {
  assert.equal(eloDelta(1000, 1000, 1), 16);
  assert.equal(eloDelta(1000, 1000, 2), -16);
});

test("un empate entre iguales no mueve a nadie", () => {
  assert.equal(eloDelta(1000, 1000, 0), 0);
});

test("ganarle a alguien mejor da más puntos que ganarle a alguien peor", () => {
  const vsBetter = eloDelta(1000, 1400, 1);
  const vsWorse = eloDelta(1400, 1000, 1);
  assert.ok(vsBetter > 16, `contra uno mejor: +${vsBetter}`);
  assert.ok(vsWorse < 16, `contra uno peor: +${vsWorse}`);
});

test("un favorito aplastante siempre gana al menos 1 punto", () => {
  assert.equal(eloDelta(3000, 0, 1), 1);
  assert.equal(eloDelta(0, 3000, 2), -1);
});

test("un empate favorece al que tiene menos puntos", () => {
  assert.ok(eloDelta(800, 1200, 0) > 0);
  assert.ok(eloDelta(1200, 800, 0) < 0);
});

test("los puntos nunca bajan de 0", () => {
  assert.equal(applyDelta(10, -16), 0);
  assert.equal(applyDelta(1000, -16), 984);
  assert.equal(applyDelta(1000, 16), 1016);
});
