import { errorSchema, rankingQuerySchema } from "./auth.schema.js";

const username = { type: "string", pattern: "^[A-Za-z0-9_]{3,16}$" } as const;

const friend = {
  type: "object",
  required: ["username", "points", "status"],
  properties: {
    username: { type: "string" },
    avatar: { type: ["string", "null"] },
    points: { type: "integer" },
    status: {
      type: "string",
      enum: ["friend", "incoming", "outgoing"],
      description: "friend = amigos; incoming = me pidió amistad; outgoing = se la pedí yo",
    },
  },
} as const;

const secured = { security: [{ bearerAuth: [] }] } as const;

export const listFriendsSchema = {
  tags: ["friends"],
  summary: "Mis amigos y solicitudes",
  ...secured,
  response: { 200: { type: "array", items: friend }, 401: errorSchema },
} as const;

export const requestFriendSchema = {
  tags: ["friends"],
  summary: "Pedir amistad",
  description:
    "Si esa persona ya me la había pedido, quedan como amigos. Repetir la petición no hace nada. " +
    "404 `player_not_found`, 400 `cannot_friend_self`, 409 `friend_limit` (máx. 100 entre amigos y solicitudes enviadas).",
  ...secured,
  body: { type: "object", required: ["username"], additionalProperties: false, properties: { username } },
  response: {
    200: {
      type: "object",
      required: ["result"],
      properties: { result: { type: "string", enum: ["requested", "accepted", "already_friends", "already_requested"] } },
    },
    400: errorSchema,
    401: errorSchema,
    404: errorSchema,
    409: errorSchema,
  },
} as const;

export const removeFriendSchema = {
  tags: ["friends"],
  summary: "Quitar amigo, cancelar o rechazar una solicitud",
  ...secured,
  params: { type: "object", required: ["username"], properties: { username } },
  response: { 204: { type: "null" }, 400: errorSchema, 401: errorSchema },
} as const;

export const friendsRankingSchema = {
  tags: ["friends"],
  summary: "Ranking entre mis amigos y yo",
  description: "Con los mismos filtros que /leaderboard (period, fighter).",
  ...secured,
  querystring: rankingQuerySchema,
  response: {
    200: {
      type: "array",
      items: {
        type: "object",
        required: ["username", "points", "wins", "losses", "streak"],
        properties: {
          username: { type: "string" },
          points: { type: "integer" },
          wins: { type: "integer" },
          losses: { type: "integer" },
          gained: { type: "integer" },
          avatar: { type: ["string", "null"] },
          favorite_fighter: { type: ["string", "null"] },
          streak: { type: "integer" },
        },
      },
    },
    401: errorSchema,
  },
} as const;
