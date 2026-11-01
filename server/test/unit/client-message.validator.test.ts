import { test } from "node:test";
import assert from "node:assert/strict";
import { parseClientMessage } from "../../src/validators/client-message.validator.js";

test("find válido y nombre limpiado", () => {
  assert.deepEqual(parseClientMessage('{"t":"find","fighter":"napoleon","name":"  <b>Ana</b>! "}'), {
    t: "find", fighter: "napoleon", name: "bAnab",
  });
});

test("find con luchador inválido se rechaza", () => {
  assert.equal(parseClientMessage('{"t":"find","fighter":"../etc"}'), null);
  assert.equal(parseClientMessage('{"t":"find","fighter":5}'), null);
  assert.equal(parseClientMessage('{"t":"find"}'), null);
});

test("input válido", () => {
  assert.deepEqual(parseClientMessage('{"t":"input","f":12,"m":255}'), { t: "input", f: 12, m: 255 });
});

test("input fuera de rango o con tipos raros se rechaza", () => {
  assert.equal(parseClientMessage('{"t":"input","f":-1,"m":1}'), null);
  assert.equal(parseClientMessage('{"t":"input","f":1.5,"m":1}'), null);
  assert.equal(parseClientMessage('{"t":"input","f":1,"m":70000}'), null);
  assert.equal(parseClientMessage('{"t":"input","f":"1","m":1}'), null);
});

test("basura y tipos desconocidos se rechazan", () => {
  assert.equal(parseClientMessage("no es json"), null);
  assert.equal(parseClientMessage("null"), null);
  assert.equal(parseClientMessage('{"t":"hack"}'), null);
});

test("cancel y leave", () => {
  assert.deepEqual(parseClientMessage('{"t":"cancel"}'), { t: "cancel" });
  assert.deepEqual(parseClientMessage('{"t":"leave"}'), { t: "leave" });
});

test("find con token: se conserva; un token mal formado se rechaza", () => {
  assert.deepEqual(parseClientMessage('{"t":"find","fighter":"napoleon","token":"abc.def"}'), {
    t: "find", fighter: "napoleon", name: "", token: "abc.def",
  });
  assert.equal(parseClientMessage('{"t":"find","fighter":"napoleon","token":5}'), null);
  assert.equal(parseClientMessage('{"t":"find","fighter":"napoleon","token":""}'), null);
  assert.equal(parseClientMessage(`{"t":"find","fighter":"napoleon","token":"${"x".repeat(201)}"}`), null);
});

test("result válido y con valores fuera de rango", () => {
  assert.deepEqual(parseClientMessage('{"t":"result","winner":1,"p1Rounds":2,"p2Rounds":1}'), {
    t: "result", winner: 1, p1Rounds: 2, p2Rounds: 1,
  });
  assert.deepEqual(parseClientMessage('{"t":"result","winner":0,"p1Rounds":1,"p2Rounds":1}'), {
    t: "result", winner: 0, p1Rounds: 1, p2Rounds: 1,
  });
  for (const bad of [
    '{"t":"result","winner":3,"p1Rounds":2,"p2Rounds":1}',
    '{"t":"result","winner":"1","p1Rounds":2,"p2Rounds":1}',
    '{"t":"result","winner":1,"p1Rounds":-1,"p2Rounds":1}',
    '{"t":"result","winner":1,"p1Rounds":2,"p2Rounds":99}',
    '{"t":"result","winner":1,"p1Rounds":1.5,"p2Rounds":1}',
    '{"t":"result","winner":1}',
  ]) {
    assert.equal(parseClientMessage(bad), null, bad);
  }
});
