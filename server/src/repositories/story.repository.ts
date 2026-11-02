import type { Queryable } from "../db/db.js";

/** Lo mínimo para retomar el modo Historia donde se dejó. La escalera se recalcula en el juego. */
export interface StorySave {
  fighter: string;
  stage: number;
  continues: number;
  continuesUsed: number;
  difficulty: number;
  savedAt: number;
}

interface StoryRow {
  fighter: string;
  stage: number;
  continues: number;
  continues_used: number;
  difficulty: number;
  saved_at: string | number;
}

/** Todo el SQL de la tabla story_saves. */
export class StoryRepository {
  constructor(private readonly db: Queryable) {}

  async get(playerId: string): Promise<StorySave | null> {
    const res = await this.db.query<StoryRow>(
      `select fighter, stage, continues, continues_used, difficulty, saved_at
         from story_saves where player_id = $1`,
      [playerId],
    );
    const r = res.rows[0];
    if (!r) return null;
    return {
      fighter: r.fighter,
      stage: r.stage,
      continues: r.continues,
      continuesUsed: r.continues_used,
      difficulty: r.difficulty,
      // bigint llega como texto desde Postgres.
      savedAt: Number(r.saved_at),
    };
  }

  /** Crea o reemplaza la partida de la cuenta. Un guardado más viejo no pisa a uno más nuevo. */
  async put(playerId: string, s: StorySave): Promise<void> {
    await this.db.query(
      `insert into story_saves (player_id, fighter, stage, continues, continues_used, difficulty, saved_at)
       values ($1, $2, $3, $4, $5, $6, $7)
       on conflict (player_id) do update set
         fighter = excluded.fighter, stage = excluded.stage, continues = excluded.continues,
         continues_used = excluded.continues_used, difficulty = excluded.difficulty,
         saved_at = excluded.saved_at, updated_at = now()
       where story_saves.saved_at <= excluded.saved_at`,
      [playerId, s.fighter, s.stage, s.continues, s.continuesUsed, s.difficulty, s.savedAt],
    );
  }

  async delete(playerId: string): Promise<void> {
    await this.db.query("delete from story_saves where player_id = $1", [playerId]);
  }
}
