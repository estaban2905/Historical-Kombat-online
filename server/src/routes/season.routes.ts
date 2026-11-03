import type { FastifyInstance } from "fastify";
import { currentSeasonSchema, mySeasonsSchema } from "../schemas/season.schema.js";

/** Temporadas: la que está en curso y cómo acabé cada una. */
export async function seasonRoutes(app: FastifyInstance): Promise<void> {
  app.get("/season", { schema: currentSeasonSchema }, async () => {
    const s = app.seasons.current();
    return { id: s.id, ends_at: s.endsAt.toISOString() };
  });

  app.get("/me/seasons", { schema: mySeasonsSchema, preHandler: app.requireAuth }, async (req) =>
    (await app.seasons.history(req.account!.id)).map((r) => ({
      season: r.season,
      rank: r.rank,
      points: r.points,
      peak_points: r.peakPoints,
      league: r.league,
      wins: r.wins,
      losses: r.losses,
    })),
  );
}
