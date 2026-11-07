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

async function register(name: string, accept_terms?: boolean): Promise<string> {
  const res = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: email(name), password: "secreto1", username: name, accept_terms },
  });
  assert.equal(res.statusCode, 201, res.body);
  return res.json().access_token as string;
}
const del = (token: string, payload: object) => app.inject({ method: "POST", url: "/me/delete", payload, headers: auth(token) });

test("borrar la cuenta: pide nombre y contraseña, y después ya no existe", async () => {
  const t = await register("Borrame_1");
  assert.equal((await del(t, { confirm_username: "otro" })).statusCode, 400);
  const wrong = await del(t, { confirm_username: "Borrame_1", password: "mala" });
  assert.equal(wrong.statusCode, 403);
  assert.equal(wrong.json().error, "wrong_password");
  assert.equal((await del(t, { confirm_username: "borrame_1", password: "secreto1" })).statusCode, 204);
  assert.equal((await app.inject({ method: "GET", url: "/me", headers: auth(t) })).statusCode, 401);
  assert.equal((await app.inject({ method: "GET", url: "/players/Borrame_1" })).statusCode, 404);
  const again = await app.inject({ method: "POST", url: "/auth/login", payload: { email: email("Borrame_1"), password: "secreto1" } });
  assert.equal(again.statusCode, 401);
});

test("el rival conserva el duelo, con 'JUGADOR ELIMINADO'", async () => {
  const a = await register("Rival_A");
  await register("Rival_B");
  const rows = await db.query<{ id: string }>("select id from players where username in ('Rival_A','Rival_B') order by username");
  const [idA, idB] = rows.rows.map((r) => r.id);
  await db.query(
    `insert into matches (p1_id, p2_id, p1_fighter, p2_fighter, winner, p1_rounds, p2_rounds, p1_delta, p2_delta)
     values ($1, $2, 'napoleon', 'cleopatra', 1, 2, 0, 10, -10)`,
    [idA, idB],
  );
  assert.equal((await del(a, { confirm_username: "Rival_A", password: "secreto1" })).statusCode, 204);
  const login = await app.inject({ method: "POST", url: "/auth/login", payload: { email: email("Rival_B"), password: "secreto1" } });
  const b = login.json().access_token as string;
  const hist = await app.inject({ method: "GET", url: "/me/matches", headers: auth(b) });
  assert.equal(hist.statusCode, 200, hist.body);
  assert.equal(hist.json()[0].opponent, "JUGADOR ELIMINADO");
});

test("el registro guarda cuándo se aceptaron los términos", async () => {
  await register("Acepta_1", true);
  await register("NoAcepta_1");
  const r = await db.query<{ username: string; ok: boolean }>(
    "select username, terms_accepted_at is not null as ok from players where username in ('Acepta_1','NoAcepta_1')",
  );
  const m = Object.fromEntries(r.rows.map((x) => [x.username, x.ok]));
  assert.equal(m["Acepta_1"], true);
  assert.equal(m["NoAcepta_1"], false);
});
