## Dirección del servidor de duelos online (server/ en este repositorio).
## En la versión web NO se usa: la dirección la entrega el servicio web en
## /config.js (ver web/ y online.gd). Esta sirve para ejecutar el juego desde
## Godot o como .exe; en ese caso pon la URL pública del servicio server de Railway
## con wss://, por ejemplo
##   wss://history-combat-server.up.railway.app/ws
## Alternativa sin tocar el código: crear user://online.cfg (ver online.gd):
##   [server]
##   url="ws://localhost:8787/ws"
extends RefCounted

## Desde Godot (F5) y en builds de depuración se usa el servidor local (npm run dev:local).
const SERVER_URL_DEV := "ws://localhost:8787/ws"
## Builds de exportación (release): el servidor de producción en Railway.
const SERVER_URL_PROD := "wss://server-production-f7f1.up.railway.app/ws"

static func server_url() -> String:
	return SERVER_URL_DEV if OS.is_debug_build() else SERVER_URL_PROD
