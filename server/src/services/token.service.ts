import { createHash, randomBytes } from "node:crypto";

/** Token aleatorio de 256 bits, apto para ir en una cabecera o en JSON. */
export function generateToken(): string {
  return randomBytes(32).toString("base64url");
}

/** Lo único que se guarda en la base de datos: un token no se puede recuperar de su hash. */
export function hashToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}
