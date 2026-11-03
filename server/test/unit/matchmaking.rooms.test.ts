import { test } from "node:test";
import assert from "node:assert/strict";
import { MatchmakingService } from "../../src/services/matchmaking.service.js";
import type { SettleOutcome } from "../../src/services/match.service.js";
import type { Peer } from "../../src/models/player.js";
import type { MatchedMessage, ServerMessage } from "../../src/models/messages.js";

type FakePeer = Peer & { got: ServerMessage[] };
const fakePeer = (): FakePeer => {
  const got: ServerMessage[] = [];
  return { got, send: (m) => void got.push(m) };
};
const matchedOf = (p: FakePeer) => p.got.find((m): m is MatchedMessage => m.t === "matched");
const isQueued = (p: FakePeer) => p.got.some((m) => m.t === "queued");

const OUTCOME: SettleOutcome = {
  p1: { delta: 16, points: 1016, wins: 1, losses: 0 },
  p2: { delta: -16, points: 984, wins: 0, losses: 1 },
};
const service = () => new MatchmakingService(() => 1, { settler: async () => OUTCOME });

test("dos jugadores con el mismo código de reto se emparejan, y el duelo es amistoso", () => {
  const mm = service();
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon", room: "ABCD2345" }, "acc-a");
  assert.equal(isQueued(a), true);
  mm.handle(b, { t: "find", fighter: "cleopatra", room: "ABCD2345" }, "acc-b");
  assert.equal(matchedOf(a)?.ranked, false, "dos cuentas, pero en un reto: no cuenta para el ranking");
  assert.equal(matchedOf(b)?.ranked, false);
  assert.equal(matchedOf(a)?.opponent.fighter, "cleopatra");
});

test("una sala de reto nunca se mezcla con la cola pública", () => {
  const mm = service();
  const publica = fakePeer();
  const reto = fakePeer();
  mm.handle(publica, { t: "find", fighter: "napoleon" }, "acc-a");
  mm.handle(reto, { t: "find", fighter: "cleopatra", room: "ABCD2345" }, "acc-b");
  assert.equal(matchedOf(publica), undefined);
  assert.equal(matchedOf(reto), undefined);
  assert.equal(isQueued(reto), true, "el del reto espera a su amigo, no al primero que pase");
});

test("y al revés: quien busca partida pública no entra a una sala de reto", () => {
  const mm = service();
  const reto = fakePeer();
  const publica = fakePeer();
  mm.handle(reto, { t: "find", fighter: "napoleon", room: "ABCD2345" }, "acc-a");
  mm.handle(publica, { t: "find", fighter: "cleopatra" }, "acc-b");
  assert.equal(matchedOf(reto), undefined);
  assert.equal(matchedOf(publica), undefined);
});

test("códigos distintos no se emparejan", () => {
  const mm = service();
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon", room: "AAAA2222" }, "acc-a");
  mm.handle(b, { t: "find", fighter: "cleopatra", room: "BBBB3333" }, "acc-b");
  assert.equal(matchedOf(a), undefined);
  assert.equal(matchedOf(b), undefined);
});

test("la misma cuenta con dos pestañas en una sala no se empareja consigo misma", () => {
  const mm = service();
  const a = fakePeer();
  const a2 = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon", room: "ABCD2345" }, "acc-a");
  mm.handle(a2, { t: "find", fighter: "napoleon", room: "ABCD2345" }, "acc-a");
  assert.equal(matchedOf(a), undefined);
  assert.equal(matchedOf(a2), undefined);
});

test("la cola pública sigue funcionando y sigue contando para el ranking", () => {
  const mm = service();
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon" }, "acc-a");
  mm.handle(b, { t: "find", fighter: "cleopatra" }, "acc-b");
  assert.equal(matchedOf(a)?.ranked, true);
});

test("cancelar saca de la sala de reto", () => {
  const mm = service();
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon", room: "ABCD2345" }, "acc-a");
  mm.handle(a, { t: "cancel" });
  mm.handle(b, { t: "find", fighter: "cleopatra", room: "ABCD2345" }, "acc-b");
  assert.equal(matchedOf(b), undefined, "ya no hay nadie esperando");
  assert.equal(mm.stats().queued, 1);
});
