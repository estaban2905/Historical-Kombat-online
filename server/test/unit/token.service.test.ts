import { test } from "node:test";
import assert from "node:assert/strict";
import { generateToken, hashToken } from "../../src/services/token.service.js";

test("los tokens son largos, únicos y seguros para una cabecera", () => {
  const a = generateToken();
  const b = generateToken();
  assert.notEqual(a, b);
  assert.ok(a.length >= 40);
  assert.match(a, /^[A-Za-z0-9_-]+$/);
});

test("el hash es estable y no revela el token", () => {
  const t = generateToken();
  assert.equal(hashToken(t), hashToken(t));
  assert.notEqual(hashToken(t), t);
  assert.notEqual(hashToken(t), hashToken(generateToken()));
  assert.match(hashToken(t), /^[0-9a-f]{64}$/);
});
