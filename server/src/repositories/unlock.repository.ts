import type { Queryable } from "../db/db.js";

export type UnlockKind = "ending" | "fighter" | "cosmetic";

export interface Unlock {
  kind: UnlockKind;
  key: string;
  unlockedAt: Date;
}

interface Row {
  kind: UnlockKind;
  key: string;
  unlocked_at: Date | string;
}

/** Todo el SQL de la tabla player_unlocks. */
export class UnlockRepository {
  constructor(private readonly db: Queryable) {}

  /** Lo desbloqueado por el jugador, lo más antiguo primero. */
  async list(playerId: string): Promise<Unlock[]> {
    const res = await this.db.query<Row>(
      "select kind, key, unlocked_at from player_unlocks where player_id = $1 order by unlocked_at, kind, key",
      [playerId],
    );
    return res.rows.map((r) => ({ kind: r.kind, key: r.key, unlockedAt: new Date(r.unlocked_at) }));
  }

  /** Añade lo que falte; lo que ya estaba se deja como está (no hay error ni se cambia la fecha). */
  async addMany(playerId: string, items: { kind: UnlockKind; key: string }[]): Promise<void> {
    if (items.length === 0) return;
    await this.db.query(
      `insert into player_unlocks (player_id, kind, key)
       select $1, kind, key from unnest($2::text[], $3::text[]) as t(kind, key)
       on conflict do nothing`,
      [playerId, items.map((i) => i.kind), items.map((i) => i.key)],
    );
  }
}
