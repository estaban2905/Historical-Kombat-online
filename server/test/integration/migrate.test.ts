import { test } from "node:test";
import assert from "node:assert/strict";
import { PGlite } from "@electric-sql/pglite";
import { migrate } from "../../src/db/migrate.js";
import { PgliteDb } from "../helpers/pglite-db.js";

test("las migraciones se aplican una vez y la segunda vez no hacen nada", async (t) => {
  const db = new PgliteDb(new PGlite());
  t.after(() => db.close());
  const first = await migrate(db);
  assert.deepEqual(first, ["001_init.sql", "002_google.sql", "003_story_saves.sql", "004_avatar.sql", "005_username_change.sql", "006_unlocks.sql", "007_cosmetics.sql", "008_friends.sql", "009_seasons.sql"]);
  assert.deepEqual(await migrate(db), []);
  const tables = await db.query<{ tablename: string }>(
    "select tablename from pg_tables where schemaname = 'public' order by tablename",
  );
  assert.deepEqual(
    tables.rows.map((r) => r.tablename),
    ["friendships", "matches", "player_unlocks", "players", "schema_migrations", "season_results", "seasons", "sessions", "story_saves"],
  );
});

test("la base de datos rechaza nombres inválidos y repetidos aunque cambie el tamaño de letra", async (t) => {
  const db = new PgliteDb(new PGlite());
  t.after(() => db.close());
  await migrate(db);
  const insert = (u: string, e: string) =>
    db.query("insert into players (username, email, password_hash) values ($1, $2, 'x')", [u, e]);
  await insert("Max_29", "a@a.com");
  await assert.rejects(insert("max_29", "b@b.com"));
  await assert.rejects(insert("Otro_1", "A@A.com"));
  await assert.rejects(insert("ab", "c@c.com"));
  await assert.rejects(insert("con espacio", "d@d.com"));
});
