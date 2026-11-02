/** Esquemas JSON de las rutas de cuentas: validan lo que llega y alimentan Swagger. */

const email = {
  type: "string",
  minLength: 6,
  maxLength: 254,
  pattern: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$",
  examples: ["max@correo.com"],
} as const;

const password = { type: "string", minLength: 6, maxLength: 128 } as const;

const username = {
  type: "string",
  pattern: "^[A-Za-z0-9_]{3,16}$",
  description: "3 a 16 letras, números o _",
  examples: ["Max_29"],
} as const;

export const profileSchema = {
  type: "object",
  required: ["id", "username", "points", "wins", "losses"],
  properties: {
    id: { type: "string", format: "uuid" },
    username: { type: "string" },
    points: { type: "integer", examples: [1000] },
    wins: { type: "integer" },
    losses: { type: "integer" },
    avatar: { type: ["string", "null"], description: "Id del luchador elegido como retrato" },
  },
} as const;

export const errorSchema = {
  type: "object",
  required: ["error", "message"],
  properties: {
    error: { type: "string", description: "Código estable que el juego traduce", examples: ["invalid_credentials"] },
    message: { type: "string" },
  },
} as const;

const sessionResponse = {
  type: "object",
  required: ["access_token", "refresh_token", "expires_in", "player"],
  properties: {
    access_token: { type: "string", description: "Va en la cabecera `Authorization: Bearer ...`" },
    refresh_token: { type: "string", description: "Se cambia por una sesión nueva en /auth/refresh" },
    expires_in: { type: "integer", description: "Segundos de vida del access_token", examples: [3600] },
    player: profileSchema,
  },
} as const;

const errors = {
  400: errorSchema,
  401: errorSchema,
  409: errorSchema,
  429: errorSchema,
} as const;

export const registerSchema = {
  tags: ["auth"],
  summary: "Crear una cuenta",
  description: "Crea la cuenta (1000 puntos de inicio) y abre sesión.",
  body: {
    type: "object",
    required: ["email", "password", "username"],
    additionalProperties: false,
    properties: { email, password, username },
  },
  response: { 201: sessionResponse, 400: errors[400], 409: errors[409], 429: errors[429] },
} as const;

export const loginSchema = {
  tags: ["auth"],
  summary: "Iniciar sesión",
  body: {
    type: "object",
    required: ["email", "password"],
    additionalProperties: false,
    properties: { email, password },
  },
  response: { 200: sessionResponse, 400: errors[400], 401: errors[401], 429: errors[429] },
} as const;

export const googleSchema = {
  tags: ["auth"],
  summary: "Entrar con Google",
  description:
    "Recibe el ID token de Google Identity Services. Si el jugador es nuevo hace falta `username`; " +
    "sin él responde 409 `username_required`. Si ya había una cuenta con ese email, pasa a ser de Google: " +
    "se borra su contraseña y se cierran sus sesiones.",
  body: {
    type: "object",
    required: ["id_token"],
    additionalProperties: false,
    properties: { id_token: { type: "string", minLength: 20, maxLength: 4096 }, username },
  },
  response: { 200: sessionResponse, 400: errors[400], 401: errors[401], 409: errors[409], 429: errors[429], 503: errorSchema },
} as const;

export const refreshSchema = {
  tags: ["auth"],
  summary: "Renovar la sesión",
  description: "Cambia un refresh_token por tokens nuevos. El refresh_token usado deja de servir.",
  body: {
    type: "object",
    required: ["refresh_token"],
    additionalProperties: false,
    properties: { refresh_token: { type: "string", minLength: 10, maxLength: 200 } },
  },
  response: { 200: sessionResponse, 400: errors[400], 401: errors[401], 429: errors[429] },
} as const;

export const logoutSchema = {
  tags: ["auth"],
  summary: "Cerrar sesión",
  security: [{ bearerAuth: [] }],
  response: { 204: { type: "null" }, 401: errors[401] },
} as const;

export const meSchema = {
  tags: ["profile"],
  summary: "Mi perfil",
  security: [{ bearerAuth: [] }],
  response: { 200: profileSchema, 401: errors[401] },
} as const;

export const rankingSchema = {
  tags: ["profile"],
  summary: "Ranking de jugadores",
  description: "Más puntos primero; a igualdad, más victorias.",
  querystring: {
    type: "object",
    additionalProperties: false,
    properties: { limit: { type: "integer", minimum: 1, maximum: 100, default: 20 } },
  },
  response: {
    200: {
      type: "array",
      items: {
        type: "object",
        required: ["username", "points", "wins", "losses"],
        properties: {
          username: { type: "string" },
          points: { type: "integer" },
          wins: { type: "integer" },
          losses: { type: "integer" },
          avatar: { type: ["string", "null"] },
        },
      },
    },
  },
} as const;

export const updateMeSchema = {
  tags: ["profile"],
  summary: "Editar mi perfil",
  description: "Por ahora solo el avatar: el id de un luchador, o null para quitarlo.",
  security: [{ bearerAuth: [] }],
  body: {
    type: "object",
    required: ["avatar"],
    additionalProperties: false,
    properties: { avatar: { type: ["string", "null"], pattern: "^[a-z0-9_]{1,40}$" } },
  },
  response: { 200: profileSchema, 400: errors[400], 401: errors[401] },
} as const;

export const matchesSchema = {
  tags: ["profile"],
  summary: "Mis últimos duelos",
  security: [{ bearerAuth: [] }],
  querystring: {
    type: "object",
    additionalProperties: false,
    properties: { limit: { type: "integer", minimum: 1, maximum: 50, default: 20 } },
  },
  response: {
    200: {
      type: "array",
      items: {
        type: "object",
        required: ["id", "played_at", "opponent", "my_fighter", "opponent_fighter", "result", "delta", "my_rounds", "opponent_rounds", "reason"],
        properties: {
          id: { type: "string", format: "uuid" },
          played_at: { type: "string", format: "date-time" },
          opponent: { type: "string" },
          my_fighter: { type: "string" },
          opponent_fighter: { type: "string" },
          result: { type: "string", enum: ["win", "loss", "draw"] },
          delta: { type: "integer", description: "Puntos ganados o perdidos" },
          my_rounds: { type: "integer" },
          opponent_rounds: { type: "integer" },
          reason: { type: "string", enum: ["normal", "forfeit"], description: "forfeit = terminó por abandono" },
        },
      },
    },
    401: errorSchema,
  },
} as const;
