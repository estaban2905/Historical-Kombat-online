import Fastify, { type FastifyInstance } from "fastify";
import websocket from "@fastify/websocket";
import { loadConfig, type AppConfig } from "./config/env.js";
import { registerServices } from "./plugins/services.js";
import { registerStatic } from "./plugins/static.js";
import { registerSwagger } from "./plugins/swagger.js";
import { gameRoutes } from "./routes/game.routes.js";
import { systemRoutes } from "./routes/system.routes.js";
import type { MatchmakingService } from "./services/matchmaking.service.js";

export interface BuildOptions {
  config?: Partial<AppConfig>;
  matchmaking?: MatchmakingService;
}

/** Arma la aplicación: plugins, servicios y rutas. No abre ningún puerto. */
export async function buildApp(options: BuildOptions = {}): Promise<FastifyInstance> {
  const config: AppConfig = { ...loadConfig(), ...options.config };
  const app = Fastify({ logger: config.logger });

  registerServices(app, config, options.matchmaking);

  // Swagger va antes de las rutas para que las registre en la documentación.
  if (config.docsEnabled) await registerSwagger(app);
  await app.register(websocket, { options: { maxPayload: config.maxPayload } });

  await app.register(systemRoutes);
  await app.register(gameRoutes);
  // Al final: así /docs, /health, /protocol y /ws tienen prioridad sobre los archivos.
  if (await registerStatic(app, config.staticDir)) app.log.info("sirviendo el juego web desde %s", config.staticDir);
  return app;
}
