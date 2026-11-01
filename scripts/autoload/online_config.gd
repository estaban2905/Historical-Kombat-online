## Dirección del servidor de duelos online (server/ en este repositorio).
## En la versión web NO se usa: el juego se conecta a la misma dirección desde la
## que se abrió (ver online.gd). Esta sirve para ejecutar el juego desde Godot o
## como .exe; en ese caso pon la URL pública de Railway con wss://, por ejemplo
##   wss://history-combat.up.railway.app/ws
## Alternativa sin tocar el código: crear user://online.cfg (ver online.gd):
##   [server]
##   url="ws://localhost:8787/ws"
extends RefCounted

const SERVER_URL := "ws://localhost:8787/ws"
