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

async function register(name: string): Promise<string> {
  const res = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: `${name.toLowerCase()}@test.com`, password: "secreto1", username: name },
  });
  assert.equal(res.statusCode, 201, res.body);
  return res.json().access_token as string;
}

const auth = (t: string) => ({ authorization: `Bearer ${t}` });
const patchMe = (t: string, payload: object) => app.inject({ method: "PATCH", url: "/me", payload, headers: auth(t) });
const unlock = (t: string, key: string) =>
  app.inject({ method: "PUT", url: "/me/unlocks", payload: { items: [{ kind: "cosmetic", key }] }, headers: auth(t) });
const me = async (t: string) => (await app.inject({ method: "GET", url: "/me", headers: auth(t) })).json();

test("una cuenta nueva no lleva ni marco ni título", async () => {
  const t = await register("Cosm_0");
  const p = await me(t);
  assert.equal(p.frame, null);
  assert.equal(p.title, null);
});

test("no se puede poner un cosmético que no se ha desbloqueado", async () => {
  const t = await register("Cosm_1");
  const res = await patchMe(t, { frame: "frame_gold" });
  assert.equal(res.statusCode, 403);
  assert.equal(res.json().error, "not_unlocked");
  assert.equal((await me(t)).frame, null);
});

test("desbloqueado se puede poner, se ve en el perfil público y se puede quitar con null", async () => {
  const t = await register("Cosm_2");
  await unlock(t, "frame_gold");
  await unlock(t, "title_guardian");
  const res = await patchMe(t, { frame: "frame_gold", title: "title_guardian" });
  assert.equal(res.statusCode, 200, res.body);
  assert.equal(res.json().frame, "frame_gold");
  assert.equal(res.json().title, "title_guardian");
  const pub = (await app.inject({ method: "GET", url: "/players/Cosm_2" })).json();
  assert.equal(pub.frame, "frame_gold");
  assert.equal(pub.title, "title_guardian");
  const removed = await patchMe(t, { frame: null });
  assert.equal(removed.json().frame, null);
  assert.equal(removed.json().title, "title_guardian", "lo que no se pasa se deja como está");
});

test("un cosmético de otra clase no vale: un final desbloqueado no es un marco", async () => {
  const t = await register("Cosm_3");
  await app.inject({ method: "PUT", url: "/me/unlocks", payload: { items: [{ kind: "ending", key: "frame_gold" }] }, headers: auth(t) });
  assert.equal((await patchMe(t, { frame: "frame_gold" })).statusCode, 403);
});

test("si un cambio falla no se aplica ninguno (el nombre tampoco)", async () => {
  const t = await register("Cosm_4");
  const res = await patchMe(t, { username: "Cosm_4_nuevo", title: "title_inventado" });
  assert.equal(res.statusCode, 403);
  assert.equal((await me(t)).username, "Cosm_4");
});

test("las claves con mala forma se rechazan", async () => {
  const t = await register("Cosm_5");
  assert.equal((await patchMe(t, { frame: "Con Espacio" })).statusCode, 400);
  assert.equal((await patchMe(t, { title: "x".repeat(41) })).statusCode, 400);
});

test("cada jugador solo puede ponerse lo suyo", async () => {
  const a = await register("Cosm_6");
  const b = await register("Cosm_7");
  await unlock(a, "frame_red");
  assert.equal((await patchMe(b, { frame: "frame_red" })).statusCode, 403);
  assert.equal((await patchMe(a, { frame: "frame_red" })).statusCode, 200);
});
