import type { FastifyInstance } from "fastify";
import type { Unlock, UnlockKind } from "../repositories/unlock.repository.js";
import { evaluateAchievements } from "../services/achievements.service.js";
import { getAchievementsSchema, getUnlocksSchema, putUnlocksSchema } from "../schemas/unlock.schema.js";

const toPublic = (list: Unlock[]) => list.map((u) => ({ kind: u.kind, key: u.key }));

/** Desbloqueos de la cuenta: se leen y solo se pueden añadir. */
export async function unlockRoutes(app: FastifyInstance): Promise<void> {
  const unlocks = app.unlocks;

  app.get("/me/achievements", { schema: getAchievementsSchema, preHandler: app.requireAuth }, async (req) => {
    const account = req.account!;
    const [results, mine] = await Promise.all([app.matchHistory.resultsOf(account.id), unlocks.list(account.id)]);
    return evaluateAchievements({
      wins: account.wins,
      losses: account.losses,
      results,
      endings: mine.filter((u) => u.kind === "ending").map((u) => u.key),
      fighterUnlocks: mine.filter((u) => u.kind === "fighter").length,
    });
  });

  app.get("/me/unlocks", { schema: getUnlocksSchema, preHandler: app.requireAuth }, async (req) =>
    toPublic(await unlocks.list(req.account!.id)),
  );

  app.put<{ Body: { items: { kind: UnlockKind; key: string }[] } }>(
    "/me/unlocks",
    { schema: putUnlocksSchema, preHandler: app.requireAuth },
    async (req) => {
      await unlocks.addMany(req.account!.id, req.body.items);
      return toPublic(await unlocks.list(req.account!.id));
    },
  );
}
