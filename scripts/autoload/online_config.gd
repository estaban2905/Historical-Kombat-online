## Dirección del servidor de duelos online (server/ en este repositorio).
## En producción es la URL pública de Railway con wss://, por ejemplo
##   wss://history-combat-server.up.railway.app/ws
## Alternativa sin tocar el código: crear user://online.cfg (ver online.gd):
##   [server]
##   url="ws://localhost:8080/ws"
extends RefCounted

const SERVER_URL := "ws://localhost:8080/ws"
