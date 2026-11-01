import type { MatchmakingService, MatchmakingStats } from "../services/matchmaking.service.js";

export function getHealth(matchmaking: MatchmakingService, hasDb: boolean): { ok: true; db: boolean } & MatchmakingStats {
  return { ok: true, db: hasDb, ...matchmaking.stats() };
}
