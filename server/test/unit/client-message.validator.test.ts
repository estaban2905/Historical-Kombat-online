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
