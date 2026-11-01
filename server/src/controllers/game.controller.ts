import type { WebSocket } from "ws";
import type { AppConfig } from "../config/env.js";
import type { Peer } from "../models/player.js";
import type { ServerMessage } from "../models/messages.js";
import type { MatchmakingService } from "../services/matchmaking.service.js";
import { RateLimiter } from "../services/rate-limiter.service.js";
import { parseClientMessage } from "../validators/client-message.validator.js";

type GameConfig = Pick<AppConfig, "maxMessagesPerSecond" | "heartbeatMs">;

/**
 * Controlador de una conexión WebSocket: traduce lo que llega por el socket
 * a llamadas al servicio de emparejamiento. No contiene reglas del juego.
 */
export function handleGameSocket(socket: WebSocket, matchmaking: MatchmakingService, config: GameConfig): void {
  const peer: Peer = {
    send(msg: ServerMessage) {
      if (socket.readyState === socket.OPEN) socket.send(JSON.stringify(msg));
    },
  };
  const limiter = new RateLimiter(config.maxMessagesPerSecond);

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
    matchmaking.handle(peer, msg);
  });

  socket.on("close", () => {
    clearInterval(heartbeat);
    matchmaking.disconnect(peer);
  });
  socket.on("error", () => socket.terminate());
}
