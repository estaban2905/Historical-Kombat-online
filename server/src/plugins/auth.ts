import type { FastifyInstance, FastifyRequest } from "fastify";
import type { Db } from "../db/db.js";
import { AppError } from "../errors.js";
import type { Account } from "../models/account.js";
import { AccountRepository } from "../repositories/account.repository.js";
import { MatchRepository } from "../repositories/match.repository.js";
import { SessionRepository } from "../repositories/session.repository.js";
import { AuthService } from "../services/auth.service.js";
import type { GoogleVerifier } from "../services/google-verifier.js";

declare module "fastify" {
  interface FastifyInstance {
    auth: AuthService;
    accounts: AccountRepository;
    matchHistory: MatchRepository;
    /** preHandler: exige `Authorization: Bearer <token>` válido y deja la cuenta en request.account. */
    requireAuth: (req: FastifyRequest) => Promise<void>;
  }
  interface FastifyRequest {
    account: Account | null;
  }
}

/** El token de la cabecera `Authorization: Bearer ...`, o null. */
export function bearerToken(req: FastifyRequest): string | null {
  const header = req.headers.authorization;
  if (!header?.startsWith("Bearer ")) return null;
  return header.slice(7).trim() || null;
}

/** Crea el servicio de cuentas sobre la base de datos y lo deja en app.auth / app.accounts. */
export function registerAuth(app: FastifyInstance, db: Db, googleVerifier: GoogleVerifier | null = null): void {
  const accounts = new AccountRepository(db);
  const auth = new AuthService(accounts, new SessionRepository(db), {}, googleVerifier);
  app.decorate("accounts", accounts);
  app.decorate("matchHistory", new MatchRepository(db));
  app.decorate("auth", auth);
  app.decorateRequest("account", null);
  app.decorate("requireAuth", async (req: FastifyRequest) => {
    const token = bearerToken(req);
    const account = token ? await auth.authenticate(token) : null;
    if (!account) throw new AppError(401, "invalid_token", "SESIÓN NO VÁLIDA");
    req.account = account;
  });
}
