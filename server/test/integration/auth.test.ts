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

const post = (url: string, payload: unknown, token?: string) =>
  app.inject({
    method: "POST",
    url,
    payload: payload as object,
    headers: token ? { authorization: `Bearer ${token}` } : {},
  });
const get = (url: string, token?: string) =>
  app.inject({ method: "GET", url, headers: token ? { authorization: `Bearer ${token}` } : {} });

async function register(name: string, email = `${name.toLowerCase()}@test.com`, password = "secreto1") {
  const res = await post("/auth/register", { email, password, username: name });
  assert.equal(res.statusCode, 201, res.body);
  return res.json() as { access_token: string; refresh_token: string; expires_in: number; player: { id: string; username: string; points: number } };
}

test("registrarse crea la cuenta con 1000 puntos y abre sesión", async () => {
  const s = await register("Ana_1");
  assert.equal(s.player.username, "Ana_1");
  assert.equal(s.player.points, 1000);
  assert.equal(s.expires_in, 3600);
  const me = await get("/me", s.access_token);
  assert.equal(me.statusCode, 200);
  assert.equal(me.json().username, "Ana_1");
});

test("las respuestas nunca incluyen email ni contraseña", async () => {
  const s = await register("Beto_2");
  const me = (await get("/me", s.access_token)).body;
  assert.ok(!/password|hash|email/i.test(me), me);
  const board = (await get("/leaderboard")).body;
  assert.ok(!/password|hash|email|@/i.test(board), board);
});

test("en la base de datos no se guarda la contraseña ni los tokens", async () => {
  const s = await register("Cata_3", "cata@test.com", "clave-muy-secreta");
  const players = await db.query<{ password_hash: string }>("select password_hash from players where username = 'Cata_3'");
  assert.ok(!players.rows[0]!.password_hash.includes("clave-muy-secreta"));
  const sessions = await db.query<{ access_hash: string; refresh_hash: string }>("select access_hash, refresh_hash from sessions");
  for (const row of sessions.rows) {
    assert.notEqual(row.access_hash, s.access_token);
    assert.notEqual(row.refresh_hash, s.refresh_token);
  }
});

test("no se puede repetir el email ni el nombre (sin distinguir mayúsculas)", async () => {
  await register("Dani_4", "dani@test.com");
  const email = await post("/auth/register", { email: "DANI@test.com", password: "secreto1", username: "Otro_4" });
  assert.equal(email.statusCode, 409);
  assert.equal(email.json().error, "email_taken");
  const name = await post("/auth/register", { email: "otro4@test.com", password: "secreto1", username: "dani_4" });
  assert.equal(name.statusCode, 409);
  assert.equal(name.json().error, "username_taken");
});

test("datos inválidos se rechazan con 400", async () => {
  const bad = [
    { email: "sin-arroba", password: "secreto1", username: "Eva_5" },
    { email: "eva@test.com", password: "123", username: "Eva_5" },
    { email: "eva@test.com", password: "secreto1", username: "ab" },
    { email: "eva@test.com", password: "secreto1", username: "con espacio" },
    { email: "eva@test.com", password: "secreto1" },
  ];
  for (const payload of bad) {
    const res = await post("/auth/register", payload);
    assert.equal(res.statusCode, 400, JSON.stringify(payload));
    assert.equal(res.json().error, "invalid_request");
  }
});

test("las propiedades desconocidas se ignoran y no se guardan", async () => {
  const res = await post("/auth/register", { email: "zeta@test.com", password: "secreto1", username: "Zeta_0", points: 99999 });
  assert.equal(res.statusCode, 201);
  assert.equal(res.json().player.points, 1000, "no se puede elegir los puntos de inicio");
});

test("iniciar sesión: correcto, contraseña mala y email desconocido", async () => {
  await register("Fede_6", "fede@test.com");
  const ok = await post("/auth/login", { email: "FEDE@test.com", password: "secreto1" });
  assert.equal(ok.statusCode, 200);
  assert.equal(ok.json().player.username, "Fede_6");

  const wrongPass = await post("/auth/login", { email: "fede@test.com", password: "mala-clave" });
  const unknown = await post("/auth/login", { email: "nadie@test.com", password: "secreto1" });
  for (const res of [wrongPass, unknown]) {
    assert.equal(res.statusCode, 401);
    assert.equal(res.json().error, "invalid_credentials");
  }
  // El mismo mensaje en ambos casos: no se puede averiguar qué emails existen.
  assert.deepEqual(wrongPass.json(), unknown.json());
});

test("renovar la sesión da tokens nuevos e invalida el refresh token usado", async () => {
  const s = await register("Gabi_7");
  const r = await post("/auth/refresh", { refresh_token: s.refresh_token });
  assert.equal(r.statusCode, 200);
  const n = r.json();
  assert.notEqual(n.access_token, s.access_token);
  assert.notEqual(n.refresh_token, s.refresh_token);

  assert.equal((await get("/me", n.access_token)).statusCode, 200);
  assert.equal((await get("/me", s.access_token)).statusCode, 401, "el access token viejo ya no sirve");
  const reuse = await post("/auth/refresh", { refresh_token: s.refresh_token });
  assert.equal(reuse.statusCode, 401, "el refresh token viejo no se puede reutilizar");
  assert.equal(reuse.json().error, "invalid_token");
});

test("un refresh token inventado se rechaza", async () => {
  const res = await post("/auth/refresh", { refresh_token: "x".repeat(43) });
  assert.equal(res.statusCode, 401);
});

test("cerrar sesión invalida el token", async () => {
  const s = await register("Hugo_8");
  // Un segundo dispositivo con la misma cuenta.
  const other = (await post("/auth/login", { email: "hugo_8@test.com", password: "secreto1" })).json();
  assert.equal((await post("/auth/logout", {}, s.access_token)).statusCode, 204);
  assert.equal((await get("/me", s.access_token)).statusCode, 401);
  assert.equal((await post("/auth/refresh", { refresh_token: s.refresh_token })).statusCode, 401, "el refresh token de esa sesión muere con ella");
  assert.equal((await get("/me", other.access_token)).statusCode, 200, "las otras sesiones no se tocan");
});

test("las rutas protegidas exigen un token válido", async () => {
  assert.equal((await get("/me")).statusCode, 401);
  assert.equal((await get("/me", "token-falso")).statusCode, 401);
  assert.equal((await post("/auth/logout", {})).statusCode, 401);
  const res = await app.inject({ method: "GET", url: "/me", headers: { authorization: "Basic abc" } });
  assert.equal(res.statusCode, 401);
});

test("un access token caducado deja de servir", async () => {
  const s = await register("Ines_9");
  await db.query("update sessions set access_expires = now() - interval '1 minute' where player_id = $1", [s.player.id]);
  assert.equal((await get("/me", s.access_token)).statusCode, 401);
  // Pero el refresh token sigue vivo y renueva la sesión.
  assert.equal((await post("/auth/refresh", { refresh_token: s.refresh_token })).statusCode, 200);
});

test("un refresh token caducado deja de servir", async () => {
  const s = await register("Juan_10");
  await db.query("update sessions set refresh_expires = now() - interval '1 minute' where player_id = $1", [s.player.id]);
  assert.equal((await post("/auth/refresh", { refresh_token: s.refresh_token })).statusCode, 401);
});

test("el ranking ordena por puntos y luego por victorias", async () => {
  const a = await register("Rank_A");
  const b = await register("Rank_B");
  const c = await register("Rank_C");
  await db.query("update players set points = 5000, wins = 1 where id = $1", [a.player.id]);
  await db.query("update players set points = 5000, wins = 9 where id = $1", [b.player.id]);
  await db.query("update players set points = 4999, wins = 99 where id = $1", [c.player.id]);
  const board = (await get("/leaderboard?limit=3")).json() as Array<{ username: string }>;
  assert.deepEqual(board.map((p) => p.username), ["Rank_B", "Rank_A", "Rank_C"]);
  assert.equal(((await get("/leaderboard?limit=2")).json() as unknown[]).length, 2);
  assert.equal((await get("/leaderboard?limit=0")).statusCode, 400);
  assert.equal((await get("/leaderboard?limit=1000")).statusCode, 400);
});

test("el límite de intentos frena la fuerza bruta (429)", async (t) => {
  const limited = await buildApp({ db, config: { logger: false, authRateLimitPerMinute: 3 } });
  t.after(() => limited.close());
  const codes: number[] = [];
  for (let i = 0; i < 5; i++) {
    const res = await limited.inject({ method: "POST", url: "/auth/login", payload: { email: "x@test.com", password: "secreto1" } });
    codes.push(res.statusCode);
  }
  assert.deepEqual(codes, [401, 401, 401, 429, 429]);
});

test("la documentación Swagger incluye las rutas de cuentas", async () => {
  const spec = (await get("/docs/json")).json();
  for (const path of ["/auth/register", "/auth/login", "/auth/refresh", "/auth/logout", "/me", "/leaderboard"]) {
    assert.ok(spec.paths[path], `falta ${path}`);
  }
  assert.ok(spec.components.securitySchemes.bearerAuth);
});

test("sin base de datos no existen las rutas de cuentas, pero el servidor funciona", async (t) => {
  const bare = await buildApp({ config: { logger: false } });
  t.after(() => bare.close());
  assert.equal((await bare.inject({ method: "POST", url: "/auth/login", payload: {} })).statusCode, 404);
  assert.equal((await bare.inject({ method: "GET", url: "/health" })).json().db, false);
});

test("/health indica que hay base de datos", async () => {
  assert.equal((await get("/health")).json().db, true);
});
