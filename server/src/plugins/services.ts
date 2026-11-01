import type { FastifyInstance } from "fastify";
import type { AppConfig } from "../config/env.js";
import { MatchmakingService } from "../services/matchmaking.service.js";

declare module "fastify" {
  interface FastifyInstance {
    matchmaking: MatchmakingService;
    appConfig: AppConfig;
  }
}

/** Crea los servicios una sola vez y los deja disponibles como app.matchmaking / app.appConfig. */
export function registerServices(
  app: FastifyInstance,
  config: AppConfig,
  matchmaking: MatchmakingService = new MatchmakingService(),
): void {
  app.decorate("appConfig", config);
  app.decorate("matchmaking", matchmaking);
}
