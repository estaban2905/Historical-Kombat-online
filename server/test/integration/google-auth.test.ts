import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../../src/app.js";
import type { GoogleIdentity } from "../../src/services/google-verifier.js";
import { createTestDb, type PgliteDb } from "../helpers/pglite-db.js";

let db: PgliteDb;
let app: FastifyInstance;
let appOff: FastifyInstance;

/** Verificador falso: el "token" es un JSON con la identidad; "malo" simula un token rechazado por Google. */
const fakeVerifier = async (token: string): Promise<GoogleIdentity> => {
  if (token.startsWith("malo")) throw new Error("token inválido");
  return JSON.parse(token) as GoogleIdentity;
};
const token = (sub: string, email: string, emailVerified = true) => JSON.stringify({ sub, email, emailVerified });

before(async () => {
  db = await createTestDb();
  app = await buildApp({ db, googleVerifier: fakeVerifier, config: { logger: false, authRateLimitPerMinute: 1000 } });
  appOff = await buildApp({ db, config: { logger: false, googleClientId: "", authRateLimitPerMinute: 1000 } });
});
after(async () => {
  await app.close();
  await appOff.close();
  await db.close();
});

const google = (id_token: string, username?: string, a = app) =>
  a.inject({ method: "POST", url: "/auth/google", payload: { id_token, ...(username ? { username } : {}) } });

test("jugador nuevo: sin nombre pide username, con nombre crea la cuenta y abre sesión", async () => {
  const t = token("sub-nuevo", "nuevo@gmail.com");
  const sinNombre = await google(t);
  assert.equal(sinNombre.statusCode, 409);
  assert.equal(sinNombre.json().error, "username_required");

  const ok = await google(t, "Nuevo_1");
  assert.equal(ok.statusCode, 200, ok.body);
  assert.equal(ok.json().player.username, "Nuevo_1");
  assert.equal(ok.json().player.points, 1000);
  const me = await app.inject({ method: "GET", url: "/me", headers: { authorization: `Bearer ${ok.json().access_token}` } });
  assert.equal(me.statusCode, 200);
});

test("jugador que vuelve: entra sin nombre y es la misma cuenta", async () => {
  const t = token("sub-vuelve", "vuelve@gmail.com");
  const a = await google(t, "Vuelve_1");
  const b = await google(t);
  assert.equal(b.statusCode, 200);
  assert.equal(b.json().player.id, a.json().player.id);
});

test("una cuenta con contraseña y el mismo email pasa a Google: no se duplica, pierde contraseña y sesiones", async () => {
  // Alguien registró el email (sin verificarlo) y tiene sesión abierta.
  const reg = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: "mixta@gmail.com", password: "secreto1", username: "Mixta_1" },
  });
  assert.equal(reg.statusCode, 201, reg.body);
  const { access_token: oldAccess, refresh_token: oldRefresh } = reg.json();

  // El dueño real del email entra con Google: misma cuenta, sin pedir nombre.
  const g = await google(token("sub-mixta", "mixta@gmail.com"));
  assert.equal(g.statusCode, 200, g.body);
  assert.equal(g.json().player.id, reg.json().player.id);

  // Quien la registró ya no puede entrar: ni con la contraseña ni con su sesión.
  const login = await app.inject({
    method: "POST",
    url: "/auth/login",
    payload: { email: "mixta@gmail.com", password: "secreto1" },
  });
  assert.equal(login.statusCode, 401);
  const me = await app.inject({ method: "GET", url: "/me", headers: { authorization: `Bearer ${oldAccess}` } });
  assert.equal(me.statusCode, 401);
  const refresh = await app.inject({ method: "POST", url: "/auth/refresh", payload: { refresh_token: oldRefresh } });
  assert.equal(refresh.statusCode, 401);

  // La sesión nueva de Google sí funciona, y volver a entrar con Google da la misma cuenta.
  const meGoogle = await app.inject({
    method: "GET",
    url: "/me",
    headers: { authorization: `Bearer ${g.json().access_token}` },
  });
  assert.equal(meGoogle.statusCode, 200);
  const again = await google(token("sub-mixta", "mixta@gmail.com"));
  assert.equal(again.json().player.id, reg.json().player.id);
});

test("un email ya enlazado a otra cuenta de Google no se puede reclamar", async () => {
  await google(token("sub-duena", "duena@gmail.com"), "Duena_1");
  const otro = await google(token("sub-intruso", "duena@gmail.com"), "Intruso_1");
  assert.equal(otro.statusCode, 401);
  assert.equal(otro.json().error, "invalid_google_token");
});

test("una cuenta de Google no puede entrar con contraseña", async () => {
  const res = await app.inject({
    method: "POST",
    url: "/auth/login",
    payload: { email: "nuevo@gmail.com", password: "cualquiera1" },
  });
  assert.equal(res.statusCode, 401);
  assert.equal(res.json().error, "invalid_credentials");
});

test("token rechazado por Google o con email sin verificar: 401", async () => {
  const malo = await google("malo-token-de-prueba-largo");
  assert.equal(malo.statusCode, 401);
  assert.equal(malo.json().error, "invalid_google_token");
  const sinVerificar = await google(token("sub-x", "x@gmail.com", false), "Equis_1");
  assert.equal(sinVerificar.statusCode, 401);
});

test("nombre de jugador repetido: 409 username_taken", async () => {
  const res = await google(token("sub-otro", "otro@gmail.com"), "Nuevo_1");
  assert.equal(res.statusCode, 409);
  assert.equal(res.json().error, "username_taken");
});

test("sin GOOGLE_CLIENT_ID la ruta responde 503", async () => {
  const res = await google(token("sub-z", "z@gmail.com"), "Zeta_1", appOff);
  assert.equal(res.statusCode, 503);
  assert.equal(res.json().error, "google_disabled");
});
