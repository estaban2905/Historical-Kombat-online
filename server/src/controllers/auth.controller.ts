import type { FastifyReply, FastifyRequest } from "fastify";
import type { AuthResult } from "../models/account.js";
import type { AuthService } from "../services/auth.service.js";
import { bearerToken } from "../plugins/auth.js";

export interface RegisterBody {
  email: string;
  password: string;
  username: string;
}
export interface LoginBody {
  email: string;
  password: string;
}
export interface GoogleBody {
  id_token: string;
  username?: string;
}
export interface RefreshBody {
  refresh_token: string;
}

/** Formato público de una sesión: snake_case, igual que el resto de APIs de login. */
function toResponse(r: AuthResult) {
  return {
    access_token: r.accessToken,
    refresh_token: r.refreshToken,
    expires_in: r.expiresIn,
    player: r.profile,
  };
}

export const authController = (auth: AuthService) => ({
  async register(req: FastifyRequest<{ Body: RegisterBody }>, reply: FastifyReply) {
    const { email, password, username } = req.body;
    return reply.status(201).send(toResponse(await auth.register(email, password, username)));
  },

  async login(req: FastifyRequest<{ Body: LoginBody }>) {
    return toResponse(await auth.login(req.body.email, req.body.password));
  },

  async google(req: FastifyRequest<{ Body: GoogleBody }>) {
    return toResponse(await auth.loginWithGoogle(req.body.id_token, req.body.username));
  },

  async refresh(req: FastifyRequest<{ Body: RefreshBody }>) {
    return toResponse(await auth.refresh(req.body.refresh_token));
  },

  async logout(req: FastifyRequest, reply: FastifyReply) {
    const token = bearerToken(req);
    if (token) await auth.logout(token);
    return reply.status(204).send();
  },
});
