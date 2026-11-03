import type { ClientMessage, ServerMessage, SettledMessage, Side, Winner } from "../models/messages.js";
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
  /** Silencio de inputs (de los dos) tras el que se cierra el duelo y pierde quien iba por detrás. */
  stallTimeoutMs?: number;
  onError?: (err: unknown) => void;
}

const DEFAULT_SETTLE_TIMEOUT_MS = 30_000;
/** 5 s de pelea a 60 inputs por segundo. */
const DEFAULT_MIN_INPUTS = 300;
/** Un tirón de red no llega a tanto; una pestaña oculta o un cliente colgado, sí. */
const DEFAULT_STALL_TIMEOUT_MS = 15_000;
/** Comprobaciones de sincronía que se guardan esperando al otro jugador (a una por segundo, ~1 min de margen). */
const MAX_PENDING_SYNCS = 64;

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
  private readonly stallTimeoutMs: number;
  private readonly onError: (err: unknown) => void;

  constructor(randomSeed: () => number = () => Math.floor(Math.random() * 0x7fffffff), options: MatchmakingOptions = {}) {
    this.randomSeed = randomSeed;
    this.settler = options.settler;
    this.settleTimeoutMs = options.settleTimeoutMs ?? DEFAULT_SETTLE_TIMEOUT_MS;
    this.minInputs = options.minInputs ?? DEFAULT_MIN_INPUTS;
    this.stallTimeoutMs = options.stallTimeoutMs ?? DEFAULT_STALL_TIMEOUT_MS;
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
        this.find(peer, msg.fighter, msg.name ?? "", accountId, msg.room ?? null);
        break;
      case "cancel":
        this.cancel(peer);
        break;
      case "leave":
        this.disconnect(peer);
        break;
      case "input":
        this.relayInput(peer, msg.f, msg.m, msg.a);
        break;
      case "sync":
        this.receiveSync(peer, msg.f, msg.c, msg.v);
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
      this.clearStall(room);
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

  private find(peer: Peer, fighter: string, name: string, accountId: string | null, roomCode: string | null): void {
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
    const player: Player = { peer, fighter, name: name || "JUGADOR", accountId, roomCode, room: null };
    this.players.set(peer, player);

    // Una cuenta nunca se empareja consigo misma (dos pestañas abiertas). Con código de reto solo se
    // empareja con quien tenga el mismo código; sin él, solo con quien tampoco lo tenga.
    const index = this.queue.findIndex((q) => q.roomCode === roomCode && (accountId === null || q.accountId !== accountId));
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
    // Los duelos de un reto entre amigos son amistosos: si no, dos amigos podrían repartirse puntos a voluntad.
    const ranked = this.settler !== undefined && first.accountId !== null && second.accountId !== null && first.roomCode === null;
    const room = newRoom(first, second, ranked);
    first.room = room;
    second.room = room;
    const seed = this.randomSeed();
    first.peer.send({ t: "matched", side: 1, seed, ranked, opponent: { fighter: second.fighter, name: second.name } });
    second.peer.send({ t: "matched", side: 2, seed, ranked, opponent: { fighter: first.fighter, name: first.name } });
  }

  private relayInput(peer: Peer, f: number, m: number, a?: number): void {
    const player = this.players.get(peer);
    const room = player?.room;
    if (!player || !room || room.closed) return;
    room.fightStarted = true;
    const side = sideOf(room, player);
    room.inputs[side]++;
    room.lastFrame[side] = Math.max(room.lastFrame[side], f);
    room.lastInputAt = Date.now();
    if (room.stallTimer === null) this.watchStall(room, this.stallTimeoutMs);
    opponentOf(room, player).peer.send(a === undefined ? { t: "input", f, m } : { t: "input", f, m, a });
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
    this.clearStall(room); // la pelea terminó: ya no hay inputs que esperar

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

  // =========================================================================
  //  Sincronía
  // =========================================================================
  /**
   * Cada cliente manda de vez en cuando un resumen de su pelea. Si el del otro para el mismo tick es distinto,
   * las simulaciones se separaron: cada uno vería una pelea diferente y daría un ganador distinto. No se sabe
   * quién tiene razón, así que el duelo se anula sin puntos.
   */
  private receiveSync(peer: Peer, f: number, c: number, v: number): void {
    const player = this.players.get(peer);
    const room = player?.room;
    if (!player || !room || room.closed || room.settled) return;
    const side = sideOf(room, player);
    const entry = room.syncs.get(f) ?? {};
    if (entry[side] !== undefined) return; // vale el primero de cada jugador
    const other = entry[side === 1 ? 2 : 1];
    if (other === undefined) {
      entry[side] = { c, v };
      room.syncs.set(f, entry);
      // Si uno manda y el otro no, no crece sin límite: se olvidan los más antiguos.
      while (room.syncs.size > MAX_PENDING_SYNCS) room.syncs.delete(room.syncs.keys().next().value as number);
      return;
    }
    room.syncs.delete(f);
    // Dos versiones distintas del resumen no son comparables (p. ej. una pestaña con el juego antiguo).
    if (other.v !== v || other.c === c) return;
    room.closed = true;
    if (room.ranked) this.discard(room, "desync");
    this.clearStall(room);
    const msg: ServerMessage = { t: "desync" };
    room.p1.peer.send(msg);
    room.p2.peer.send(msg);
  }

  // =========================================================================
  //  Espera de inputs
  // =========================================================================
  /**
   * Mientras dura la pelea, los dos clientes mandan inputs sin parar. Si pasa `ms` sin que llegue ninguno
   * (pestaña oculta, cliente colgado), el duelo se cierra: no se puede dejar al rival esperando para siempre.
   */
  private watchStall(room: Room, ms: number): void {
    room.stallTimer = setTimeout(() => {
      room.stallTimer = null;
      const idle = Date.now() - room.lastInputAt;
      if (idle < this.stallTimeoutMs) {
        this.watchStall(room, this.stallTimeoutMs - idle);
        return;
      }
      this.resolveStall(room);
    }, ms);
    room.stallTimer.unref?.();
  }

  /**
   * Cuando uno se congela, el otro aún manda unos ticks adelantados y luego también se queda esperando:
   * los dos callan. Pierde el que quedó por detrás en ticks. Si van igualados no se sabe quién: se anula.
   */
  private resolveStall(room: Room): void {
    if (room.closed || room.settled) return;
    room.closed = true;
    const behind: 0 | Side = room.lastFrame[1] < room.lastFrame[2] ? 1 : room.lastFrame[2] < room.lastFrame[1] ? 2 : 0;
    if (room.ranked) {
      if (behind !== 0) this.forfeit(room, behind === 1 ? 2 : 1);
      else this.discard(room, "stalled");
    }
    const msg: ServerMessage = { t: "timeout", loser: behind };
    room.p1.peer.send(msg);
    room.p2.peer.send(msg);
  }

  private clearStall(room: Room): void {
    if (room.stallTimer) clearTimeout(room.stallTimer);
    room.stallTimer = null;
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
    this.clearStall(room);
  }
}

function unranked(): SettledMessage {
  return { t: "settled", ranked: false, ok: true, delta: 0, points: 0, wins: 0, losses: 0 };
}

function settled(outcome: SettleOutcome, side: Side, reason: "normal" | "forfeit"): SettledMessage {
  const mine = side === 1 ? outcome.p1 : outcome.p2;
  return { t: "settled", ranked: true, ok: true, ...mine, ...(reason === "forfeit" ? { reason } : {}) };
}
