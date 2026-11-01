import pg from "pg";
import type { Db, Queryable } from "./db.js";

/** Postgres de verdad (el servicio de Railway), con un pool de conexiones. */
export class PgDb implements Db {
  private readonly pool: pg.Pool;

  constructor(connectionString: string, maxConnections = 10) {
    this.pool = new pg.Pool({ connectionString, max: maxConnections });
  }

  async query<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<{ rows: T[] }> {
    const res = await this.pool.query(sql, params);
    return { rows: res.rows as T[] };
  }

  async exec(sql: string): Promise<void> {
    await this.pool.query(sql);
  }

  async transaction<T>(fn: (tx: Queryable) => Promise<T>): Promise<T> {
    const client = await this.pool.connect();
    const tx: Queryable = {
      query: async <R = Record<string, unknown>>(sql: string, params?: unknown[]) => {
        const res = await client.query(sql, params);
        return { rows: res.rows as R[] };
      },
      exec: async (sql: string) => {
        await client.query(sql);
      },
    };
    try {
      await client.query("BEGIN");
      const result = await fn(tx);
      await client.query("COMMIT");
      return result;
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  }

  async close(): Promise<void> {
    await this.pool.end();
  }
}
