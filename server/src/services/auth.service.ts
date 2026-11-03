import { AppError, DuplicateAccountError } from "../errors.js";
import { toProfile, type Account, type AuthResult } from "../models/account.js";
import type { AccountRepository } from "../repositories/account.repository.js";
import type { SessionRepository } from "../repositories/session.repository.js";
import { hashPassword, verifyPassword } from "./password.service.js";
import type { GoogleVerifier } from "./google-verifier.js";
import { generateToken, hashToken } from "./token.service.js";

export interface AuthOptions {
  accessTtlMs: number;
  refreshTtlMs: number;
}

const DEFAULTS: AuthOptions = {
  accessTtlMs: 60 * 60 * 1000, // 1 hora
  refreshTtlMs: 60 * 24 * 60 * 60 * 1000, // 60 días
};

const INVALID_CREDENTIALS = new AppError(401, "invalid_credentials", "EMAIL O CONTRASEÑA INCORRECTOS");
const USERNAME_REQUIRED = new AppError(409, "username_required", "ELIGE UN NOMBRE DE JUGADOR");
const GOOGLE_OFF = new AppError(503, "google_disabled", "GOOGLE NO ESTÁ DISPONIBLE");
const INVALID_GOOGLE = new AppError(401, "invalid_google_token", "NO SE PUDO VERIFICAR TU CUENTA DE GOOGLE");
const INVALID_TOKEN = new AppError(401, "invalid_token", "SESIÓN NO VÁLIDA");
/** Días que hay que esperar entre un cambio de nombre y el siguiente. */
export const USERNAME_COOLDOWN_DAYS = 7;

/** Registro, inicio de sesión y sesiones. No sabe nada de HTTP. */
export class AuthService {
  /** Contraseña falsa para gastar el mismo tiempo cuando el email no existe (no delata qué cuentas hay). */
  private dummyHash: Promise<string> | null = null;
  private readonly opts: AuthOptions;

  constructor(
    private readonly accounts: AccountRepository,
    private readonly sessions: SessionRepository,
    opts: Partial<AuthOptions> = {},
    /** Sin verificador, el inicio de sesión con Google está apagado. */
    private readonly googleVerifier: GoogleVerifier | null = null,
  ) {
    this.opts = { ...DEFAULTS, ...opts };
  }

  async register(email: string, password: string, username: string): Promise<AuthResult> {
    const passwordHash = await hashPassword(password);
    let account: Account;
    try {
      account = await this.accounts.create({ username, email: email.trim(), passwordHash });
    } catch (err) {
      if (err instanceof DuplicateAccountError) {
        throw err.field === "email"
          ? new AppError(409, "email_taken", "ESE EMAIL YA ESTÁ REGISTRADO")
          : new AppError(409, "username_taken", "ESE NOMBRE YA ESTÁ EN USO");
      }
      throw err;
    }
    return this.issue(account);
  }

  async login(email: string, password: string): Promise<AuthResult> {
    const account = await this.accounts.findByEmail(email.trim());
    if (!account) {
      this.dummyHash ??= hashPassword("contraseña-falsa");
      await verifyPassword(password, await this.dummyHash);
      throw INVALID_CREDENTIALS;
    }
    // Una cuenta de Google no tiene contraseña: no se puede entrar con una.
    if (account.passwordHash === null) {
      this.dummyHash ??= hashPassword("contraseña-falsa");
      await verifyPassword(password, await this.dummyHash);
      throw INVALID_CREDENTIALS;
    }
    if (!(await verifyPassword(password, account.passwordHash))) throw INVALID_CREDENTIALS;
    await this.sessions.deleteExpired(account.id);
    return this.issue(account);
  }

  /**
   * Entra con un ID token de Google. Si la cuenta no existe se crea, y para eso hace falta
   * `username` (si falta, 409 username_required y el juego lo pide). Si ya hay una cuenta con
   * ese email (verificado por Google), pasa a ser de Google: se borra su contraseña y se
   * cierran sus sesiones (ver AccountRepository.claimForGoogle).
   */
  async loginWithGoogle(idToken: string, username?: string): Promise<AuthResult> {
    if (!this.googleVerifier) throw GOOGLE_OFF;
    let who;
    try {
      who = await this.googleVerifier(idToken);
    } catch {
      throw INVALID_GOOGLE;
    }
    if (!who.emailVerified) throw INVALID_GOOGLE;

    const known = await this.accounts.findByGoogleSub(who.sub);
    if (known) {
      await this.sessions.deleteExpired(known.id);
      return this.issue(known);
    }
    const sameEmail = await this.accounts.findByEmail(who.email);
    if (sameEmail) {
      // "Google gana": el registro con email no lo verifica, así que quien lo registró pudo
      // no ser su dueño. Pierde la contraseña y las sesiones; la cuenta queda solo para Google.
      if (sameEmail.googleSub !== null || !(await this.accounts.claimForGoogle(sameEmail.id, who.sub))) {
        throw INVALID_GOOGLE; // ese email ya está enlazado a otra cuenta de Google
      }
      return this.issue({ ...sameEmail, googleSub: who.sub, passwordHash: null });
    }
    if (!username) throw USERNAME_REQUIRED;
    try {
      return await this.issue(await this.accounts.create({ username, email: who.email, googleSub: who.sub }));
    } catch (err) {
      if (err instanceof DuplicateAccountError) throw new AppError(409, "username_taken", "ESE NOMBRE YA ESTÁ EN USO");
      throw err;
    }
  }

  /** Cambia un refresh token por una sesión nueva. El refresh token viejo deja de servir. */
  async refresh(refreshToken: string): Promise<AuthResult> {
    const session = await this.sessions.findByRefreshHash(hashToken(refreshToken));
    if (!session) throw INVALID_TOKEN;
    const account = await this.accounts.findById(session.playerId);
    if (!account) throw INVALID_TOKEN;
    await this.sessions.delete(session.id);
    return this.issue(account);
  }

  async logout(accessToken: string): Promise<void> {
    await this.sessions.deleteByAccessHash(hashToken(accessToken));
  }

  /** Cambia el nombre de la cuenta (una vez cada USERNAME_COOLDOWN_DAYS días) y devuelve la cuenta ya actualizada. */
  async rename(account: Account, username: string): Promise<Account> {
    // Escribir el mismo nombre otra vez no cambia nada ni gasta la espera.
    if (username === account.username) return account;
    let changed: boolean;
    try {
      changed = await this.accounts.rename(account.id, username, USERNAME_COOLDOWN_DAYS);
    } catch (err) {
      if (err instanceof DuplicateAccountError) throw new AppError(409, "username_taken", "ESE NOMBRE YA ESTÁ EN USO");
      throw err;
    }
    if (!changed) {
      throw new AppError(429, "username_cooldown", `SOLO PUEDES CAMBIAR TU NOMBRE UNA VEZ CADA ${USERNAME_COOLDOWN_DAYS} DÍAS`);
    }
    return (await this.accounts.findById(account.id))!;
  }

  /**
   * Cambia la contraseña (pide la actual) y cierra las demás sesiones de la cuenta: quien la tuviera
   * abierta en otro equipo tendrá que entrar de nuevo. Las cuentas de Google no tienen contraseña.
   */
  async changePassword(account: Account, accessToken: string, current: string, next: string): Promise<void> {
    if (account.passwordHash === null) {
      throw new AppError(400, "no_password", "TU CUENTA ENTRA CON GOOGLE: NO TIENE CONTRASEÑA");
    }
    if (!(await verifyPassword(current, account.passwordHash))) {
      throw new AppError(403, "wrong_password", "LA CONTRASEÑA ACTUAL NO ES CORRECTA");
    }
    await this.accounts.setPasswordHash(account.id, await hashPassword(next));
    await this.sessions.deleteOthers(account.id, hashToken(accessToken));
  }

  /** La cuenta a la que pertenece un access token válido, o null. */
  async authenticate(accessToken: string): Promise<Account | null> {
    const session = await this.sessions.findByAccessHash(hashToken(accessToken));
    return session ? this.accounts.findById(session.playerId) : null;
  }

  private async issue(account: Account): Promise<AuthResult> {
    const accessToken = generateToken();
    const refreshToken = generateToken();
    const now = Date.now();
    await this.sessions.create({
      playerId: account.id,
      accessHash: hashToken(accessToken),
      refreshHash: hashToken(refreshToken),
      accessExpires: new Date(now + this.opts.accessTtlMs),
      refreshExpires: new Date(now + this.opts.refreshTtlMs),
    });
    return {
      accessToken,
      refreshToken,
      expiresIn: Math.floor(this.opts.accessTtlMs / 1000),
      profile: toProfile(account),
    };
  }
}
