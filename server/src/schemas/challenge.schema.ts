import { MAX_WAIT_S } from "../services/challenge.service.js";
import { errorSchema } from "./auth.schema.js";

const secured = { security: [{ bearerAuth: [] }] } as const;
const code = { type: "string", pattern: "^[A-Z0-9]{6,12}$" } as const;

export const createChallengeSchema = {
  tags: ["friends"],
  summary: "Retar a un amigo",
  description:
    "Abre una sala privada de 2 minutos. Quien reta entra con `find` y `room: code`; el amigo ve el reto en GET /me/challenges " +
    "y entra con el mismo código. Un reto nuevo cancela el anterior. Los duelos de un reto no mueven puntos. " +
    "403 `not_friends` si no son amigos, 404 `player_not_found`, 400 `cannot_challenge_self`.",
  ...secured,
  body: {
    type: "object",
    required: ["to"],
    additionalProperties: false,
    properties: { to: { type: "string", pattern: "^[A-Za-z0-9_]{3,16}$" } },
  },
  response: {
    200: {
      type: "object",
      required: ["code", "expires_in"],
      properties: { code, expires_in: { type: "integer", description: "Segundos de vida" } },
    },
    400: errorSchema,
    401: errorSchema,
    403: errorSchema,
    404: errorSchema,
  },
} as const;

export const listChallengesSchema = {
  tags: ["friends"],
  summary: "Retos que me han hecho",
  description:
    "Con wait=N (1-25 s), si no hay ninguno la respuesta espera hasta N segundos y llega en cuanto alguien me reta " +
    "(espera larga, para avisar al momento).",
  ...secured,
  querystring: {
    type: "object",
    additionalProperties: false,
    properties: { wait: { type: "integer", minimum: 0, maximum: MAX_WAIT_S } },
  },
  response: {
    200: {
      type: "array",
      items: {
        type: "object",
        required: ["code", "from", "expires_in"],
        properties: { code, from: { type: "string" }, expires_in: { type: "integer" } },
      },
    },
    401: errorSchema,
  },
} as const;

export const cancelChallengeSchema = {
  tags: ["friends"],
  summary: "Cancelar o rechazar un reto",
  ...secured,
  params: { type: "object", required: ["code"], properties: { code } },
  response: { 204: { type: "null" }, 400: errorSchema, 401: errorSchema },
} as const;
