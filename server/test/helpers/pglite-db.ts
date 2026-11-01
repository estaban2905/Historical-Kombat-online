import { PGlite } from "@electric-sql/pglite";
import { PgliteDb } from "../../src/db/pglite-db.js";
import { migrate } from "../../src/db/migrate.js";

export { PgliteDb };

/** Base de datos nueva en memoria, con todas las migraciones aplicadas. */
export async function createTestDb(): Promise<PgliteDb> {
  const db = new PgliteDb(new PGlite());
  await migrate(db);
  return db;
}
