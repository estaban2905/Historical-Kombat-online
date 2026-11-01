import type { FastifyInstance } from "fastify";
import type { AppConfig } from "../config/env.js";
import { MatchmakingService } from "../services/matchmaking.service.js";

declare module "fastify" {
  interface FastifyInstance {
    matchmaking: MatchmakingService;
    appConfig: AppConfig;
    /** true si hay base de datos conectada (cuentas disponibles). */
    hasDb: boolean;
  }
}

/** Crea los servicios una sola vez y los deja disponibles como app.matchmaking / app.appConfig. */
export function registerServices(
  app: FastifyInstance,
  config: AppConfig,
  matchmaking: MatchmakingService = new MatchmakingService(),
  hasDb = false,
): void {
  app.decorate("appConfig", config);
  app.decorate("matchmaking", matchmaking);
  app.decorate("hasDb", hasDb);
}
