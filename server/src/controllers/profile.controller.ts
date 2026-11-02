import type { FastifyRequest } from "fastify";
import { toProfile } from "../models/account.js";
import type { AccountRepository } from "../repositories/account.repository.js";
import type { MatchRepository } from "../repositories/match.repository.js";

export const profileController = (accounts: AccountRepository, matches: MatchRepository) => ({
  /** requireAuth ya dejó la cuenta en la petición. */
  me(req: FastifyRequest) {
    return toProfile(req.account!);
  },

  /** Cambia el avatar y devuelve el perfil ya actualizado. */
  async updateMe(req: FastifyRequest<{ Body: { avatar: string | null } }>) {
    await accounts.setAvatar(req.account!.id, req.body.avatar);
    return toProfile({ ...req.account!, avatar: req.body.avatar });
  },

  /** Mis últimos duelos, en el formato público (snake_case). */
  async myMatches(req: FastifyRequest<{ Querystring: { limit?: number } }>) {
    const rows = await matches.history(req.account!.id, req.query.limit ?? 20);
    return rows.map((m) => ({
      id: m.id,
      played_at: m.playedAt.toISOString(),
      opponent: m.opponent,
      my_fighter: m.myFighter,
      opponent_fighter: m.opponentFighter,
      result: m.result,
      delta: m.delta,
      my_rounds: m.myRounds,
      opponent_rounds: m.opponentRounds,
      reason: m.reason,
    }));
  },

  ranking(req: FastifyRequest<{ Querystring: { limit?: number } }>) {
    return accounts.ranking(req.query.limit ?? 20);
  },
});
