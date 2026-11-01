/**
 * Lo mínimo que el resto del servidor necesita de la base de datos.
 * Así los repositorios no dependen del driver: en producción es Postgres
 * (pg-db.ts) y en las pruebas un Postgres embebido en memoria.
 */
export interface Queryable {
  query<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<{ rows: T[] }>;
  /** Varias sentencias seguidas, sin parámetros (migraciones). */
  exec(sql: string): Promise<void>;
}

export interface Db extends Queryable {
  /** Todo o nada: si `fn` lanza un error se deshace todo. */
  transaction<T>(fn: (tx: Queryable) => Promise<T>): Promise<T>;
  close(): Promise<void>;
}

/** Código de Postgres para "ya existe" (clave única repetida). */
export const UNIQUE_VIOLATION = "23505";

export function isUniqueViolation(err: unknown): err is { code: string; constraint?: string } {
  return typeof err === "object" && err !== null && (err as { code?: unknown }).code === UNIQUE_VIOLATION;
}
