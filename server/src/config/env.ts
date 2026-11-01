/** Toda la configuración sale de variables de entorno, con valores por defecto sensatos. */
export interface AppConfig {
  port: number;
  /** Carpeta con el juego exportado a Web; si no existe, solo se sirve el online. */
  staticDir: string;
  /** Publica Swagger UI en /docs. */
  docsEnabled: boolean;
  /** Tamaño máximo de un mensaje WebSocket, en bytes. */
  maxPayload: number;
  /** Mensajes por segundo permitidos por socket (a 60 fps, un input por frame son 60). */
  maxMessagesPerSecond: number;
  /** Cada cuánto se hace ping para detectar conexiones muertas. */
  heartbeatMs: number;
  logger: boolean;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return {
    port: toInt(env["PORT"], 8787),
    staticDir: env["STATIC_DIR"] ?? "public",
    docsEnabled: env["DOCS_ENABLED"] !== "false",
    maxPayload: toInt(env["MAX_PAYLOAD"], 1024),
    maxMessagesPerSecond: toInt(env["MAX_MESSAGES_PER_SECOND"], 120),
    heartbeatMs: toInt(env["HEARTBEAT_MS"], 15_000),
    logger: env["LOG"] !== "false",
  };
}

function toInt(value: string | undefined, fallback: number): number {
  const n = Number.parseInt(value ?? "", 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}
