import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import type { FastifyInstance } from "fastify";
import { buildApp } from "../../src/app.js";
import type { MatchedMessage, ServerMessage } from "../../src/models/messages.js";
import { MatchService } from "../../src/services/match.service.js";
import { MatchmakingService } from "../../src/services/matchmaking.service.js";
import { createTestDb, type PgliteDb } from "../helpers/pglite-db.js";

let db: PgliteDb;
let app: FastifyInstance;
let wsUrl: string;

before(async () => {
  db = await createTestDb();
  const matchmaking = new MatchmakingService(undefined, { settler: new MatchService(db).settle, minInputs: 3 });
  app = await buildApp({ db, matchmaking, config: { logger: false, authRateLimitPerMinute: 1000 } });
  await app.listen({ port: 0, host: "127.0.0.1" });
  const addr = app.server.address();
  assert.ok(addr && typeof addr === "object");
  wsUrl = `ws://127.0.0.1:${addr.port}/ws`;
});
after(async () => {
  await app.close();
  await db.close();
});

async function register(name: string): Promise<string> {
  const res = await app.inject({
    method: "POST",
    url: "/auth/register",
    payload: { email: `${name.toLowerCase()}@test.com`, password: "secreto1", username: name },
  });
  assert.equal(res.statusCode, 201, res.body);
  return res.json().access_token as string;
}

const auth = (t: string) => ({ authorization: `Bearer ${t}` });
const befriend = async (ta: string, na: string, tb: string, nb: string) => {
  await app.inject({ method: "POST", url: "/me/friends", payload: { username: nb }, headers: auth(ta) });
  await app.inject({ method: "POST", url: "/me/friends", payload: { username: na }, headers: auth(tb) });
};
const challenge = (t: string | undefined, to: string) =>
  app.inject({ method: "POST", url: "/me/challenges", payload: { to }, headers: t ? auth(t) : {} });
const incoming = async (t: string) =>
  (await app.inject({ method: "GET", url: "/me/challenges", headers: auth(t) })).json() as { code: string; from: string; expires_in: number }[];

function connect() {
  const ws = new WebSocket(wsUrl);
  const got: ServerMessage[] = [];
  ws.addEventListener("message", (e) => got.push(JSON.parse(String(e.data)) as ServerMessage));
  const opened = new Promise<void>((res) => ws.addEventListener("open", () => res()));
  const next = async <T extends ServerMessage["t"]>(type: T): Promise<Extract<ServerMessage, { t: T }>> => {
    const deadline = Date.now() + 5000;
    for (;;) {
      const i = got.findIndex((m) => m.t === type);
      if (i >= 0) return got.splice(i, 1)[0] as Extract<ServerMessage, { t: T }>;
      if (Date.now() > deadline) throw new Error(`no llegó "${type}"; llegó: ${JSON.stringify(got)}`);
      await new Promise((r) => setTimeout(r, 25));
    }
  };
  return { ws, opened, next, send: (m: object) => ws.send(JSON.stringify(m)), got };
}

test("los retos exigen sesión", async () => {
  assert.equal((await challenge(undefined, "Alguien")).statusCode, 401);
  assert.equal((await app.inject({ method: "GET", url: "/me/challenges" })).statusCode, 401);
});

test("solo se puede retar a un amigo", async () => {
  const a = await register("Reto_A1");
  await register("Reto_B1");
  const res = await challenge(a, "Reto_B1");
  assert.equal(res.statusCode, 403);
  assert.equal(res.json().error, "not_friends");
});

test("no se puede retar a uno mismo, a quien no existe ni con un nombre inválido", async () => {
  const a = await register("Reto_A2");
  assert.equal((await challenge(a, "Reto_A2")).json().error, "cannot_challenge_self");
  assert.equal((await challenge(a, "Nadie_Aqui")).statusCode, 404);
  assert.equal((await challenge(a, "x")).statusCode, 400);
});

test("un amigo ve el reto, con el nombre de quien lo hizo, y puede rechazarlo", async () => {
  const a = await register("Reto_A3");
  const b = await register("Reto_B3");
  await befriend(a, "Reto_A3", b, "Reto_B3");
  const res = await challenge(a, "Reto_B3");
  assert.equal(res.statusCode, 200, res.body);
  assert.match(res.json().code, /^[A-Z0-9]{8}$/);
  assert.ok(res.json().expires_in > 100);
  const [seen] = await incoming(b);
  assert.equal(seen?.from, "Reto_A3");
  assert.equal(seen?.code, res.json().code);
  assert.deepEqual(await incoming(a), [], "quien reta no lo ve entrante");
  const del = await app.inject({ method: "DELETE", url: `/me/challenges/${seen!.code}`, headers: auth(b) });
  assert.equal(del.statusCode, 204);
  assert.deepEqual(await incoming(b), []);
});

test("un tercero no puede anular un reto ajeno (y no se entera de si existe)", async () => {
  const a = await register("Reto_A4");
  const b = await register("Reto_B4");
  const c = await register("Reto_C4");
  await befriend(a, "Reto_A4", b, "Reto_B4");
  const { code } = (await challenge(a, "Reto_B4")).json();
  const del = await app.inject({ method: "DELETE", url: `/me/challenges/${code}`, headers: auth(c) });
  assert.equal(del.statusCode, 204);
  assert.equal((await incoming(b)).length, 1, "el reto sigue ahí");
});

test("dos amigos entran con el código y se emparejan en un duelo amistoso", async () => {
  const a = await register("Reto_A5");
  const b = await register("Reto_B5");
  await befriend(a, "Reto_A5", b, "Reto_B5");
  const { code } = (await challenge(a, "Reto_B5")).json();
  const ca = connect();
  const cb = connect();
  await Promise.all([ca.opened, cb.opened]);
  ca.send({ t: "find", fighter: "napoleon", token: a, room: code });
  await ca.next("queued");
  cb.send({ t: "find", fighter: "cleopatra", token: b, room: code });
  const [ma, mb] = (await Promise.all([ca.next("matched"), cb.next("matched")])) as [MatchedMessage, MatchedMessage];
  assert.equal(ma.ranked, false, "un reto no mueve puntos");
  assert.equal(mb.ranked, false);
  assert.equal(ma.opponent.name, "Reto_B5");
  ca.ws.close();
  cb.ws.close();
});

test("quien no es del reto no puede entrar a su sala, aunque tenga el código", async () => {
  const a = await register("Reto_A6");
  const b = await register("Reto_B6");
  const intruso = await register("Reto_X6");
  await befriend(a, "Reto_A6", b, "Reto_B6");
  const { code } = (await challenge(a, "Reto_B6")).json();
  const c = connect();
  await c.opened;
  c.send({ t: "find", fighter: "napoleon", token: intruso, room: code });
  const err = await c.next("error");
  assert.equal(err.msg, "invalid_room");
  c.ws.close();
});

test("un código inventado o ya gastado no abre sala", async () => {
  const a = await register("Reto_A7");
  const b = await register("Reto_B7");
  await befriend(a, "Reto_A7", b, "Reto_B7");
  const c = connect();
  await c.opened;
  c.send({ t: "find", fighter: "napoleon", token: a, room: "INVENTAD" });
  assert.equal((await c.next("error")).msg, "invalid_room");
  const { code } = (await challenge(a, "Reto_B7")).json();
  const ca = connect();
  const cb = connect();
  await Promise.all([ca.opened, cb.opened]);
  ca.send({ t: "find", fighter: "napoleon", token: a, room: code });
  await ca.next("queued");
  cb.send({ t: "find", fighter: "cleopatra", token: b, room: code });
  await Promise.all([ca.next("matched"), cb.next("matched")]);
  const again = connect();
  await again.opened;
  again.send({ t: "find", fighter: "napoleon", token: a, room: code });
  assert.equal((await again.next("error")).msg, "invalid_room", "el código ya se gastó");
  for (const x of [c, ca, cb, again]) x.ws.close();
});

test("un invitado no puede usar una sala (el mensaje ni siquiera es válido)", async () => {
  const c = connect();
  await c.opened;
  c.send({ t: "find", fighter: "napoleon", room: "ABCD2345" });
  assert.equal((await c.next("error")).msg, "mensaje no válido");
  c.ws.close();
});

const httpUrl = () => wsUrl.replace("ws://", "http://").replace(/\/ws$/, "");

test("espera larga: la petición con ?wait responde en cuanto llega el reto", async () => {
  const a = await register("Reto_Espera_A");
  const b = await register("Reto_Espera_B");
  await befriend(a, "Reto_Espera_A", b, "Reto_Espera_B");
  const started = Date.now();
  const waiting = fetch(`${httpUrl()}/me/challenges?wait=20`, { headers: auth(b) });
  await new Promise((r) => setTimeout(r, 300));
  assert.equal(app.challenges.waitingCount() >= 1, true, "B está esperando");
  const sent = await challenge(a, "Reto_Espera_B");
  const res = await waiting;
  const list = (await res.json()) as { code: string; from: string }[];
  assert.equal(res.status, 200);
  assert.deepEqual(list.map((c) => [c.code, c.from]), [[sent.json().code, "Reto_Espera_A"]]);
  assert.ok(Date.now() - started < 5000, "llega al momento, no a los 20 s");
});

test("espera larga: sin retos responde vacío al acabar el plazo, y con uno ya hecho no espera", async () => {
  const a = await register("Reto_Plazo_A");
  const b = await register("Reto_Plazo_B");
  await befriend(a, "Reto_Plazo_A", b, "Reto_Plazo_B");
  const started = Date.now();
  const empty = await app.inject({ method: "GET", url: "/me/challenges?wait=1", headers: auth(b) });
  assert.deepEqual(empty.json(), []);
  assert.ok(Date.now() - started >= 900, "esperó el plazo");
  await challenge(a, "Reto_Plazo_B");
  const started2 = Date.now();
  const now = await app.inject({ method: "GET", url: "/me/challenges?wait=20", headers: auth(b) });
  assert.equal(now.json().length, 1);
  assert.ok(Date.now() - started2 < 1000, "ya había uno: contesta sin esperar");
  assert.equal((await app.inject({ method: "GET", url: "/me/challenges?wait=26", headers: auth(b) })).statusCode, 400, "más de 25 s no");
});

test("espera larga: si el juego corta la conexión se deja de esperar", async () => {
  const b = await register("Reto_Corte_B");
  const before = app.challenges.waitingCount();
  const abort = new AbortController();
  const req = fetch(`${httpUrl()}/me/challenges?wait=20`, { headers: auth(b), signal: abort.signal }).catch(() => null);
  await new Promise((r) => setTimeout(r, 300));
  assert.equal(app.challenges.waitingCount(), before + 1);
  abort.abort();
  await req;
  await new Promise((r) => setTimeout(r, 300));
  assert.equal(app.challenges.waitingCount(), before, "no queda nadie esperando");
});
