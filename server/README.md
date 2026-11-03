# History Combat · Servidor online

Empareja jugadores y reenvía sus inputs para el duelo online. No simula la pelea: cada cliente la calcula por su cuenta con la misma semilla.

Fastify + `@fastify/websocket` + Swagger. Node 22+.

## Comandos

```
npm install
npm run dev        # servidor con recarga en http://localhost:8787
npm run dev:local  # lo mismo pero CON cuentas, sin Postgres: base de datos embebida en .dev-data/
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
| `POST /auth/register` · `/auth/login` · `/auth/google` · `/auth/refresh` · `/auth/logout` | Cuentas y sesiones (solo con base de datos) |
| `GET /me` · `PATCH /me` · `GET /me/matches` | Mi perfil, cambiar mi avatar (id de un luchador), mi nombre (una vez cada 7 días) y el marco y título que llevo puestos (solo los desbloqueados como `cosmetic`) y mi historial de duelos (con token) |
| `POST /me/password` | Cambia mi contraseña (pide la actual y cierra las demás sesiones; no vale para cuentas de Google) |
| `GET /me/unlocks` · `PUT /me/unlocks` | Lo que he desbloqueado (finales vistos, luchadores ganados, cosméticos). Solo se lee y se añade: desbloquear es para siempre |
| `GET /me/friends` · `POST /me/friends` · `DELETE /me/friends/:nombre` | Mis amigos y solicitudes; pedir amistad (si esa persona ya me la había pedido, quedan como amigos); quitar un amigo o cancelar/rechazar una solicitud. Máx. 100 entre amigos y solicitudes enviadas |
| `POST /me/challenges` · `GET /me/challenges` · `DELETE /me/challenges/:codigo` | Retar a un amigo (abre una sala privada de 2 minutos con un código), ver los retos que me hacen y cancelar o rechazar. Quien reta y el retado entran con `find` + `room: codigo`; el duelo es **amistoso** (no mueve puntos) |
| `GET /me/friends/leaderboard` | Ranking entre mis amigos y yo |
| `GET /me/achievements` | Mis logros (clave, progreso y meta), calculados al momento con mis duelos y desbloqueos: no se guardan. El juego pone los nombres |
| `GET /leaderboard` · `GET /players/:nombre` | El ranking (con luchador favorito y racha) y el perfil público de cualquier jugador (puesto, favorito, racha y 10 últimos duelos; sin email) |
| `GET` · `PUT` · `DELETE /me/story` | Partida guardada del modo Historia (con token): una por cuenta, para seguir desde otro dispositivo. `GET` da 404 si no hay |

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
| `LOGIN_RATE_LIMIT_PER_EMAIL` | 10 | Intentos de login cada 15 minutos para un mismo email, desde cualquier IP |
| `TRUST_PROXY_HOPS` | 1 | Proxies delante del servidor (Railway: 1). La IP del cliente se lee de `X-Forwarded-For` saltando solo esos; lo que el cliente añada no cuenta |
| `GOOGLE_CLIENT_ID` | (vacía) | Client ID de Google (OAuth tipo web). Con él, `POST /auth/google` acepta ID tokens de Google; sin él responde 503. Debe ser el mismo que usa el servicio web |

## Duelos con ranking

- Un duelo cuenta solo si **los dos son cuentas distintas**: ambos mandan `find` con su `token`. Con un invitado se juega igual, pero sin puntos (y el invitado siempre se llama `INVITADO`).
- El servidor no simula la pelea. Al terminar, **cada cliente reporta** `result {winner, p1Rounds, p2Rounds}` según su simulación (idéntica a la del rival). Si los dos coinciden se guarda; si no, se descarta (`mismatch`).
- Se descarta también si el duelo fue demasiado corto (`too_short`, menos de 300 inputs por jugador) o si el segundo reporte no llega en 30 s (`timeout`).
- **Abandono:** quien se desconecta en plena pelea sin haber reportado pierde; gana el que se quedó (`reason: forfeit`). Irse antes de que empiece la pelea, o después de reportar, no es abandono.
- **Puntos:** Elo con K=32 (empiezan en 1000, nunca bajan de 0; una victoria da al menos +1). Los puntos de los dos jugadores y la fila de `matches` se guardan en una sola transacción.
- Cada jugador recibe `settled` con su `delta` y sus totales.

## Protocolo (resumen)

`find` → `queued` → `matched` → intercambio de `input` → `result` → `settled` (o `opponent_left`).
Detalle completo en `GET /protocol` o en `/docs`.
