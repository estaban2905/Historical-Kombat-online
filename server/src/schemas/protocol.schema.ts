/**
 * Descripción JSON Schema de los mensajes del WebSocket (/ws).
 * OpenAPI no sabe describir WebSockets, así que este catálogo se publica
 * en GET /protocol y aparece en Swagger.
 */
const find = {
  type: "object",
  required: ["t", "fighter"],
  properties: {
    t: { const: "find" },
    fighter: { type: "string", pattern: "^[a-z0-9_]+$", maxLength: 40, examples: ["napoleon"] },
    name: { type: "string", maxLength: 16, examples: ["ANA"] },
  },
  description: "Entrar a la cola de emparejamiento con el luchador elegido.",
} as const;

const cancel = {
  type: "object",
  required: ["t"],
  properties: { t: { const: "cancel" } },
  description: "Salir de la cola antes de encontrar rival.",
} as const;

const leave = {
  type: "object",
  required: ["t"],
  properties: { t: { const: "leave" } },
  description: "Abandonar la partida en curso.",
} as const;

const input = {
  type: "object",
  required: ["t", "f", "m"],
  properties: {
    t: { const: "input" },
    f: { type: "integer", minimum: 0, description: "Número de frame del input", examples: [120] },
    m: { type: "integer", minimum: 0, maximum: 65535, description: "Máscara de bits de botones", examples: [5] },
  },
  description: "Botones apretados en un frame. Se reenvía tal cual al rival.",
} as const;

const queued = {
  type: "object",
  required: ["t"],
  properties: { t: { const: "queued" } },
  description: "Estás en la cola, esperando rival.",
} as const;

const matched = {
  type: "object",
  required: ["t", "side", "seed", "opponent"],
  properties: {
    t: { const: "matched" },
    side: { type: "integer", enum: [1, 2], description: "1 = controlas a P1, 2 = a P2" },
    seed: { type: "integer", description: "Semilla común del azar para ambas simulaciones" },
    opponent: {
      type: "object",
      required: ["fighter", "name"],
      properties: { fighter: { type: "string" }, name: { type: "string" } },
    },
  },
  description: "Se encontró rival: empieza la partida.",
} as const;

const opponentLeft = {
  type: "object",
  required: ["t"],
  properties: { t: { const: "opponent_left" } },
  description: "El rival se desconectó.",
} as const;

const error = {
  type: "object",
  required: ["t", "msg"],
  properties: { t: { const: "error" }, msg: { type: "string" } },
  description: "El mensaje enviado no era válido o no corresponde en este estado.",
} as const;

export const clientMessages = { find, cancel, leave, input } as const;
export const serverMessages = { queued, matched, input, opponent_left: opponentLeft, error } as const;

export const protocolSchema = {
  tags: ["protocol"],
  summary: "Catálogo de mensajes del WebSocket",
  description:
    "Conéctate a `ws(s)://<host>/ws` y envía/recibe mensajes JSON de una línea. " +
    "Flujo: `find` → `queued` → `matched` → intercambio de `input` → `opponent_left` o `leave`.",
  response: {
    200: {
      type: "object",
      required: ["endpoint", "client", "server"],
      properties: {
        endpoint: { type: "string", examples: ["/ws"] },
        client: { type: "object", description: "Mensajes que envía el juego", additionalProperties: true },
        server: { type: "object", description: "Mensajes que envía el servidor", additionalProperties: true },
      },
    },
  },
} as const;
