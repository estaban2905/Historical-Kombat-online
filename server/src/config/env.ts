/** Toda la configuración sale de variables de entorno, con valores por defecto sensatos. */
export interface AppConfig {
  port: number;
  /** Publica Swagger UI en /docs. */
  docsEnabled: boolean;
  /** Tamaño máximo de un mensaje WebSocket, en bytes. */
  maxPayload: number;
  /** Mensajes por segundo permitidos por socket (a 60 fps, un input por frame son 60). */
  maxMessagesPerSecond: number;
  /** Cada cuánto se hace ping para detectar conexiones muertas. */
  heartbeatMs: number;
  /** Silencio de inputs en una pelea (de los dos) tras el que se cierra el duelo y pierde quien iba por detrás. */
  stallTimeoutMs: number;
  /** Postgres (en Railway: ${{Postgres.DATABASE_URL}}). Sin él no hay cuentas, solo emparejamiento. */
  databaseUrl: string;
  /** Orígenes que pueden llamar a la API desde un navegador (la web del juego). Vacío = cualquiera. */
  allowedOrigins: string[];
  /** Client ID de Google (OAuth, tipo web). Vacío = el inicio de sesión con Google está apagado. */
  googleClientId: string;
  /** Intentos de registro/login por minuto y por IP. */
  authRateLimitPerMinute: number;
  /** Intentos de login cada 15 minutos para un mismo email, vengan de la IP que vengan. */
  loginRateLimitPerEmail: number;
  /**
   * Proxies delante del servidor (Railway: 1). La IP del cliente se toma de X-Forwarded-For
   * saltando solo esos proxies: lo que el cliente escriba antes en la cabecera no cuenta.
   */
  trustProxyHops: number;
  logger: boolean;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): AppConfig {
  return {
    port: toInt(env["PORT"], 8787),
    docsEnabled: env["DOCS_ENABLED"] !== "false",
    maxPayload: toInt(env["MAX_PAYLOAD"], 1024),
    maxMessagesPerSecond: toInt(env["MAX_MESSAGES_PER_SECOND"], 120),
    heartbeatMs: toInt(env["HEARTBEAT_MS"], 15_000),
    stallTimeoutMs: toInt(env["STALL_TIMEOUT_MS"], 15_000),
    databaseUrl: env["DATABASE_URL"] ?? "",
    allowedOrigins: (env["ALLOWED_ORIGINS"] ?? "")
      .split(",")
      .map((o) => o.trim())
      .filter((o) => o !== ""),
    googleClientId: (env["GOOGLE_CLIENT_ID"] ?? "").trim(),
    authRateLimitPerMinute: toInt(env["AUTH_RATE_LIMIT_PER_MINUTE"], 10),
    loginRateLimitPerEmail: toInt(env["LOGIN_RATE_LIMIT_PER_EMAIL"], 10),
    trustProxyHops: toInt(env["TRUST_PROXY_HOPS"], 1),
    logger: env["LOG"] !== "false",
  };
}

function toInt(value: string | undefined, fallback: number): number {
  const n = Number.parseInt(value ?? "", 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}
