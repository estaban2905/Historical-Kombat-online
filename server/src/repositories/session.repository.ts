import type { Queryable } from "../db/db.js";

export interface SessionRow {
  id: string;
  playerId: string;
}

interface Row {
  id: string;
  player_id: string;
}

/** Todo el SQL de la tabla sessions. Solo se manejan hashes de tokens, nunca los tokens. */
export class SessionRepository {
  constructor(private readonly db: Queryable) {}

  async create(input: {
    playerId: string;
    accessHash: string;
    refreshHash: string;
    accessExpires: Date;
    refreshExpires: Date;
  }): Promise<void> {
    await this.db.query(
      `insert into sessions (player_id, access_hash, refresh_hash, access_expires, refresh_expires)
       values ($1, $2, $3, $4, $5)`,
      [input.playerId, input.accessHash, input.refreshHash, input.accessExpires, input.refreshExpires],
    );
  }

  /** La sesión cuyo access token no ha caducado. */
  async findByAccessHash(hash: string): Promise<SessionRow | null> {
    const res = await this.db.query<Row>(
      "select id, player_id from sessions where access_hash = $1 and access_expires > now()",
      [hash],
    );
    const r = res.rows[0];
    return r ? { id: r.id, playerId: r.player_id } : null;
  }

  /** La sesión cuyo refresh token no ha caducado. */
  async findByRefreshHash(hash: string): Promise<SessionRow | null> {
    const res = await this.db.query<Row>(
      "select id, player_id from sessions where refresh_hash = $1 and refresh_expires > now()",
      [hash],
    );
    const r = res.rows[0];
    return r ? { id: r.id, playerId: r.player_id } : null;
  }

  async delete(id: string): Promise<void> {
    await this.db.query("delete from sessions where id = $1", [id]);
  }

  async deleteByAccessHash(hash: string): Promise<void> {
    await this.db.query("delete from sessions where access_hash = $1", [hash]);
  }

  /** Limpieza: borra las sesiones de un jugador cuyo refresh token ya caducó. */
  async deleteExpired(playerId: string): Promise<void> {
    await this.db.query("delete from sessions where player_id = $1 and refresh_expires <= now()", [playerId]);
  }
}
