import type { FastifyInstance } from "fastify";
import { AppError } from "../errors.js";
import type { StorySave } from "../repositories/story.repository.js";
import { deleteStorySchema, getStorySchema, putStorySchema } from "../schemas/story.schema.js";

interface StoryBody {
  fighter: string;
  stage: number;
  continues: number;
  continues_used: number;
  difficulty: number;
  saved_at: number;
}

const toPublic = (s: StorySave) => ({
  fighter: s.fighter,
  stage: s.stage,
  continues: s.continues,
  continues_used: s.continuesUsed,
  difficulty: s.difficulty,
  saved_at: s.savedAt,
});

/** Partida guardada del modo Historia: una por cuenta. */
export async function storyRoutes(app: FastifyInstance): Promise<void> {
  const story = app.storySaves;

  app.get("/me/story", { schema: getStorySchema, preHandler: app.requireAuth }, async (req) => {
    const save = await story.get(req.account!.id);
    if (!save) throw new AppError(404, "no_story_save", "NO HAY PARTIDA GUARDADA");
    return toPublic(save);
  });

  app.put<{ Body: StoryBody }>("/me/story", { schema: putStorySchema, preHandler: app.requireAuth }, async (req) => {
    const b = req.body;
    await story.put(req.account!.id, {
      fighter: b.fighter,
      stage: b.stage,
      continues: b.continues,
      continuesUsed: b.continues_used,
      difficulty: b.difficulty,
      savedAt: b.saved_at,
    });
    // Lo que quedó guardado (si el cliente mandó uno viejo, es el que ya había).
    return toPublic((await story.get(req.account!.id))!);
  });

  app.delete("/me/story", { schema: deleteStorySchema, preHandler: app.requireAuth }, async (req, reply) => {
    await story.delete(req.account!.id);
    return reply.code(204).send();
  });
}
