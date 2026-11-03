import type { Queryable } from "../db/db.js";
import type { DesyncStore } from "../services/desync-ledger.js";

/** Todo el SQL de la tabla desync_strikes: las anulaciones por desincronización de cada cuenta. */
export class DesyncRepository implements DesyncStore {
  constructor(
    private readonly db: Queryable,
    /** Cuánto tiempo cuenta una anulación (ms). */
    private readonly windowMs: number,
  ) {}

  async record(accountId: string): Promise<number> {
    await this.db.query("insert into desync_strikes (player_id) values ($1)", [accountId]);
    // Lo caducado de cualquier cuenta se borra aquí: así la tabla no crece y no hace falta ninguna tarea aparte.
    await this.db.query("delete from desync_strikes where at < now() - $1::double precision * interval '1 millisecond'", [this.windowMs]);
    return this.count(accountId);
  }

  async count(accountId: string): Promise<number> {
    const res = await this.db.query<{ n: number | string }>(
      "select count(*) as n from desync_strikes where player_id = $1 and at >= now() - $2::double precision * interval '1 millisecond'",
      [accountId, this.windowMs],
    );
    return Number(res.rows[0]?.n ?? 0);
  }
}
