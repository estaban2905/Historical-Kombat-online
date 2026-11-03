import { errorSchema } from "./auth.schema.js";

const secured = { security: [{ bearerAuth: [] }] } as const;

export const currentSeasonSchema = {
  tags: ["seasons"],
  summary: "La temporada en curso",
  description: "Cada mes (UTC) es una temporada. Al terminar, los puntos se acercan a 1000 a la mitad.",
  response: {
    200: {
      type: "object",
      required: ["id", "ends_at"],
      properties: {
        id: { type: "string", description: "AAAA-MM" },
        ends_at: { type: "string", format: "date-time" },
      },
    },
  },
} as const;

export const mySeasonsSchema = {
  tags: ["seasons"],
  summary: "Cómo acabé cada temporada",
  description:
    "La más reciente primero. league es la liga máxima alcanzada (da el marco); rank, el puesto final entre " +
    "quienes jugaron ese mes.",
  ...secured,
  response: {
    200: {
      type: "array",
      items: {
        type: "object",
        required: ["season", "rank", "points", "peak_points", "league", "wins", "losses"],
        properties: {
          season: { type: "string" },
          rank: { type: "integer" },
          points: { type: "integer" },
          peak_points: { type: "integer" },
          league: { type: "string", enum: ["bronze", "silver", "gold", "diamond"] },
          wins: { type: "integer" },
          losses: { type: "integer" },
        },
      },
    },
    401: errorSchema,
  },
} as const;
