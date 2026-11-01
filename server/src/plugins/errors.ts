import type { FastifyError, FastifyInstance } from "fastify";
import { AppError } from "../errors.js";

/**
 * Todas las respuestas de error tienen la misma forma, {error, message}, y el
 * juego se guía por `error` (un código estable). Nunca se filtra un error interno.
 */
export function registerErrorHandler(app: FastifyInstance): void {
  app.setErrorHandler((error: FastifyError, request, reply) => {
    if (error instanceof AppError) {
      return reply.status(error.status).send({ error: error.code, message: error.message });
    }
    if (error.validation) {
      return reply.status(400).send({ error: "invalid_request", message: "DATOS NO VÁLIDOS" });
    }
    const status = error.statusCode ?? 500;
    if (status === 429) {
      return reply.status(429).send({ error: "rate_limited", message: "DEMASIADOS INTENTOS, ESPERA UN POCO" });
    }
    if (status < 500) {
      return reply.status(status).send({ error: "bad_request", message: "PETICIÓN NO VÁLIDA" });
    }
    request.log.error(error);
    return reply.status(500).send({ error: "internal", message: "ERROR DEL SERVIDOR" });
  });
}
