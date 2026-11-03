import type { FastifyRequest } from "fastify";
import { AppError } from "../errors.js";
import { toProfile } from "../models/account.js";
import type { AccountRepository } from "../repositories/account.repository.js";
import type { MatchHistoryEntry, MatchRepository } from "../repositories/match.repository.js";

/** Un duelo en el formato público (snake_case). */
const publicMatch = (m: MatchHistoryEntry) => ({
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
});

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
    return rows.map(publicMatch);
  },

  /** Ranking con el luchador favorito y la racha de cada jugador. */
  async ranking(req: FastifyRequest<{ Querystring: { limit?: number } }>) {
    const rows = await accounts.ranking(req.query.limit ?? 20);
    const stats = await matches.statsFor(rows.map((r) => r.id));
    return rows.map((r) => ({
      username: r.username,
      points: r.points,
      wins: r.wins,
      losses: r.losses,
      avatar: r.avatar,
      favorite_fighter: stats.get(r.id)!.favoriteFighter,
      streak: stats.get(r.id)!.streak,
    }));
  },

  /** Perfil de cualquier jugador, por nombre. Nunca incluye el email ni el id. */
  async publicProfile(req: FastifyRequest<{ Params: { username: string } }>) {
    const a = await accounts.findByUsername(req.params.username);
    if (!a) throw new AppError(404, "player_not_found", "JUGADOR NO ENCONTRADO");
    const rank = await accounts.rankOf(a);
    const stats = (await matches.statsFor([a.id])).get(a.id)!;
    const recent = await matches.history(a.id, 10);
    return {
      username: a.username,
      points: a.points,
      wins: a.wins,
      losses: a.losses,
      avatar: a.avatar,
      rank,
      favorite_fighter: stats.favoriteFighter,
      streak: stats.streak,
      recent: recent.map(publicMatch),
    };
  },
});
