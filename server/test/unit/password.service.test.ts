import { test } from "node:test";
import assert from "node:assert/strict";
import { hashPassword, verifyPassword } from "../../src/services/password.service.js";

test("una contraseña correcta se verifica y una incorrecta no", async () => {
  const hash = await hashPassword("secreto1");
  assert.equal(await verifyPassword("secreto1", hash), true);
  assert.equal(await verifyPassword("secreto2", hash), false);
  assert.equal(await verifyPassword("", hash), false);
});

test("el hash no contiene la contraseña y lleva sus parámetros", async () => {
  const hash = await hashPassword("secreto1");
  assert.ok(!hash.includes("secreto1"));
  assert.match(hash, /^scrypt\$16384\$8\$1\$/);
});

test("la misma contraseña da hashes distintos (sal aleatoria)", async () => {
  assert.notEqual(await hashPassword("secreto1"), await hashPassword("secreto1"));
});

test("un hash guardado mal formado nunca coincide", async () => {
  assert.equal(await verifyPassword("x", ""), false);
  assert.equal(await verifyPassword("x", "texto-cualquiera"), false);
  assert.equal(await verifyPassword("x", "bcrypt$1$2$3$4$5"), false);
});
