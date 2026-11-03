import type { Db, Queryable } from "../db/db.js";
import { UnlockRepository } from "../repositories/unlock.repository.js";

/** Ligas por puntos (las mismas que muestra el juego en scripts/ui/league.gd). */
export const LEAGUES = [
  { key: "bronze", from: 0 },
  { key: "silver", from: 1100 },
  { key: "gold", from: 1300 },
  { key: "diamond", from: 1500 },
] as const;
export type League = (typeof LEAGUES)[number]["key"];

/** Marco que se gana según la liga máxima alcanzada en la temporada (en Bronce no hay). */
export const SEASON_FRAMES: Partial<Record<League, string>> = {
  silver: "frame_season_silver",
  gold: "frame_season_gold",
  diamond: "frame_season_diamond",
};
/** Títulos del podio: el primero y el segundo y tercero. */
export const TITLE_CHAMPION = "title_season_champion";
export const TITLE_PODIUM = "title_season_podium";

/** Puntos con los que todos empiezan. */
const BASE_POINTS = 1000;

/** Liga de unos puntos. */
export function leagueOf(points: number): League {
  let league: League = "bronze";
  for (const l of LEAGUES) if (points >= l.from) league = l.key;
  return league;
}

/** Temporada de una fecha: el mes en UTC, "AAAA-MM". */
export function seasonOf(date: Date): string {
  return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
}

/** Cuándo empieza una temporada: el día 1 de su mes a las 00:00 UTC. */
export function seasonStart(id: string): Date {
  const [year, month] = id.split("-").map(Number) as [number, number];
  return new Date(Date.UTC(year, month - 1, 1));
}

/** Cuándo termina una temporada: el día 1 del mes siguiente a las 00:00 UTC. */
export function seasonEnd(id: string): Date {
  const [year, month] = id.split("-").map(Number) as [number, number];
  return new Date(Date.UTC(year, month, 1));
}

/** Reinicio suave: los puntos se acercan a 1000 a la mitad (1400 → 1200, 800 → 900). */
export function softReset(points: number): number {
  return BASE_POINTS + Math.trunc((points - BASE_POINTS) / 2);
}

export interface SeasonResult {
  season: string;
  rank: number;
  points: number;
  peakPoints: number;
  league: League;
  wins: number;
  losses: number;
}

interface ResultRow {
  season: string;
  rank: number;
  points: number;
  peak_points: number;
  league: League;
  wins: number;
  losses: number;
}

/** Temporadas: cuál está abierta, cerrarla al cambiar de mes y el historial de cada jugador. */
export class SeasonService {
  constructor(
    private readonly db: Db,
    private readonly now: () => Date = () => new Date(),
  ) {}

  /** La temporada en curso y cuándo termina. */
  current(): { id: string; endsAt: Date } {
    const id = seasonOf(this.now());
    return { id, endsAt: seasonEnd(id) };
  }

  /**
   * Si la temporada abierta ya no es la del mes actual, la cierra y abre la nueva. La primera vez solo abre
   * la actual. Devuelve el id de la cerrada (o null). Varias instancias a la vez: solo una la cierra (la que
   * consigue marcarla como cerrada); las demás no hacen nada.
   */
  async rollover(): Promise<string | null> {
    const currentId = seasonOf(this.now());
    return this.db.transaction(async (tx) => {
      const open = await tx.query<{ id: string }>("select id from seasons where closed_at is null for update");
      const row = open.rows[0];
      if (row && row.id === currentId) return null;
      let closed: string | null = null;
      if (row) {
        const res = await tx.query<{ id: string }>(
          "update seasons set closed_at = $2 where id = $1 and closed_at is null returning id",
          [row.id, this.now().toISOString()],
        );
        if (res.rows.length === 0) return null;
        await this.close(tx, row.id);
        closed = row.id;
      }
      await tx.query("insert into seasons (id, started_at) values ($1, $2) on conflict (id) do nothing", [
        currentId,
        seasonStart(currentId).toISOString(),
      ]);
      return closed;
    });
  }

  /** Cómo acabó el jugador cada temporada, la más reciente primero. */
  async history(playerId: string, limit = 12): Promise<SeasonResult[]> {
    const res = await this.db.query<ResultRow>(
      `select season, rank, points, peak_points, league, wins, losses from season_results
        where player_id = $1 order by season desc limit $2`,
      [playerId, limit],
    );
    return res.rows.map((r) => ({
      season: r.season,
      rank: r.rank,
      points: r.points,
      peakPoints: r.peak_points,
      league: r.league,
      wins: r.wins,
      losses: r.losses,
    }));
  }

  /**
   * Guarda los resultados de quienes jugaron algún duelo en el mes de la temporada, da las recompensas y hace el
   * reinicio suave de todos.
   */
  private async close(tx: Queryable, season: string): Promise<void> {
    const players = await tx.query<{ id: string; points: number; peak: number; wins: number; losses: number }>(
      `with pm as (
         select p1_id as pid, (winner = 1)::int as w, (winner = 2)::int as l from matches
          where played_at >= $1 and played_at < $2
         union all
         select p2_id, (winner = 2)::int, (winner = 1)::int from matches where played_at >= $1 and played_at < $2)
       select p.id, p.points, greatest(p.season_peak, p.points) as peak, sum(pm.w)::int as wins, sum(pm.l)::int as losses
         from pm join players p on p.id = pm.pid
        group by p.id
        order by p.points desc, p.wins desc, p.created_at asc`,
      [seasonStart(season).toISOString(), seasonEnd(season).toISOString()],
    );
    const unlocks = new UnlockRepository(tx);
    for (const [i, p] of players.rows.entries()) {
      const rank = i + 1;
      const league = leagueOf(p.peak);
      await tx.query(
        `insert into season_results (season, player_id, rank, points, peak_points, league, wins, losses)
         values ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [season, p.id, rank, p.points, p.peak, league, p.wins, p.losses],
      );
      const rewards: string[] = [];
      const frame = SEASON_FRAMES[league];
      if (frame) rewards.push(frame);
      if (rank === 1) rewards.push(TITLE_CHAMPION);
      else if (rank <= 3) rewards.push(TITLE_PODIUM);
      await unlocks.addMany(p.id, rewards.map((key) => ({ kind: "cosmetic" as const, key })));
    }
    // Reinicio suave de todos (también de quien no jugó este mes); el máximo de la nueva temporada parte de ahí.
    await tx.query(
      `update players set points = ${BASE_POINTS} + trunc((points - ${BASE_POINTS}) / 2.0)::int,
                          season_peak = ${BASE_POINTS} + trunc((points - ${BASE_POINTS}) / 2.0)::int`,
    );
  }
}
