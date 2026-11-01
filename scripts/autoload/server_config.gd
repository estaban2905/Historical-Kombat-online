## Dónde está el servidor (server/ de este repositorio): una sola fuente para el
## WebSocket de los duelos (online.gd) y para la API de cuentas (backend.gd).
## Orden de prioridad:
##   1. override_ws (las pruebas lo fijan)
##   2. En el navegador: window.HC_SERVER_URL, que entrega el servicio web en /config.js
##   3. user://online.cfg:  [server]  url="ws://localhost:8787/ws"
##   4. online_config.gd (Godot / .exe)
class_name ServerConfig
extends RefCounted

const Config := preload("res://scripts/autoload/online_config.gd")
const CONFIG_PATH := "user://online.cfg"

## Solo para pruebas: fuerza la dirección WebSocket (ws://host:puerto/ws).
static var override_ws: String = ""

## Dirección del WebSocket de los duelos.
static func ws_url() -> String:
	if override_ws != "":
		return override_ws
	if OS.has_feature("web"):
		var web_url: Variant = JavaScriptBridge.eval("window.HC_SERVER_URL || ''")
		if web_url is String and web_url != "":
			return web_url
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		return str(cfg.get_value("server", "url", Config.SERVER_URL))
	return Config.SERVER_URL

## Dirección base de la API HTTP: la misma del WebSocket, sin /ws y con http(s).
static func http_url() -> String:
	return to_http(ws_url())

static func to_http(ws: String) -> String:
	var url := ws.strip_edges().trim_suffix("/").trim_suffix("/ws")
	if url.begins_with("wss://"):
		return "https://" + url.trim_prefix("wss://")
	if url.begins_with("ws://"):
		return "http://" + url.trim_prefix("ws://")
	return url
