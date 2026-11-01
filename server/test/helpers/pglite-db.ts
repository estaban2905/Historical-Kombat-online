import { PGlite } from "@electric-sql/pglite";
import type { Db, Queryable } from "../../src/db/db.js";
import { migrate } from "../../src/db/migrate.js";

/** Postgres real pero embebido y en memoria: las pruebas no necesitan Docker ni servidor. */
export class PgliteDb implements Db {
  constructor(private readonly pg: PGlite) {}

  async query<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<{ rows: T[] }> {
    const res = await this.pg.query<T>(sql, params);
    return { rows: res.rows };
  }

  async exec(sql: string): Promise<void> {
    await this.pg.exec(sql);
  }

  async transaction<T>(fn: (tx: Queryable) => Promise<T>): Promise<T> {
    return this.pg.transaction(async (t) =>
      fn({
        query: async <R = Record<string, unknown>>(sql: string, params?: unknown[]) => {
          const res = await t.query<R>(sql, params);
          return { rows: res.rows };
        },
        exec: async (sql: string) => {
          await t.exec(sql);
        },
      }),
    );
  }

  async close(): Promise<void> {
    await this.pg.close();
  }
}

/** Base de datos nueva, con todas las migraciones aplicadas. */
export async function createTestDb(): Promise<PgliteDb> {
  const db = new PgliteDb(new PGlite());
  await migrate(db);
  return db;
}
