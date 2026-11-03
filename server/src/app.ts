import Fastify, { type FastifyInstance } from "fastify";
import cors from "@fastify/cors";
import rateLimit from "@fastify/rate-limit";
import websocket from "@fastify/websocket";
import { loadConfig, type AppConfig } from "./config/env.js";
import type { Db } from "./db/db.js";
import { registerAuth } from "./plugins/auth.js";
import { registerErrorHandler } from "./plugins/errors.js";
import { registerServices } from "./plugins/services.js";
import { registerSwagger } from "./plugins/swagger.js";
import { authRoutes } from "./routes/auth.routes.js";
import { gameRoutes } from "./routes/game.routes.js";
import { profileRoutes } from "./routes/profile.routes.js";
import { challengeRoutes } from "./routes/challenge.routes.js";
import { friendRoutes } from "./routes/friend.routes.js";
import { storyRoutes } from "./routes/story.routes.js";
import { unlockRoutes } from "./routes/unlock.routes.js";
import { systemRoutes } from "./routes/system.routes.js";
import { MatchService } from "./services/match.service.js";
import { createGoogleVerifier, type GoogleVerifier } from "./services/google-verifier.js";
import { MatchmakingService } from "./services/matchmaking.service.js";

export interface BuildOptions {
  config?: Partial<AppConfig>;
  matchmaking?: MatchmakingService;
  /** Base de datos ya migrada. Sin ella no hay cuentas: solo emparejamiento. */
  db?: Db;
  /** Para pruebas: reemplaza la verificación real contra Google. */
  googleVerifier?: GoogleVerifier;
}

/** Arma la aplicación: plugins, servicios y rutas. No abre ningún puerto. */
export async function buildApp(options: BuildOptions = {}): Promise<FastifyInstance> {
  const config: AppConfig = { ...loadConfig(), ...options.config };
  // Detrás del proxy de Railway: la IP real del cliente viene en X-Forwarded-For. Solo se
  // confía en los saltos de nuestros proxies; con `true` el cliente podría inventarse su IP
  // y esquivar el límite de intentos.
  // (Es lo mismo que `trustProxy: <número>`, que los tipos de Fastify no admiten.)
  const app = Fastify({ logger: config.logger, trustProxy: (_addr, hop) => hop < config.trustProxyHops });

  registerErrorHandler(app);
  // Con base de datos, los duelos entre cuentas se guardan (puntos, ranking e historial).
  const matches = options.db ? new MatchService(options.db) : undefined;
  const matchmaking =
    options.matchmaking ??
    new MatchmakingService(undefined, { settler: matches?.settle, onError: (err) => app.log.error(err) });
  registerServices(app, config, matchmaking, options.db !== undefined);

  // Por defecto solo deja pasar GET, HEAD y POST: sin esto el navegador bloquea PATCH /me y PUT/DELETE /me/story.
  await app.register(cors, {
    origin: config.allowedOrigins.length > 0 ? config.allowedOrigins : true,
    methods: ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE"],
  });

  // Swagger va antes de las rutas para que las registre en la documentación.
  if (config.docsEnabled) await registerSwagger(app);
  await app.register(websocket, { options: { maxPayload: config.maxPayload } });

  await app.register(systemRoutes);
  await app.register(gameRoutes);
  if (options.db) {
    await app.register(rateLimit, { global: false });
    const googleVerifier =
      options.googleVerifier ?? (config.googleClientId ? createGoogleVerifier(config.googleClientId) : null);
    registerAuth(app, options.db, googleVerifier);
    await app.register(authRoutes, { prefix: "/auth" });
    await app.register(profileRoutes);
    await app.register(storyRoutes);
    await app.register(friendRoutes);
    await app.register(challengeRoutes);
    await app.register(unlockRoutes);
  }
  return app;
}
