import type { FastifyInstance } from "fastify";
import { profileController } from "../controllers/profile.controller.js";
import { matchesSchema, meSchema, rankingSchema, updateMeSchema } from "../schemas/auth.schema.js";

export async function profileRoutes(app: FastifyInstance): Promise<void> {
  const c = profileController(app.accounts, app.matchHistory);
  app.get("/me", { schema: meSchema, preHandler: app.requireAuth }, async (req) => c.me(req));
  app.patch<{ Body: { avatar: string | null } }>(
    "/me",
    { schema: updateMeSchema, preHandler: app.requireAuth },
    async (req) => c.updateMe(req),
  );
  app.get<{ Querystring: { limit?: number } }>(
    "/me/matches",
    { schema: matchesSchema, preHandler: app.requireAuth },
    async (req) => c.myMatches(req),
  );
  app.get<{ Querystring: { limit?: number } }>("/leaderboard", { schema: rankingSchema }, async (req) => c.ranking(req));
}
