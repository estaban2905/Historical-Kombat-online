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
| `POST /auth/register` · `/auth/login` · `/auth/refresh` · `/auth/logout` | Cuentas y sesiones (solo con base de datos) |
| `GET /me` · `GET /leaderboard` | Mi perfil (con token) y ranking |

## Estructura

```
src/
  index.ts                 arranque y cierre limpio
  app.ts                   arma la app (plugins, servicios, rutas)
  config/env.ts            variables de entorno
  db/                      acceso a Postgres (pg-db.ts) y migraciones automáticas (migrate.ts)
  models/                  tipos: mensajes, jugador, sala, cuenta
  repositories/            todo el SQL (cuentas, sesiones)
  validators/              validación de lo que manda el cliente
  services/                lógica: emparejamiento, cuentas, contraseñas, tokens
  controllers/             traducen HTTP/WebSocket a llamadas a servicios
  routes/                  registran las rutas de Fastify
  schemas/                 esquemas JSON (validan y alimentan Swagger)
  plugins/                 servicios compartidos y Swagger
migrations/                SQL numerado (001_init.sql...). Se aplican solas al arrancar; las ya publicadas no se editan
test/
  unit/                    lógica sin red
  integration/             servidor real: WebSockets, cuentas con Postgres embebido y el driver pg real
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
| `DATABASE_URL` | (vacía) | Postgres. En Railway: `${{Postgres.DATABASE_URL}}`. Sin ella no hay cuentas, solo emparejamiento |
| `ALLOWED_ORIGINS` | (vacía = cualquiera) | Dominios de la web del juego, separados por comas |
| `AUTH_RATE_LIMIT_PER_MINUTE` | 10 | Intentos de registro/login por minuto y por IP |

## Protocolo (resumen)

`find` → `queued` → `matched` → intercambio de `input` → `opponent_left` / `leave`.
Detalle completo en `GET /protocol` o en `/docs`.
