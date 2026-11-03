import type { FastifyInstance } from "fastify";
import { profileController, type RankingQuery, type UpdateMeBody } from "../controllers/profile.controller.js";
import { changePasswordSchema, matchesSchema, meSchema, publicProfileSchema, rankingSchema, updateMeSchema } from "../schemas/auth.schema.js";

export async function profileRoutes(app: FastifyInstance): Promise<void> {
  const c = profileController(app.accounts, app.matchHistory, app.auth, app.unlocks);
  // Probar contraseñas a ciegas: el mismo freno por IP que el inicio de sesión.
  const rateLimit = { rateLimit: { max: app.appConfig.authRateLimitPerMinute, timeWindow: "1 minute" } };
  app.get("/me", { schema: meSchema, preHandler: app.requireAuth }, async (req) => c.me(req));
  app.patch<{ Body: UpdateMeBody }>(
    "/me",
    { schema: updateMeSchema, preHandler: app.requireAuth },
    async (req) => c.updateMe(req),
  );
  app.post<{ Body: { current_password: string; new_password: string } }>(
    "/me/password",
    { schema: changePasswordSchema, config: rateLimit, preHandler: app.requireAuth },
    async (req, reply) => {
      await c.changePassword(req);
      return reply.code(204).send();
    },
  );
  app.get<{ Querystring: { limit?: number } }>(
    "/me/matches",
    { schema: matchesSchema, preHandler: app.requireAuth },
    async (req) => c.myMatches(req),
  );
  app.get<{ Params: { username: string } }>("/players/:username", { schema: publicProfileSchema }, async (req) => c.publicProfile(req));
  app.get<{ Querystring: RankingQuery }>("/leaderboard", { schema: rankingSchema }, async (req) => c.ranking(req));
}
