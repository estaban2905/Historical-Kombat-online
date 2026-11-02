import type { FastifyInstance, FastifyRequest } from "fastify";
import {
  authController,
  type GoogleBody,
  type LoginBody,
  type RefreshBody,
  type RegisterBody,
} from "../controllers/auth.controller.js";
import { AppError } from "../errors.js";
import { googleSchema, loginSchema, logoutSchema, refreshSchema, registerSchema } from "../schemas/auth.schema.js";

const TOO_MANY_ATTEMPTS = new AppError(429, "rate_limited", "DEMASIADOS INTENTOS, ESPERA UN POCO");

/** Se registra con prefijo /auth. */
export async function authRoutes(app: FastifyInstance): Promise<void> {
  const c = authController(app.auth);
  // Freno a la fuerza bruta: pocos intentos por minuto y por IP.
  const rateLimit = { rateLimit: { max: app.appConfig.authRateLimitPerMinute, timeWindow: "1 minute" } };
  // Y por cuenta: frena también al que prueba contraseñas desde muchas IPs. Va aparte del
  // límite por IP (el plugin solo aplica uno por petición) y después de validar el body.
  const emailLimit = app.createRateLimit({
    max: app.appConfig.loginRateLimitPerEmail,
    timeWindow: 15 * 60 * 1000,
    keyGenerator: (req) => `login:${(req.body as LoginBody).email.trim().toLowerCase()}`,
  });
  const perEmail = async (req: FastifyRequest) => {
    const r = await emailLimit(req);
    // (`isAllowed` del plugin significa "está en la lista blanca", no "puede pasar".)
    if (!r.isAllowed && r.isExceeded) throw TOO_MANY_ATTEMPTS;
  };

  app.post<{ Body: RegisterBody }>("/register", { schema: registerSchema, config: rateLimit }, c.register);
  app.post<{ Body: LoginBody }>("/login", { schema: loginSchema, config: rateLimit, preHandler: perEmail }, c.login);
  app.post<{ Body: GoogleBody }>("/google", { schema: googleSchema, config: rateLimit }, c.google);
  app.post<{ Body: RefreshBody }>("/refresh", { schema: refreshSchema, config: rateLimit }, c.refresh);
  app.post("/logout", { schema: logoutSchema, preHandler: app.requireAuth }, c.logout);
}
