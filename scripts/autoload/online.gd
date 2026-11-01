## Autoload "Online": duelo contra otra persona por internet.
##   - Conexión WebSocket con el servidor (server/ en este repositorio).
##   - Cola de emparejamiento: find_match() → QUEUED → MATCHED.
##   - Durante la pelea reparte los botones entre el combate y el rival
##     (la sincronización en sí está en lockstep_session.gd).
## Si la conexión se pierde o el rival se va, avisa por señal y el juego decide.
##
## Servidor: online_config.gd, o un archivo user://online.cfg con
##   [server]
##   url="wss://xxxx.up.railway.app/ws"
extends Node

signal state_changed(state: State)
## Hay rival: side, fighters y semilla ya están disponibles.
signal matched
## El rival se fue en plena pelea y ya no quedan botones suyos por aplicar.
signal opponent_left
## Fallo de conexión (mensaje legible para mostrar en pantalla).
signal failed(message: String)

enum State { IDLE, CONNECTING, QUEUED, MATCHED, FIGHTING }

const CONFIG_PATH := "user://online.cfg"
const Config := preload("res://scripts/autoload/online_config.gd")
## Si el servidor no responde en este tiempo, se da por caído.
const CONNECT_TIMEOUT := 8.0
const DEFAULT_NAME := "JUGADOR"

var url: String = ""
var state: State = State.IDLE
## 1 = controlo a P1, 2 = controlo a P2.
var side: int = 1
## Semilla común que reparte el servidor (reservada: hoy la simulación no usa azar).
var match_seed: int = 0
var opponent_fighter: StringName = &""
var opponent_name: String = ""

## Ticks seguidos esperando los botones del rival (para avisar al jugador).
var stalled_ticks: int:
	get:
		return _session.stalled_ticks if _session != null else 0

var _ws: WebSocketPeer
var _session: LockstepSession
var _pending: Array[Dictionary] = []
var _connect_time: float = 0.0
## Lee el teclado de J1 (WASD + U/I/J/K/O/L) aunque yo juegue de P2.
var _sampler := InputManager.new(1)
## El rival cerró su conexión. Se avisa solo cuando ya no quedan botones suyos por
## aplicar: si terminó la partida antes que yo, aún me faltan ticks por jugar.
var _opponent_gone: bool = false
var _left_emitted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	url = Config.SERVER_URL
	if OS.has_feature("web"):
		# En el navegador, el servicio web entrega la dirección del servidor en
		# /config.js (variable SERVER_URL del servicio), que index.html carga antes del juego.
		var web_url: Variant = JavaScriptBridge.eval("window.HC_SERVER_URL || ''")
		if web_url is String and web_url != "":
			url = web_url
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		url = str(cfg.get_value("server", "url", url))
	set_process(false)

# =========================================================================
#  Emparejamiento
# =========================================================================
## Conecta y entra en la cola con el luchador elegido.
func find_match(fighter_id: StringName, player_name: String) -> void:
	disconnect_from_server()
	_set_state(State.CONNECTING)
	_connect_time = 0.0
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	if err != OK:
		_fail("NO SE PUDO CONECTAR")
		return
	_pending.append({"t": "find", "fighter": String(fighter_id), "name": player_name})
	set_process(true)

## Sale de la cola (antes de encontrar rival).
func cancel() -> void:
	if state == State.QUEUED or state == State.CONNECTING:
		disconnect_from_server()

## Cierra la conexión y olvida la partida.
func disconnect_from_server() -> void:
	_close_socket()
	_session = null
	_opponent_gone = false
	_left_emitted = false
	_set_state(State.IDLE)

## Llamar al empezar el combate: marca la pelea en curso.
func begin_fight() -> void:
	_opponent_gone = false
	_left_emitted = false
	_set_state(State.FIGHTING)

# =========================================================================
#  Combate
# =========================================================================
## Fuente de entradas del combate (ver CombatManager.set_input_source).
## [] = faltan los botones del rival: el combate espera ese tick.
func input_source(tick: int) -> Array:
	if _session == null:
		return []
	var masks := _session.masks_for(tick)
	if masks.is_empty() and _opponent_gone and not _left_emitted:
		_left_emitted = true
		opponent_left.emit()
	return masks

func _new_session() -> LockstepSession:
	return LockstepSession.new(side, _sampler.sample_mask, func(frame: int, mask: int):
		_send({"t": "input", "f": frame, "m": mask}))

# =========================================================================
#  Red
# =========================================================================
func _process(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_CONNECTING:
			_connect_time += delta
			if _connect_time > CONNECT_TIMEOUT:
				_fail("EL SERVIDOR NO RESPONDE")
		WebSocketPeer.STATE_OPEN:
			for msg in _pending:
				_ws.send_text(JSON.stringify(msg))
			_pending.clear()
			while _ws != null and _ws.get_available_packet_count() > 0:
				_on_message(_ws.get_packet().get_string_from_utf8())
		WebSocketPeer.STATE_CLOSED:
			_on_closed()

func _send(msg: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))

func _on_message(text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		return
	match str(data.get("t", "")):
		"queued":
			_set_state(State.QUEUED)
		"matched":
			side = int(data.get("side", 1))
			match_seed = int(data.get("seed", 0))
			var opp: Dictionary = data.get("opponent", {})
			opponent_fighter = StringName(str(opp.get("fighter", "")))
			opponent_name = str(opp.get("name", DEFAULT_NAME))
			# La sesión existe desde ya: el rival puede entrar al combate antes que yo
			# y sus primeros botones no deben perderse.
			_session = _new_session()
			_set_state(State.MATCHED)
			matched.emit()
		"input":
			# Un mensaje fuera de lugar nunca debe tumbar la partida.
			if _session != null and data.has("f") and data.has("m"):
				_session.receive(int(data["f"]), int(data["m"]))
		"opponent_left":
			if state == State.FIGHTING:
				_opponent_gone = true
				_close_socket()
			else:
				_fail("EL RIVAL SE FUE")
		"error":
			push_warning("Servidor: %s" % str(data.get("msg", "")))

func _on_closed() -> void:
	var was := state
	_ws = null
	set_process(false)
	if was == State.IDLE:
		return
	_fail("SE PERDIÓ LA CONEXIÓN" if was != State.CONNECTING else "NO SE PUDO CONECTAR")

## Cierra solo el socket; la sesión conserva los botones ya recibidos.
func _close_socket() -> void:
	if _ws != null:
		if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_ws.send_text(JSON.stringify({"t": "leave"}))
		_ws.close()
	_ws = null
	_pending.clear()
	set_process(false)

func _fail(message: String) -> void:
	disconnect_from_server()
	failed.emit(message)

func _set_state(s: State) -> void:
	if state == s:
		return
	state = s
	state_changed.emit(s)
