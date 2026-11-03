import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../../src/app.js";
import { createTestDb, type PgliteDb } from "../helpers/pglite-db.js";

let db: PgliteDb;
let app: FastifyInstance;

before(async () => {
  db = await createTestDb();
  app = await buildApp({ db, config: { logger: false, authRateLimitPerMinute: 1000 } });
});
after(async () => {
  await app.close();
  await db.close();
});

const auth = (token: string) => ({ authorization: `Bearer ${token}` });
const email = (name: string) => `${name.toLowerCase()}@test.com`;

async function register(name: string): Promise<string> {
  const res = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: email(name), password: "secreto1", username: name },
  });
  assert.equal(res.statusCode, 201, res.body);
  return res.json().access_token as string;
}

const login = (name: string, password: string) =>
  app.inject({ method: "POST", url: "/auth/login", payload: { email: email(name), password } });
const patchMe = (token: string, payload: object) => app.inject({ method: "PATCH", url: "/me", payload, headers: auth(token) });
const changePassword = (token: string | undefined, payload: object) =>
  app.inject({ method: "POST", url: "/me/password", payload, headers: token ? auth(token) : {} });
const me = async (token: string) => (await app.inject({ method: "GET", url: "/me", headers: auth(token) })).json();

// ---- Nombre ----

test("cambiar el nombre: el perfil, el ranking y la búsqueda pública usan el nuevo", async () => {
  const t = await register("Viejo_1");
  const res = await patchMe(t, { username: "Nuevo_1" });
  assert.equal(res.statusCode, 200, res.body);
  assert.equal(res.json().username, "Nuevo_1");
  assert.equal((await me(t)).username, "Nuevo_1");
  assert.equal((await app.inject({ method: "GET", url: "/players/Nuevo_1" })).statusCode, 200);
  assert.equal((await app.inject({ method: "GET", url: "/players/Viejo_1" })).statusCode, 404);
  assert.equal((await login("Viejo_1", "secreto1")).statusCode, 200, "se entra con el email, no con el nombre");
});

test("el nombre no puede estar en uso, ni cambiando mayúsculas, y no se toca el avatar", async () => {
  const t = await register("Cambio_A");
  await register("Ocupado_1");
  const res = await patchMe(t, { username: "ocupado_1", avatar: "tesla" });
  assert.equal(res.statusCode, 409);
  assert.equal(res.json().error, "username_taken");
  assert.equal((await me(t)).avatar, null, "si el nombre falla no se cambia nada");
  assert.equal((await me(t)).username, "Cambio_A");
});

test("solo se puede cambiar una vez cada 7 días", async () => {
  const t = await register("Espera_1");
  assert.equal((await patchMe(t, { username: "Espera_2" })).statusCode, 200);
  const second = await patchMe(t, { username: "Espera_3" });
  assert.equal(second.statusCode, 429);
  assert.equal(second.json().error, "username_cooldown");
  await db.query("update players set username_changed_at = now() - interval '8 days' where username = 'Espera_2'");
  assert.equal((await patchMe(t, { username: "Espera_3" })).statusCode, 200);
});

test("escribir el mismo nombre no cambia nada ni gasta la espera", async () => {
  const t = await register("Igual_1");
  assert.equal((await patchMe(t, { username: "Igual_1" })).statusCode, 200);
  const row = await db.query<{ username_changed_at: string | null }>("select username_changed_at from players where username = 'Igual_1'");
  assert.equal(row.rows[0]!.username_changed_at, null);
  assert.equal((await patchMe(t, { username: "Igual_2" })).statusCode, 200, "el primer cambio de verdad sigue disponible");
});

test("cambiar solo las mayúsculas de mi propio nombre está permitido", async () => {
  const t = await register("mayus_1");
  const res = await patchMe(t, { username: "Mayus_1" });
  assert.equal(res.statusCode, 200, res.body);
  assert.equal(res.json().username, "Mayus_1");
});

test("un nombre con formato inválido se rechaza", async () => {
  const t = await register("Formato_1");
  assert.equal((await patchMe(t, { username: "ab" })).statusCode, 400);
  assert.equal((await patchMe(t, { username: "con espacio" })).statusCode, 400);
  assert.equal((await me(t)).username, "Formato_1");
});

test("nombre y avatar a la vez", async () => {
  const t = await register("Doble_1");
  const res = await patchMe(t, { username: "Doble_2", avatar: "napoleon" });
  assert.equal(res.statusCode, 200);
  assert.equal(res.json().username, "Doble_2");
  assert.equal(res.json().avatar, "napoleon");
});

// ---- Contraseña ----

test("cambiar la contraseña: la nueva sirve, la vieja no, y las otras sesiones se cierran", async () => {
  const current = await register("Clave_1");
  const otherDevice = (await login("Clave_1", "secreto1")).json().access_token as string;
  assert.equal((await app.inject({ method: "GET", url: "/me", headers: auth(otherDevice) })).statusCode, 200);

  const res = await changePassword(current, { current_password: "secreto1", new_password: "nueva-clave" });
  assert.equal(res.statusCode, 204, res.body);

  assert.equal((await login("Clave_1", "nueva-clave")).statusCode, 200);
  assert.equal((await login("Clave_1", "secreto1")).statusCode, 401);
  assert.equal((await app.inject({ method: "GET", url: "/me", headers: auth(current) })).statusCode, 200, "la sesión que cambió la clave sigue");
  assert.equal((await app.inject({ method: "GET", url: "/me", headers: auth(otherDevice) })).statusCode, 401, "la otra sesión se cerró");
});

test("con la contraseña actual equivocada responde 403 y no cambia nada", async () => {
  const t = await register("Clave_2");
  const res = await changePassword(t, { current_password: "equivocada", new_password: "nueva-clave" });
  assert.equal(res.statusCode, 403);
  assert.equal(res.json().error, "wrong_password");
  assert.equal((await login("Clave_2", "secreto1")).statusCode, 200);
});

test("una contraseña nueva demasiado corta se rechaza", async () => {
  const t = await register("Clave_3");
  assert.equal((await changePassword(t, { current_password: "secreto1", new_password: "123" })).statusCode, 400);
  assert.equal((await changePassword(t, { current_password: "secreto1" })).statusCode, 400);
});

test("una cuenta de Google no tiene contraseña que cambiar", async () => {
  const t = await register("Clave_4");
  await db.query("update players set password_hash = null, google_sub = 'sub-clave-4' where username = 'Clave_4'");
  const res = await changePassword(t, { current_password: "secreto1", new_password: "nueva-clave" });
  assert.equal(res.statusCode, 400);
  assert.equal(res.json().error, "no_password");
});

test("sin sesión no se puede cambiar la contraseña ni el nombre", async () => {
  assert.equal((await changePassword(undefined, { current_password: "a", new_password: "123456" })).statusCode, 401);
  assert.equal((await app.inject({ method: "PATCH", url: "/me", payload: { username: "Sin_Sesion" } })).statusCode, 401);
});
