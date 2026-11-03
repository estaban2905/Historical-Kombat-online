import type { WebSocket } from "ws";
import type { AppConfig } from "../config/env.js";
import type { Peer } from "../models/player.js";
import type { ServerMessage } from "../models/messages.js";
import type { ChallengeService } from "../services/challenge.service.js";
import type { MatchmakingService } from "../services/matchmaking.service.js";
import { RateLimiter } from "../services/rate-limiter.service.js";
import { parseClientMessage } from "../validators/client-message.validator.js";

type GameConfig = Pick<AppConfig, "maxMessagesPerSecond" | "heartbeatMs">;

/** Resuelve un access token a su cuenta (undefined si el servidor no tiene base de datos). */
export type Authenticator = (token: string) => Promise<{ id: string; username: string } | null>;

/**
 * Controlador de una conexión WebSocket: traduce lo que llega por el socket
 * a llamadas al servicio de emparejamiento. No contiene reglas del juego.
 */
export function handleGameSocket(
  socket: WebSocket,
  matchmaking: MatchmakingService,
  config: GameConfig,
  authenticate?: Authenticator,
  onError: (err: unknown) => void = () => undefined,
  challenges?: ChallengeService,
): void {
  const peer: Peer = {
    send(msg: ServerMessage) {
      if (socket.readyState === socket.OPEN) socket.send(JSON.stringify(msg));
    },
  };
  const limiter = new RateLimiter(config.maxMessagesPerSecond);

  // Los mensajes de un socket se procesan de uno en uno y en orden, aunque alguno tenga
  // que esperar a la base de datos (verificar el token): un `cancel` o un `input` no
  // puede adelantarse a un `find` que aún se está comprobando.
  let chain: Promise<void> = Promise.resolve();
  const enqueue = (task: () => Promise<void> | void): void => {
    chain = chain.then(task).catch(onError);
  };

  // Ping periódico: detecta conexiones muertas (cerraron la pestaña sin avisar).
  let alive = true;
  socket.on("pong", () => {
    alive = true;
  });
  const heartbeat = setInterval(() => {
    if (!alive) {
      socket.terminate();
      return;
    }
    alive = false;
    socket.ping();
  }, config.heartbeatMs);

  socket.on("message", (data: Buffer) => {
    if (!limiter.allow()) {
      peer.send({ t: "error", msg: "demasiados mensajes" });
      socket.close(1008, "rate limit");
      return;
    }
    const msg = parseClientMessage(data.toString("utf8"));
    if (!msg) {
      peer.send({ t: "error", msg: "mensaje no válido" });
      return;
    }
    enqueue(async () => {
      if (msg.t !== "find" || msg.token === undefined || !authenticate) {
        // Invitado: nunca se acepta el nombre que mande, para que nadie se haga pasar por una cuenta.
        matchmaking.handle(peer, msg.t === "find" ? { t: "find", fighter: msg.fighter, name: "INVITADO" } : msg);
        return;
      }
      const account = await authenticate(msg.token);
      if (!account) {
        peer.send({ t: "error", msg: "invalid_token" });
        return;
      }
      // Una sala de reto solo la abren sus dos jugadores y mientras el reto siga vivo.
      if (msg.room !== undefined && !challenges?.join(msg.room, account.id)) {
        peer.send({ t: "error", msg: "invalid_room" });
        return;
      }
      const find = { t: "find" as const, fighter: msg.fighter, name: account.username };
      matchmaking.handle(peer, msg.room === undefined ? find : { ...find, room: msg.room }, account.id);
    });
  });

  socket.on("close", () => {
    clearInterval(heartbeat);
    enqueue(() => matchmaking.disconnect(peer));
  });
  socket.on("error", () => socket.terminate());
}
