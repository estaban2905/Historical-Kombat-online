import { randomBytes } from "node:crypto";

/** Un reto de un jugador a un amigo: abre una sala privada a la que solo entran esos dos. */
export interface Challenge {
  code: string;
  fromId: string;
  fromName: string;
  toId: string;
  expiresAt: number;
  /** Quién ya entró a la sala con este código. */
  joined: Set<string>;
}

/** Cuánto vive un reto sin que el otro entre. */
export const CHALLENGE_TTL_MS = 120_000;
/** Lo más que se deja esperando una petición de retos (GET /me/challenges?wait=). */
export const MAX_WAIT_S = 25;

/** Sin 0/O ni 1/I: el código se puede leer y copiar sin confundirse. */
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

export function randomCode(length = 8): string {
  return Array.from(randomBytes(length), (b) => ALPHABET[b % ALPHABET.length]).join("");
}

/**
 * Retos entre amigos, en memoria: duran dos minutos y no hace falta guardarlos. Cada jugador tiene como mucho
 * un reto enviado a la vez (uno nuevo cancela el anterior). Los duelos de un reto son amistosos: no mueven puntos.
 */
export class ChallengeService {
  private readonly byCode = new Map<string, Challenge>();
  /** Quién está esperando un reto (espera larga): por jugador, las funciones que lo despiertan. */
  private readonly waiting = new Map<string, Set<() => void>>();

  constructor(
    private readonly now: () => number = Date.now,
    private readonly ttlMs: number = CHALLENGE_TTL_MS,
    private readonly newCode: () => string = randomCode,
  ) {}

  /** `from` reta a `toId`. Cancela el reto anterior de `from`, si había. */
  create(from: { id: string; name: string }, toId: string): Challenge {
    this.sweep();
    for (const c of this.byCode.values()) if (c.fromId === from.id) this.byCode.delete(c.code);
    let code = this.newCode();
    while (this.byCode.has(code)) code = this.newCode();
    const challenge: Challenge = { code, fromId: from.id, fromName: from.name, toId, expiresAt: this.now() + this.ttlMs, joined: new Set() };
    this.byCode.set(code, challenge);
    for (const wake of this.waiting.get(toId) ?? []) wake();
    return challenge;
  }

  /**
   * Espera hasta `ms` a que a `toId` le llegue un reto (o hasta que `cancelled` se cumpla, p. ej. si el cliente
   * corta la conexión). No dice cuál: después se mira incoming().
   */
  waitForIncoming(toId: string, ms: number, cancelled?: Promise<void>): Promise<void> {
    return new Promise((resolve) => {
      const set = this.waiting.get(toId) ?? new Set<() => void>();
      this.waiting.set(toId, set);
      let timer: ReturnType<typeof setTimeout> | undefined;
      const done = () => {
        clearTimeout(timer);
        set.delete(done);
        if (set.size === 0) this.waiting.delete(toId);
        resolve();
      };
      set.add(done);
      timer = setTimeout(done, ms);
      void cancelled?.then(done);
    });
  }

  /** Cuántos jugadores tienen una espera abierta (para las pruebas). */
  waitingCount(): number {
    return this.waiting.size;
  }

  /** Los retos que me han hecho y siguen vivos. */
  incoming(toId: string): Challenge[] {
    this.sweep();
    return [...this.byCode.values()].filter((c) => c.toId === toId);
  }

  /** Segundos que le quedan al reto. */
  secondsLeft(c: Challenge): number {
    return Math.max(0, Math.ceil((c.expiresAt - this.now()) / 1000));
  }

  /** Quien reta o quien es retado lo anula (cancelar o rechazar). false si no existe o no es suyo. */
  cancel(code: string, accountId: string): boolean {
    this.sweep();
    const c = this.byCode.get(code);
    if (!c || (c.fromId !== accountId && c.toId !== accountId)) return false;
    this.byCode.delete(code);
    return true;
  }

  /**
   * Entrar a la sala del reto. Solo pueden los dos jugadores del reto, mientras siga vivo. Cuando los dos
   * han entrado el reto se gasta: un código no vale para una segunda partida.
   */
  join(code: string, accountId: string): boolean {
    this.sweep();
    const c = this.byCode.get(code);
    if (!c || (c.fromId !== accountId && c.toId !== accountId)) return false;
    c.joined.add(accountId);
    if (c.joined.size === 2) this.byCode.delete(code);
    return true;
  }

  private sweep(): void {
    const t = this.now();
    for (const [code, c] of this.byCode) if (c.expiresAt <= t) this.byCode.delete(code);
  }
}
