import type { FastifyInstance } from "fastify";
import { profileController } from "../controllers/profile.controller.js";
import { meSchema, rankingSchema } from "../schemas/auth.schema.js";

export async function profileRoutes(app: FastifyInstance): Promise<void> {
  const c = profileController(app.accounts);
  app.get("/me", { schema: meSchema, preHandler: app.requireAuth }, async (req) => c.me(req));
  app.get<{ Querystring: { limit?: number } }>("/leaderboard", { schema: rankingSchema }, async (req) => c.ranking(req));
}
