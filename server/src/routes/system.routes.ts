import type { FastifyInstance } from "fastify";
import { getHealth } from "../controllers/health.controller.js";
import { getProtocol } from "../controllers/protocol.controller.js";
import { healthSchema } from "../schemas/health.schema.js";
import { protocolSchema } from "../schemas/protocol.schema.js";

export async function systemRoutes(app: FastifyInstance): Promise<void> {
  app.get("/health", { schema: healthSchema }, async () => getHealth(app.matchmaking, app.hasDb));
  app.get("/protocol", { schema: protocolSchema }, async () => getProtocol());
}
