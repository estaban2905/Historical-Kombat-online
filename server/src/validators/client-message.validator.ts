import type { ClientMessage, Winner } from "../models/messages.js";

export const MAX_NAME_LENGTH = 16;
export const MAX_FIGHTER_LENGTH = 40;
/** Los inputs son una máscara de bits de botones; 16 bits sobran. */
export const MAX_INPUT_MASK = 0xffff;
export const MAX_TOKEN_LENGTH = 200;
/** Rondas ganadas por jugador en un duelo (el juego usa 2, con tope de 5 rondas). */
export const MAX_ROUNDS = 20;

const FIGHTER_ID = /^[a-z0-9_]+$/;

/**
 * Valida y normaliza lo que llega por el socket. Devuelve null si no es un
 * mensaje válido: el servidor nunca debe fiarse de lo que manda el cliente.
 */
export function parseClientMessage(raw: string): ClientMessage | null {
  let data: unknown;
  try {
    data = JSON.parse(raw);
  } catch {
    return null;
  }
  if (typeof data !== "object" || data === null) return null;
  const msg = data as Record<string, unknown>;

  switch (msg["t"]) {
    case "find":
      return parseFind(msg);
    case "input":
      return parseInput(msg);
    case "result":
      return parseResult(msg);
    case "cancel":
      return { t: "cancel" };
    case "leave":
      return { t: "leave" };
    default:
      return null;
  }
}

function parseFind(msg: Record<string, unknown>): ClientMessage | null {
  const fighter = msg["fighter"];
  if (typeof fighter !== "string" || fighter.length > MAX_FIGHTER_LENGTH || !FIGHTER_ID.test(fighter)) {
    return null;
  }
  const name = typeof msg["name"] === "string" ? sanitizeName(msg["name"]) : "";
  const token = msg["token"];
  if (token === undefined) return { t: "find", fighter, name };
  // Un token mal formado es un error, no "juega de invitado": así el jugador se entera.
  if (typeof token !== "string" || token === "" || token.length > MAX_TOKEN_LENGTH) return null;
  return { t: "find", fighter, name, token };
}

function parseInput(msg: Record<string, unknown>): ClientMessage | null {
  const f = msg["f"];
  const m = msg["m"];
  if (!Number.isInteger(f) || (f as number) < 0) return null;
  if (!Number.isInteger(m) || (m as number) < 0 || (m as number) > MAX_INPUT_MASK) return null;
  const a = msg["a"];
  if (a === undefined) return { t: "input", f: f as number, m: m as number };
  if (!Number.isInteger(a) || (a as number) < 0) return null;
  return { t: "input", f: f as number, m: m as number, a: a as number };
}

function parseResult(msg: Record<string, unknown>): ClientMessage | null {
  const winner = msg["winner"];
  const p1Rounds = msg["p1Rounds"];
  const p2Rounds = msg["p2Rounds"];
  if (winner !== 0 && winner !== 1 && winner !== 2) return null;
  for (const r of [p1Rounds, p2Rounds]) {
    if (!Number.isInteger(r) || (r as number) < 0 || (r as number) > MAX_ROUNDS) return null;
  }
  return { t: "result", winner: winner as Winner, p1Rounds: p1Rounds as number, p2Rounds: p2Rounds as number };
}

function sanitizeName(name: string): string {
  return name.replace(/[^A-Za-z0-9_ ]/g, "").trim().slice(0, MAX_NAME_LENGTH);
}
