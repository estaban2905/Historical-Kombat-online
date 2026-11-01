import type { FastifyInstance } from "fastify";
import { handleGameSocket } from "../controllers/game.controller.js";

export async function gameRoutes(app: FastifyInstance): Promise<void> {
  app.get("/ws", { websocket: true, schema: { hide: true } }, (socket) => {
    handleGameSocket(socket, app.matchmaking, app.appConfig);
  });
}
