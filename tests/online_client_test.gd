## Un cliente real del duelo online, para la prueba de extremo a extremo.
## Se lanzan DOS procesos contra el servidor de server/ y se comparan sus logs
## (ver tests/run_online_e2e.sh). Cada uno entra a la cola, juega TICKS ticks
## con botones al azar usando Online (WebSocket de verdad) y escribe una línea
## "CHK <tick> <checksum>" cada 100 ticks. Si los dos PCs van sincronizados, las
## líneas coinciden.
## Con --email y --name entra con una cuenta (la crea si no existe): el duelo cuenta para el
## ranking y al final se imprime "SETTLED ..." con los puntos que confirmó el servidor.
## Uso:  godot --headless --path . res://tests/OnlineClientTest.tscn -- --url=ws://127.0.0.1:8787/ws --fighter=napoleon --seed=1 [--email=a@b.com --name=Ana_1]
## Para llenar un servidor de datos de verdad (tests/populate_dev.sh), además:
##   --duels=N            juega N duelos seguidos (cada uno vuelve a la cola: los rivales van variando); 0 = solo lo social
##   --fighters=a,b,c     luchador de cada duelo, por turnos (en vez de --fighter)
##   --aggr=0.12          probabilidad de atacar en cada tick (más alta = gana más)
##   --friends=Ana,Beto   pide amistad a esos jugadores antes de jugar (si ya la pidieron ellos, quedan amigos)
##   --challenge-to=Ana   reta a Ana y juega ese duelo amistoso en la sala privada del reto
##   --challenge-from=Ana espera el reto de Ana (espera larga) y entra a su sala
extends Node

const TICKS := 600

var _fighter: StringName = &"napoleon"
var _fighters: Array[StringName] = []
var _email := ""
var _name := ""
var _seed := 1
var _duels := 1
var _aggr := 0.12
var _friends := PackedStringArray()
var _challenge_to := ""
var _challenge_from := ""
var _token := ""
## Duelos ya jugados (y si el que está en curso es amistoso).
var _played := 0
var _friendly := false
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
		elif arg.begins_with("--duels="):
			_duels = int(arg.trim_prefix("--duels="))
		elif arg.begins_with("--fighters="):
			for f in arg.trim_prefix("--fighters=").split(","):
				_fighters.append(StringName(f))
		elif arg.begins_with("--aggr="):
			_aggr = float(arg.trim_prefix("--aggr="))
		elif arg.begins_with("--friends="):
			_friends = arg.trim_prefix("--friends=").split(",", false)
		elif arg.begins_with("--challenge-to="):
			_challenge_to = arg.trim_prefix("--challenge-to=")
		elif arg.begins_with("--challenge-from="):
			_challenge_from = arg.trim_prefix("--challenge-from=")
	_rng.seed = _seed
	_run.call_deferred()

func _run() -> void:
	Game.mode = Game.Mode.ONLINE
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	Online.failed.connect(func(m: String): _finish("FALLO de conexión: %s" % m, 1))
	if _email != "":
		Backend.session_path = "user://session_e2e_%d.cfg" % _seed
		var r := await Backend.sign_up(_email, "secreto1", _name)
		if not r.ok:
			r = await Backend.sign_in(_email, "secreto1")
		if not r.ok:
			_finish("FALLO de cuenta: %s" % r.error, 1)
			return
		_token = Backend.access_token
		print("CUENTA %s" % Backend.username())
		for f in _friends:
			var fr := await Backend.request_friend(f)
			print("AMISTAD %s %s %s" % [f, fr.get("result", ""), fr.get("error", "")])
	if _duels <= 0:
		_finish("", 0)   # --duels=0: solo lo social
		return
	await _next_duel()

## Entra al siguiente duelo: primero el reto (si hay), luego la cola con ranking.
func _next_duel() -> void:
	var room := ""
	_friendly = false
	if _played == 0 and _challenge_to != "":
		var ch := await Backend.create_challenge(_challenge_to)
		if not ch.ok:
			_finish("FALLO al retar a %s: %s" % [_challenge_to, ch.error], 1)
			return
		room = str(ch.code)
		print("RETO a %s sala=%s" % [_challenge_to, room])
	elif _played == 0 and _challenge_from != "":
		var deadline := Time.get_ticks_msec() + 60000
		while room == "" and Time.get_ticks_msec() < deadline:
			for c in await Backend.fetch_challenges(Backend.CHALLENGE_WAIT):
				if str(c.get("from", "")).to_lower() == _challenge_from.to_lower():
					room = str(c.get("code", ""))
		if room == "":
			_finish("FALLO: no llegó el reto de %s" % _challenge_from, 1)
			return
		print("RETO de %s sala=%s" % [_challenge_from, room])
	_friendly = room != ""
	if not _fighters.is_empty():
		_fighter = _fighters[_played % _fighters.size()]
	Online.find_match(_fighter, Backend.username() if _token != "" else "BOT%d" % _seed, _token, room)
	# Con varios duelos seguidos puede que al final ya no quede nadie en la cola: se termina sin error.
	var matched := [false]
	var on_matched := func(_a = null, _b = null, _c = null): matched[0] = true
	Online.matched.connect(on_matched, CONNECT_ONE_SHOT)
	var wait_until := Time.get_ticks_msec() + (45000 if _played > 0 else 120000)
	while not matched[0] and not _done and Time.get_ticks_msec() < wait_until:
		await get_tree().process_frame
	if _done:
		return
	if not matched[0]:
		Online.matched.disconnect(on_matched)
		print("SIN RIVAL tras %d duelos" % _played)
		_finish("", 0)
		return
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
	if _rng.randf() < _aggr:
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
	if _friendly and s.get("ranked", true):
		_finish("FALLO: el duelo del reto contó para el ranking", 1)
		return
	if s.get("ranked", false) and s.get("ok", false):
		Backend.apply_settled(s)
		# Como la pantalla de resultados: los títulos de logros se dan al terminar el duelo.
		for title in await Cosmetics.refresh_achievements():
			print("TITULO %s" % title)
	_played += 1
	if _played >= _duels:
		_finish("", 0)
		return
	Online.disconnect_from_server()
	await get_tree().create_timer(_rng.randf_range(0.2, 1.5)).timeout
	_fight_over = false
	await _next_duel()

func _finish(message: String, code: int) -> void:
	if _done:
		return
	_done = true
	if message != "":
		print(message)
	# Soltarse del servidor: el rival, que puede ir unos ticks atrás, debe poder terminar igual.
	Online.disconnect_from_server()
	get_tree().quit(code)
