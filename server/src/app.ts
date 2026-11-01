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
import { systemRoutes } from "./routes/system.routes.js";
import { MatchService } from "./services/match.service.js";
import { MatchmakingService } from "./services/matchmaking.service.js";

export interface BuildOptions {
  config?: Partial<AppConfig>;
  matchmaking?: MatchmakingService;
  /** Base de datos ya migrada. Sin ella no hay cuentas: solo emparejamiento. */
  db?: Db;
}

/** Arma la aplicación: plugins, servicios y rutas. No abre ningún puerto. */
export async function buildApp(options: BuildOptions = {}): Promise<FastifyInstance> {
  const config: AppConfig = { ...loadConfig(), ...options.config };
  // Detrás del proxy de Railway: la IP real del cliente viene en X-Forwarded-For.
  const app = Fastify({ logger: config.logger, trustProxy: true });

  registerErrorHandler(app);
  // Con base de datos, los duelos entre cuentas se guardan (puntos, ranking e historial).
  const matches = options.db ? new MatchService(options.db) : undefined;
  const matchmaking =
    options.matchmaking ??
    new MatchmakingService(undefined, { settler: matches?.settle, onError: (err) => app.log.error(err) });
  registerServices(app, config, matchmaking, options.db !== undefined);

  await app.register(cors, { origin: config.allowedOrigins.length > 0 ? config.allowedOrigins : true });

  // Swagger va antes de las rutas para que las registre en la documentación.
  if (config.docsEnabled) await registerSwagger(app);
  await app.register(websocket, { options: { maxPayload: config.maxPayload } });

  await app.register(systemRoutes);
  await app.register(gameRoutes);
  if (options.db) {
    await app.register(rateLimit, { global: false });
    registerAuth(app, options.db);
    await app.register(authRoutes, { prefix: "/auth" });
    await app.register(profileRoutes);
  }
  return app;
}
