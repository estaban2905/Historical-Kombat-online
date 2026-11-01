/** Error de la API con su código HTTP y un código estable que el juego puede traducir. */
export class AppError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
  }
}

/** La base de datos rechazó crear la cuenta porque el nombre o el email ya existen. */
export class DuplicateAccountError extends Error {
  constructor(readonly field: "username" | "email") {
    super(`${field} duplicado`);
  }
}
