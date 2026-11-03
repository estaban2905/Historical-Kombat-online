import { test } from "node:test";
import assert from "node:assert/strict";
import { MatchmakingService } from "../../src/services/matchmaking.service.js";
import type { SettleOutcome, SettleRequest } from "../../src/services/match.service.js";
import type { Peer } from "../../src/models/player.js";
import type { ServerMessage, SettledMessage } from "../../src/models/messages.js";
import { parseClientMessage } from "../../src/validators/client-message.validator.js";

type FakePeer = Peer & { got: ServerMessage[] };
const fakePeer = (): FakePeer => {
  const got: ServerMessage[] = [];
  return { got, send: (m) => void got.push(m) };
};
const settledOf = (p: FakePeer) => p.got.find((m): m is SettledMessage => m.t === "settled");
const desyncOf = (p: FakePeer) => p.got.find((m) => m.t === "desync");
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const OUTCOME: SettleOutcome = {
  p1: { delta: 16, points: 1016, wins: 1, losses: 0 },
  p2: { delta: -16, points: 984, wins: 0, losses: 1 },
};

function ranked() {
  const calls: SettleRequest[] = [];
  const mm = new MatchmakingService(() => 1, {
    settler: async (req) => {
      calls.push(req);
      return OUTCOME;
    },
    minInputs: 3,
  });
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon", name: "ANA" }, "acc-a");
  mm.handle(b, { t: "find", fighter: "cleopatra", name: "BETO" }, "acc-b");
  return { mm, a, b, calls };
}

const sync = (f: number, c: number, v = 1) => ({ t: "sync" as const, f, c, v });

test("si los dos checksums coinciden en cada comprobación, el duelo sigue", async () => {
  const { mm, a, b, calls } = ranked();
  for (const f of [60, 120, 180]) {
    mm.handle(a, sync(f, 1000 + f));
    mm.handle(b, sync(f, 1000 + f));
  }
  await sleep(5);
  assert.equal(desyncOf(a), undefined);
  assert.equal(desyncOf(b), undefined);
  assert.equal(calls.length, 0);
});

test("si los checksums de un mismo tick difieren, el duelo se anula sin puntos para los dos", async () => {
  const { mm, a, b, calls } = ranked();
  mm.handle(a, sync(60, 111));
  mm.handle(b, sync(60, 222));
  await sleep(5);
  assert.deepEqual(desyncOf(a), { t: "desync" });
  assert.deepEqual(desyncOf(b), { t: "desync" });
  assert.equal(calls.length, 0);
  assert.equal(settledOf(a)?.ok, false);
  assert.equal(settledOf(a)?.reason, "desync");
  assert.equal(settledOf(b)?.reason, "desync");
});

test("el orden de llegada no importa: el segundo en llegar detecta la diferencia", async () => {
  const { mm, a, b } = ranked();
  mm.handle(b, sync(120, 5));
  mm.handle(a, sync(120, 6));
  assert.notEqual(desyncOf(a), undefined);
  assert.notEqual(desyncOf(b), undefined);
});

test("versiones distintas del snapshot no se comparan: no hay desincronización que anular", () => {
  const { mm, a, b } = ranked();
  mm.handle(a, sync(60, 111, 1));
  mm.handle(b, sync(60, 222, 2));
  assert.equal(desyncOf(a), undefined);
  assert.equal(desyncOf(b), undefined);
});

test("un mismo jugador no puede adelantarse al otro repitiendo el mismo tick", () => {
  const { mm, a, b } = ranked();
  mm.handle(a, sync(60, 111));
  mm.handle(a, sync(60, 999)); // se ignora: ya mandó el suyo
  mm.handle(b, sync(60, 111));
  assert.equal(desyncOf(a), undefined, "vale el primer checksum de cada uno");
});

test("la memoria está acotada si uno manda y el otro nunca", () => {
  const { mm, a, b } = ranked();
  for (let i = 1; i <= 500; i++) mm.handle(a, sync(i * 60, i));
  // El otro llega mucho después: solo se comparan los últimos que se guardaron.
  mm.handle(b, sync(500 * 60, 500));
  assert.equal(desyncOf(a), undefined);
  mm.handle(b, sync(60, 12345)); // el primero ya se olvidó: no hay con qué compararlo
  assert.equal(desyncOf(a), undefined);
});

test("un sync de quien no está en una sala se ignora", () => {
  const mm = new MatchmakingService(() => 1);
  const lone = fakePeer();
  mm.handle(lone, sync(60, 1));
  assert.deepEqual(lone.got, []);
});

test("en un duelo sin ranking solo se avisa de la desincronización", async () => {
  const calls: SettleRequest[] = [];
  const mm = new MatchmakingService(() => 1, {
    settler: async (req) => {
      calls.push(req);
      return OUTCOME;
    },
  });
  const a = fakePeer();
  const g = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" }, "acc-a");
  mm.handle(g, { t: "find", fighter: "y" });
  mm.handle(a, sync(60, 1));
  mm.handle(g, sync(60, 2));
  assert.deepEqual(desyncOf(a), { t: "desync" });
  assert.deepEqual(desyncOf(g), { t: "desync" });
  assert.equal(settledOf(a), undefined);
  assert.equal(calls.length, 0);
});

test("tras anularse por desincronización ya no se acepta un resultado", async () => {
  const { mm, a, b, calls } = ranked();
  for (let f = 0; f < 4; f++) {
    mm.handle(a, { t: "input", f, m: 1 });
    mm.handle(b, { t: "input", f, m: 2 });
  }
  mm.handle(a, sync(60, 1));
  mm.handle(b, sync(60, 2));
  mm.handle(a, { t: "result", winner: 1, p1Rounds: 2, p2Rounds: 0 });
  mm.handle(b, { t: "result", winner: 1, p1Rounds: 2, p2Rounds: 0 });
  await sleep(5);
  assert.equal(calls.length, 0);
});

test("el validador acepta sync bien formado y rechaza lo demás", () => {
  assert.deepEqual(parseClientMessage('{"t":"sync","f":60,"c":123456789,"v":1}'), { t: "sync", f: 60, c: 123456789, v: 1 });
  assert.deepEqual(parseClientMessage('{"t":"sync","f":60,"c":-5,"v":1}'), { t: "sync", f: 60, c: -5, v: 1 });
  for (const bad of [
    '{"t":"sync","f":-1,"c":1,"v":1}',
    '{"t":"sync","f":1.5,"c":1,"v":1}',
    '{"t":"sync","f":60,"c":"x","v":1}',
    '{"t":"sync","f":60,"c":1}',
    '{"t":"sync","f":60,"c":1,"v":0}',
    '{"t":"sync","f":60,"c":1,"v":1e9}',
    '{"t":"sync","f":60,"c":1.5,"v":1}',
    '{"t":"sync"}',
  ]) {
    assert.equal(parseClientMessage(bad), null, bad);
  }
});
