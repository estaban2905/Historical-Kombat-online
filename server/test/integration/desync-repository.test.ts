import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { DesyncRepository } from "../../src/repositories/desync.repository.js";
import { createTestDb, type PgliteDb } from "../helpers/pglite-db.js";

let db: PgliteDb;
const HOUR = 60 * 60 * 1000;

before(async () => {
  db = await createTestDb();
});
after(async () => {
  await db.close();
});

async function newPlayer(name: string): Promise<string> {
  const res = await db.query<{ id: string }>(
    "insert into players (username, email, password_hash) values ($1, $2, 'x') returning id",
    [name, `${name}@test.com`],
  );
  return res.rows[0]!.id;
}

test("cuenta las anulaciones de cada cuenta por separado y las conserva", async () => {
  const repo = new DesyncRepository(db, 24 * HOUR);
  const a = await newPlayer("ana");
  const b = await newPlayer("beto");
  assert.equal(await repo.record(a), 1);
  assert.equal(await repo.record(a), 2);
  assert.equal(await repo.record(b), 1);
  assert.equal(await repo.count(a), 2);
  // Otra instancia (un servidor reiniciado) ve lo mismo: el contador no vive en memoria.
  assert.equal(await new DesyncRepository(db, 24 * HOUR).count(a), 2);
});

test("las anulaciones fuera de la ventana no cuentan y se borran al anotar la siguiente", async () => {
  const repo = new DesyncRepository(db, 24 * HOUR);
  const c = await newPlayer("carla");
  await db.query("insert into desync_strikes (player_id, at) values ($1, now() - interval '25 hours')", [c]);
  await db.query("insert into desync_strikes (player_id, at) values ($1, now() - interval '2 hours')", [c]);
  assert.equal(await repo.count(c), 1, "la de hace 25 h ya no cuenta");
  assert.equal(await repo.record(c), 2);
  const left = await db.query<{ n: string }>("select count(*) as n from desync_strikes where player_id = $1", [c]);
  assert.equal(Number(left.rows[0]?.n), 2, "la caducada se borró");
});

test("al borrar una cuenta se borran sus anulaciones", async () => {
  const repo = new DesyncRepository(db, 24 * HOUR);
  const d = await newPlayer("dani");
  await repo.record(d);
  await db.query("delete from players where id = $1", [d]);
  assert.equal(await repo.count(d), 0);
});
