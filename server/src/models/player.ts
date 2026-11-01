import type { ServerMessage } from "./messages.js";
import type { Room } from "./room.js";

/**
 * Lo mínimo que el servicio necesita de una conexión.
 * Así la lógica no depende de WebSockets y se prueba sin red.
 */
export interface Peer {
  send(msg: ServerMessage): void;
}

export interface Player {
  peer: Peer;
  fighter: string;
  name: string;
  /** Sala en la que está peleando; null si está en cola. */
  room: Room | null;
}
