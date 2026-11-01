import type { ClientMessage, SettledMessage, Side, Winner } from "../models/messages.js";
import type { Peer, Player } from "../models/player.js";
import { newRoom, opponentOf, sideOf, type Report, type Room } from "../models/room.js";
import type { SettleOutcome, Settler } from "./match.service.js";

export interface MatchmakingStats {
  queued: number;
  rooms: number;
}

export interface MatchmakingOptions {
  /** Guarda los duelos entre cuentas. Sin él, ningún duelo cuenta para el ranking. */
  settler?: Settler;
  /** Cuánto se espera al segundo resultado antes de descartar el duelo. */
  settleTimeoutMs?: number;
  /** Inputs mínimos por jugador para que un duelo cuente (descarta duelos "de mentira"). */
  minInputs?: number;
  onError?: (err: unknown) => void;
}

const DEFAULT_SETTLE_TIMEOUT_MS = 30_000;
/** 5 s de pelea a 60 inputs por segundo. */
const DEFAULT_MIN_INPUTS = 300;

/**
 * Cola de emparejamiento, salas de dos jugadores y cierre de los duelos.
 * Es lógica pura: no sabe nada de WebSockets ni de Fastify.
 *
 * El servidor no simula la pelea, así que no puede saber quién ganó. Por eso cada
 * cliente reporta el resultado de SU simulación (que es idéntica a la del rival):
 * si los dos reportes coinciden se guarda; si no, se descarta. Quien se desconecta en
 * plena pelea sin haber reportado pierde por abandono.
 */
export class MatchmakingService {
  private readonly players = new Map<Peer, Player>();
  private queue: Player[] = [];
  private readonly randomSeed: () => number;
  private readonly settler: Settler | undefined;
  private readonly settleTimeoutMs: number;
  private readonly minInputs: number;
  private readonly onError: (err: unknown) => void;

  constructor(randomSeed: () => number = () => Math.floor(Math.random() * 0x7fffffff), options: MatchmakingOptions = {}) {
    this.randomSeed = randomSeed;
    this.settler = options.settler;
    this.settleTimeoutMs = options.settleTimeoutMs ?? DEFAULT_SETTLE_TIMEOUT_MS;
    this.minInputs = options.minInputs ?? DEFAULT_MIN_INPUTS;
    this.onError = options.onError ?? (() => undefined);
  }

  stats(): MatchmakingStats {
    const rooms = new Set<Room>();
    for (const p of this.players.values()) if (p.room && !p.room.closed) rooms.add(p.room);
    return { queued: this.queue.length, rooms: rooms.size };
  }

  /** `accountId`: la cuenta ya verificada del que busca partida (null = invitado). */
  handle(peer: Peer, msg: ClientMessage, accountId: string | null = null): void {
    switch (msg.t) {
      case "find":
        this.find(peer, msg.fighter, msg.name ?? "", accountId);
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
      case "result":
        this.receiveResult(peer, { winner: msg.winner, p1Rounds: msg.p1Rounds, p2Rounds: msg.p2Rounds });
        break;
    }
  }

  /** Hay que llamarlo cuando se cae el socket. */
  disconnect(peer: Peer): void {
    const player = this.players.get(peer);
    if (!player) return;
    this.players.delete(peer);
    this.queue = this.queue.filter((p) => p !== player);

    const room = player.room;
    if (!room) return;
    const other = opponentOf(room, player);
    if (!room.closed) {
      room.closed = true;
      const side = sideOf(room, player);
      // Se fue en plena pelea sin haber dado su resultado: abandono.
      if (room.ranked && !room.settled && room.fightStarted && room.reports[side] === null) {
        this.forfeit(room, side === 1 ? 2 : 1);
      }
      other.peer.send({ t: "opponent_left" });
    }
    // Si ya no queda nadie, no hay nada que esperar.
    if (!this.players.has(other.peer)) this.clearTimer(room);
  }

  private find(peer: Peer, fighter: string, name: string, accountId: string | null): void {
    const existing = this.players.get(peer);
    if (existing) {
      // Si su rival se fue, la sala ya está cerrada y puede buscar otra partida.
      if (existing.room && !existing.room.closed) {
        peer.send({ t: "error", msg: "ya estás en una partida" });
        return;
      }
      if (!existing.room) {
        peer.send({ t: "error", msg: "ya estás en la cola" });
        return;
      }
      // Deja atrás el duelo anterior: ya no se espera ningún resultado de esa sala.
      existing.room.settled = true;
      this.clearTimer(existing.room);
      this.players.delete(peer);
    }
    const player: Player = { peer, fighter, name: name || "JUGADOR", accountId, room: null };
    this.players.set(peer, player);

    // Una cuenta nunca se empareja consigo misma (dos pestañas abiertas).
    const index = this.queue.findIndex((q) => accountId === null || q.accountId !== accountId);
    const rival = index >= 0 ? this.queue.splice(index, 1)[0] : undefined;
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
    const ranked = this.settler !== undefined && first.accountId !== null && second.accountId !== null;
    const room = newRoom(first, second, ranked);
    first.room = room;
    second.room = room;
    const seed = this.randomSeed();
    first.peer.send({ t: "matched", side: 1, seed, ranked, opponent: { fighter: second.fighter, name: second.name } });
    second.peer.send({ t: "matched", side: 2, seed, ranked, opponent: { fighter: first.fighter, name: first.name } });
  }

  private relayInput(peer: Peer, f: number, m: number): void {
    const player = this.players.get(peer);
    const room = player?.room;
    if (!player || !room || room.closed) return;
    room.fightStarted = true;
    room.inputs[sideOf(room, player)]++;
    opponentOf(room, player).peer.send({ t: "input", f, m });
  }

  // =========================================================================
  //  Resultados
  // =========================================================================
  private receiveResult(peer: Peer, report: Report): void {
    const player = this.players.get(peer);
    const room = player?.room;
    if (!player || !room || room.settled) return;
    const side = sideOf(room, player);
    if (room.reports[side] !== null) return; // un solo reporte por jugador

    if (!room.ranked) {
      room.reports[side] = report;
      peer.send(unranked());
      return;
    }
    room.reports[side] = report;

    const mine = room.reports[1];
    const theirs = room.reports[2];
    if (mine === null || theirs === null) {
      // Falta el del rival: se espera un tiempo y, si no llega, se descarta.
      if (room.timer === null) {
        room.timer = setTimeout(() => this.discard(room, "timeout"), this.settleTimeoutMs);
        room.timer.unref?.();
      }
      return;
    }
    if (mine.winner !== theirs.winner || mine.p1Rounds !== theirs.p1Rounds || mine.p2Rounds !== theirs.p2Rounds) {
      this.discard(room, "mismatch");
      return;
    }
    if (room.inputs[1] < this.minInputs || room.inputs[2] < this.minInputs) {
      this.discard(room, "too_short");
      return;
    }
    void this.settle(room, mine.winner, mine.p1Rounds, mine.p2Rounds, "normal");
  }

  /** El rival se fue sin dar su resultado: gana el que se quedó. */
  private forfeit(room: Room, winner: Side): void {
    if (Math.max(room.inputs[1], room.inputs[2]) < this.minInputs) {
      this.discard(room, "too_short");
      return;
    }
    const stayed = room.reports[winner];
    void this.settle(room, winner, stayed?.p1Rounds ?? 0, stayed?.p2Rounds ?? 0, "forfeit");
  }

  /** Guarda el duelo y avisa a los dos del resultado. */
  private async settle(room: Room, winner: Winner, p1Rounds: number, p2Rounds: number, reason: "normal" | "forfeit"): Promise<void> {
    if (room.settled || !this.settler || !room.p1.accountId || !room.p2.accountId) return;
    room.settled = true;
    this.clearTimer(room);
    try {
      const outcome = await this.settler({
        p1Id: room.p1.accountId,
        p2Id: room.p2.accountId,
        p1Fighter: room.p1.fighter,
        p2Fighter: room.p2.fighter,
        winner,
        p1Rounds,
        p2Rounds,
        reason,
      });
      room.p1.peer.send(settled(outcome, 1, reason));
      room.p2.peer.send(settled(outcome, 2, reason));
    } catch (err) {
      this.onError(err);
      this.notifyFailed(room, "error");
    }
  }

  /** El duelo no se guarda: nadie gana ni pierde puntos. */
  private discard(room: Room, reason: string): void {
    if (room.settled) return;
    room.settled = true;
    this.clearTimer(room);
    this.notifyFailed(room, reason);
  }

  private notifyFailed(room: Room, reason: string): void {
    const msg: SettledMessage = { t: "settled", ranked: true, ok: false, delta: 0, points: 0, wins: 0, losses: 0, reason };
    room.p1.peer.send(msg);
    room.p2.peer.send(msg);
  }

  private clearTimer(room: Room): void {
    if (room.timer) clearTimeout(room.timer);
    room.timer = null;
  }
}

function unranked(): SettledMessage {
  return { t: "settled", ranked: false, ok: true, delta: 0, points: 0, wins: 0, losses: 0 };
}

function settled(outcome: SettleOutcome, side: Side, reason: "normal" | "forfeit"): SettledMessage {
  const mine = side === 1 ? outcome.p1 : outcome.p2;
  return { t: "settled", ranked: true, ok: true, ...mine, ...(reason === "forfeit" ? { reason } : {}) };
}
