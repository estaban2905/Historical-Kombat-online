import type { FastifyInstance } from "fastify";
import type { Unlock, UnlockKind } from "../repositories/unlock.repository.js";
import { getUnlocksSchema, putUnlocksSchema } from "../schemas/unlock.schema.js";

const toPublic = (list: Unlock[]) => list.map((u) => ({ kind: u.kind, key: u.key }));

/** Desbloqueos de la cuenta: se leen y solo se pueden añadir. */
export async function unlockRoutes(app: FastifyInstance): Promise<void> {
  const unlocks = app.unlocks;

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
