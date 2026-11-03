import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../../src/app.js";
import type { MatchedMessage, ServerMessage, SettledMessage } from "../../src/models/messages.js";
import { MatchService } from "../../src/services/match.service.js";
import { MatchmakingService } from "../../src/services/matchmaking.service.js";
import { createTestDb, type PgliteDb } from "../helpers/pglite-db.js";

/**
 * Duelos completos de punta a punta: cuentas reales en la base de datos, WebSockets
 * reales, puntos repartidos por el servidor e historial consultado por HTTP.
 */
let db: PgliteDb;
let app: FastifyInstance;
let base: string;
let wsUrl: string;

before(async () => {
  db = await createTestDb();
  const matchmaking = new MatchmakingService(undefined, {
    settler: new MatchService(db).settle,
    minInputs: 3,
    settleTimeoutMs: 2000,
    stallTimeoutMs: 600,
  });
  app = await buildApp({ db, matchmaking, config: { logger: false, authRateLimitPerMinute: 1000 } });
  await app.listen({ port: 0, host: "127.0.0.1" });
  const addr = app.server.address();
  assert.ok(addr && typeof addr === "object");
  base = `http://127.0.0.1:${addr.port}`;
  wsUrl = `ws://127.0.0.1:${addr.port}/ws`;
});

after(async () => {
  await app.close();
  await db.close();
});

interface Account {
  token: string;
  name: string;
}

async function register(name: string): Promise<Account> {
  const res = await fetch(`${base}/auth/register`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email: `${name.toLowerCase()}@test.com`, password: "secreto1", username: name }),
  });
  assert.equal(res.status, 201);
  return { token: ((await res.json()) as { access_token: string }).access_token, name };
}

const me = async (a: Account) =>
  (await (await fetch(`${base}/me`, { headers: { authorization: `Bearer ${a.token}` } })).json()) as {
    points: number; wins: number; losses: number;
  };

const history = async (a: Account) =>
  (await (await fetch(`${base}/me/matches`, { headers: { authorization: `Bearer ${a.token}` } })).json()) as Array<{
    opponent: string; result: string; delta: number; reason: string; my_fighter: string; my_rounds: number;
  }>;

function connect() {
  const ws = new WebSocket(wsUrl);
  const got: ServerMessage[] = [];
  const waiting: Array<() => void> = [];
  ws.addEventListener("message", (e) => {
    got.push(JSON.parse(String(e.data)) as ServerMessage);
    waiting.splice(0).forEach((fn) => fn());
  });
  const opened = new Promise<void>((res) => ws.addEventListener("open", () => res()));
  async function next<T extends ServerMessage["t"]>(type: T): Promise<Extract<ServerMessage, { t: T }>> {
    const deadline = Date.now() + 5000;
    for (;;) {
      const i = got.findIndex((m) => m.t === type);
      if (i >= 0) return got.splice(i, 1)[0] as Extract<ServerMessage, { t: T }>;
      if (Date.now() > deadline) throw new Error(`no llegó "${type}"; llegó: ${JSON.stringify(got)}`);
      await new Promise<void>((res) => {
        waiting.push(res);
        setTimeout(res, 100);
      });
    }
  }
  const send = (msg: object) => ws.send(JSON.stringify(msg));
  return { ws, opened, next, send, got };
}

/** Dos cuentas conectadas y ya emparejadas, con la pelea "en marcha" (inputs enviados). */
async function startDuel(a: Account, b: Account) {
  const ca = connect();
  const cb = connect();
  await Promise.all([ca.opened, cb.opened]);
  ca.send({ t: "find", fighter: "napoleon", token: a.token });
  await ca.next("queued");
  cb.send({ t: "find", fighter: "cleopatra", token: b.token });
  const [ma, mb] = (await Promise.all([ca.next("matched"), cb.next("matched")])) as [MatchedMessage, MatchedMessage];
  for (let f = 0; f < 4; f++) {
    ca.send({ t: "input", f, m: 1 });
    cb.send({ t: "input", f, m: 2 });
  }
  await ca.next("input");
  await cb.next("input");
  return { ca, cb, ma, mb };
}

test("duelo entre cuentas: se guardan puntos, victorias, historial y ranking", async () => {
  const ana = await register("Duelo_Ana");
  const beto = await register("Duelo_Beto");
  const { ca, cb, ma, mb } = await startDuel(ana, beto);

  assert.equal(ma.ranked, true);
  assert.equal(ma.side, 1);
  assert.equal(mb.side, 2);
  assert.equal(ma.opponent.name, "Duelo_Beto", "el nombre del rival es el de su cuenta");
  assert.equal(mb.opponent.name, "Duelo_Ana");

  ca.send({ t: "result", winner: 1, p1Rounds: 2, p2Rounds: 1 });
  cb.send({ t: "result", winner: 1, p1Rounds: 2, p2Rounds: 1 });
  const sa: SettledMessage = await ca.next("settled");
  const sb: SettledMessage = await cb.next("settled");

  assert.deepEqual(sa, { t: "settled", ranked: true, ok: true, delta: 16, points: 1016, wins: 1, losses: 0 });
  assert.deepEqual(sb, { t: "settled", ranked: true, ok: true, delta: -16, points: 984, wins: 0, losses: 1 });
  const stats = async (a: Account) => {
    const { points, wins, losses } = await me(a);
    return { points, wins, losses };
  };
  assert.deepEqual(await stats(ana), { points: 1016, wins: 1, losses: 0 });
  assert.deepEqual(await stats(beto), { points: 984, wins: 0, losses: 1 });

  const [h] = await history(ana);
  assert.equal(h?.opponent, "Duelo_Beto");
  assert.equal(h?.result, "win");
  assert.equal(h?.delta, 16);
  assert.equal(h?.reason, "normal");
  assert.equal(h?.my_fighter, "napoleon");
  assert.equal(h?.my_rounds, 2);
  const [hb] = await history(beto);
  assert.equal(hb?.result, "loss");
  assert.equal(hb?.delta, -16);
  assert.equal(hb?.my_fighter, "cleopatra");

  const board = (await (await fetch(`${base}/leaderboard`)).json()) as Array<{ username: string }>;
  const names = board.map((p) => p.username);
  assert.ok(names.indexOf("Duelo_Ana") < names.indexOf("Duelo_Beto"));

  ca.ws.close();
  cb.ws.close();
});

test("si los dos clientes discrepan, nadie gana ni pierde puntos", async () => {
  const c = await register("Trampa_C");
  const d = await register("Trampa_D");
  const { ca, cb } = await startDuel(c, d);
  ca.send({ t: "result", winner: 1, p1Rounds: 2, p2Rounds: 0 });
  cb.send({ t: "result", winner: 2, p1Rounds: 0, p2Rounds: 2 }); // el otro dice que ganó él
  const sa = await ca.next("settled");
  assert.equal(sa.ok, false);
  assert.equal(sa.reason, "mismatch");
  assert.equal((await me(c)).points, 1000);
  assert.equal((await me(d)).points, 1000);
  assert.deepEqual(await history(c), []);
  ca.ws.close();
  cb.ws.close();
});

test("irse en plena pelea es abandono: el otro gana y queda en el historial", async () => {
  const e = await register("Fuga_E");
  const f = await register("Fuga_F");
  const { ca, cb } = await startDuel(e, f);
  ca.ws.close(); // E abandona
  await cb.next("opponent_left");
  const s = await cb.next("settled");
  assert.equal(s.ok, true);
  assert.equal(s.reason, "forfeit");
  assert.equal(s.delta, 16);
  assert.equal((await me(f)).points, 1016);
  assert.equal((await me(e)).points, 984);
  assert.equal((await history(f))[0]?.reason, "forfeit");
  assert.equal((await history(e))[0]?.result, "loss");
  cb.ws.close();
});

test("quien termina primero se va y el otro aún guarda el duelo", async () => {
  const g = await register("Lag_G");
  const h = await register("Lag_H");
  const { ca, cb } = await startDuel(g, h);
  ca.send({ t: "result", winner: 2, p1Rounds: 1, p2Rounds: 2 });
  await new Promise((r) => setTimeout(r, 50));
  ca.ws.close(); // el que va adelantado sale a Resultados y se desconecta
  await cb.next("opponent_left");
  cb.send({ t: "result", winner: 2, p1Rounds: 1, p2Rounds: 2 });
  const s = await cb.next("settled");
  assert.equal(s.ok, true);
  assert.equal(s.reason, undefined, "no fue abandono");
  assert.equal((await me(h)).wins, 1);
  assert.equal((await me(g)).losses, 1);
  cb.ws.close();
});

test("un token no válido se rechaza y no entra a la cola", async () => {
  const c = connect();
  await c.opened;
  c.send({ t: "find", fighter: "napoleon", token: "token-inventado" });
  const err = await c.next("error");
  assert.equal(err.msg, "invalid_token");
  assert.equal(app.matchmaking.stats().queued, 0);
  c.ws.close();
});

test("un invitado puede jugar contra una cuenta, pero no cuenta para el ranking", async () => {
  const i = await register("Mixto_I");
  const guest = connect();
  const acc = connect();
  await Promise.all([guest.opened, acc.opened]);
  acc.send({ t: "find", fighter: "napoleon", token: i.token });
  await acc.next("queued");
  guest.send({ t: "find", fighter: "cleopatra", name: "Mixto_I" }); // intenta hacerse pasar por la cuenta
  const mg = await guest.next("matched");
  const ma = await acc.next("matched");
  assert.equal(mg.ranked, false);
  assert.equal(ma.ranked, false);
  assert.equal(ma.opponent.name, "INVITADO", "un invitado nunca puede usar el nombre de una cuenta");
  acc.send({ t: "result", winner: 1, p1Rounds: 2, p2Rounds: 0 });
  assert.equal((await acc.next("settled")).ranked, false);
  assert.equal((await me(i)).points, 1000);
  guest.ws.close();
  acc.ws.close();
});

test("los mensajes de un socket se procesan en orden (find y cancel seguidos)", async () => {
  const j = await register("Orden_J");
  const c = connect();
  await c.opened;
  // El find espera a la base de datos para verificar el token; el cancel llega justo detrás.
  c.send({ t: "find", fighter: "napoleon", token: j.token });
  c.send({ t: "cancel" });
  await new Promise((r) => setTimeout(r, 300));
  assert.equal(app.matchmaking.stats().queued, 0, "el cancel no se puede adelantar al find");
  c.ws.close();
});

test("si un jugador se congela, el servidor cierra el duelo: pierde él, gana el otro y queda en el historial", async () => {
  const x = await register("Congela_X");
  const y = await register("Congela_Y");
  const { ca, cb } = await startDuel(x, y);
  // X no vuelve a enviar nada (pestaña oculta); Y sigue unos ticks adelantado y se queda esperando.
  for (let f = 4; f < 10; f++) cb.send({ t: "input", f, m: 2 });
  assert.deepEqual(await ca.next("timeout"), { t: "timeout", loser: 1 });
  assert.deepEqual(await cb.next("timeout"), { t: "timeout", loser: 1 });
  const s = await cb.next("settled");
  assert.equal(s.ok, true);
  assert.equal(s.reason, "forfeit");
  assert.equal(s.delta, 16);
  assert.equal((await me(y)).points, 1016);
  assert.equal((await me(x)).points, 984);
  assert.equal((await history(x))[0]?.result, "loss");
  assert.equal((await history(y))[0]?.reason, "forfeit");
  ca.ws.close();
  cb.ws.close();
});
