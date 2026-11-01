import { test } from "node:test";
import assert from "node:assert/strict";
import { RateLimiter } from "../../src/services/rate-limiter.service.js";

test("permite hasta el máximo por segundo y luego bloquea", () => {
  let now = 0;
  const rl = new RateLimiter(3, () => now);
  assert.deepEqual([rl.allow(), rl.allow(), rl.allow(), rl.allow()], [true, true, true, false]);
});

test("la ventana se reinicia pasado un segundo", () => {
  let now = 0;
  const rl = new RateLimiter(1, () => now);
  assert.equal(rl.allow(), true);
  assert.equal(rl.allow(), false);
  now = 1000;
  assert.equal(rl.allow(), true);
});
