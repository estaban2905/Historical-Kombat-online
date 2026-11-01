# History Combat · Web

Entrega el juego exportado a Web (carpeta `public/`) y le dice a qué servidor de partidas conectarse. Fastify + `@fastify/static`. Node 22+.

## Rutas

| Ruta | Qué es |
|---|---|
| `GET /` | El juego (`index.html`, `.wasm`, `.pck`; con Brotli/gzip ya comprimidos) |
| `GET /config.js` | `window.HC_SERVER_URL = "<SERVER_URL>"`; el juego lo lee antes de arrancar |
| `GET /health` | Estado (lo usa Railway) |

## Variables de entorno

| Variable | Defecto | Descripción |
|---|---|---|
| `PORT` | 8788 | Puerto (Railway lo define solo) |
| `SERVER_URL` | (vacía) | Dirección WebSocket del servicio `server`, p. ej. `wss://history-combat-server.up.railway.app/ws` |
| `STATIC_DIR` | public | Carpeta del juego exportado |
| `LOG` | true | `false` apaga los logs |

## Probarlo en local

```
# 1) exportar el juego (Godot) a build/web/ y copiarlo aquí
cp ../build/web/* public/ && npm run precompress
# 2) servidor de partidas en otra terminal: cd ../server && npm run dev   (puerto 8787)
# 3) esta web
npm install && SERVER_URL=ws://localhost:8787/ws npm run dev
# 4) abrir http://localhost:8788
```

El contenido de `public/` no se versiona (solo `.gitkeep`): lo deja el pipeline antes de desplegar.
