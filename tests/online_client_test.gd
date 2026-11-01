## Un cliente real del duelo online, para la prueba de extremo a extremo.
## Se lanzan DOS procesos contra el servidor de server/ y se comparan sus logs
## (ver tests/run_online_e2e.sh). Cada uno entra a la cola, juega TICKS ticks
## con botones al azar usando Online (WebSocket de verdad) y escribe una línea
## "CHK <tick> <checksum>" cada 100 ticks. Si los dos PCs van sincronizados, las
## líneas coinciden.
## Uso:  godot --headless --path . res://tests/OnlineClientTest.tscn -- --url=ws://127.0.0.1:8080/ws --fighter=napoleon --seed=1
extends Node

const TICKS := 600

var _fighter: StringName = &"napoleon"
var _seed := 1
var _combat: CombatManager
var _rng := RandomNumberGenerator.new()
var _done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--url="):
			Online.url = arg.trim_prefix("--url=")
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
	Online.find_match(_fighter, "BOT%d" % _seed)
	await Online.matched
	print("MATCHED side=%d rival=%s (%s) seed=%d" % [Online.side, Online.opponent_fighter, Online.opponent_name, Online.match_seed])
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
	if _done:
		return
	var t := _combat.tick_count
	if t % 100 == 0:
		print("CHK %d %d" % [t, _combat.state_checksum()])
	if t >= TICKS:
		_finish("FIN tick=%d vida=%.0f/%.0f" % [t, _combat.p1.health, _combat.p2.health], 0)
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

func _finish(message: String, code: int) -> void:
	if _done:
		return
	_done = true
	print(message)
	# Soltarse del servidor: el rival, que puede ir unos ticks atrás, debe poder terminar igual.
	Online.disconnect_from_server()
	get_tree().quit(code)
