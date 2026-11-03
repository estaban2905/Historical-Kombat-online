import { test } from "node:test";
import assert from "node:assert/strict";
import { MatchmakingService, type SuspiciousEvent } from "../../src/services/matchmaking.service.js";
import type { SettleOutcome, SettleRequest } from "../../src/services/match.service.js";
import type { Peer } from "../../src/models/player.js";
import type { ServerMessage } from "../../src/models/messages.js";

type FakePeer = Peer & { got: ServerMessage[] };
const fakePeer = (): FakePeer => {
  const got: ServerMessage[] = [];
  return { got, send: (m) => void got.push(m) };
};
const inputsReceivedBy = (p: FakePeer) => p.got.filter((m) => m.t === "input").length;
const timeoutOf = (p: FakePeer) => p.got.find((m) => m.t === "timeout");
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const OUTCOME: SettleOutcome = {
  p1: { delta: 16, points: 1016, wins: 1, losses: 0 },
  p2: { delta: -16, points: 984, wins: 0, losses: 1 },
};
const STALL_MS = 40;

// El tick `f` de cada input lo manda el cliente, y en una pelea parada pierde quien iba por detrás en ticks.
// Si el servidor aceptara cualquier `f`, un cliente que va perdiendo mandaría uno enorme y se quedaría callado
// para que el honesto figure como el que se congeló.

function ranked() {
  const calls: SettleRequest[] = [];
  const events: SuspiciousEvent[] = [];
  const mm = new MatchmakingService(() => 1, {
    settler: async (req) => {
      calls.push(req);
      return OUTCOME;
    },
    minInputs: 3,
    stallTimeoutMs: STALL_MS,
    stallMinTicks: 1,
    onSuspicious: (e) => events.push(e),
  });
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon", name: "ANA" }, "acc-a");
  mm.handle(b, { t: "find", fighter: "cleopatra", name: "BETO" }, "acc-b");
  return { mm, a, b, calls, events };
}

const input = (mm: MatchmakingService, peer: Peer, f: number) => mm.handle(peer, { t: "input", f, m: 1 });
function send(mm: MatchmakingService, peer: Peer, from: number, to: number) {
  for (let f = from; f <= to; f++) input(mm, peer, f);
}

test("un tick desorbitado se ignora: no se reenvía y no sirve para ganar la espera", async () => {
  const { mm, a, b, calls, events } = ranked();
  send(mm, a, 4, 8);
  send(mm, b, 4, 12); // P2 es honesto y sigue hasta quedarse esperando a P1
  input(mm, a, 999_999); // P1 va perdiendo: manda un tick imposible y se queda callado
  await sleep(STALL_MS * 3);

  assert.equal(inputsReceivedBy(b), 5, "a P2 solo le llegan los ticks válidos de P1 (4 a 8)");
  assert.deepEqual(timeoutOf(a), { t: "timeout", loser: 1 }, "el que se calla pierde, por mucho que haya mandado");
  assert.equal(calls.length, 1);
  assert.equal(calls[0]?.winner, 2, "gana el honesto");
  assert.equal(calls[0]?.reason, "forfeit");
  assert.deepEqual(events, [{ kind: "frame_out_of_range", accountId: "acc-a", frame: 999_999, limit: 12 + 20 }]);
});

test("solo se avisa del primer tick imposible de cada jugador, no de cada uno", () => {
  const { mm, a, events } = ranked();
  send(mm, a, 4, 6);
  for (let i = 0; i < 50; i++) input(mm, a, 10_000 + i);
  assert.equal(events.length, 1);
});

test("hasta dónde puede adelantarse: 20 ticks al último del rival, ni uno más", () => {
  const { mm, a, b } = ranked();
  send(mm, b, 4, 10); // el último de P2 es el 10
  send(mm, a, 4, 30); // 10 + 20
  assert.equal(inputsReceivedBy(b), 27, "del 4 al 30 llegan todos");
  input(mm, a, 31);
  assert.equal(inputsReceivedBy(b), 27, "el 31 se pasa");
});

test("un cliente honesto con el retraso máximo nunca es rechazado", () => {
  // Esperando el tick siguiente al último del rival, un cliente con retraso 15 ya mandó hasta rival + 16.
  const { mm, a, b, events } = ranked();
  send(mm, b, 4, 10);
  send(mm, a, 4, 10 + 16);
  assert.equal(inputsReceivedBy(b), 23);
  assert.deepEqual(events, []);
});

test("al empezar, antes de que el rival mande nada, se acepta el arranque normal", () => {
  const { mm, a, events } = ranked();
  send(mm, a, 4, 7); // ticks 0 a 3 sin esperar, con el retraso inicial de 4
  assert.deepEqual(events, []);
});

test("una pelea entera con retraso máximo en los dos lados no rechaza nada", () => {
  const { mm, a, b, events } = ranked();
  const DELAY = 15;
  const sentUntil = { a: 3, b: 3 };
  for (let tick = 0; tick < 600; tick++) {
    for (const [name, peer] of [["a", a], ["b", b]] as const) {
      send(mm, peer, sentUntil[name] + 1, tick + DELAY);
      sentUntil[name] = Math.max(sentUntil[name], tick + DELAY);
    }
  }
  assert.deepEqual(events, []);
  assert.equal(inputsReceivedBy(b), 611, "del tick 4 al 614 (el 599 del bucle más el retraso), todos");
});

test("repetir un tick o volver atrás se ignora y no infla el conteo de inputs", () => {
  const { mm, a, b } = ranked();
  send(mm, a, 4, 6);
  for (let i = 0; i < 10; i++) input(mm, a, 6);
  input(mm, a, 2);
  assert.equal(inputsReceivedBy(b), 3, "solo llegan 4, 5 y 6");
});

test("un duelo con ticks repetidos no llega a los inputs mínimos para contar", async () => {
  const { mm, a, b, calls } = ranked(); // minInputs: 3
  send(mm, a, 4, 4);
  for (let i = 0; i < 100; i++) input(mm, a, 4); // 100 mensajes, un solo tick
  send(mm, b, 4, 8);
  mm.handle(a, { t: "result", winner: 1, p1Rounds: 2, p2Rounds: 0 });
  mm.handle(b, { t: "result", winner: 1, p1Rounds: 2, p2Rounds: 0 });
  await sleep(5);
  assert.equal(calls.length, 0, "P1 solo aportó un input válido");
});
