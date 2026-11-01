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
const last = (p: FakePeer) => p.got.at(-1);
const settledOf = (p: FakePeer) => p.got.find((m): m is SettledMessage => m.t === "settled");
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const OUTCOME: SettleOutcome = {
  p1: { delta: 16, points: 1016, wins: 1, losses: 0 },
  p2: { delta: -16, points: 984, wins: 0, losses: 1 },
};

/** Dos cuentas emparejadas, con un "guardador" falso que apunta lo que recibe. */
function ranked(options: { minInputs?: number; settleTimeoutMs?: number } = {}) {
  const calls: SettleRequest[] = [];
  const mm = new MatchmakingService(() => 1, {
    settler: async (req) => {
      calls.push(req);
      return OUTCOME;
    },
    minInputs: 3,
    ...options,
  });
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon", name: "ANA" }, "acc-a");
  mm.handle(b, { t: "find", fighter: "cleopatra", name: "BETO" }, "acc-b");
  return { mm, a, b, calls };
}

/** Los dos mandan algunos inputs: la pelea "empezó" y duró lo suficiente. */
function play(mm: MatchmakingService, a: Peer, b: Peer, ticks = 3) {
  for (let i = 0; i < ticks; i++) {
    mm.handle(a, { t: "input", f: i, m: 1 });
    mm.handle(b, { t: "input", f: i, m: 2 });
  }
}

const result = (winner: 0 | 1 | 2, p1Rounds = 2, p2Rounds = 0) => ({ t: "result" as const, winner, p1Rounds, p2Rounds });

test("dos cuentas distintas forman un duelo con ranking", () => {
  const { a, b } = ranked();
  assert.equal((a.got.at(-1) as { ranked: boolean }).ranked, true);
  assert.equal((b.got.at(-1) as { ranked: boolean }).ranked, true);
});

test("con un invitado el duelo no cuenta", () => {
  const mm = new MatchmakingService(() => 1, { settler: async () => OUTCOME });
  const a = fakePeer();
  const g = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" }, "acc-a");
  mm.handle(g, { t: "find", fighter: "y" });
  assert.equal((a.got.at(-1) as { ranked: boolean }).ranked, false);
});

test("sin guardador (sin base de datos) ningún duelo cuenta", () => {
  const mm = new MatchmakingService(() => 1);
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" }, "acc-a");
  mm.handle(b, { t: "find", fighter: "y" }, "acc-b");
  assert.equal((a.got.at(-1) as { ranked: boolean }).ranked, false);
});

test("una cuenta no se empareja consigo misma (dos pestañas)", () => {
  const mm = new MatchmakingService(() => 1, { settler: async () => OUTCOME });
  const tab1 = fakePeer();
  const tab2 = fakePeer();
  mm.handle(tab1, { t: "find", fighter: "x" }, "acc-a");
  mm.handle(tab2, { t: "find", fighter: "y" }, "acc-a");
  assert.deepEqual(last(tab2), { t: "queued" });
  assert.equal(mm.stats().queued, 2);
  // Pero sí con otra persona.
  const other = fakePeer();
  mm.handle(other, { t: "find", fighter: "z" }, "acc-b");
  assert.equal(last(other)?.t, "matched");
  assert.equal(mm.stats().queued, 1);
});

test("si los dos reportan lo mismo, se guarda y cada uno recibe SUS puntos", async () => {
  const { mm, a, b, calls } = ranked();
  play(mm, a, b);
  mm.handle(a, result(1));
  assert.equal(settledOf(a), undefined, "con un solo reporte todavía no se guarda");
  mm.handle(b, result(1));
  await sleep(5);
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0], {
    p1Id: "acc-a", p2Id: "acc-b", p1Fighter: "napoleon", p2Fighter: "cleopatra",
    winner: 1, p1Rounds: 2, p2Rounds: 0, reason: "normal",
  });
  assert.deepEqual(settledOf(a), { t: "settled", ranked: true, ok: true, delta: 16, points: 1016, wins: 1, losses: 0 });
  assert.deepEqual(settledOf(b), { t: "settled", ranked: true, ok: true, delta: -16, points: 984, wins: 0, losses: 1 });
});

test("si los reportes no coinciden, no se guarda nada", async () => {
  const { mm, a, b, calls } = ranked();
  play(mm, a, b);
  mm.handle(a, result(1));
  mm.handle(b, result(2, 0, 2)); // el rival dice que ganó él
  await sleep(5);
  assert.equal(calls.length, 0);
  assert.equal(settledOf(a)?.ok, false);
  assert.equal(settledOf(a)?.reason, "mismatch");
  assert.equal(settledOf(b)?.reason, "mismatch");
});

test("un duelo demasiado corto no cuenta", async () => {
  const { mm, a, b, calls } = ranked({ minInputs: 100 });
  play(mm, a, b, 3);
  mm.handle(a, result(1));
  mm.handle(b, result(1));
  await sleep(5);
  assert.equal(calls.length, 0);
  assert.equal(settledOf(a)?.reason, "too_short");
});

test("si solo uno reporta, el duelo se descarta al pasar el tiempo", async () => {
  const { mm, a, b, calls } = ranked({ settleTimeoutMs: 20 });
  play(mm, a, b);
  mm.handle(a, result(1));
  await sleep(60);
  assert.equal(calls.length, 0);
  assert.equal(settledOf(a)?.reason, "timeout");
  assert.equal(settledOf(b)?.reason, "timeout");
});

test("el segundo reporte llega después de que el primero se fue: se guarda igual", async () => {
  // Pasa siempre: quien termina antes sale a Resultados y se desconecta; el otro aún termina su pelea.
  const { mm, a, b, calls } = ranked();
  play(mm, a, b);
  mm.handle(a, result(1));
  mm.disconnect(a);
  assert.equal(last(b)?.t, "opponent_left");
  assert.equal(calls.length, 0, "irse tras reportar no es abandonar");
  mm.handle(b, result(1));
  await sleep(5);
  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.reason, "normal");
  assert.equal(settledOf(b)?.ok, true);
});

test("irse en plena pelea sin reportar es abandono: gana el que se quedó", async () => {
  const { mm, a, b, calls } = ranked();
  play(mm, a, b);
  mm.disconnect(a); // P1 se va
  await sleep(5);
  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.winner, 2);
  assert.equal(calls[0]?.reason, "forfeit");
  assert.equal(settledOf(b)?.reason, "forfeit");
  assert.equal(settledOf(b)?.ok, true);
});

test("abandonar un duelo cortísimo no regala la victoria", async () => {
  const { mm, a, b, calls } = ranked({ minInputs: 100 });
  play(mm, a, b, 2);
  mm.disconnect(a);
  await sleep(5);
  assert.equal(calls.length, 0);
  assert.equal(settledOf(b)?.reason, "too_short");
});

test("irse antes de que empiece la pelea no es abandono", async () => {
  const { mm, a, b, calls } = ranked();
  mm.disconnect(a); // todavía en la pantalla VS: no hubo inputs
  await sleep(5);
  assert.equal(calls.length, 0);
  assert.equal(settledOf(b), undefined);
  assert.equal(last(b)?.t, "opponent_left");
});

test("un jugador no puede reportar dos veces ni después de guardado", async () => {
  const { mm, a, b, calls } = ranked();
  play(mm, a, b);
  mm.handle(a, result(1));
  mm.handle(a, result(2, 0, 2)); // intento de cambiar su reporte
  mm.handle(b, result(1));
  await sleep(5);
  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.winner, 1, "vale el primer reporte");
  mm.handle(a, result(2, 0, 2));
  mm.handle(b, result(2, 0, 2));
  await sleep(5);
  assert.equal(calls.length, 1, "ya guardado: no se vuelve a guardar");
});

test("si falla la base de datos, nadie gana ni pierde y se avisa", async () => {
  const errors: unknown[] = [];
  const mm = new MatchmakingService(() => 1, {
    settler: async () => {
      throw new Error("base de datos caída");
    },
    minInputs: 1,
    onError: (e) => errors.push(e),
  });
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" }, "acc-a");
  mm.handle(b, { t: "find", fighter: "y" }, "acc-b");
  play(mm, a, b, 1);
  mm.handle(a, result(1));
  mm.handle(b, result(1));
  await sleep(5);
  assert.equal(errors.length, 1);
  assert.equal(settledOf(a)?.ok, false);
  assert.equal(settledOf(a)?.reason, "error");
});

test("en un duelo sin ranking, reportar solo responde 'sin ranking'", () => {
  const mm = new MatchmakingService(() => 1, { settler: async () => OUTCOME });
  const a = fakePeer();
  const g = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" }, "acc-a");
  mm.handle(g, { t: "find", fighter: "y" });
  mm.handle(a, result(1));
  assert.deepEqual(settledOf(a), { t: "settled", ranked: false, ok: true, delta: 0, points: 0, wins: 0, losses: 0 });
});

test("quien se queda puede buscar otra partida tras irse su rival", () => {
  const { mm, a, b } = ranked();
  play(mm, a, b);
  mm.disconnect(a);
  mm.handle(b, { t: "find", fighter: "y" }, "acc-b");
  assert.deepEqual(last(b), { t: "queued" });
});
