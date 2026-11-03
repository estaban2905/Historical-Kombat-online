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

const patch = (token: string | undefined, payload: object) =>
  app.inject({ method: "PATCH", url: "/me", payload, headers: token ? { authorization: `Bearer ${token}` } : {} });

async function register(name: string): Promise<string> {
  const res = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: `${name.toLowerCase()}@test.com`, password: "secreto1", username: name },
  });
  assert.equal(res.statusCode, 201, res.body);
  return res.json().access_token as string;
}

const me = async (token: string) =>
  (await app.inject({ method: "GET", url: "/me", headers: { authorization: `Bearer ${token}` } })).json();

test("una cuenta nueva no tiene avatar", async () => {
  const t = await register("Avatar_0");
  assert.equal((await me(t)).avatar, null);
});

test("sin sesión no se puede cambiar el avatar", async () => {
  assert.equal((await patch(undefined, { avatar: "nikola_tesla" })).statusCode, 401);
});

test("elegir avatar lo guarda en el perfil y en el ranking, y null lo quita", async () => {
  const t = await register("Avatar_1");
  const res = await patch(t, { avatar: "nikola_tesla" });
  assert.equal(res.statusCode, 200, res.body);
  assert.equal(res.json().avatar, "nikola_tesla");
  assert.equal((await me(t)).avatar, "nikola_tesla");
  const board = (await app.inject({ method: "GET", url: "/leaderboard" })).json() as { username: string; avatar: string | null }[];
  assert.equal(board.find((p) => p.username === "Avatar_1")?.avatar, "nikola_tesla");
  assert.equal((await patch(t, { avatar: null })).json().avatar, null);
  assert.equal((await me(t)).avatar, null);
});

test("rechaza ids con forma inválida y ignora campos de más (no se pueden tocar los puntos)", async () => {
  const t = await register("Avatar_2");
  assert.equal((await patch(t, { avatar: "Con Espacio" })).statusCode, 400);
  assert.equal((await patch(t, { avatar: "x".repeat(41) })).statusCode, 400);
  assert.equal((await patch(t, { avatar: "tesla", points: 9999 })).json().points, 1000);
  assert.equal((await patch(t, {})).statusCode, 400);
});

test("CORS permite PATCH desde el navegador (el preflight lo declara)", async () => {
  const res = await app.inject({
    method: "OPTIONS",
    url: "/me",
    headers: { origin: "https://juego.example", "access-control-request-method": "PATCH", "access-control-request-headers": "authorization,content-type" },
  });
  assert.equal(res.statusCode, 204);
  assert.match(String(res.headers["access-control-allow-methods"]), /PATCH/);
});
