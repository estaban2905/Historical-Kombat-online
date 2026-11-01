/**
 * Mensajes JSON entre el juego (cliente) y el servidor, por WebSocket.
 * El servidor no simula la pelea: empareja y reenvía inputs.
 */

export type Side = 1 | 2;

/** Lo que manda el cliente. */
export type ClientMessage =
  | { t: "find"; fighter: string; name?: string }
  | { t: "cancel" }
  | { t: "input"; f: number; m: number }
  | { t: "leave" };

export interface MatchedMessage {
  t: "matched";
  /** 1 = el cliente controla a P1, 2 = a P2. */
  side: Side;
  /** Semilla común del azar para que ambas simulaciones coincidan. */
  seed: number;
  opponent: { fighter: string; name: string };
}

/** Lo que manda el servidor. */
export type ServerMessage =
  | { t: "queued" }
  | MatchedMessage
  | { t: "input"; f: number; m: number }
  | { t: "opponent_left" }
  | { t: "error"; msg: string };

export type ClientMessageType = ClientMessage["t"];
export type ServerMessageType = ServerMessage["t"];
