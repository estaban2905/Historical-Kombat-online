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
  await seed();
});
after(async () => {
  await app.close();
  await db.close();
});

interface Row {
  username: string;
  points: number;
  wins: number;
  losses: number;
  gained?: number;
}

async function register(name: string): Promise<{ id: string; token: string }> {
  const res = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: `${name.toLowerCase()}@test.com`, password: "secreto1", username: name },
  });
  assert.equal(res.statusCode, 201, res.body);
  return { id: res.json().player.id as string, token: res.json().access_token as string };
}

const DAY = 24 * 60 * 60 * 1000;

/** Un duelo con ranking hace `daysAgo` días: gana p1 (+16 / -16). También mueve los puntos totales. */
async function duel(p1: string, p2: string, f1: string, f2: string, daysAgo: number): Promise<void> {
  await db.query(
    `insert into matches (p1_id, p2_id, p1_fighter, p2_fighter, winner, p1_rounds, p2_rounds, p1_delta, p2_delta, played_at)
     values ($1, $2, $3, $4, 1, 2, 0, 16, -16, $5)`,
    [p1, p2, f1, f2, new Date(Date.now() - daysAgo * DAY).toISOString()],
  );
  await db.query("update players set points = points + 16, wins = wins + 1 where id = $1", [p1]);
  await db.query("update players set points = points - 16, losses = losses + 1 where id = $1", [p2]);
}

const board = async (url: string, token?: string): Promise<Row[]> => {
  const res = await app.inject({ method: "GET", url, headers: token ? { authorization: `Bearer ${token}` } : {} });
  assert.equal(res.statusCode, 200, res.body);
  return res.json() as Row[];
};
const names = (rows: Row[]) => rows.map((r) => r.username);

let veterano: { id: string; token: string };
let novato: { id: string; token: string };
let rival: { id: string; token: string };

async function seed(): Promise<void> {
  veterano = await register("Filtro_Vet");
  novato = await register("Filtro_Nov");
  rival = await register("Filtro_Riv");
  await register("Filtro_Nada");
  // El veterano ganó mucho hace un mes; el novato ganó esta semana con Tesla y una vez con Napoleón.
  for (let i = 0; i < 4; i++) await duel(veterano.id, rival.id, "napoleon", "cleopatra", 30);
  await duel(novato.id, rival.id, "nikola_tesla", "cleopatra", 2);
  await duel(novato.id, rival.id, "nikola_tesla", "cleopatra", 1);
  await duel(novato.id, veterano.id, "napoleon", "napoleon", 3);
}

test("sin filtros: por puntos totales, como siempre, y sin gained", async () => {
  const rows = await board("/leaderboard?limit=100");
  assert.ok(names(rows).indexOf("Filtro_Vet") < names(rows).indexOf("Filtro_Nov"));
  assert.ok(names(rows).includes("Filtro_Nada"), "salen también los que no han jugado");
  assert.equal(rows[0]!.gained, undefined);
});

test("semanal: solo cuentan los duelos de los últimos 7 días", async () => {
  const rows = await board("/leaderboard?period=week");
  const nov = rows.find((r) => r.username === "Filtro_Nov")!;
  const vet = rows.find((r) => r.username === "Filtro_Vet")!;
  assert.equal(names(rows)[0], "Filtro_Nov", "el novato ganó más puntos esta semana");
  assert.deepEqual([nov.wins, nov.losses, nov.gained], [3, 0, 48]);
  assert.deepEqual([vet.wins, vet.losses, vet.gained], [0, 1, -16], "del veterano solo cuenta la derrota de esta semana");
  assert.equal(vet.points, 1000 + 4 * 16 - 16, "points sigue siendo el total, para la liga");
  assert.ok(!names(rows).includes("Filtro_Nada"), "sin duelos esa semana no sale");
});

test("por luchador: solo los duelos jugados con él", async () => {
  const tesla = await board("/leaderboard?fighter=nikola_tesla");
  assert.deepEqual(names(tesla), ["Filtro_Nov"]);
  assert.equal(tesla[0]!.wins, 2);
  const napoleon = await board("/leaderboard?fighter=napoleon");
  assert.deepEqual(names(napoleon), ["Filtro_Vet", "Filtro_Nov"], "el veterano ganó 4 con Napoleón (y perdió 1)");
  assert.deepEqual([napoleon[0]!.wins, napoleon[0]!.losses, napoleon[0]!.gained], [4, 1, 48]);
  const cleo = await board("/leaderboard?fighter=cleopatra");
  assert.deepEqual([cleo[0]!.username, cleo[0]!.gained], ["Filtro_Riv", -96], "también salen los que solo perdieron");
});

test("los dos filtros a la vez", async () => {
  const rows = await board("/leaderboard?period=week&fighter=napoleon");
  assert.deepEqual(names(rows), ["Filtro_Nov", "Filtro_Vet"]);
});

test("filtros no válidos: 400", async () => {
  for (const q of ["period=month", "fighter=NAPOLEON", "fighter=a;drop"]) {
    const res = await app.inject({ method: "GET", url: `/leaderboard?${q}` });
    assert.equal(res.statusCode, 400, q);
  }
});

test("el ranking de amigos admite los mismos filtros", async () => {
  const ask = (t: string, username: string) =>
    app.inject({ method: "POST", url: "/me/friends", payload: { username }, headers: { authorization: `Bearer ${t}` } });
  await ask(novato.token, "Filtro_Vet");
  await ask(veterano.token, "Filtro_Nov");
  const all = await board("/me/friends/leaderboard", novato.token);
  assert.deepEqual(names(all), ["Filtro_Vet", "Filtro_Nov"]);
  const week = await board("/me/friends/leaderboard?period=week", novato.token);
  assert.deepEqual(names(week), ["Filtro_Nov", "Filtro_Vet"], "esta semana va primero el novato; el rival no es amigo y no sale");
  assert.equal(week[0]!.gained, 48);
});
