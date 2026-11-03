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

const call = (method: "GET" | "PUT" | "DELETE", token?: string, payload?: object) =>
  app.inject({ method, url: "/me/story", payload, headers: token ? { authorization: `Bearer ${token}` } : {} });

async function register(name: string): Promise<string> {
  const res = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: `${name.toLowerCase()}@test.com`, password: "secreto1", username: name },
  });
  assert.equal(res.statusCode, 201, res.body);
  return res.json().access_token as string;
}

const save = (over: object = {}) => ({
  fighter: "nikola_tesla",
  stage: 7,
  continues: 2,
  continues_used: 1,
  difficulty: 1,
  saved_at: 1_000,
  ...over,
});

test("sin sesión no se puede leer ni guardar", async () => {
  assert.equal((await call("GET")).statusCode, 401);
  assert.equal((await call("PUT", undefined, save())).statusCode, 401);
  assert.equal((await call("DELETE")).statusCode, 401);
});

test("sin partida guardada responde 404", async () => {
  const t = await register("Story_0");
  const res = await call("GET", t);
  assert.equal(res.statusCode, 404);
  assert.equal(res.json().error, "no_story_save");
});

test("guardar y volver a leer devuelve lo mismo", async () => {
  const t = await register("Story_1");
  assert.equal((await call("PUT", t, save())).statusCode, 200);
  const res = await call("GET", t);
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.json(), save());
});

test("guardar de nuevo reemplaza la partida; un guardado más viejo no pisa al nuevo", async () => {
  const t = await register("Story_2");
  await call("PUT", t, save({ stage: 3, saved_at: 100 }));
  await call("PUT", t, save({ stage: 4, saved_at: 200 }));
  assert.equal((await call("GET", t)).json().stage, 4);
  const old = await call("PUT", t, save({ stage: 1, saved_at: 50 }));
  assert.equal(old.statusCode, 200);
  assert.equal(old.json().stage, 4, "devuelve lo que quedó guardado");
  assert.equal((await call("GET", t)).json().stage, 4);
});

test("cada cuenta ve solo su partida", async () => {
  const a = await register("Story_3");
  const b = await register("Story_4");
  await call("PUT", a, save({ stage: 9 }));
  assert.equal((await call("GET", b)).statusCode, 404);
  assert.equal((await call("GET", a)).json().stage, 9);
});

test("borrar elimina la partida (y se puede repetir sin error)", async () => {
  const t = await register("Story_5");
  await call("PUT", t, save());
  assert.equal((await call("DELETE", t)).statusCode, 204);
  assert.equal((await call("GET", t)).statusCode, 404);
  assert.equal((await call("DELETE", t)).statusCode, 204);
});

const list = (token: string) =>
  app.inject({ method: "GET", url: "/me/stories", headers: { authorization: `Bearer ${token}` } });
const del = (token: string, query: string) =>
  app.inject({ method: "DELETE", url: `/me/story${query}`, headers: { authorization: `Bearer ${token}` } });

test("una partida por luchador: empezar con otro no borra la anterior", async () => {
  const t = await register("Story_7");
  await call("PUT", t, save({ fighter: "nikola_tesla", stage: 6, saved_at: 100 }));
  await call("PUT", t, save({ fighter: "napoleon", stage: 2, saved_at: 200 }));
  const all = (await list(t)).json();
  assert.deepEqual(
    all.map((s: { fighter: string; stage: number }) => [s.fighter, s.stage]),
    [
      ["napoleon", 2],
      ["nikola_tesla", 6],
    ],
    "la más reciente primero",
  );
  // GET /me/story sigue dando la más reciente.
  assert.equal((await call("GET", t)).json().fighter, "napoleon");
});

test("guardar a un luchador solo reemplaza la partida de ese luchador", async () => {
  const t = await register("Story_8");
  await call("PUT", t, save({ fighter: "nikola_tesla", stage: 6, saved_at: 100 }));
  await call("PUT", t, save({ fighter: "napoleon", stage: 2, saved_at: 150 }));
  await call("PUT", t, save({ fighter: "nikola_tesla", stage: 7, saved_at: 300 }));
  const all = (await list(t)).json();
  assert.equal(all.length, 2);
  assert.equal(all[0].fighter, "nikola_tesla");
  assert.equal(all[0].stage, 7);
  assert.equal(all[1].stage, 2);
});

test("borrar con luchador quita solo esa partida; sin luchador, la más reciente", async () => {
  const t = await register("Story_9");
  await call("PUT", t, save({ fighter: "nikola_tesla", saved_at: 100 }));
  await call("PUT", t, save({ fighter: "napoleon", saved_at: 200 }));
  await call("PUT", t, save({ fighter: "cleopatra", saved_at: 300 }));
  assert.equal((await del(t, "?fighter=nikola_tesla")).statusCode, 204);
  assert.deepEqual(
    (await list(t)).json().map((s: { fighter: string }) => s.fighter),
    ["cleopatra", "napoleon"],
  );
  assert.equal((await del(t, "")).statusCode, 204);
  assert.deepEqual(
    (await list(t)).json().map((s: { fighter: string }) => s.fighter),
    ["napoleon"],
  );
  assert.equal((await del(t, "?fighter=Mal Id!")).statusCode, 400);
});

test("una cuenta sin partidas ve una lista vacía y otra cuenta no ve las ajenas", async () => {
  const a = await register("Story_10");
  const b = await register("Story_11");
  assert.deepEqual((await list(a)).json(), []);
  await call("PUT", a, save());
  assert.deepEqual((await list(b)).json(), []);
  assert.equal((await list("")).statusCode, 401);
});

test("rechaza datos no válidos", async () => {
  const t = await register("Story_6");
  for (const bad of [
    save({ stage: -1 }),
    save({ stage: 1.5 }),
    save({ fighter: "Nikola Tesla!" }),
    save({ fighter: "" }),
    save({ continues: 999 }),
    { fighter: "nikola_tesla" },
  ]) {
    const res = await call("PUT", t, bad);
    assert.equal(res.statusCode, 400, JSON.stringify(bad));
  }
});
