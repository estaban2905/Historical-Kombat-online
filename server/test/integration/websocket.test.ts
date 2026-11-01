import { test } from "node:test";
import assert from "node:assert/strict";
import { buildApp } from "../../src/app.js";
import type { MatchedMessage, ServerMessage } from "../../src/models/messages.js";

/** Prueba de punta a punta con WebSockets reales contra un servidor local. */
test("dos clientes reales se emparejan y se pasan inputs", async (t) => {
  const app = await buildApp({ config: { logger: false } });
  await app.listen({ port: 0, host: "127.0.0.1" });
  t.after(() => app.close());
  const addr = app.server.address();
  assert.ok(addr && typeof addr === "object");
  const url = `ws://127.0.0.1:${addr.port}/ws`;

  function connect() {
    const ws = new WebSocket(url);
    const got: ServerMessage[] = [];
    const waiting: Array<() => void> = [];
    ws.addEventListener("message", (e) => {
      got.push(JSON.parse(String(e.data)) as ServerMessage);
      waiting.splice(0).forEach((fn) => fn());
    });
    const opened = new Promise<void>((res) => ws.addEventListener("open", () => res()));
    async function next(type: ServerMessage["t"]): Promise<ServerMessage> {
      for (;;) {
        const i = got.findIndex((m) => m.t === type);
        if (i >= 0) return got.splice(i, 1)[0]!;
        await new Promise<void>((res) => waiting.push(res));
      }
    }
    return { ws, opened, next };
  }

  const a = connect();
  const b = connect();
  await Promise.all([a.opened, b.opened]);

  a.ws.send(JSON.stringify({ t: "find", fighter: "napoleon", name: "ANA" }));
  assert.deepEqual(await a.next("queued"), { t: "queued" });
  b.ws.send(JSON.stringify({ t: "find", fighter: "cleopatra", name: "BETO" }));

  const ma = (await a.next("matched")) as MatchedMessage;
  const mb = (await b.next("matched")) as MatchedMessage;
  assert.equal(ma.side, 1);
  assert.equal(mb.side, 2);
  assert.equal(ma.seed, mb.seed);

  a.ws.send(JSON.stringify({ t: "input", f: 3, m: 9 }));
  assert.deepEqual(await b.next("input"), { t: "input", f: 3, m: 9 });

  a.ws.close();
  assert.deepEqual(await b.next("opponent_left"), { t: "opponent_left" });
  b.ws.close();
});

test("un mensaje inválido recibe error y no tumba la conexión", async (t) => {
  const app = await buildApp({ config: { logger: false } });
  await app.listen({ port: 0, host: "127.0.0.1" });
  t.after(() => app.close());
  const addr = app.server.address();
  assert.ok(addr && typeof addr === "object");

  const ws = new WebSocket(`ws://127.0.0.1:${addr.port}/ws`);
  const reply = new Promise<ServerMessage>((res) =>
    ws.addEventListener("message", (e) => res(JSON.parse(String(e.data)) as ServerMessage)),
  );
  await new Promise<void>((res) => ws.addEventListener("open", () => res()));
  ws.send("basura");
  assert.equal((await reply).t, "error");
  ws.close();
});
