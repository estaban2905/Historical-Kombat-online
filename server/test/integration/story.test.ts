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
