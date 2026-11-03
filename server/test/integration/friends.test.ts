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
const ask = (t: string, username: string) =>
  app.inject({ method: "POST", url: "/me/friends", payload: { username }, headers: auth(t) });
const list = async (t: string) =>
  (await app.inject({ method: "GET", url: "/me/friends", headers: auth(t) })).json() as { username: string; status: string }[];
const remove = (t: string, username: string) => app.inject({ method: "DELETE", url: `/me/friends/${username}`, headers: auth(t) });
const statusOf = async (t: string, username: string) => (await list(t)).find((f) => f.username === username)?.status;

test("sin sesión no se puede nada", async () => {
  assert.equal((await app.inject({ method: "GET", url: "/me/friends" })).statusCode, 401);
  assert.equal((await app.inject({ method: "POST", url: "/me/friends", payload: { username: "Alguien" } })).statusCode, 401);
  assert.equal((await app.inject({ method: "GET", url: "/me/friends/leaderboard" })).statusCode, 401);
});

test("pedir amistad: él la ve entrante y yo saliente; al aceptar los dos son amigos", async () => {
  const a = await register("Amigo_A1");
  const b = await register("Amigo_B1");
  const res = await ask(a, "Amigo_B1");
  assert.equal(res.statusCode, 200, res.body);
  assert.equal(res.json().result, "requested");
  assert.equal(await statusOf(a, "Amigo_B1"), "outgoing");
  assert.equal(await statusOf(b, "Amigo_A1"), "incoming");
  const accepted = await ask(b, "Amigo_A1");
  assert.equal(accepted.json().result, "accepted");
  assert.equal(await statusOf(a, "Amigo_B1"), "friend");
  assert.equal(await statusOf(b, "Amigo_A1"), "friend");
});

test("repetir la petición no hace nada ni duplica", async () => {
  const a = await register("Amigo_A2");
  await register("Amigo_B2");
  await ask(a, "Amigo_B2");
  assert.equal((await ask(a, "Amigo_B2")).json().result, "already_requested");
  assert.equal((await list(a)).length, 1);
});

test("si los dos se piden amistad a la vez, quedan como amigos sin duplicar la fila", async () => {
  const a = await register("Amigo_A3");
  const b = await register("Amigo_B3");
  const [r1, r2] = await Promise.all([ask(a, "Amigo_B3"), ask(b, "Amigo_A3")]);
  assert.equal(r1.statusCode, 200);
  assert.equal(r2.statusCode, 200);
  const rows = await db.query("select 1 from friendships f join players p on p.id = f.requester_id where p.username in ('Amigo_A3', 'Amigo_B3')");
  assert.equal(rows.rows.length, 1, "una sola fila para el par");
  // Una de las dos peticiones quedó pendiente y la otra la aceptó, o ambas cayeron en la misma fila: se resuelve con una más.
  await ask(a, "Amigo_B3");
  await ask(b, "Amigo_A3");
  assert.equal(await statusOf(a, "Amigo_B3"), "friend");
});

test("no se puede pedir amistad a uno mismo ni a quien no existe", async () => {
  const a = await register("Amigo_A4");
  const self = await ask(a, "Amigo_A4");
  assert.equal(self.statusCode, 400);
  assert.equal(self.json().error, "cannot_friend_self");
  const nobody = await ask(a, "Nadie_Aqui");
  assert.equal(nobody.statusCode, 404);
  assert.equal(nobody.json().error, "player_not_found");
  assert.equal((await ask(a, "x")).statusCode, 400);
});

test("el nombre se busca sin distinguir mayúsculas", async () => {
  const a = await register("Amigo_A5");
  await register("Amigo_B5");
  assert.equal((await ask(a, "amigo_b5")).json().result, "requested");
});

test("quitar: deja de ser amigo para los dos, y rechazar o cancelar también quitan la solicitud", async () => {
  const a = await register("Amigo_A6");
  const b = await register("Amigo_B6");
  const c = await register("Amigo_C6");
  await ask(a, "Amigo_B6");
  await ask(b, "Amigo_A6");
  assert.equal((await remove(a, "Amigo_B6")).statusCode, 204);
  assert.equal(await statusOf(a, "Amigo_B6"), undefined);
  assert.equal(await statusOf(b, "Amigo_A6"), undefined);
  await ask(a, "Amigo_C6");
  assert.equal((await remove(c, "Amigo_A6")).statusCode, 204, "rechazar");
  assert.equal(await statusOf(a, "Amigo_C6"), undefined);
  await ask(a, "Amigo_C6");
  assert.equal((await remove(a, "Amigo_C6")).statusCode, 204, "cancelar la mía");
  assert.equal(await statusOf(c, "Amigo_A6"), undefined);
  assert.equal((await remove(a, "Amigo_C6")).statusCode, 204, "quitar lo que no hay no falla");
  assert.equal((await remove(a, "Nadie_Aqui")).statusCode, 204, "ni a quien no existe");
  assert.equal(await statusOf(b, "Amigo_A6"), undefined);
});

test("cada uno ve solo lo suyo", async () => {
  const a = await register("Amigo_A7");
  await register("Amigo_B7");
  const c = await register("Amigo_C7");
  await ask(a, "Amigo_B7");
  assert.deepEqual(await list(c), []);
});

test("el ranking de amigos trae solo a mis amigos y a mí, ordenados por puntos", async () => {
  const a = await register("Rank_A8");
  const b = await register("Rank_B8");
  await register("Rank_C8");
  await ask(a, "Rank_B8");
  await ask(b, "Rank_A8");
  await db.query("update players set points = 1200 where username = 'Rank_B8'");
  const res = await app.inject({ method: "GET", url: "/me/friends/leaderboard", headers: auth(a) });
  assert.equal(res.statusCode, 200, res.body);
  const names = (res.json() as { username: string; points: number }[]).map((r) => r.username);
  assert.deepEqual(names, ["Rank_B8", "Rank_A8"], "sin el tercero, que no es amigo");
});

test("las solicitudes pendientes no cuentan como amigos en el ranking", async () => {
  const a = await register("Rank_A9");
  await register("Rank_B9");
  await ask(a, "Rank_B9");
  const res = await app.inject({ method: "GET", url: "/me/friends/leaderboard", headers: auth(a) });
  assert.deepEqual((res.json() as { username: string }[]).map((r) => r.username), ["Rank_A9"]);
});

test("hay un tope de amigos y solicitudes enviadas", async () => {
  const a = await register("Tope_A");
  const me = (await db.query<{ id: string }>("select id from players where username = 'Tope_A'")).rows[0]!.id;
  // 100 solicitudes enviadas, insertadas directamente para no registrar 100 cuentas por la API.
  for (let i = 0; i < 100; i++) {
    const name = `Tp${String(i).padStart(3, "0")}`;
    await db.query("insert into players (username, email, password_hash) values ($1, $2, 'x')", [name, `${name}@t.com`]);
    await db.query(
      "insert into friendships (requester_id, addressee_id, status) select $1, id, 'pending' from players where username = $2",
      [me, name],
    );
  }
  await register("Tope_Extra");
  const res = await ask(a, "Tope_Extra");
  assert.equal(res.statusCode, 409);
  assert.equal(res.json().error, "friend_limit");
});

test("al borrar una cuenta se borran sus amistades", async () => {
  const a = await register("Borra_A");
  await register("Borra_B");
  await ask(a, "Borra_B");
  await db.query("delete from players where username = 'Borra_A'");
  const b = (await db.query<{ id: string }>("select id from players where username = 'Borra_B'")).rows[0]!.id;
  const rows = await db.query("select 1 from friendships where requester_id = $1 or addressee_id = $1", [b]);
  assert.equal(rows.rows.length, 0);
});
