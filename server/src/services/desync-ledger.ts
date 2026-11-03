/** Cuentas distintas que se vigilan a la vez; pasado esto se barren las entradas caducadas. */
const MAX_TRACKED_ACCOUNTS = 10_000;

/**
 * Cuenta, por cuenta, los duelos que se anularon por desincronización en una ventana de tiempo.
 *
 * Cuando las simulaciones de los dos clientes se separan, el servidor no puede saber quién tiene razón:
 * no simula la pelea. Sin más, quien va perdiendo podría mandar un resumen falso para anular el duelo y
 * librarse de la derrota. Lo que sí se ve es el patrón: el tramposo aparece en todas sus anulaciones y sus
 * rivales, solo en la suya. Por eso se lleva la cuenta y quien se repite deja de salir gratis.
 *
 * Vive en memoria: un reinicio del servidor la vacía. Es una defensa contra el abuso repetido, no un registro.
 */
export class DesyncLedger {
  private readonly strikes = new Map<string, number[]>();

  constructor(
    private readonly windowMs: number,
    private readonly now: () => number = Date.now,
  ) {}

  /** Anota una anulación de esta cuenta y devuelve cuántas lleva dentro de la ventana (la nueva incluida). */
  record(accountId: string): number {
    const at = this.now();
    const recent = this.recentOf(accountId, at);
    recent.push(at);
    this.strikes.set(accountId, recent);
    if (this.strikes.size > MAX_TRACKED_ACCOUNTS) this.sweep(at);
    return recent.length;
  }

  /** Anulaciones de esta cuenta dentro de la ventana. */
  count(accountId: string): number {
    return this.recentOf(accountId, this.now()).length;
  }

  private recentOf(accountId: string, at: number): number[] {
    return (this.strikes.get(accountId) ?? []).filter((t) => t > at - this.windowMs);
  }

  private sweep(at: number): void {
    for (const id of this.strikes.keys()) {
      const recent = this.recentOf(id, at);
      if (recent.length === 0) this.strikes.delete(id);
      else this.strikes.set(id, recent);
    }
  }
}
