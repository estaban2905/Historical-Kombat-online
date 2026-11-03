/**
 * Mensajes JSON entre el juego (cliente) y el servidor, por WebSocket.
 * El servidor no simula la pelea: empareja, reenvía inputs y guarda el resultado.
 */

export type Side = 1 | 2;
/** 1 = gana P1, 2 = gana P2, 0 = empate. */
export type Winner = 0 | 1 | 2;

/** Lo que manda el cliente. */
export type ClientMessage =
  /** `token`: access token de la cuenta; sin él se juega de invitado (sin puntos). */
  /** `room`: código de un reto entre amigos; solo se empareja con quien entre con el mismo código (y pide `token`). */
  | { t: "find"; fighter: string; name?: string; token?: string; room?: string }
  | { t: "cancel" }
  | { t: "input"; f: number; m: number; a?: number }
  /**
   * Resumen del estado de la pelea de este cliente en el tick `f`. Si los dos clientes mandan un `c` distinto
   * para el mismo tick (y la misma versión `v` del resumen), sus simulaciones se separaron y el duelo se anula.
   */
  | { t: "sync"; f: number; c: number; v: number }
  /** Resultado de la pelea según la simulación de este cliente. Los dos deben coincidir. */
  | { t: "result"; winner: Winner; p1Rounds: number; p2Rounds: number }
  | { t: "leave" };

export interface MatchedMessage {
  t: "matched";
  /** 1 = el cliente controla a P1, 2 = a P2. */
  side: Side;
  /** Semilla común del azar para que ambas simulaciones coincidan. */
  seed: number;
  /** true si los dos son cuentas: el resultado cuenta para puntos y ranking. */
  ranked: boolean;
  opponent: { fighter: string; name: string };
}

/** Cierre del duelo: qué pasó con los puntos. */
export interface SettledMessage {
  t: "settled";
  /** El duelo contaba para el ranking. */
  ranked: boolean;
  /** false = no se guardó (resultados distintos, tiempo agotado, duelo demasiado corto...). */
  ok: boolean;
  /** Puntos ganados o perdidos. */
  delta: number;
  /** Mis totales después del duelo. */
  points: number;
  wins: number;
  losses: number;
  /** Por qué no se guardó ("stalled" = nadie respondió y no se sabe quién), o "forfeit" si ganó por abandono del rival. */
  reason?: string;
}

/** Lo que manda el servidor. */
export type ServerMessage =
  | { t: "queued" }
  | MatchedMessage
  | { t: "input"; f: number; m: number; a?: number }
  | SettledMessage
  | { t: "opponent_left" }
  /** Los resúmenes de estado de los dos clientes no coinciden: las peleas se separaron y el duelo se anula. */
  | { t: "desync" }
  /**
   * La pelea no avanzó durante `stallTimeoutMs`: el duelo se cierra. `loser` es el que iba por detrás
   * (el que dejó de responder); 0 = no se sabe quién, el duelo se anula.
   */
  | { t: "timeout"; loser: 0 | Side }
  | { t: "error"; msg: string };

export type ClientMessageType = ClientMessage["t"];
export type ServerMessageType = ServerMessage["t"];
