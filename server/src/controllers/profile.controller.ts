import type { FastifyRequest } from "fastify";
import { toProfile } from "../models/account.js";
import type { AccountRepository } from "../repositories/account.repository.js";

export const profileController = (accounts: AccountRepository) => ({
  /** requireAuth ya dejó la cuenta en la petición. */
  me(req: FastifyRequest) {
    return toProfile(req.account!);
  },

  ranking(req: FastifyRequest<{ Querystring: { limit?: number } }>) {
    return accounts.ranking(req.query.limit ?? 20);
  },
});
