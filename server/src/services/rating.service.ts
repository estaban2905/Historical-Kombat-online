import type { Winner } from "../models/messages.js";

/** Cuánto se mueve el marcador por duelo (más alto = cambios más grandes). */
export const K_FACTOR = 32;

/**
 * Puntos que gana P1 (negativo = pierde) según el sistema Elo: ganarle a alguien
 * mejor da más puntos que ganarle a alguien peor. P2 recibe el valor opuesto.
 * Una victoria o derrota siempre mueve al menos 1 punto; un empate puede dar 0.
 */
export function eloDelta(p1Points: number, p2Points: number, winner: Winner): number {
  const expected = 1 / (1 + 10 ** ((p2Points - p1Points) / 400));
  const score = winner === 1 ? 1 : winner === 2 ? 0 : 0.5;
  const delta = Math.round(K_FACTOR * (score - expected));
  if (winner === 1) return Math.max(delta, 1);
  if (winner === 2) return Math.min(delta, -1);
  return delta;
}

/** Los puntos nunca bajan de 0. Devuelve el total nuevo. */
export function applyDelta(points: number, delta: number): number {
  return Math.max(points + delta, 0);
}
