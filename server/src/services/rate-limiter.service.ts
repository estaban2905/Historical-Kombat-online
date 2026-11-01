/** Limita cuántos eventos se aceptan por segundo (ventana fija de 1 s). */
export class RateLimiter {
  private windowStart: number;
  private count = 0;

  constructor(
    private readonly maxPerSecond: number,
    private readonly now: () => number = Date.now,
  ) {
    this.windowStart = this.now();
  }

  /** true si el evento está permitido. */
  allow(): boolean {
    const t = this.now();
    if (t - this.windowStart >= 1000) {
      this.windowStart = t;
      this.count = 0;
    }
    return ++this.count <= this.maxPerSecond;
  }
}
