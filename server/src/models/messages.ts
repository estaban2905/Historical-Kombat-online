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
  /** Por qué no se guardó, o "forfeit" si ganó por abandono del rival. */
  reason?: string;
}

/** Lo que manda el servidor. */
export type ServerMessage =
  | { t: "queued" }
  | MatchedMessage
  | { t: "input"; f: number; m: number; a?: number }
  | SettledMessage
  | { t: "opponent_left" }
  | { t: "error"; msg: string };

export type ClientMessageType = ClientMessage["t"];
export type ServerMessageType = ServerMessage["t"];
