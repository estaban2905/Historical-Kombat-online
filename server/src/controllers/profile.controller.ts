import type { FastifyRequest } from "fastify";
import { AppError } from "../errors.js";
import { bearerToken } from "../plugins/auth.js";
import { toProfile } from "../models/account.js";
import type { AccountRepository } from "../repositories/account.repository.js";
import type { MatchHistoryEntry, MatchRepository } from "../repositories/match.repository.js";
import type { UnlockRepository } from "../repositories/unlock.repository.js";
import type { AuthService } from "../services/auth.service.js";

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

export interface UpdateMeBody {
  avatar?: string | null;
  username?: string;
  frame?: string | null;
  title?: string | null;
}

const NOT_UNLOCKED = new AppError(403, "not_unlocked", "TODAVÍA NO HAS DESBLOQUEADO ESO");

export const profileController = (
  accounts: AccountRepository,
  matches: MatchRepository,
  auth: AuthService,
  unlocks: UnlockRepository,
) => ({
  /** requireAuth ya dejó la cuenta en la petición. */
  me(req: FastifyRequest) {
    return toProfile(req.account!);
  },

  /** Cambia el avatar y/o el nombre, y devuelve el perfil ya actualizado. */
  async updateMe(req: FastifyRequest<{ Body: UpdateMeBody }>) {
    let account = req.account!;
    const { frame, title } = req.body;
    // Se comprueba todo lo que puede fallar antes de cambiar nada: o se aplica el cambio entero o ninguno.
    for (const key of [frame, title]) {
      if (key && !(await unlocks.has(account.id, "cosmetic", key))) throw NOT_UNLOCKED;
    }
    // El nombre primero: si falla (ocupado o en espera) no se cambia nada del avatar.
    if (req.body.username !== undefined) account = await auth.rename(account, req.body.username);
    if (frame !== undefined || title !== undefined) {
      await accounts.setCosmetics(account.id, { frame, title });
      account = { ...account, frame: frame !== undefined ? frame : account.frame, title: title !== undefined ? title : account.title };
    }
    if (req.body.avatar !== undefined) {
      await accounts.setAvatar(account.id, req.body.avatar);
      account = { ...account, avatar: req.body.avatar };
    }
    return toProfile(account);
  },

  async changePassword(req: FastifyRequest<{ Body: { current_password: string; new_password: string } }>) {
    await auth.changePassword(req.account!, bearerToken(req)!, req.body.current_password, req.body.new_password);
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
      frame: a.frame,
      title: a.title,
      rank,
      favorite_fighter: stats.favoriteFighter,
      streak: stats.streak,
      recent: recent.map(publicMatch),
    };
  },
});
