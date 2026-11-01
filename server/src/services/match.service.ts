import type { Db } from "../db/db.js";
import type { Winner } from "../models/messages.js";
import { AccountRepository } from "../repositories/account.repository.js";
import { MatchRepository } from "../repositories/match.repository.js";
import { applyDelta, eloDelta } from "./rating.service.js";

export interface SettleRequest {
  p1Id: string;
  p2Id: string;
  p1Fighter: string;
  p2Fighter: string;
  winner: Winner;
  p1Rounds: number;
  p2Rounds: number;
  reason: "normal" | "forfeit";
}

/** Cómo quedó un jugador tras el duelo. */
export interface SettleSide {
  delta: number;
  points: number;
  wins: number;
  losses: number;
}

export interface SettleOutcome {
  p1: SettleSide;
  p2: SettleSide;
}

/** Guarda el resultado de un duelo y reparte los puntos. */
export type Settler = (req: SettleRequest) => Promise<SettleOutcome>;

export class MatchService {
  constructor(private readonly db: Db) {}

  /**
   * Todo o nada, en una transacción: los puntos de los dos jugadores y la fila del
   * historial se guardan juntos. Los jugadores quedan bloqueados mientras tanto, así
   * dos duelos simultáneos del mismo jugador no se pisan.
   */
  readonly settle: Settler = (req) =>
    this.db.transaction(async (tx) => {
      const accounts = new AccountRepository(tx);
      const players = await accounts.lockPair(req.p1Id, req.p2Id);
      const p1 = players.get(req.p1Id);
      const p2 = players.get(req.p2Id);
      if (!p1 || !p2) throw new Error("cuenta no encontrada al guardar el duelo");

      const delta1 = eloDelta(p1.points, p2.points, req.winner);
      const points1 = applyDelta(p1.points, delta1);
      const points2 = applyDelta(p2.points, -delta1);
      const out1 = req.winner === 0 ? "draw" : req.winner === 1 ? "win" : "loss";
      const out2 = req.winner === 0 ? "draw" : req.winner === 2 ? "win" : "loss";
      await accounts.applyResult(p1.id, points1, out1);
      await accounts.applyResult(p2.id, points2, out2);

      const p1Delta = points1 - p1.points;
      const p2Delta = points2 - p2.points;
      await new MatchRepository(tx).insert({
        p1Id: p1.id,
        p2Id: p2.id,
        p1Fighter: req.p1Fighter,
        p2Fighter: req.p2Fighter,
        winner: req.winner,
        p1Rounds: req.p1Rounds,
        p2Rounds: req.p2Rounds,
        p1Delta,
        p2Delta,
        reason: req.reason,
      });

      return {
        p1: { delta: p1Delta, points: points1, wins: p1.wins + (out1 === "win" ? 1 : 0), losses: p1.losses + (out1 === "loss" ? 1 : 0) },
        p2: { delta: p2Delta, points: points2, wins: p2.wins + (out2 === "win" ? 1 : 0), losses: p2.losses + (out2 === "loss" ? 1 : 0) },
      };
    });
}
