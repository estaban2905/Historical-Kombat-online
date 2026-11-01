import type { MatchmakingService, MatchmakingStats } from "../services/matchmaking.service.js";

export function getHealth(matchmaking: MatchmakingService): { ok: true } & MatchmakingStats {
  return { ok: true, ...matchmaking.stats() };
}
