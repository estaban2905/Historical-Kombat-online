## Un cliente real del duelo online, para la prueba de extremo a extremo.
## Se lanzan DOS procesos contra el servidor de server/ y se comparan sus logs
## (ver tests/run_online_e2e.sh). Cada uno entra a la cola, juega TICKS ticks
## con botones al azar usando Online (WebSocket de verdad) y escribe una línea
## "CHK <tick> <checksum>" cada 100 ticks. Si los dos PCs van sincronizados, las
## líneas coinciden.
## Con --email y --name entra con una cuenta (la crea si no existe): el duelo cuenta para el
## ranking y al final se imprime "SETTLED ..." con los puntos que confirmó el servidor.
## Uso:  godot --headless --path . res://tests/OnlineClientTest.tscn -- --url=ws://127.0.0.1:8787/ws --fighter=napoleon --seed=1 [--email=a@b.com --name=Ana_1]
extends Node

const TICKS := 600

var _fighter: StringName = &"napoleon"
var _email := ""
var _name := ""
var _seed := 1
var _combat: CombatManager
var _rng := RandomNumberGenerator.new()
var _done := false
## La pelea simulada ya terminó (puede que aún se esté esperando la confirmación de puntos).
var _fight_over := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--url="):
			ServerConfig.override_ws = arg.trim_prefix("--url=")
		elif arg.begins_with("--email="):
			_email = arg.trim_prefix("--email=")
		elif arg.begins_with("--name="):
			_name = arg.trim_prefix("--name=")
		elif arg.begins_with("--fighter="):
			_fighter = StringName(arg.trim_prefix("--fighter="))
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
	_rng.seed = _seed
	_run.call_deferred()

func _run() -> void:
	Game.mode = Game.Mode.ONLINE
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	Online.failed.connect(func(m: String): _finish("FALLO de conexión: %s" % m, 1))
	var token := ""
	if _email != "":
		Backend.session_path = "user://session_e2e_%d.cfg" % _seed
		var r := await Backend.sign_up(_email, "secreto1", _name)
		if not r.ok:
			r = await Backend.sign_in(_email, "secreto1")
		if not r.ok:
			_finish("FALLO de cuenta: %s" % r.error, 1)
			return
		token = Backend.access_token
	Online.find_match(_fighter, "BOT%d" % _seed, token)
	await Online.matched
	print("MATCHED side=%d rival=%s (%s) ranked=%s seed=%d" % [Online.side, Online.opponent_fighter, Online.opponent_name, Online.ranked, Online.match_seed])
	# Igual que el lobby: el servidor decide quién es P1 y quién P2.
	if Online.side == 1:
		Game.p1_fighter_id = _fighter
		Game.p2_fighter_id = Online.opponent_fighter
	else:
		Game.p1_fighter_id = Online.opponent_fighter
		Game.p2_fighter_id = _fighter
	_combat = load(Game.SCENE_FIGHT).instantiate() as CombatManager
	add_child(_combat)
	_combat.ticked.connect(_on_tick)
	_press_random()

## Cada tick, cambia lo que "teclea" este jugador (entradas virtuales del muestreador).
func _on_tick() -> void:
	if _done or _fight_over:
		return
	var t := _combat.tick_count
	if t % 100 == 0:
		print("CHK %d %d" % [t, _combat.state_checksum()])
	if t >= TICKS:
		_end_fight(t)
		return
	if t % 12 == 0:
		_press_random()
	if _rng.randf() < 0.12:
		Online._sampler.press(&"punch_light" if _rng.randf() < 0.5 else &"kick_heavy")

func _press_random() -> void:
	var inp := Online._sampler
	inp.release_all()
	var toward: StringName = &"right" if Online.side == 1 else &"left"
	var away: StringName = &"left" if Online.side == 1 else &"right"
	var r := _rng.randf()
	if r < 0.55:
		inp.hold(toward)
	elif r < 0.7:
		inp.hold(away)
	if _rng.randf() < 0.12:
		inp.hold(&"jump")
	if _rng.randf() < 0.1:
		inp.hold(&"block")

## La pelea de la prueba termina a los TICKS ticks. Como hace la pantalla de resultados: se
## reporta el resultado, se deja el combate y se espera a que el servidor confirme los puntos.
func _end_fight(t: int) -> void:
	_fight_over = true
	var h1: float = _combat.p1.health
	var h2: float = _combat.p2.health
	var winner := 1 if h1 > h2 else (2 if h2 > h1 else 0)
	print("FIN tick=%d vida=%.0f/%.0f" % [t, h1, h2])
	Online.report_result(winner, _combat.round_manager.wins[1], _combat.round_manager.wins[2])
	_combat.queue_free()
	if _email == "":
		_finish("", 0)
		return
	var deadline := Time.get_ticks_msec() + 20000
	while Online.last_settled.is_empty() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var s: Dictionary = Online.last_settled
	if s.is_empty():
		_finish("FALLO: el servidor no confirmó los puntos", 1)
		return
	print("SETTLED ranked=%s ok=%s delta=%d points=%d wins=%d losses=%d reason=%s" % [
		s.get("ranked"), s.get("ok"), int(s.get("delta", 0)), int(s.get("points", 0)),
		int(s.get("wins", 0)), int(s.get("losses", 0)), s.get("reason", "")])
	_finish("", 0)

func _finish(message: String, code: int) -> void:
	if _done:
		return
	_done = true
	if message != "":
		print(message)
	# Soltarse del servidor: el rival, que puede ir unos ticks atrás, debe poder terminar igual.
	Online.disconnect_from_server()
	get_tree().quit(code)
