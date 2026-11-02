import type { FastifyInstance } from "fastify";
import {
  authController,
  type GoogleBody,
  type LoginBody,
  type RefreshBody,
  type RegisterBody,
} from "../controllers/auth.controller.js";
import { googleSchema, loginSchema, logoutSchema, refreshSchema, registerSchema } from "../schemas/auth.schema.js";

/** Se registra con prefijo /auth. */
export async function authRoutes(app: FastifyInstance): Promise<void> {
  const c = authController(app.auth);
  // Freno a la fuerza bruta: pocos intentos por minuto y por IP.
  const rateLimit = { rateLimit: { max: app.appConfig.authRateLimitPerMinute, timeWindow: "1 minute" } };

  app.post<{ Body: RegisterBody }>("/register", { schema: registerSchema, config: rateLimit }, c.register);
  app.post<{ Body: LoginBody }>("/login", { schema: loginSchema, config: rateLimit }, c.login);
  app.post<{ Body: GoogleBody }>("/google", { schema: googleSchema, config: rateLimit }, c.google);
  app.post<{ Body: RefreshBody }>("/refresh", { schema: refreshSchema, config: rateLimit }, c.refresh);
  app.post("/logout", { schema: logoutSchema, preHandler: app.requireAuth }, c.logout);
}
