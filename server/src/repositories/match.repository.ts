import type { Queryable } from "../db/db.js";
import type { Winner } from "../models/messages.js";

export interface NewMatch {
  p1Id: string;
  p2Id: string;
  p1Fighter: string;
  p2Fighter: string;
  winner: Winner;
  p1Rounds: number;
  p2Rounds: number;
  p1Delta: number;
  p2Delta: number;
  reason: "normal" | "forfeit";
}

export interface MatchHistoryEntry {
  id: string;
  playedAt: Date;
  opponent: string;
  myFighter: string;
  opponentFighter: string;
  result: "win" | "loss" | "draw";
  delta: number;
  myRounds: number;
  opponentRounds: number;
  reason: "normal" | "forfeit";
}

interface HistoryRow {
  id: string;
  played_at: Date | string;
  reason: "normal" | "forfeit";
  winner: number;
  is_p1: boolean;
  opponent: string;
  my_fighter: string;
  opponent_fighter: string;
  delta: number;
  my_rounds: number;
  opponent_rounds: number;
}

/** Lo que se deduce de los duelos de un jugador. */
export interface PlayerStats {
  /** El luchador con el que más ha jugado (a igualdad, el primero por id), o null sin duelos. */
  favoriteFighter: string | null;
  /** Victorias seguidas hasta hoy: un empate o una derrota la cortan. */
  streak: number;
}

/** Cada duelo visto desde cada lado: una fila por jugador y duelo. */
const PLAYER_MATCHES = `
  select p1_id as pid, p1_fighter as fighter, played_at, id,
         case winner when 0 then 'draw' when 1 then 'win' else 'loss' end as result
    from matches
  union all
  select p2_id, p2_fighter, played_at, id,
         case winner when 0 then 'draw' when 2 then 'win' else 'loss' end
    from matches`;

/** Todo el SQL de la tabla matches. */
export class MatchRepository {
  constructor(private readonly db: Queryable) {}

  /** Todos los duelos de un jugador, del más antiguo al más reciente, vistos desde su lado. */
  async resultsOf(playerId: string): Promise<{ result: "win" | "loss" | "draw"; myRounds: number; opponentRounds: number }[]> {
    const res = await this.db.query<{ result: "win" | "loss" | "draw"; my_rounds: number; opponent_rounds: number }>(
      `select case when winner = 0 then 'draw' when (winner = 1) = (p1_id = $1) then 'win' else 'loss' end as result,
              case when p1_id = $1 then p1_rounds else p2_rounds end as my_rounds,
              case when p1_id = $1 then p2_rounds else p1_rounds end as opponent_rounds
         from matches where p1_id = $1 or p2_id = $1
        order by played_at, id`,
      [playerId],
    );
    return res.rows.map((r) => ({ result: r.result, myRounds: r.my_rounds, opponentRounds: r.opponent_rounds }));
  }

  /** Luchador favorito y racha de cada jugador de la lista (los que no han jugado salen con null y 0). */
  async statsFor(playerIds: string[]): Promise<Map<string, PlayerStats>> {
    const out = new Map<string, PlayerStats>(playerIds.map((id) => [id, { favoriteFighter: null, streak: 0 }]));
    if (playerIds.length === 0) return out;
    const fighters = await this.db.query<{ pid: string; fighter: string; n: number }>(
      `with pm as (${PLAYER_MATCHES})
       select pid, fighter, count(*)::int as n from pm where pid = any($1::uuid[]) group by pid, fighter`,
      [playerIds],
    );
    const best = new Map<string, { fighter: string; n: number }>();
    for (const r of fighters.rows) {
      const cur = best.get(r.pid);
      if (!cur || r.n > cur.n || (r.n === cur.n && r.fighter < cur.fighter)) best.set(r.pid, { fighter: r.fighter, n: r.n });
    }
    for (const [pid, b] of best) out.get(pid)!.favoriteFighter = b.fighter;
    // La racha son las victorias antes de la primera que no lo es, contando desde el duelo más reciente.
    const streaks = await this.db.query<{ pid: string; streak: number }>(
      `with pm as (${PLAYER_MATCHES}),
            ranked as (
              select pid, result, row_number() over (partition by pid order by played_at desc, id) as rn
                from pm where pid = any($1::uuid[]))
       select pid, coalesce(min(rn) filter (where result <> 'win') - 1, count(*))::int as streak
         from ranked group by pid`,
      [playerIds],
    );
    for (const r of streaks.rows) out.get(r.pid)!.streak = r.streak;
    return out;
  }

  async insert(m: NewMatch): Promise<void> {
    await this.db.query(
      `insert into matches
         (p1_id, p2_id, p1_fighter, p2_fighter, winner, p1_rounds, p2_rounds, p1_delta, p2_delta, reason)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [m.p1Id, m.p2Id, m.p1Fighter, m.p2Fighter, m.winner, m.p1Rounds, m.p2Rounds, m.p1Delta, m.p2Delta, m.reason],
    );
  }

  /** Los duelos más recientes de un jugador, vistos desde su lado. */
  async history(playerId: string, limit: number): Promise<MatchHistoryEntry[]> {
    const res = await this.db.query<HistoryRow>(
      `select m.id, m.played_at, m.reason, m.winner,
              (m.p1_id = $1) as is_p1,
              case when m.p1_id = $1 then o2.username else o1.username end as opponent,
              case when m.p1_id = $1 then m.p1_fighter else m.p2_fighter end as my_fighter,
              case when m.p1_id = $1 then m.p2_fighter else m.p1_fighter end as opponent_fighter,
              case when m.p1_id = $1 then m.p1_delta else m.p2_delta end as delta,
              case when m.p1_id = $1 then m.p1_rounds else m.p2_rounds end as my_rounds,
              case when m.p1_id = $1 then m.p2_rounds else m.p1_rounds end as opponent_rounds
         from matches m
         join players o1 on o1.id = m.p1_id
         join players o2 on o2.id = m.p2_id
        where m.p1_id = $1 or m.p2_id = $1
        order by m.played_at desc, m.id
        limit $2`,
      [playerId, limit],
    );
    return res.rows.map((r) => ({
      id: r.id,
      playedAt: new Date(r.played_at),
      opponent: r.opponent,
      myFighter: r.my_fighter,
      opponentFighter: r.opponent_fighter,
      result: r.winner === 0 ? "draw" : r.winner === (r.is_p1 ? 1 : 2) ? "win" : "loss",
      delta: r.delta,
      myRounds: r.my_rounds,
      opponentRounds: r.opponent_rounds,
      reason: r.reason,
    }));
  }
}
