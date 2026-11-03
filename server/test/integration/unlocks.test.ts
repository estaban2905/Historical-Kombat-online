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
const get = (t?: string) => app.inject({ method: "GET", url: "/me/unlocks", headers: t ? auth(t) : {} });
const put = (t: string | undefined, items: unknown) =>
  app.inject({ method: "PUT", url: "/me/unlocks", payload: { items }, headers: t ? auth(t) : {} });

test("sin sesión no se puede leer ni añadir", async () => {
  assert.equal((await get()).statusCode, 401);
  assert.equal((await put(undefined, [])).statusCode, 401);
});

test("una cuenta nueva no tiene nada desbloqueado", async () => {
  const t = await register("Unlock_0");
  assert.deepEqual((await get(t)).json(), []);
});

test("añadir desbloqueos los guarda y devuelve la lista completa", async () => {
  const t = await register("Unlock_1");
  const res = await put(t, [
    { kind: "fighter", key: "napoleon" },
    { kind: "ending", key: "repair" },
  ]);
  assert.equal(res.statusCode, 200, res.body);
  const keys = (res.json() as { kind: string; key: string }[]).map((u) => `${u.kind}:${u.key}`).sort();
  assert.deepEqual(keys, ["ending:repair", "fighter:napoleon"]);
  assert.equal((await get(t)).json().length, 2);
});

test("repetir un desbloqueo no falla ni lo duplica ni cambia su fecha", async () => {
  const t = await register("Unlock_2");
  await put(t, [{ kind: "ending", key: "free" }]);
  const before = await db.query<{ unlocked_at: string }>("select unlocked_at from player_unlocks where key = 'free'");
  await db.query("update player_unlocks set unlocked_at = now() - interval '1 day' where key = 'free'");
  const old = await db.query<{ unlocked_at: string }>("select unlocked_at from player_unlocks where key = 'free'");
  const res = await put(t, [{ kind: "ending", key: "free" }, { kind: "ending", key: "free" }, { kind: "fighter", key: "tesla" }]);
  assert.equal(res.statusCode, 200);
  assert.equal(res.json().length, 2);
  const after = await db.query<{ unlocked_at: string }>("select unlocked_at from player_unlocks where key = 'free'");
  assert.equal(String(after.rows[0]!.unlocked_at), String(old.rows[0]!.unlocked_at), "la fecha original se conserva");
  assert.notEqual(String(before.rows[0]!.unlocked_at), "");
});

test("cada cuenta ve solo lo suyo", async () => {
  const a = await register("Unlock_3");
  const b = await register("Unlock_4");
  await put(a, [{ kind: "fighter", key: "cleopatra" }]);
  assert.deepEqual((await get(b)).json(), []);
});

test("los desbloqueos no se pueden quitar: no hay ruta para borrarlos", async () => {
  const t = await register("Unlock_5");
  await put(t, [{ kind: "fighter", key: "lautaro" }]);
  assert.equal((await app.inject({ method: "DELETE", url: "/me/unlocks", headers: auth(t) })).statusCode, 404);
  assert.equal((await put(t, [])).json().length, 1, "una lista vacía no borra nada");
});

test("se rechazan tipos desconocidos, claves con mala forma y demasiados elementos", async () => {
  const t = await register("Unlock_6");
  assert.equal((await put(t, [{ kind: "otro", key: "x" }])).statusCode, 400);
  assert.equal((await put(t, [{ kind: "fighter", key: "Con Espacio" }])).statusCode, 400);
  assert.equal((await put(t, [{ kind: "fighter", key: "x".repeat(41) }])).statusCode, 400);
  assert.equal((await put(t, [{ kind: "fighter" }])).statusCode, 400);
  const many = Array.from({ length: 201 }, (_, i) => ({ kind: "fighter", key: `f${i}` }));
  assert.equal((await put(t, many)).statusCode, 400);
  assert.deepEqual((await get(t)).json(), []);
});

test("al borrar la cuenta se borran sus desbloqueos", async () => {
  const t = await register("Unlock_7");
  await put(t, [{ kind: "ending", key: "rewrite" }]);
  await db.query("delete from players where username = 'Unlock_7'");
  const left = await db.query("select 1 from player_unlocks where key = 'rewrite'");
  assert.equal(left.rows.length, 0);
});

// ---- Logros ----

const achievements = async (t: string) =>
  (await app.inject({ method: "GET", url: "/me/achievements", headers: auth(t) })).json() as {
    key: string; progress: number; goal: number; done: boolean;
  }[];
const byKey = (list: { key: string; done: boolean; progress: number }[], key: string) => list.find((a) => a.key === key)!;

test("los logros exigen sesión", async () => {
  assert.equal((await app.inject({ method: "GET", url: "/me/achievements" })).statusCode, 401);
});

test("una cuenta nueva no tiene ningún logro", async () => {
  const t = await register("Logro_0");
  assert.ok((await achievements(t)).every((a) => !a.done));
});

test("los logros salen de mis duelos y de mis desbloqueos", async () => {
  const t = await register("Logro_1");
  const other = await register("Logro_2");
  const ids = await db.query<{ id: string; username: string }>("select id, username from players where username in ('Logro_1', 'Logro_2')");
  const me = ids.rows.find((r) => r.username === "Logro_1")!.id;
  const rival = ids.rows.find((r) => r.username === "Logro_2")!.id;
  // Cinco victorias seguidas, la primera 2-0. Los contadores de la cuenta los lleva el servidor al jugar: aquí se fijan a mano.
  for (let i = 0; i < 5; i++) {
    await db.query(
      `insert into matches (p1_id, p2_id, p1_fighter, p2_fighter, winner, p1_rounds, p2_rounds, p1_delta, p2_delta, played_at)
       values ($1, $2, 'a', 'b', 1, 2, $3, 16, -16, now() + ($4 || ' minutes')::interval)`,
      [me, rival, i === 0 ? 0 : 1, String(i)],
    );
  }
  await db.query("update players set wins = 5 where id = $1", [me]);
  await put(t, [{ kind: "ending", key: "free" }, { kind: "fighter", key: "napoleon" }]);
  const list = await achievements(t);
  assert.equal(byKey(list, "first_win").done, true);
  assert.equal(byKey(list, "streak_5").done, true);
  assert.equal(byKey(list, "flawless").done, true);
  assert.equal(byKey(list, "wins_10").done, false);
  assert.equal(byKey(list, "wins_10").progress, 5);
  assert.equal(byKey(list, "story_done").done, true);
  assert.equal(byKey(list, "hidden_ending").done, true);
  assert.equal(byKey(list, "all_endings").progress, 1);
  assert.equal(byKey(list, "collector").progress, 1);
  assert.ok((await achievements(other)).every((a) => !a.done), "el rival no hereda nada");
});
