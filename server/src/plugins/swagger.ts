import type { FastifyInstance } from "fastify";
import swagger from "@fastify/swagger";
import swaggerUi from "@fastify/swagger-ui";

/** Documentación OpenAPI: JSON en /docs/json y la interfaz en /docs. */
export async function registerSwagger(app: FastifyInstance): Promise<void> {
  await app.register(swagger, {
    openapi: {
      info: {
        title: "History Combat · Servidor online",
        description:
          "Empareja jugadores y reenvía sus inputs para el duelo online.\n\n" +
          "El combate en tiempo real va por **WebSocket** en `/ws`; OpenAPI no puede describirlo, " +
          "por eso los mensajes están en `GET /protocol`.",
        version: "0.1.0",
      },
      tags: [
        { name: "system", description: "Estado del servidor" },
        { name: "protocol", description: "Mensajes del WebSocket" },
      ],
    },
  });
  await app.register(swaggerUi, { routePrefix: "/docs" });
}
