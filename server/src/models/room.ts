import type { Player } from "./player.js";

export interface Room {
  p1: Player;
  p2: Player;
}

/** El rival de `player` dentro de la sala. */
export function opponentOf(room: Room, player: Player): Player {
  return room.p1 === player ? room.p2 : room.p1;
}
