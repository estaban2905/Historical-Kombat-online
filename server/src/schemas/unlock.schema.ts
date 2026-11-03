import { errorSchema } from "./auth.schema.js";

const unlock = {
  type: "object",
  required: ["kind", "key"],
  additionalProperties: false,
  properties: {
    kind: { type: "string", enum: ["ending", "fighter", "cosmetic"] },
    key: { type: "string", pattern: "^[a-z0-9_]{1,40}$", description: "Final, luchador o cosmético concreto" },
  },
} as const;

const unlockList = { type: "array", items: unlock } as const;

export const getAchievementsSchema = {
  tags: ["unlocks"],
  summary: "Mis logros",
  description:
    "Se calculan al momento con mis duelos y mis desbloqueos: no se guardan, así que no hay nada que sincronizar. " +
    "El juego pone el nombre y la descripción de cada `key`.",
  security: [{ bearerAuth: [] }],
  response: {
    200: {
      type: "array",
      items: {
        type: "object",
        required: ["key", "progress", "goal", "done"],
        properties: {
          key: { type: "string" },
          progress: { type: "integer", description: "Lo que llevo (nunca más que la meta)" },
          goal: { type: "integer" },
          done: { type: "boolean" },
        },
      },
    },
    401: errorSchema,
  },
} as const;

export const getUnlocksSchema = {
  tags: ["unlocks"],
  summary: "Lo que he desbloqueado",
  security: [{ bearerAuth: [] }],
  response: { 200: unlockList, 401: errorSchema },
} as const;

export const putUnlocksSchema = {
  tags: ["unlocks"],
  summary: "Añadir desbloqueos",
  description: "Solo añade (desbloquear es para siempre) y lo repetido se ignora. Devuelve la lista completa.",
  security: [{ bearerAuth: [] }],
  body: {
    type: "object",
    required: ["items"],
    additionalProperties: false,
    properties: { items: { ...unlockList, maxItems: 200 } },
  },
  response: { 200: unlockList, 400: errorSchema, 401: errorSchema },
} as const;
