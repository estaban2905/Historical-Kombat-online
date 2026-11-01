import { test } from "node:test";
import assert from "node:assert/strict";
import { MatchmakingService } from "../../src/services/matchmaking.service.js";
import type { Peer } from "../../src/models/player.js";
import type { ServerMessage } from "../../src/models/messages.js";

function fakePeer(): Peer & { got: ServerMessage[] } {
  const got: ServerMessage[] = [];
  return { got, send: (m) => void got.push(m) };
}

test("un jugador solo queda en cola", () => {
  const mm = new MatchmakingService(() => 1);
  const a = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon" });
  assert.deepEqual(a.got, [{ t: "queued" }]);
  assert.equal(mm.stats().queued, 1);
});

test("dos jugadores se emparejan: el primero es P1, misma semilla", () => {
  const mm = new MatchmakingService(() => 42);
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "napoleon", name: "ANA" });
  mm.handle(b, { t: "find", fighter: "cleopatra", name: "BETO" });

  assert.deepEqual(a.got.at(-1), {
    t: "matched", side: 1, seed: 42, ranked: false, opponent: { fighter: "cleopatra", name: "BETO" },
  });
  assert.deepEqual(b.got.at(-1), {
    t: "matched", side: 2, seed: 42, ranked: false, opponent: { fighter: "napoleon", name: "ANA" },
  });
  assert.deepEqual(mm.stats(), { queued: 0, rooms: 1 });
});

test("los inputs se reenvían solo al rival", () => {
  const mm = new MatchmakingService();
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" });
  mm.handle(b, { t: "find", fighter: "y" });
  mm.handle(a, { t: "input", f: 10, m: 5 });

  assert.deepEqual(b.got.at(-1), { t: "input", f: 10, m: 5 });
  assert.equal(a.got.some((m) => m.t === "input"), false);
});

test("un input sin partida se ignora", () => {
  const mm = new MatchmakingService();
  const a = fakePeer();
  mm.handle(a, { t: "input", f: 1, m: 1 });
  assert.deepEqual(a.got, []);
});

test("si uno se desconecta, el rival recibe opponent_left y puede volver a buscar", () => {
  const mm = new MatchmakingService();
  const a = fakePeer();
  const b = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" });
  mm.handle(b, { t: "find", fighter: "y" });
  mm.disconnect(a);

  assert.deepEqual(b.got.at(-1), { t: "opponent_left" });
  assert.equal(mm.stats().rooms, 0);

  mm.handle(b, { t: "find", fighter: "y" });
  assert.deepEqual(b.got.at(-1), { t: "queued" });
});

test("cancelar saca al jugador de la cola", () => {
  const mm = new MatchmakingService();
  const a = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" });
  mm.handle(a, { t: "cancel" });
  assert.equal(mm.stats().queued, 0);

  const c = fakePeer();
  mm.handle(c, { t: "find", fighter: "z" });
  assert.deepEqual(c.got, [{ t: "queued" }]);
});

test("el que se desconecta en cola no se empareja después", () => {
  const mm = new MatchmakingService();
  const a = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" });
  mm.disconnect(a);
  const b = fakePeer();
  mm.handle(b, { t: "find", fighter: "y" });
  assert.deepEqual(b.got, [{ t: "queued" }]);
});

test("no se puede buscar partida dos veces", () => {
  const mm = new MatchmakingService();
  const a = fakePeer();
  mm.handle(a, { t: "find", fighter: "x" });
  mm.handle(a, { t: "find", fighter: "x" });
  assert.equal(a.got.at(-1)?.t, "error");
  assert.equal(mm.stats().queued, 1);
});
