import type { FastifyInstance } from "fastify";
import { AppError } from "../errors.js";
import { cancelChallengeSchema, createChallengeSchema, listChallengesSchema } from "../schemas/challenge.schema.js";

/** Retos entre amigos: crear, ver los que me hacen y cancelar o rechazar. */
export async function challengeRoutes(app: FastifyInstance): Promise<void> {
  const challenges = app.challenges;

  app.post<{ Body: { to: string } }>(
    "/me/challenges",
    { schema: createChallengeSchema, preHandler: app.requireAuth },
    async (req) => {
      const me = req.account!;
      const other = await app.accounts.findByUsername(req.body.to);
      if (!other) throw new AppError(404, "player_not_found", "JUGADOR NO ENCONTRADO");
      if (other.id === me.id) throw new AppError(400, "cannot_challenge_self", "NO PUEDES RETARTE A TI MISMO");
      if (!(await app.friends.areFriends(me.id, other.id))) {
        throw new AppError(403, "not_friends", "SOLO PUEDES RETAR A TUS AMIGOS");
      }
      const c = challenges.create({ id: me.id, name: me.username }, other.id);
      return { code: c.code, expires_in: challenges.secondsLeft(c) };
    },
  );

  app.get("/me/challenges", { schema: listChallengesSchema, preHandler: app.requireAuth }, async (req) =>
    challenges.incoming(req.account!.id).map((c) => ({ code: c.code, from: c.fromName, expires_in: challenges.secondsLeft(c) })),
  );

  app.delete<{ Params: { code: string } }>(
    "/me/challenges/:code",
    { schema: cancelChallengeSchema, preHandler: app.requireAuth },
    async (req, reply) => {
      // Un código que no existe o que no es mío no se distingue: no hay nada que anular y no se delata nada.
      challenges.cancel(req.params.code, req.account!.id);
      return reply.code(204).send();
    },
  );
}
