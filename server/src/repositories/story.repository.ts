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

const COLUMNS = "fighter, stage, continues, continues_used, difficulty, saved_at";

const toSave = (r: StoryRow): StorySave => ({
  fighter: r.fighter,
  stage: r.stage,
  continues: r.continues,
  continuesUsed: r.continues_used,
  difficulty: r.difficulty,
  // bigint llega como texto desde Postgres.
  savedAt: Number(r.saved_at),
});

/** Todo el SQL de la tabla story_saves: una partida por cuenta y luchador. */
export class StoryRepository {
  constructor(private readonly db: Queryable) {}

  /** La partida de ese luchador o, sin luchador, la más reciente de la cuenta. */
  async get(playerId: string, fighter?: string): Promise<StorySave | null> {
    const res = fighter
      ? await this.db.query<StoryRow>(`select ${COLUMNS} from story_saves where player_id = $1 and fighter = $2`, [
          playerId,
          fighter,
        ])
      : await this.db.query<StoryRow>(
          `select ${COLUMNS} from story_saves where player_id = $1 order by saved_at desc limit 1`,
          [playerId],
        );
    const r = res.rows[0];
    return r ? toSave(r) : null;
  }

  /** Todas las partidas de la cuenta, la más reciente primero. */
  async list(playerId: string): Promise<StorySave[]> {
    const res = await this.db.query<StoryRow>(
      `select ${COLUMNS} from story_saves where player_id = $1 order by saved_at desc`,
      [playerId],
    );
    return res.rows.map(toSave);
  }

  /** Crea o reemplaza la partida de ese luchador. Un guardado más viejo no pisa a uno más nuevo. */
  async put(playerId: string, s: StorySave): Promise<void> {
    await this.db.query(
      `insert into story_saves (player_id, fighter, stage, continues, continues_used, difficulty, saved_at)
       values ($1, $2, $3, $4, $5, $6, $7)
       on conflict (player_id, fighter) do update set
         stage = excluded.stage, continues = excluded.continues,
         continues_used = excluded.continues_used, difficulty = excluded.difficulty,
         saved_at = excluded.saved_at, updated_at = now()
       where story_saves.saved_at <= excluded.saved_at`,
      [playerId, s.fighter, s.stage, s.continues, s.continuesUsed, s.difficulty, s.savedAt],
    );
  }

  /** Borra la partida de ese luchador o, sin luchador, la más reciente (lo que hacían los clientes de una sola partida). */
  async delete(playerId: string, fighter?: string): Promise<void> {
    if (fighter) {
      await this.db.query("delete from story_saves where player_id = $1 and fighter = $2", [playerId, fighter]);
      return;
    }
    await this.db.query(
      `delete from story_saves where player_id = $1 and fighter =
         (select fighter from story_saves where player_id = $1 order by saved_at desc limit 1)`,
      [playerId],
    );
  }
}
