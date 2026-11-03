import type { FastifyInstance } from "fastify";
import { AppError } from "../errors.js";
import type { StorySave } from "../repositories/story.repository.js";
import { deleteStorySchema, getStorySchema, listStoriesSchema, putStorySchema } from "../schemas/story.schema.js";

interface StoryBody {
  fighter: string;
  stage: number;
  continues: number;
  continues_used: number;
  difficulty: number;
  saved_at: number;
}

/** Tope de partidas por cuenta: el plantel es mucho menor, esto solo evita que se llene la tabla con ids inventados. */
const MAX_SAVES_PER_ACCOUNT = 64;

const toPublic = (s: StorySave) => ({
  fighter: s.fighter,
  stage: s.stage,
  continues: s.continues,
  continues_used: s.continuesUsed,
  difficulty: s.difficulty,
  saved_at: s.savedAt,
});

/** Partidas guardadas del modo Historia: una por cuenta y luchador. */
export async function storyRoutes(app: FastifyInstance): Promise<void> {
  const story = app.storySaves;

  // La más reciente (lo que leían los clientes de una sola partida).
  app.get("/me/story", { schema: getStorySchema, preHandler: app.requireAuth }, async (req) => {
    const save = await story.get(req.account!.id);
    if (!save) throw new AppError(404, "no_story_save", "NO HAY PARTIDA GUARDADA");
    return toPublic(save);
  });

  app.get("/me/stories", { schema: listStoriesSchema, preHandler: app.requireAuth }, async (req) =>
    (await story.list(req.account!.id)).map(toPublic),
  );

  app.put<{ Body: StoryBody }>("/me/story", { schema: putStorySchema, preHandler: app.requireAuth }, async (req) => {
    const b = req.body;
    const playerId = req.account!.id;
    if (!(await story.get(playerId, b.fighter)) && (await story.list(playerId)).length >= MAX_SAVES_PER_ACCOUNT) {
      throw new AppError(400, "too_many_story_saves", "DEMASIADAS PARTIDAS GUARDADAS");
    }
    await story.put(playerId, {
      fighter: b.fighter,
      stage: b.stage,
      continues: b.continues,
      continuesUsed: b.continues_used,
      difficulty: b.difficulty,
      savedAt: b.saved_at,
    });
    // Lo que quedó guardado de ese luchador (si el cliente mandó uno viejo, es el que ya había).
    return toPublic((await story.get(playerId, b.fighter))!);
  });

  app.delete<{ Querystring: { fighter?: string } }>(
    "/me/story",
    { schema: deleteStorySchema, preHandler: app.requireAuth },
    async (req, reply) => {
      await story.delete(req.account!.id, req.query.fighter);
      return reply.code(204).send();
    },
  );
}
