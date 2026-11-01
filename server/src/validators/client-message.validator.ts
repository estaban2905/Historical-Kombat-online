import type { ClientMessage } from "../models/messages.js";

export const MAX_NAME_LENGTH = 16;
export const MAX_FIGHTER_LENGTH = 40;
/** Los inputs son una máscara de bits de botones; 16 bits sobran. */
export const MAX_INPUT_MASK = 0xffff;

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
  return { t: "find", fighter, name };
}

function parseInput(msg: Record<string, unknown>): ClientMessage | null {
  const f = msg["f"];
  const m = msg["m"];
  if (!Number.isInteger(f) || (f as number) < 0) return null;
  if (!Number.isInteger(m) || (m as number) < 0 || (m as number) > MAX_INPUT_MASK) return null;
  return { t: "input", f: f as number, m: m as number };
}

function sanitizeName(name: string): string {
  return name.replace(/[^A-Za-z0-9_ ]/g, "").trim().slice(0, MAX_NAME_LENGTH);
}
