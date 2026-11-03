import type { FastifyInstance } from "fastify";
import { leaderboard, type RankingQuery } from "../controllers/profile.controller.js";
import { AppError } from "../errors.js";
import { MAX_FRIENDS } from "../repositories/friend.repository.js";
import { friendsRankingSchema, listFriendsSchema, removeFriendSchema, requestFriendSchema } from "../schemas/friend.schema.js";

/** Amigos: pedir, aceptar (pidiéndola de vuelta), quitar, y el ranking entre amigos. */
export async function friendRoutes(app: FastifyInstance): Promise<void> {
  const friends = app.friends;

  app.get("/me/friends", { schema: listFriendsSchema, preHandler: app.requireAuth }, async (req) =>
    friends.list(req.account!.id),
  );

  app.post<{ Body: { username: string } }>(
    "/me/friends",
    { schema: requestFriendSchema, preHandler: app.requireAuth },
    async (req) => {
      const other = await app.accounts.findByUsername(req.body.username);
      if (!other) throw new AppError(404, "player_not_found", "JUGADOR NO ENCONTRADO");
      if (other.id === req.account!.id) throw new AppError(400, "cannot_friend_self", "NO PUEDES SER TU PROPIO AMIGO");
      const result = await friends.request(req.account!.id, other.id);
      if (result === null) throw new AppError(409, "friend_limit", `YA TIENES ${MAX_FRIENDS} AMIGOS Y SOLICITUDES`);
      return { result };
    },
  );

  app.delete<{ Params: { username: string } }>(
    "/me/friends/:username",
    { schema: removeFriendSchema, preHandler: app.requireAuth },
    async (req, reply) => {
      const other = await app.accounts.findByUsername(req.params.username);
      // Si ese jugador ya no existe no hay nada que quitar: no se delata nada y no falla.
      if (other) await friends.remove(req.account!.id, other.id);
      return reply.code(204).send();
    },
  );

  app.get<{ Querystring: RankingQuery }>(
    "/me/friends/leaderboard",
    { schema: friendsRankingSchema, preHandler: app.requireAuth },
    async (req) => {
      const me = req.account!.id;
      const ids = [me, ...(await friends.friendIds(me))];
      return leaderboard(app.accounts, app.matchHistory, { ...req.query, limit: ids.length }, ids);
    },
  );
}
