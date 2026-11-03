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
  return res.json().player.id as string;
}

let clock = Date.parse("2026-01-01T00:00:00Z");

/** Un duelo entre dos jugadores; winner: 1 = gana p1, 2 = gana p2, 0 = empate. Cada uno ocurre un minuto después del anterior. */
async function duel(p1: string, p2: string, f1: string, f2: string, winner: 0 | 1 | 2): Promise<void> {
  clock += 60_000;
  await db.query(
    `insert into matches (p1_id, p2_id, p1_fighter, p2_fighter, winner, p1_rounds, p2_rounds, p1_delta, p2_delta, played_at)
     values ($1, $2, $3, $4, $5, 2, 1, $6, $7, $8)`,
    [p1, p2, f1, f2, winner, winner === 1 ? 16 : -16, winner === 1 ? -16 : 16, new Date(clock).toISOString()],
  );
}

const get = (url: string) => app.inject({ method: "GET", url });

test("un jugador sin duelos: sin favorito, racha 0 y puesto en el ranking", async () => {
  await register("Perfil_0");
  const res = await get("/players/Perfil_0");
  assert.equal(res.statusCode, 200, res.body);
  const p = res.json();
  assert.equal(p.username, "Perfil_0");
  assert.equal(p.favorite_fighter, null);
  assert.equal(p.streak, 0);
  assert.equal(p.avatar, null);
  assert.deepEqual(p.recent, []);
  assert.ok(p.rank >= 1);
});

test("el nombre se busca sin distinguir mayúsculas y no se filtra nada privado", async () => {
  await register("Perfil_1");
  const res = await get("/players/perfil_1");
  assert.equal(res.statusCode, 200);
  const keys = Object.keys(res.json());
  assert.ok(!keys.includes("id") && !keys.includes("email") && !keys.includes("password_hash"), keys.join(","));
});

test("un jugador que no existe responde 404 y un nombre inválido 400", async () => {
  const res = await get("/players/Nadie_Aqui");
  assert.equal(res.statusCode, 404);
  assert.equal(res.json().error, "player_not_found");
  assert.equal((await get("/players/a")).statusCode, 400);
});

test("favorito: el luchador más jugado, desde cualquiera de los dos lados", async () => {
  const a = await register("Fav_A");
  const b = await register("Fav_B");
  await duel(a, b, "tesla", "napoleon", 1);
  await duel(b, a, "napoleon", "tesla", 2); // a juega como p2, otra vez con tesla
  await duel(a, b, "einstein", "napoleon", 2);
  assert.equal((await get("/players/Fav_A")).json().favorite_fighter, "tesla");
  assert.equal((await get("/players/Fav_B")).json().favorite_fighter, "napoleon");
});

test("a igualdad de duelos, el favorito es el primero por id (el resultado no cambia entre llamadas)", async () => {
  const a = await register("Emp_A");
  const b = await register("Emp_B");
  await duel(a, b, "zeta", "x", 1);
  await duel(a, b, "alfa", "x", 1);
  assert.equal((await get("/players/Emp_A")).json().favorite_fighter, "alfa");
});

test("racha: victorias seguidas desde el duelo más reciente; una derrota o un empate la cortan", async () => {
  const a = await register("Racha_A");
  const b = await register("Racha_B");
  await duel(a, b, "t", "n", 1); // gana
  await duel(a, b, "t", "n", 2); // pierde
  await duel(a, b, "t", "n", 1); // gana
  await duel(b, a, "n", "t", 2); // gana (como p2)
  await duel(a, b, "t", "n", 1); // gana
  assert.equal((await get("/players/Racha_A")).json().streak, 3);
  assert.equal((await get("/players/Racha_B")).json().streak, 0);
  await duel(a, b, "t", "n", 0); // empate: corta la racha
  assert.equal((await get("/players/Racha_A")).json().streak, 0);
});

test("si todos sus duelos son victorias, la racha es el total", async () => {
  const a = await register("Todo_A");
  const b = await register("Todo_B");
  await duel(a, b, "t", "n", 1);
  await duel(a, b, "t", "n", 1);
  assert.equal((await get("/players/Todo_A")).json().streak, 2);
});

test("los últimos duelos van del más reciente al más antiguo y vistos desde su lado", async () => {
  const a = await register("Rec_A");
  const b = await register("Rec_B");
  await duel(a, b, "t", "n", 1);
  await duel(b, a, "n", "t", 1); // b gana: a pierde
  const p = (await get("/players/Rec_A")).json();
  assert.equal(p.recent.length, 2);
  assert.equal(p.recent[0].result, "loss");
  assert.equal(p.recent[0].opponent, "Rec_B");
  assert.equal(p.recent[1].result, "win");
});

test("el ranking trae favorito y racha, y el puesto del perfil coincide con él", async () => {
  const board = (await get("/leaderboard?limit=100")).json() as {
    username: string;
    favorite_fighter: string | null;
    streak: number;
  }[];
  const racha = board.find((p) => p.username === "Racha_A");
  assert.equal(racha?.streak, 0);
  assert.equal(racha?.favorite_fighter, "t");
  for (const [i, entry] of board.entries()) {
    if (["Perfil_0", "Fav_A", "Rec_B"].includes(entry.username)) {
      assert.equal((await get(`/players/${entry.username}`)).json().rank, i + 1, entry.username);
    }
  }
});
