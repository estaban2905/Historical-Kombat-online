import type { ClientMessage, ServerMessage, SettledMessage, Side, Winner } from "../models/messages.js";
import type { Peer, Player } from "../models/player.js";
import { newRoom, opponentOf, sideOf, type Report, type Room } from "../models/room.js";
import { DesyncLedger, type DesyncStore } from "./desync-ledger.js";
import type { SettleOutcome, Settler } from "./match.service.js";

/** Algo que el servidor descartó o vigila porque un cliente no se comporta como el juego. */
export type SuspiciousEvent =
  | { kind: "frame_out_of_range"; accountId: string | null; frame: number; limit: number }
  | { kind: "desync_strike"; accountId: string; strikes: number }
  | { kind: "desync_forfeit"; accountId: string; strikes: number };

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
  /** Tiempo sin que la pelea avance tras el que se cierra el duelo y pierde quien iba por detrás. */
  stallTimeoutMs?: number;
  /** Margen para que el segundo jugador empiece a mandar inputs (carga de la pelea) antes de contar la espera normal. */
  stallStartGraceMs?: number;
  /** Ticks que debe avanzar la pelea (el lado más lento) para contar como progreso y reiniciar la espera. */
  stallMinTicks?: number;
  /** Duelos anulados por desincronización, dentro de la ventana, a partir de los cuales una cuenta deja de salir gratis. */
  desyncStrikeLimit?: number;
  /** Ventana en la que se cuentan las desincronizaciones de una cuenta (si no se da `desyncStore`). */
  desyncWindowMs?: number;
  /** Dónde se anotan las desincronizaciones por cuenta. Por defecto, en memoria; con base de datos, `DesyncRepository`. */
  desyncStore?: DesyncStore;
  /** Aviso de comportamiento sospechoso de un cliente (para registrarlo; no cambia el resultado). */
  onSuspicious?: (event: SuspiciousEvent) => void;
  onError?: (err: unknown) => void;
}

const DEFAULT_SETTLE_TIMEOUT_MS = 30_000;
/** 5 s de pelea a 60 inputs por segundo. */
const DEFAULT_MIN_INPUTS = 300;
/** Un tirón de red no llega a tanto; una pestaña oculta o un cliente colgado, sí. */
const DEFAULT_STALL_TIMEOUT_MS = 15_000;
/** Cargar la escena de pelea en un navegador lento puede tardar bastante más que en otro equipo. */
const DEFAULT_STALL_START_GRACE_MS = 60_000;
/**
 * 30 ticks cada 15 s son 2 por segundo: la pelea a 1/30 de velocidad. Por debajo ya no se está jugando.
 * Medido: un Chrome con render por software movió la pelea a ~8 ticks/s, así que hay margen.
 */
const DEFAULT_STALL_MIN_TICKS = 30;
/** Dos anulaciones pueden ser mala suerte o un fallo del juego; a la tercera en un día ya es un patrón. */
const DEFAULT_DESYNC_STRIKE_LIMIT = 3;
export const DEFAULT_DESYNC_WINDOW_MS = 24 * 60 * 60 * 1000;

// Del protocolo del cliente (scripts/lockstep_session.gd). Un cliente honesto manda los ticks de uno en uno,
// sin repetir ni saltarse ninguno, empezando por INITIAL_DELAY, y con un retraso que nunca pasa de MAX_DELAY.
const CLIENT_INITIAL_DELAY = 4;
const CLIENT_MAX_DELAY = 15;
/**
 * Cuánto puede adelantarse el tick de un jugador al último que mandó el rival. Un cliente solo ejecuta el tick T
 * cuando tiene el T del rival, y manda por adelantado hasta T + retraso: como mucho MAX_DELAY + 1 por delante
 * (mientras espera el tick siguiente al último del rival). Se deja margen para no echar a nadie por un redondeo.
 */
const MAX_LEAD_TICKS = CLIENT_MAX_DELAY + 1 + 4;
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
  private readonly stallMinTicks: number;
  private readonly stallStartGraceMs: number;
  private readonly desyncs: DesyncStore;
  private readonly desyncStrikeLimit: number;
  private readonly onSuspicious: (event: SuspiciousEvent) => void;
  private readonly onError: (err: unknown) => void;

  constructor(randomSeed: () => number = () => Math.floor(Math.random() * 0x7fffffff), options: MatchmakingOptions = {}) {
    this.randomSeed = randomSeed;
    this.settler = options.settler;
    this.settleTimeoutMs = options.settleTimeoutMs ?? DEFAULT_SETTLE_TIMEOUT_MS;
    this.minInputs = options.minInputs ?? DEFAULT_MIN_INPUTS;
    this.stallTimeoutMs = options.stallTimeoutMs ?? DEFAULT_STALL_TIMEOUT_MS;
    this.stallMinTicks = options.stallMinTicks ?? DEFAULT_STALL_MIN_TICKS;
    this.stallStartGraceMs = options.stallStartGraceMs ?? DEFAULT_STALL_START_GRACE_MS;
    this.desyncs = options.desyncStore ?? new DesyncLedger(options.desyncWindowMs ?? DEFAULT_DESYNC_WINDOW_MS);
    this.desyncStrikeLimit = options.desyncStrikeLimit ?? DEFAULT_DESYNC_STRIKE_LIMIT;
    this.onSuspicious = options.onSuspicious ?? (() => undefined);
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
    const side = sideOf(room, player);

    // El tick lo dice el cliente y de él depende quién pierde si la pelea se para (ver resolveStall): no se
    // puede aceptar cualquiera. Uno honesto nunca repite un tick ni se adelanta mucho al último del rival.
    if (f <= room.lastFrame[side]) return;
    const limit = Math.max(room.lastFrame[side === 1 ? 2 : 1], CLIENT_INITIAL_DELAY - 1) + MAX_LEAD_TICKS;
    if (f > limit) {
      if (++room.rejected[side] === 1) this.onSuspicious({ kind: "frame_out_of_range", accountId: player.accountId, frame: f, limit });
      return;
    }

    room.fightStarted = true;
    room.inputs[side]++;
    const joined = room.lastFrame[side] < 0; // su primer input: la pelea de este lado ya cargó
    room.lastFrame[side] = f;
    const now = Date.now();
    if (room.stallTimer === null) {
      room.lastProgressAt = now;
      this.watchStall(room, this.stallLimitMs(room));
    } else if (joined && room.lastFrame[side === 1 ? 2 : 1] >= 0) {
      // Ya están los dos: la espera normal cuenta desde aquí, no desde el primero.
      room.lastProgressAt = now;
      this.clearStall(room);
      this.watchStall(room, this.stallTimeoutMs);
    }
    // Que lleguen mensajes no es que la pelea avance: un goteo de inputs sueltos dejaría al rival casi parado
    // sin que nunca se agotara la espera. Solo cuenta lo que hace avanzar al lado más lento.
    const common = Math.min(room.lastFrame[1], room.lastFrame[2]);
    if (common - room.progressFrame >= this.stallMinTicks) {
      room.progressFrame = common;
      room.lastProgressAt = now;
    }
    opponentOf(room, player).peer.send(a === undefined ? { t: "input", f, m } : { t: "input", f, m, a });
  }

  // =========================================================================
  //  Resultados
  // =========================================================================
  private receiveResult(peer: Peer, report: Report): void {
    const player = this.players.get(peer);
    const room = player?.room;
    if (!player || !room || room.settled || room.desynced) return;
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
    room.desynced = true; // mientras se decide, ningún resultado puede cerrar el duelo por otro camino
    this.clearStall(room);
    void this.resolveDesync(room);
  }

  /**
   * Un duelo con ranking cuyas peleas se separaron se anula sin puntos, porque no se sabe quién tiene razón.
   * Pero eso sería una salida gratis para quien va perdiendo (basta mandar un resumen falso), así que se anota
   * la anulación en las dos cuentas. Si una acumula `desyncStrikeLimit` dentro de la ventana y más que su rival,
   * es la que se repite en todas: pierde por abandono. El rival, que solo aparece en la suya, no sale perjudicado.
   *
   * Los dos reciben `desync`; `loser` dice quién pierde, o falta si el duelo se anuló.
   */
  private async resolveDesync(room: Room): Promise<void> {
    let loser: 0 | Side = 0;
    if (room.ranked) {
      try {
        loser = await this.punishRepeatedDesync(room);
      } catch (err) {
        // Sin poder consultar el historial no se castiga a nadie: se anula sin puntos, como la primera vez.
        this.onError(err);
        this.discard(room, "desync");
      }
    }
    const msg: ServerMessage = loser === 0 ? { t: "desync" } : { t: "desync", loser };
    room.p1.peer.send(msg);
    room.p2.peer.send(msg);
  }

  /** Anota la anulación en las dos cuentas y decide el duelo. Devuelve quién pierde (0 = se anula). */
  private async punishRepeatedDesync(room: Room): Promise<0 | Side> {
    const id1 = room.p1.accountId;
    const id2 = room.p2.accountId;
    if (!id1 || !id2) {
      this.discard(room, "desync");
      return 0;
    }
    const strikes1 = await this.desyncs.record(id1);
    const strikes2 = await this.desyncs.record(id2);
    this.onSuspicious({ kind: "desync_strike", accountId: id1, strikes: strikes1 });
    this.onSuspicious({ kind: "desync_strike", accountId: id2, strikes: strikes2 });

    const limit = this.desyncStrikeLimit;
    const offender: 0 | Side = strikes1 >= limit && strikes1 > strikes2 ? 1 : strikes2 >= limit && strikes2 > strikes1 ? 2 : 0;
    if (offender === 0) {
      this.discard(room, "desync");
      return 0;
    }
    this.onSuspicious({ kind: "desync_forfeit", accountId: offender === 1 ? id1 : id2, strikes: offender === 1 ? strikes1 : strikes2 });
    // Si el duelo era demasiado corto, forfeit() lo anula sin puntos y nadie pierde.
    return this.forfeit(room, offender === 1 ? 2 : 1) ? offender : 0;
  }

  // =========================================================================
  //  Espera de inputs
  // =========================================================================
  /**
   * Mientras dura la pelea, los dos clientes mandan inputs sin parar. Si pasa `ms` sin que la pelea avance
   * (pestaña oculta, cliente colgado, o un goteo de inputs que no la mueve), el duelo se cierra: no se puede
   * dejar al rival esperando para siempre.
   */
  private watchStall(room: Room, ms: number): void {
    room.stallTimer = setTimeout(() => {
      room.stallTimer = null;
      const idle = Date.now() - room.lastProgressAt;
      const limit = this.stallLimitMs(room);
      if (idle < limit) {
        this.watchStall(room, limit - idle);
        return;
      }
      this.resolveStall(room);
    }, ms);
    room.stallTimer.unref?.();
  }

  /**
   * Cuánto silencio se aguanta. Mientras solo uno ha mandado inputs, el otro puede estar todavía cargando la
   * pelea (en un navegador lento tarda más que en uno rápido): se le da un margen largo antes de darlo por
   * perdido. Cuando ya están los dos, vale la espera normal.
   */
  private stallLimitMs(room: Room): number {
    const bothStarted = room.lastFrame[1] >= 0 && room.lastFrame[2] >= 0;
    return bothStarted ? this.stallTimeoutMs : Math.max(this.stallTimeoutMs, this.stallStartGraceMs);
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

  /** El rival se fue sin dar su resultado: gana el que se quedó. Devuelve false si el duelo era muy corto y se anuló. */
  private forfeit(room: Room, winner: Side): boolean {
    if (Math.max(room.inputs[1], room.inputs[2]) < this.minInputs) {
      this.discard(room, "too_short");
      return false;
    }
    const stayed = room.reports[winner];
    void this.settle(room, winner, stayed?.p1Rounds ?? 0, stayed?.p2Rounds ?? 0, "forfeit");
    return true;
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
