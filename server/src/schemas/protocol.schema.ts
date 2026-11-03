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
    name: { type: "string", maxLength: 16, examples: ["ANA"], description: "Se ignora: el nombre es el de la cuenta, o INVITADO" },
    room: {
      type: "string",
      pattern: "^[A-Z0-9]{6,12}$",
      description:
        "Código de un reto entre amigos (POST /me/challenges). Solo se empareja con quien entre con el mismo código; " +
        "pide `token` y el duelo es amistoso (no mueve puntos). Un reto que no es tuyo o caducó responde error `invalid_room`.",
    },
    token: {
      type: "string",
      maxLength: 200,
      description: "access_token de la cuenta. Sin él se juega de invitado, sin puntos. Un token no válido responde error `invalid_token`.",
    },
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
    f: {
      type: "integer",
      minimum: 0,
      description:
        "Número de frame del input. Estrictamente creciente por jugador y sin adelantarse más de 20 al último del rival; " +
        "si no, el servidor lo ignora.",
      examples: [120],
    },
    m: { type: "integer", minimum: 0, maximum: 65535, description: "Máscara de bits de botones", examples: [5] },
    a: {
      type: "integer",
      minimum: 0,
      description: "Acuse: último frame del rival recibido. El rival mide con él la latencia (opcional)",
      examples: [117],
    },
  },
  description: "Botones apretados en un frame. Se reenvía tal cual al rival.",
} as const;

const sync = {
  type: "object",
  required: ["t", "f", "c", "v"],
  properties: {
    t: { const: "sync" },
    f: { type: "integer", minimum: 0, description: "Tick de la pelea al que corresponde el resumen", examples: [600] },
    c: { type: "integer", description: "Resumen (hash) del estado de la pelea de este cliente en ese tick", examples: [123456789] },
    v: { type: "integer", minimum: 1, description: "Versión del resumen: solo se comparan resúmenes de la misma versión", examples: [1] },
  },
  description:
    "Comprobación de sincronía, cada 60 ticks. Si el rival manda un resumen distinto para el mismo tick, " +
    "el duelo se anula sin puntos y los dos reciben `desync`. Si una cuenta acumula 3 anulaciones en 24 h y más que su rival, " +
    "pierde por abandono.",
} as const;

const result = {
  type: "object",
  required: ["t", "winner", "p1Rounds", "p2Rounds"],
  properties: {
    t: { const: "result" },
    winner: { type: "integer", enum: [0, 1, 2], description: "1 = gana P1, 2 = gana P2, 0 = empate" },
    p1Rounds: { type: "integer", minimum: 0, maximum: 20 },
    p2Rounds: { type: "integer", minimum: 0, maximum: 20 },
  },
  description:
    "Resultado de la pelea según la simulación de este cliente. En un duelo entre cuentas, el servidor solo lo guarda si " +
    "el rival reporta exactamente lo mismo.",
} as const;

const settled = {
  type: "object",
  required: ["t", "ranked", "ok", "delta", "points", "wins", "losses"],
  properties: {
    t: { const: "settled" },
    ranked: { type: "boolean", description: "El duelo contaba para el ranking" },
    ok: { type: "boolean", description: "false = no se guardó" },
    delta: { type: "integer", description: "Puntos ganados (+) o perdidos (-)" },
    points: { type: "integer", description: "Mis puntos totales" },
    wins: { type: "integer" },
    losses: { type: "integer" },
    reason: { type: "string", description: "mismatch, timeout, too_short, error, o forfeit (ganó por abandono)" },
  },
  description: "El duelo terminó: así quedaron los puntos.",
} as const;

const queued = {
  type: "object",
  required: ["t"],
  properties: { t: { const: "queued" } },
  description: "Estás en la cola, esperando rival.",
} as const;

const matched = {
  type: "object",
  required: ["t", "side", "seed", "ranked", "opponent"],
  properties: {
    t: { const: "matched" },
    side: { type: "integer", enum: [1, 2], description: "1 = controlas a P1, 2 = a P2" },
    seed: { type: "integer", description: "Semilla común del azar para ambas simulaciones" },
    ranked: { type: "boolean", description: "Los dos son cuentas: el resultado cuenta para el ranking" },
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

const timeout = {
  type: "object",
  required: ["t", "loser"],
  properties: {
    t: { const: "timeout" },
    loser: { type: "integer", enum: [0, 1, 2], description: "El que dejó de responder (iba por detrás); 0 = no se sabe y el duelo se anula" },
  },
  description: "La pelea no avanzó durante un tiempo: el duelo se cierra. Pierde quien dejó de responder.",
} as const;

const desync = {
  type: "object",
  required: ["t"],
  properties: { t: { const: "desync" } },
  description: "Las dos peleas se separaron (resúmenes distintos para el mismo tick): el duelo se anula sin puntos.",
} as const;

const error = {
  type: "object",
  required: ["t", "msg"],
  properties: { t: { const: "error" }, msg: { type: "string" } },
  description: "El mensaje enviado no era válido o no corresponde en este estado.",
} as const;

export const clientMessages = { find, cancel, leave, input, sync, result } as const;
export const serverMessages = { queued, matched, input, settled, opponent_left: opponentLeft, timeout, desync, error } as const;

export const protocolSchema = {
  tags: ["protocol"],
  summary: "Catálogo de mensajes del WebSocket",
  description:
    "Conéctate a `ws(s)://<host>/ws` y envía/recibe mensajes JSON de una línea. " +
    "Flujo: `find` → `queued` → `matched` → intercambio de `input` → `result` → `settled`. " +
    "Si el rival se va: `opponent_left`. Si la pelea no avanza durante 15 s: `timeout`. Si las peleas se separan (`sync` distinto): `desync`.",
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
