import type { FastifyInstance } from "fastify";
import { handleGameSocket } from "../controllers/game.controller.js";

export async function gameRoutes(app: FastifyInstance): Promise<void> {
  app.get("/ws", { websocket: true, schema: { hide: true } }, (socket) => {
    const authenticate = app.hasDb ? (token: string) => app.auth.authenticate(token) : undefined;
    handleGameSocket(socket, app.matchmaking, app.appConfig, authenticate, (err) => app.log.error(err), app.hasDb ? app.challenges : undefined);
  });
}
