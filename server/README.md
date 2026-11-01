# History Combat · Servidor online

Empareja jugadores y reenvía sus inputs para el duelo online. No simula la pelea: cada cliente la calcula por su cuenta con la misma semilla.

Fastify + `@fastify/websocket` + Swagger. Node 22+.

## Comandos

```
npm install
npm run dev        # servidor con recarga en http://localhost:8787
npm test           # pruebas unitarias e integración
npm run typecheck
npm run build && npm start
```

## Rutas

| Ruta | Qué es |
|---|---|
| `GET /health` | Estado (lo usa Railway) |
| `GET /protocol` | Catálogo de mensajes del WebSocket |
| `GET /docs` | Swagger UI (`/docs/json` es el OpenAPI) |
| `WS /ws` | Conexión de juego |

## Estructura

```
src/
  index.ts                 arranque y cierre limpio
  app.ts                   arma la app (plugins, servicios, rutas)
  config/env.ts            variables de entorno
  models/                  tipos: mensajes, jugador, sala
  validators/              validación de lo que manda el cliente
  services/                lógica: emparejamiento, límite de mensajes
  controllers/             traducen HTTP/WebSocket a llamadas a servicios
  routes/                  registran las rutas de Fastify
  schemas/                 esquemas JSON (validan y alimentan Swagger)
  plugins/                 servicios compartidos y Swagger
test/
  unit/                    lógica sin red
  integration/             servidor real con WebSockets
```

Regla: las dependencias van de fuera hacia dentro (`routes → controllers → services → models`). Los servicios no conocen Fastify ni WebSocket.

## Variables de entorno

| Variable | Defecto | Descripción |
|---|---|---|
| `PORT` | 8787 | Puerto (Railway lo define solo) |
| `DOCS_ENABLED` | true | `false` oculta `/docs` |
| `MAX_PAYLOAD` | 1024 | Bytes máximos por mensaje |
| `MAX_MESSAGES_PER_SECOND` | 120 | Límite por conexión |
| `HEARTBEAT_MS` | 15000 | Intervalo del ping |
| `LOG` | true | `false` apaga los logs |

## Protocolo (resumen)

`find` → `queued` → `matched` → intercambio de `input` → `opponent_left` / `leave`.
Detalle completo en `GET /protocol` o en `/docs`.
