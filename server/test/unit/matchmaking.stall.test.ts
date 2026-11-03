import { test } from "node:test";
import assert from "node:assert/strict";
import { MatchmakingService } from "../../src/services/matchmaking.service.js";
import type { SettleOutcome, SettleRequest } from "../../src/services/match.service.js";
import type { Peer } from "../../src/models/player.js";
import type { ServerMessage, SettledMessage } from "../../src/models/messages.js";

type FakePeer = Peer & { got: ServerMessage[] };
const fakePeer = (): FakePeer => {
  const got: ServerMessage[] = [];
  return { got, send: (m) => void got.push(m) };
};
const settledOf = (p: FakePeer) => p.got.find((m): m is SettledMessage => m.t === "settled");
const timeoutOf = (p: FakePeer) => p.got.find((m) => m.t === "timeout");
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const OUTCOME: SettleOutcome = {
  p1: { delta: 16, points: 1016, wins: 1, losses: 0 },
  p2: { delta: -16, points: 984, wins: 0, losses: 1 },
};
const STALL_MS = 40;

/**
 * Dos cuentas emparejadas; la espera se agota a los 40 ms. Por defecto basta que la pelea avance un tick para
 * reiniciarla: así estas pruebas no dependen del ritmo mínimo real (60 ticks), que se prueba aparte.
 */
function ranked(stallMinTicks = 1, stallStartGraceMs = 0) {
  const calls: SettleRequest[] = [];
  const mm = new MatchmakingService(() => 1, {
    settler: async (req) => {
      calls.push(req);
      return OUTCOME;
    },
    minInputs: 3,
    stallTimeoutMs: STALL_MS,
    stallMinTicks,
    stallStartGraceMs,
  });
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon", name: "ANA" }, "acc-a");
  mm.handle(b, { t: "find", fighter: "cleopatra", name: "BETO" }, "acc-b");
  return { mm, a, b, calls };
}

/** `from`..`to` (incluidos): los inputs que ese jugador manda en esos ticks. */
function send(mm: MatchmakingService, peer: Peer, from: number, to: number) {
  for (let f = from; f <= to; f++) mm.handle(peer, { t: "input", f, m: 1 });
}

// Cuando un jugador se congela (pestaña oculta), el otro sigue enviando unos ticks adelantados y luego
// también se queda esperando: los dos dejan de enviar. El culpable es el que va por detrás en frames.

test("si un jugador deja de enviar, pierde él aunque el otro también se haya quedado esperando", async () => {
  const { mm, a, b, calls } = ranked();
  send(mm, a, 0, 5); // P1 se congela en el tick 5
  send(mm, b, 0, 9); // P2 llega unos ticks más lejos y se queda esperando
  await sleep(STALL_MS * 3);
  assert.deepEqual(timeoutOf(a), { t: "timeout", loser: 1 });
  assert.deepEqual(timeoutOf(b), { t: "timeout", loser: 1 });
  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.winner, 2, "gana quien se quedó esperando");
  assert.equal(calls[0]?.reason, "forfeit");
  assert.equal(settledOf(b)?.ok, true);
  assert.equal(settledOf(a)?.reason, "forfeit");
});

test("si el congelado es P2, gana P1", async () => {
  const { mm, a, b, calls } = ranked();
  send(mm, a, 0, 9);
  send(mm, b, 0, 5);
  await sleep(STALL_MS * 3);
  assert.deepEqual(timeoutOf(a), { t: "timeout", loser: 2 });
  assert.equal(calls[0]?.winner, 1);
});

test("si no se puede saber quién tiene la culpa, el duelo se anula sin puntos", async () => {
  const { mm, a, b, calls } = ranked();
  send(mm, a, 0, 5);
  send(mm, b, 0, 5);
  await sleep(STALL_MS * 3);
  assert.deepEqual(timeoutOf(a), { t: "timeout", loser: 0 });
  assert.deepEqual(timeoutOf(b), { t: "timeout", loser: 0 });
  assert.equal(calls.length, 0);
  assert.equal(settledOf(a)?.ok, false);
  assert.equal(settledOf(a)?.reason, "stalled");
});

test("mientras lleguen inputs de cualquiera de los dos no se agota la espera", async () => {
  const { mm, a, b, calls } = ranked();
  for (let i = 0; i < 8; i++) {
    send(mm, a, i, i);
    send(mm, b, i, i);
    await sleep(STALL_MS / 2);
  }
  assert.equal(timeoutOf(a), undefined);
  assert.equal(calls.length, 0);
  await sleep(STALL_MS * 3); // ahora sí: silencio
  assert.notEqual(timeoutOf(a), undefined);
});

test("un goteo de inputs sueltos no mantiene vivo el duelo: cuenta lo que avanza la pelea, no los mensajes", async () => {
  const { mm, a, b, calls } = ranked(20); // la pelea debe avanzar 20 ticks por espera
  send(mm, a, 0, 5); // P1 se congela...
  send(mm, b, 0, 9);
  // ...y solo suelta un input cada 15 ms (menos que los 40 ms de espera). P2, honesto, responde cada uno.
  for (let i = 6; i < 14; i++) {
    mm.handle(a, { t: "input", f: i, m: 1 });
    mm.handle(b, { t: "input", f: i + 4, m: 1 });
    await sleep(15);
  }
  assert.deepEqual(timeoutOf(a), { t: "timeout", loser: 1 });
  assert.equal(calls[0]?.winner, 2);
  assert.equal(calls[0]?.reason, "forfeit");
});

test("si la pelea avanza al ritmo mínimo, el goteo no se confunde con una congelación", async () => {
  const { mm, a, b } = ranked(2); // basta con 2 ticks por espera
  for (let t = 0; t < 8; t++) {
    mm.handle(a, { t: "input", f: t * 2, m: 1 });
    mm.handle(a, { t: "input", f: t * 2 + 1, m: 1 });
    mm.handle(b, { t: "input", f: t * 2, m: 1 });
    mm.handle(b, { t: "input", f: t * 2 + 1, m: 1 });
    await sleep(STALL_MS / 4);
  }
  assert.equal(timeoutOf(a), undefined);
  assert.equal(timeoutOf(b), undefined);
});

// Cargar la escena de pelea tarda distinto en cada equipo: el que arranca primero no puede ganar por esperar.

test("quien tarda en cargar la pelea no pierde por ello: el reloj de la espera solo corre cuando están los dos", async () => {
  const { mm, a, b, calls } = ranked(1, STALL_MS * 6); // margen de arranque de 240 ms
  send(mm, a, 0, 5); // P1 ya está peleando...
  await sleep(STALL_MS * 3); // ...y P2 sigue cargando: más que la espera normal, menos que el margen
  assert.equal(timeoutOf(a), undefined);
  send(mm, b, 0, 5); // P2 llega
  await sleep(STALL_MS / 2);
  assert.equal(timeoutOf(a), undefined, "la espera normal cuenta desde que llegó el segundo, no desde el primero");
  await sleep(STALL_MS * 3); // ahora sí: los dos callan
  assert.notEqual(timeoutOf(a), undefined);
  assert.equal(calls.length, 0, "iban igualados: se anula sin puntos");
});

test("si el segundo nunca llega a cargar, agota el margen y pierde", async () => {
  const { mm, a, b, calls } = ranked(1, STALL_MS * 3);
  send(mm, a, 0, 5);
  await sleep(STALL_MS * 6);
  assert.deepEqual(timeoutOf(a), { t: "timeout", loser: 2 });
  assert.deepEqual(timeoutOf(b), { t: "timeout", loser: 2 });
  assert.equal(calls[0]?.winner, 1);
  assert.equal(calls[0]?.reason, "forfeit");
});

test("una pelea cortísima congelada no regala la victoria", async () => {
  const { mm, a, b, calls } = ranked();
  send(mm, a, 0, 0);
  send(mm, b, 0, 1);
  await sleep(STALL_MS * 3);
  assert.equal(calls.length, 0);
  assert.equal(settledOf(b)?.reason, "too_short");
});

test("al reportar su resultado, la pelea terminó: ya no se espera a los inputs", async () => {
  const { mm, a, b } = ranked();
  send(mm, a, 0, 5);
  send(mm, b, 0, 5);
  mm.handle(a, { t: "result", winner: 1, p1Rounds: 2, p2Rounds: 0 });
  await sleep(STALL_MS * 3);
  assert.equal(timeoutOf(a), undefined);
  assert.equal(timeoutOf(b), undefined);
});

test("si uno se desconecta, el abandono ya lo resuelve y no se avisa dos veces", async () => {
  const { mm, a, b, calls } = ranked();
  send(mm, a, 0, 5);
  send(mm, b, 0, 5);
  mm.disconnect(a);
  await sleep(STALL_MS * 3);
  assert.equal(timeoutOf(b), undefined);
  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.reason, "forfeit");
});

test("en un duelo sin ranking solo se avisa: no hay puntos que repartir", async () => {
  const calls: SettleRequest[] = [];
  const mm = new MatchmakingService(() => 1, {
    settler: async (req) => {
      calls.push(req);
      return OUTCOME;
    },
    stallTimeoutMs: STALL_MS,
  });
  const a = fakePeer();
  const g = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" }, "acc-a");
  mm.handle(g, { t: "find", fighter: "y" });
  send(mm, a, 0, 3);
  send(mm, g, 0, 9);
  await sleep(STALL_MS * 3);
  assert.deepEqual(timeoutOf(a), { t: "timeout", loser: 1 });
  assert.deepEqual(timeoutOf(g), { t: "timeout", loser: 1 });
  assert.equal(calls.length, 0);
  assert.equal(settledOf(a), undefined);
});

test("quien se queda puede buscar otra partida tras agotarse la espera", async () => {
  const { mm, a, b } = ranked();
  send(mm, a, 0, 5);
  send(mm, b, 0, 9);
  await sleep(STALL_MS * 3);
  mm.handle(b, { t: "find", fighter: "y" }, "acc-b");
  assert.deepEqual(b.got.at(-1), { t: "queued" });
});
