import { errorSchema } from "./auth.schema.js";

const storySave = {
  type: "object",
  required: ["fighter", "stage", "continues", "continues_used", "difficulty", "saved_at"],
  additionalProperties: false,
  properties: {
    fighter: { type: "string", pattern: "^[a-z0-9_]{1,64}$", description: "Id del luchador del jugador" },
    stage: { type: "integer", minimum: 0, maximum: 200, description: "Combate actual (desde 0)" },
    continues: { type: "integer", minimum: 0, maximum: 20, description: "Revanchas que quedan en la época" },
    continues_used: { type: "integer", minimum: 0, maximum: 10000, description: "Revanchas gastadas en toda la partida" },
    difficulty: { type: "integer", minimum: 0, maximum: 20 },
    saved_at: { type: "integer", minimum: 0, description: "Segundos Unix del guardado" },
  },
} as const;

const errors = { 401: errorSchema, 404: errorSchema } as const;

export const getStorySchema = {
  tags: ["story"],
  summary: "Mi partida guardada del modo Historia",
  security: [{ bearerAuth: [] }],
  response: { 200: storySave, 401: errors[401], 404: errors[404] },
} as const;

export const putStorySchema = {
  tags: ["story"],
  summary: "Guardar mi partida del modo Historia",
  description: "Reemplaza la partida de la cuenta. Un guardado más antiguo que el existente se ignora.",
  security: [{ bearerAuth: [] }],
  body: storySave,
  response: { 200: storySave, 400: errorSchema, 401: errors[401] },
} as const;

export const deleteStorySchema = {
  tags: ["story"],
  summary: "Borrar mi partida del modo Historia",
  security: [{ bearerAuth: [] }],
  response: { 204: { type: "null" }, 401: errors[401] },
} as const;
