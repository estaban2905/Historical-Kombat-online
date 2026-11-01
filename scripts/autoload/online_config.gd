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

const SERVER_URL := "ws://localhost:8787/ws"
