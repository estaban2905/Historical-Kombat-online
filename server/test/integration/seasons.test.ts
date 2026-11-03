import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../../src/app.js";
import { leagueOf, seasonEnd, seasonOf, SeasonService, softReset } from "../../src/services/season.service.js";
import { createTestDb, type PgliteDb } from "../helpers/pglite-db.js";

let db: PgliteDb;
let app: FastifyInstance;
/** Reloj de las temporadas: las pruebas lo mueven de mes. */
let now = new Date("2026-11-10T12:00:00Z");

before(async () => {
  db = await createTestDb();
  app = await buildApp({ db, now: () => now, config: { logger: false, authRateLimitPerMinute: 1000 } });
});
after(async () => {
  await app.close();
  await db.close();
});

async function register(name: string): Promise<{ id: string; token: string }> {
  const res = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: `${name.toLowerCase()}@test.com`, password: "secreto1", username: name },
  });
  assert.equal(res.statusCode, 201, res.body);
  return { id: res.json().player.id as string, token: res.json().access_token as string };
}

/** Pone los puntos (y el máximo de la temporada) de un jugador y le apunta un duelo ganado o perdido en `at`. */
async function played(p: string, rival: string, points: number, peak: number, win: boolean, at: string): Promise<void> {
  await db.query("update players set points = $2, season_peak = $3 where id = $1", [p, points, peak]);
  await db.query(
    `insert into matches (p1_id, p2_id, p1_fighter, p2_fighter, winner, p1_rounds, p2_rounds, p1_delta, p2_delta, played_at)
     values ($1, $2, 'napoleon', 'cleopatra', $3, 2, 1, 0, 0, $4)`,
    [p, rival, win ? 1 : 2, at],
  );
}

const cosmetics = async (id: string) =>
  (await db.query<{ key: string }>("select key from player_unlocks where player_id = $1 and kind = 'cosmetic' order by key", [id]))
    .rows.map((r) => r.key);
const pointsOf = async (id: string) =>
  (await db.query<{ points: number; season_peak: number }>("select points, season_peak from players where id = $1", [id])).rows[0]!;

test("reglas: liga por puntos, mes en UTC y reinicio suave", () => {
  assert.deepEqual([leagueOf(1099), leagueOf(1100), leagueOf(1300), leagueOf(1500), leagueOf(400)], ["bronze", "silver", "gold", "diamond", "bronze"]);
  assert.equal(seasonOf(new Date("2026-11-30T23:59:59Z")), "2026-11");
  assert.equal(seasonOf(new Date("2026-12-01T00:00:00Z")), "2026-12");
  assert.equal(seasonEnd("2026-12").toISOString(), "2027-01-01T00:00:00.000Z", "diciembre termina en enero del año siguiente");
  assert.deepEqual([softReset(1400), softReset(800), softReset(1000), softReset(1101)], [1200, 900, 1000, 1050]);
});

test("GET /season: la temporada en curso y cuándo termina", async () => {
  const res = await app.inject({ method: "GET", url: "/season" });
  assert.equal(res.statusCode, 200, res.body);
  assert.deepEqual(res.json(), { id: "2026-11", ends_at: "2026-12-01T00:00:00.000Z" });
});

test("al cambiar de mes: resultados, recompensas, reinicio suave y una sola vez", async () => {
  const campeon = await register("Temp_Uno");
  const segundo = await register("Temp_Dos");
  const tercero = await register("Temp_Tres");
  const cuarto = await register("Temp_Cuatro");
  const ausente = await register("Temp_Ausente");
  // Ganar un duelo de verdad sube el máximo de la temporada.
  await app.seasons.rollover();
  await played(campeon.id, segundo.id, 1520, 1560, true, "2026-11-05T10:00:00Z");
  await played(segundo.id, tercero.id, 1350, 1360, true, "2026-11-06T10:00:00Z");
  await played(tercero.id, cuarto.id, 1100, 1310, false, "2026-11-07T10:00:00Z");
  await played(cuarto.id, campeon.id, 1050, 1060, true, "2026-11-08T10:00:00Z");
  // Un duelo de octubre no hace que el ausente cuente en noviembre.
  await played(ausente.id, cuarto.id, 1200, 1200, true, "2026-10-20T10:00:00Z");

  assert.equal(await app.seasons.rollover(), null, "mismo mes: no se cierra nada");
  now = new Date("2026-12-01T00:05:00Z");
  assert.equal(await app.seasons.rollover(), "2026-11");
  assert.equal(await app.seasons.rollover(), null, "otra comprobación no la vuelve a cerrar");
  assert.equal(await new SeasonService(db, () => now).rollover(), null, "ni otra instancia del servidor");

  const res = await app.inject({ method: "GET", url: "/me/seasons", headers: { authorization: `Bearer ${tercero.token}` } });
  assert.equal(res.statusCode, 200, res.body);
  assert.deepEqual(res.json(), [
    { season: "2026-11", rank: 3, points: 1100, peak_points: 1310, league: "gold", wins: 0, losses: 2 },
  ], "el tercero bajó a Plata, pero la liga es la máxima alcanzada: Oro");

  const ranks = await db.query<{ username: string; rank: number }>(
    "select p.username, r.rank from season_results r join players p on p.id = r.player_id where r.season = '2026-11' order by r.rank",
  );
  assert.deepEqual(ranks.rows.map((r) => r.username), ["Temp_Uno", "Temp_Dos", "Temp_Tres", "Temp_Cuatro"], "solo quienes jugaron ese mes");

  assert.deepEqual(await cosmetics(campeon.id), ["frame_season_diamond", "title_season_champion"]);
  assert.deepEqual(await cosmetics(segundo.id), ["frame_season_gold", "title_season_podium"]);
  assert.deepEqual(await cosmetics(tercero.id), ["frame_season_gold", "title_season_podium"]);
  assert.deepEqual(await cosmetics(cuarto.id), [], "Bronce y cuarto: nada");

  assert.deepEqual(await pointsOf(campeon.id), { points: 1260, season_peak: 1260 }, "1520 → 1260 y el máximo parte de ahí");
  assert.deepEqual(await pointsOf(cuarto.id), { points: 1025, season_peak: 1025 });
  assert.equal((await pointsOf(ausente.id)).points, 1100, "el que no jugó también se reinicia (1200 → 1100)");

  const current = await app.inject({ method: "GET", url: "/season" });
  assert.equal(current.json().id, "2026-12");
});

test("la recompensa se puede poner como marco y título", async () => {
  const res = await app.inject({
    method: "POST",
    url: "/auth/login",
    payload: { email: "temp_uno@test.com", password: "secreto1" },
  });
  const token = res.json().access_token as string;
  const put = await app.inject({
    method: "PATCH",
    url: "/me",
    payload: { frame: "frame_season_diamond", title: "title_season_champion" },
    headers: { authorization: `Bearer ${token}` },
  });
  assert.equal(put.statusCode, 200, put.body);
  assert.equal(put.json().frame, "frame_season_diamond");
});

test("ganar un duelo sube el máximo de la temporada, perderlo no lo baja", async () => {
  const a = await register("Temp_Pico");
  await app.accounts.applyResult(a.id, 1180, "win");
  await app.accounts.applyResult(a.id, 1150, "loss");
  assert.deepEqual(await pointsOf(a.id), { points: 1150, season_peak: 1180 });
});

test("sin sesión no hay historial de temporadas", async () => {
  assert.equal((await app.inject({ method: "GET", url: "/me/seasons" })).statusCode, 401);
});
