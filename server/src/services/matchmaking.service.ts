import type { ClientMessage } from "../models/messages.js";
import type { Peer, Player } from "../models/player.js";
import { opponentOf, type Room } from "../models/room.js";

export interface MatchmakingStats {
  queued: number;
  rooms: number;
}

/**
 * Cola de emparejamiento y salas de dos jugadores.
 * Es lógica pura: no sabe nada de WebSockets ni de Fastify.
 */
export class MatchmakingService {
  private readonly players = new Map<Peer, Player>();
  private queue: Player[] = [];
  private readonly randomSeed: () => number;

  constructor(randomSeed: () => number = () => Math.floor(Math.random() * 0x7fffffff)) {
    this.randomSeed = randomSeed;
  }

  stats(): MatchmakingStats {
    const rooms = new Set<Room>();
    for (const p of this.players.values()) if (p.room) rooms.add(p.room);
    return { queued: this.queue.length, rooms: rooms.size };
  }

  handle(peer: Peer, msg: ClientMessage): void {
    switch (msg.t) {
      case "find":
        this.find(peer, msg.fighter, msg.name ?? "");
        break;
      case "cancel":
        this.cancel(peer);
        break;
      case "leave":
        this.disconnect(peer);
        break;
      case "input":
        this.relayInput(peer, msg.f, msg.m);
        break;
    }
  }

  /** Hay que llamarlo cuando se cae el socket. */
  disconnect(peer: Peer): void {
    const player = this.players.get(peer);
    if (!player) return;
    this.players.delete(peer);
    this.queue = this.queue.filter((p) => p !== player);

    if (player.room) {
      const other = opponentOf(player.room, player);
      other.room = null;
      this.players.delete(other.peer);
      other.peer.send({ t: "opponent_left" });
    }
  }

  private find(peer: Peer, fighter: string, name: string): void {
    const existing = this.players.get(peer);
    if (existing) {
      peer.send({ t: "error", msg: existing.room ? "ya estás en una partida" : "ya estás en la cola" });
      return;
    }
    const player: Player = { peer, fighter, name: name || "JUGADOR", room: null };
    this.players.set(peer, player);

    const rival = this.queue.shift();
    if (!rival) {
      this.queue.push(player);
      peer.send({ t: "queued" });
      return;
    }
    this.startRoom(rival, player);
  }

  private cancel(peer: Peer): void {
    const player = this.players.get(peer);
    if (!player || player.room) return;
    this.queue = this.queue.filter((p) => p !== player);
    this.players.delete(peer);
  }

  private startRoom(first: Player, second: Player): void {
    // Quien esperaba antes es P1.
    const room: Room = { p1: first, p2: second };
    first.room = room;
    second.room = room;
    const seed = this.randomSeed();
    first.peer.send({ t: "matched", side: 1, seed, opponent: { fighter: second.fighter, name: second.name } });
    second.peer.send({ t: "matched", side: 2, seed, opponent: { fighter: first.fighter, name: first.name } });
  }

  private relayInput(peer: Peer, f: number, m: number): void {
    const player = this.players.get(peer);
    if (!player?.room) return;
    opponentOf(player.room, player).peer.send({ t: "input", f, m });
  }
}
