import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { PGlite } from "@electric-sql/pglite";
import { PGLiteSocketServer } from "@electric-sql/pglite-socket";
import { buildApp } from "../../src/app.js";
import { migrate } from "../../src/db/migrate.js";
import { PgDb } from "../../src/db/pg-db.js";

/**
 * Prueba del driver real de producción (`pg`, el mismo que usa Railway) contra un
 * servidor que habla el protocolo de red de Postgres. Así se comprueba la conexión,
 * las consultas con parámetros, las transacciones y las migraciones de verdad.
 */
const PORT = 54000 + Math.floor(Math.random() * 1000);
let embedded: PGlite;
let server: PGLiteSocketServer;
let db: PgDb;

before(async () => {
  embedded = await PGlite.create();
  server = new PGLiteSocketServer({ db: embedded, port: PORT, host: "127.0.0.1" });
  await server.start();
  // El servidor embebido atiende una conexión a la vez: un pool de 1.
  db = new PgDb(`postgres://postgres:postgres@127.0.0.1:${PORT}/postgres`, 1);
});

after(async () => {
  await db.close();
  await server.stop();
  await embedded.close();
});

test("PgDb: migra y consulta con parámetros", async () => {
  assert.deepEqual(await migrate(db), ["001_init.sql", "002_google.sql", "003_story_saves.sql", "004_avatar.sql", "005_username_change.sql", "006_unlocks.sql"]);
  assert.deepEqual(await migrate(db), []);
  const res = await db.query<{ n: number }>("select $1::int + 1 as n", [41]);
  assert.equal(res.rows[0]!.n, 42);
});

test("PgDb: una transacción con error se deshace entera", async () => {
  await assert.rejects(
    db.transaction(async (tx) => {
      await tx.query("insert into players (username, email, password_hash) values ('Tx_1', 'tx@t.com', 'x')");
      throw new Error("falla a mitad");
    }),
    /falla a mitad/,
  );
  const n = await db.query<{ c: string }>("select count(*)::text as c from players where username = 'Tx_1'");
  assert.equal(n.rows[0]!.c, "0");
});

test("PgDb: el flujo completo de cuentas funciona con el driver real", async (t) => {
  const app = await buildApp({ db, config: { logger: false, authRateLimitPerMinute: 1000 } });
  t.after(() => app.close());
  const reg = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: "real@test.com", password: "secreto1", username: "Real_1" },
  });
  assert.equal(reg.statusCode, 201, reg.body);
  const me = await app.inject({ method: "GET", url: "/me", headers: { authorization: `Bearer ${reg.json().access_token}` } });
  assert.equal(me.statusCode, 200, me.body);
  assert.equal(me.json().username, "Real_1");
  const board = await app.inject({ method: "GET", url: "/leaderboard" });
  assert.equal(board.json()[0].username, "Real_1");

  // El duplicado va al final: el servidor embebido de pruebas corta la conexión tras un error SQL
  // (un Postgres real no lo hace), y lo que se prueba aquí es el driver, no ese servidor.
  const dup = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: "REAL@test.com", password: "secreto1", username: "Otro_1" },
  });
  assert.equal(dup.statusCode, 409);
  assert.equal(dup.json().error, "email_taken");
});
