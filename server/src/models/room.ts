import type { Side, Winner } from "./messages.js";
import type { Player } from "./player.js";

/** Lo que un cliente dice que pasó en la pelea. */
export interface Report {
  winner: Winner;
  p1Rounds: number;
  p2Rounds: number;
}

export interface Room {
  p1: Player;
  p2: Player;
  /** Los dos son cuentas distintas: el resultado cuenta para el ranking. */
  ranked: boolean;
  /** Alguien se fue: ya no se emparejan ni se reenvían inputs, pero aún puede llegar un resultado. */
  closed: boolean;
  /** Ya se mandaron inputs: la pelea empezó de verdad (antes, irse no es abandonar). */
  fightStarted: boolean;
  /** Inputs recibidos de cada lado; sirven para descartar duelos demasiado cortos. */
  inputs: { 1: number; 2: number };
  reports: { 1: Report | null; 2: Report | null };
  /** El resultado ya se guardó o se descartó: no se acepta nada más. */
  settled: boolean;
  /** Espera del segundo resultado. */
  timer: ReturnType<typeof setTimeout> | null;
  /** Último tick recibido de cada lado: el que va por detrás es el que dejó de responder. */
  lastFrame: { 1: number; 2: number };
  /** Cuándo llegó el último input de cualquiera de los dos (ms). */
  lastInputAt: number;
  /** Vigila que sigan llegando inputs mientras dura la pelea. */
  stallTimer: ReturnType<typeof setTimeout> | null;
  /** Resúmenes de estado por tick, a la espera de que llegue el del otro jugador. */
  syncs: Map<number, { 1?: SyncEntry; 2?: SyncEntry }>;
}

/** Resumen del estado de la pelea de un cliente en un tick y versión del resumen. */
export interface SyncEntry {
  c: number;
  v: number;
}

/** El rival de `player` dentro de la sala. */
export function opponentOf(room: Room, player: Player): Player {
  return room.p1 === player ? room.p2 : room.p1;
}

export function sideOf(room: Room, player: Player): Side {
  return room.p1 === player ? 1 : 2;
}

export function newRoom(p1: Player, p2: Player, ranked: boolean): Room {
  return {
    p1,
    p2,
    ranked,
    closed: false,
    fightStarted: false,
    inputs: { 1: 0, 2: 0 },
    reports: { 1: null, 2: null },
    settled: false,
    timer: null,
    lastFrame: { 1: -1, 2: -1 },
    lastInputAt: 0,
    stallTimer: null,
    syncs: new Map(),
  };
}
