import { test } from "node:test";
import assert from "node:assert/strict";
import { ChallengeService, randomCode } from "../../src/services/challenge.service.js";

/** Un servicio con reloj propio (se adelanta a mano) y códigos predecibles. */
function setup(ttlMs = 1000) {
  let clock = 1_000_000;
  let n = 0;
  const svc = new ChallengeService(() => clock, ttlMs, () => `CODIGO${++n}`);
  return { svc, advance: (ms: number) => void (clock += ms) };
}
const ana = { id: "ana", name: "ANA" };

test("el retado ve el reto con el nombre de quien lo hizo y los segundos que le quedan", () => {
  const { svc } = setup(120_000);
  const c = svc.create(ana, "beto");
  const [seen] = svc.incoming("beto");
  assert.equal(seen?.code, c.code);
  assert.equal(seen?.fromName, "ANA");
  assert.equal(svc.secondsLeft(seen!), 120);
  assert.deepEqual(svc.incoming("ana"), [], "quien reta no lo ve entrante");
  assert.deepEqual(svc.incoming("carla"), [], "ni un tercero");
});

test("un reto caduca solo", () => {
  const { svc, advance } = setup(1000);
  const c = svc.create(ana, "beto");
  advance(999);
  assert.equal(svc.incoming("beto").length, 1);
  advance(1);
  assert.deepEqual(svc.incoming("beto"), []);
  assert.equal(svc.join(c.code, "ana"), false, "caducado: ya no se entra");
});

test("un reto nuevo cancela el anterior del mismo jugador, pero no los de otros", () => {
  const { svc } = setup();
  const first = svc.create(ana, "beto");
  const other = svc.create({ id: "carla", name: "CARLA" }, "beto");
  const second = svc.create(ana, "dani");
  assert.equal(svc.join(first.code, "ana"), false, "el primero de Ana ya no existe");
  assert.equal(svc.incoming("dani")[0]?.code, second.code);
  assert.equal(svc.incoming("beto")[0]?.code, other.code, "el de Carla sigue");
});

test("solo los dos jugadores del reto pueden entrar a la sala", () => {
  const { svc } = setup();
  const c = svc.create(ana, "beto");
  assert.equal(svc.join(c.code, "intruso"), false);
  assert.equal(svc.join(c.code, "ana"), true);
  assert.equal(svc.join(c.code, "beto"), true);
});

test("cuando los dos han entrado el código se gasta", () => {
  const { svc } = setup();
  const c = svc.create(ana, "beto");
  svc.join(c.code, "ana");
  svc.join(c.code, "ana");
  assert.equal(svc.incoming("beto").length, 1, "uno solo dentro (aunque entre dos veces) no lo gasta");
  svc.join(c.code, "beto");
  assert.equal(svc.join(c.code, "ana"), false, "gastado: no vale para una segunda partida");
  assert.deepEqual(svc.incoming("beto"), []);
});

test("cancelar o rechazar: solo los dos jugadores, y un código ajeno no se distingue de uno que no existe", () => {
  const { svc } = setup();
  const c = svc.create(ana, "beto");
  assert.equal(svc.cancel(c.code, "intruso"), false);
  assert.equal(svc.incoming("beto").length, 1);
  assert.equal(svc.cancel(c.code, "beto"), true, "rechaza el retado");
  assert.deepEqual(svc.incoming("beto"), []);
  assert.equal(svc.cancel("NOEXISTE", "ana"), false);
  const d = svc.create(ana, "beto");
  assert.equal(svc.cancel(d.code, "ana"), true, "cancela quien reta");
});

test("los códigos generados tienen la forma esperada y no se repiten", () => {
  const codes = new Set(Array.from({ length: 200 }, () => randomCode()));
  assert.equal(codes.size, 200);
  for (const c of codes) assert.match(c, /^[A-HJ-NP-Z2-9]{8}$/);
});

test("si un código generado ya existe se genera otro", () => {
  let clock = 0;
  const codes = ["REPETIDO", "REPETIDO", "DISTINTO"];
  const svc = new ChallengeService(() => clock, 1000, () => codes.shift()!);
  const a = svc.create(ana, "beto");
  const b = svc.create({ id: "carla", name: "CARLA" }, "beto");
  assert.equal(a.code, "REPETIDO");
  assert.equal(b.code, "DISTINTO");
  void clock;
});
