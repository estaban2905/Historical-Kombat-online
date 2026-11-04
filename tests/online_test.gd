## Prueba del duelo online sin red real.
## Simula DOS PCs, cada uno con su combate completo y su LockstepSession, unidos
## por un "cable" con latencia y variación. Cada jugador teclea botones al azar
## (semilla fija). Comprueba que:
##   - las dos peleas quedan idénticas en cada tick (mismo checksum), con o sin lag;
##   - si el lag supera el retraso de entrada, el combate espera y NO se desincroniza
##     (tampoco el reloj de la ronda);
##   - los botones de cada jugador llegan al luchador correcto (P1/P2);
##   - el servidor/rival que se va se detecta recién al agotar los botones recibidos;
##   - con mucho lag, el retraso se ajusta solo y la pelea deja de esperar.
## Uso:  godot --headless --path . res://tests/OnlineTest.tscn
extends Node

const TICKS := 900
const SAMPLE_EVERY := 10

var _failures := 0
var _frame := 0
## Mensajes en tránsito: {to: LockstepSession, at: frame, f, m, a}. Orden de llegada = orden de envío.
var _wire: Array[Dictionary] = []
var _last_arrival: Dictionary = {}
var _latency := 0
var _jitter := 0
var _net_rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		_failures += 1

func _run() -> void:
	print("\n=== HISTORY COMBAT · PRUEBA ONLINE (2 PCs simulados) ===")
	Online.use_rollback = false   # esta prueba cubre el lockstep (el rollback tiene la suya: RollbackNetTest)
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	Game.p1_fighter_id = &"donald_trump"
	Game.p2_fighter_id = &"napoleon"
	await _case("sin lag", 0, 0)
	await _case("lag 3 frames (dentro del retraso)", 3, 0)
	await _case("lag 12 frames con variación (provoca esperas)", 12, 6)
	await _case_adaptive_delay()
	await _case_lone_inputs()
	await _case_opponent_gone()
	await _case_timeout_message()
	await _case_timeout_ends_the_fight()
	await _case_sync_points()
	await _case_desync_ends_the_fight()
	print("\n=== RESULTADO: %d fallos ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

# -------------------------------------------------------------------------
#  Cable simulado
# -------------------------------------------------------------------------
func _physics_process(_delta: float) -> void:
	_frame += 1
	while not _wire.is_empty() and _wire[0].at <= _frame:
		var msg: Dictionary = _wire.pop_front()
		(msg.to as LockstepSession).receive(msg.f, msg.m, msg.a)

func _sender(to_ref: Array) -> Callable:
	return func(frame: int, mask: int, ack: int) -> void:
		var to: LockstepSession = to_ref[0]
		var at := _frame + _latency + (_net_rng.randi_range(0, _jitter) if _jitter > 0 else 0)
		# Un WebSocket entrega en orden: la variación nunca adelanta un mensaje a otro.
		at = maxi(at, _last_arrival.get(to, 0))
		_last_arrival[to] = at
		_wire.append({"to": to, "at": at, "f": frame, "m": mask, "a": ack})

## Reloj de las sesiones: el del cable simulado, en ms.
func _clock() -> int:
	return roundi(_frame * 1000.0 / 60.0)

## Botones al azar, siempre la misma secuencia para la misma semilla y jugador.
func _scripted_sampler(seed_value: int, player: int) -> Callable:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var state := {"held": 0, "n": 0}
	return func() -> int:
		if state.n % 12 == 0:
			state.held = _random_movement(rng, player)
		state.n += 1
		var m: int = state.held
		if rng.randf() < 0.12:
			m |= 1 << (5 + rng.randi_range(0, 5))
		return m

func _random_movement(rng: RandomNumberGenerator, player: int) -> int:
	var m := 0
	var toward := 1 if player == 0 else 0
	var r := rng.randf()
	if r < 0.55:
		m |= 1 << toward
	elif r < 0.7:
		m |= 1 << (1 - toward)
	if rng.randf() < 0.12:
		m |= 1 << 2
	if rng.randf() < 0.1:
		m |= 1 << 3
	if rng.randf() < 0.1:
		m |= 1 << 4
	return m

func _new_combat() -> CombatManager:
	var combat := load(Game.SCENE_FIGHT).instantiate() as CombatManager
	add_child(combat)
	return combat

# -------------------------------------------------------------------------
#  Casos
# -------------------------------------------------------------------------
func _case(label: String, latency: int, jitter: int) -> void:
	_wire.clear()
	_last_arrival.clear()
	_latency = latency
	_jitter = jitter
	_net_rng.seed = 99
	var ref_a := [null]
	var ref_b := [null]
	var sess_a := LockstepSession.new(1, _scripted_sampler(11, 0), _sender(ref_b), _clock)
	var sess_b := LockstepSession.new(2, _scripted_sampler(22, 1), _sender(ref_a), _clock)
	ref_a[0] = sess_a
	ref_b[0] = sess_b
	var a := _new_combat()
	var b := _new_combat()
	a.set_input_source(sess_a.masks_for)
	b.set_input_source(sess_b.masks_for)

	var snaps_a := {}
	var snaps_b := {}
	var max_stall := 0
	var guard := 0
	while (a.tick_count < TICKS or b.tick_count < TICKS) and guard < TICKS * 40:
		await get_tree().physics_frame
		guard += 1
		max_stall = maxi(max_stall, maxi(sess_a.stalled_ticks, sess_b.stalled_ticks))
		for pair in [[a, snaps_a], [b, snaps_b]]:
			var c: CombatManager = pair[0]
			# Solo la primera vez que se ve cada tick: durante la cinemática de un ultimate
			# tick_count no cambia aunque el estado sí, y cada PC la observa en un frame distinto.
			if c.tick_count % SAMPLE_EVERY == 0 and c.tick_count > 0 and c.tick_count <= TICKS \
					and not pair[1].has(c.tick_count):
				pair[1][c.tick_count] = hash(c.state_snapshot())

	var common := 0
	var diverge := -1
	for t in snaps_a:
		if snaps_b.has(t):
			common += 1
			if snaps_a[t] != snaps_b[t] and diverge == -1:
				diverge = t
	var progressed := a.tick_count >= TICKS and b.tick_count >= TICKS
	var hurt: bool = a.p1.health < a.p1.data.max_health or a.p2.health < a.p2.data.max_health
	check(progressed, "%s: los dos llegan al tick %d (A %d, B %d)" % [label, TICKS, a.tick_count, b.tick_count])
	check(common > 0 and diverge == -1, "%s: %d muestras idénticas%s" % [
		label, common, "" if diverge == -1 else " · primera divergencia en el tick %d" % diverge])
	check(hurt, "%s: hubo golpes de verdad (vida %.0f / %.0f)" % [label, a.p1.health, a.p2.health])
	if latency > 4:
		check(max_stall > 0, "%s: el combate esperó al rival (espera máx. %d ticks)" % [label, max_stall])
	else:
		check(max_stall <= 6, "%s: casi sin esperas (máx. %d)" % [label, max_stall])
	remove_child(a)
	remove_child(b)
	a.free()
	b.free()

## Con 12 frames de lag (200 ms de ida) el retraso inicial no alcanza: al principio
## se espera en casi cada tick (cámara lenta), pero el retraso sube solo y después
## la pelea corre a velocidad normal, sin desincronizarse.
func _case_adaptive_delay() -> void:
	_wire.clear()
	_last_arrival.clear()
	_latency = 12
	_jitter = 2
	_net_rng.seed = 7
	var ref_a := [null]
	var ref_b := [null]
	var sess_a := LockstepSession.new(1, _scripted_sampler(33, 0), _sender(ref_b), _clock)
	var sess_b := LockstepSession.new(2, _scripted_sampler(44, 1), _sender(ref_a), _clock)
	ref_a[0] = sess_a
	ref_b[0] = sess_b
	var a := _new_combat()
	var b := _new_combat()
	a.set_input_source(sess_a.masks_for)
	b.set_input_source(sess_b.masks_for)
	var frames_late := 0
	var ticks_late := 0
	var snaps_a := {}
	var snaps_b := {}
	var guard := 0
	while (a.tick_count < 600 or b.tick_count < 600) and guard < 6000:
		var before := a.tick_count
		await get_tree().physics_frame
		guard += 1
		if a.tick_count >= 300:
			frames_late += 1
			ticks_late += a.tick_count - before
		for pair in [[a, snaps_a], [b, snaps_b]]:
			var c: CombatManager = pair[0]
			if c.tick_count % SAMPLE_EVERY == 0 and c.tick_count > 0 and not pair[1].has(c.tick_count):
				pair[1][c.tick_count] = hash(c.state_snapshot())
	var common := 0
	var same := true
	for t in snaps_a:
		if snaps_b.has(t):
			common += 1
			same = same and snaps_a[t] == snaps_b[t]
	var speed := float(ticks_late) / maxf(frames_late, 1.0)
	check(sess_a.delay >= 12 and sess_b.delay >= 12,
		"el retraso sube solo con el lag (A %d, B %d ticks; ida y vuelta %.0f ms)" % [sess_a.delay, sess_b.delay, sess_a.rtt_ms])
	check(speed > 0.95, "ya ajustado, la pelea corre a velocidad normal (%.0f%% de 60 ticks/s)" % (speed * 100.0))
	check(common > 0 and same, "las dos peleas siguen idénticas tras cambiar el retraso (%d muestras)" % common)
	remove_child(a)
	remove_child(b)
	a.free()
	b.free()

## Cada jugador solo manda sus botones al luchador que le toca.
func _case_lone_inputs() -> void:
	_wire.clear()
	_last_arrival.clear()
	_latency = 0
	_jitter = 0
	var ref_a := [null]
	var ref_b := [null]
	# Solo P2 (B) pulsa «derecha» (bit 1) todo el tiempo; P1 (A) no toca nada.
	var sess_a := LockstepSession.new(1, func() -> int: return 0, _sender(ref_b))
	var sess_b := LockstepSession.new(2, func() -> int: return 1 << 0, _sender(ref_a))  # izquierda
	ref_a[0] = sess_a
	ref_b[0] = sess_b
	var a := _new_combat()
	var b := _new_combat()
	a.set_input_source(sess_a.masks_for)
	b.set_input_source(sess_b.masks_for)
	var x0 := a.p2.position.x
	var guard := 0
	# La intro de la ronda dura ~72 ticks: hasta entonces nadie puede moverse.
	while (a.tick_count < 150 or b.tick_count < 150) and guard < 2000:
		await get_tree().physics_frame
		guard += 1
	check(a.p2.position.x < x0 - 5.0 and b.p2.position.x < x0 - 5.0,
		"los botones de B mueven a P2 en AMBOS PCs (P2 x: %.0f → A %.0f, B %.0f)" % [x0, a.p2.position.x, b.p2.position.x])
	check(is_equal_approx(a.p1.position.x, b.p1.position.x) and is_equal_approx(a.p2.position.x, b.p2.position.x),
		"las posiciones coinciden entre los dos PCs")
	remove_child(a)
	remove_child(b)
	a.free()
	b.free()

## La sesión no inventa botones: sin los del rival, se detiene (y el aviso lo da Online).
func _case_opponent_gone() -> void:
	var sent: Array = []
	var sess := LockstepSession.new(1, func() -> int: return 0, func(f: int, m: int, _a: int): sent.append([f, m]))
	# Ticks iniciales: no necesitan botones del rival.
	for t in LockstepSession.INITIAL_DELAY:
		check(not sess.masks_for(t).is_empty(), "tick %d inicial se juega sin esperar" % t)
	check(sess.masks_for(LockstepSession.INITIAL_DELAY).is_empty(), "sin botones del rival, el tick %d espera" % LockstepSession.INITIAL_DELAY)
	check(sess.stalled_ticks == 1, "cuenta la espera")
	sess.receive(LockstepSession.INITIAL_DELAY, 5)
	var m := sess.masks_for(LockstepSession.INITIAL_DELAY)
	check(m == [0, 5], "al llegar los botones del rival, el tick se juega (P1=%s)" % [str(m)])
	check(sess.stalled_ticks == 0, "la espera se reinicia")
	# Pedir el mismo tick varias veces no manda botones repetidos.
	var before := sent.size()
	sess.masks_for(LockstepSession.INITIAL_DELAY + 1)
	sess.masks_for(LockstepSession.INITIAL_DELAY + 1)
	check(sent.size() - before == 1, "un solo envío por tick aunque se repita la consulta")
	# Del lado de P2 el orden de las máscaras se invierte.
	var s2 := LockstepSession.new(2, func() -> int: return 3, func(_f: int, _m: int, _a: int): pass)
	s2.receive(LockstepSession.INITIAL_DELAY, 7)
	for t in LockstepSession.INITIAL_DELAY:
		s2.masks_for(t)
	check(s2.masks_for(LockstepSession.INITIAL_DELAY) == [7, 3], "P2 recibe [rival, yo]")

## El servidor cierra el duelo si nadie responde (NET-02): el cliente lo recibe y cuenta la espera.
func _case_timeout_message() -> void:
	var got: Array = []
	var on_timeout := func(loser: int) -> void: got.append(loser)
	Online.timed_out.connect(on_timeout)
	Online._on_message('{"t":"timeout","loser":1}')
	check(got.is_empty(), "fuera de una pelea se ignora el cierre por espera")
	Online.begin_fight()
	Online._on_message('{"t":"timeout","loser":2}')
	Online._on_message('{"t":"timeout","loser":9}')
	Online._on_message('{"t":"timeout"}')
	check(got == [2, 0, 0], "el cierre por espera avisa de quién perdió; si el dato no vale, se anula (%s)" % [str(got)])
	Online.timed_out.disconnect(on_timeout)
	# La cuenta atrás que ve el jugador sale de los ticks esperando al rival.
	Online._session = LockstepSession.new(1, func() -> int: return 0, func(_f: int, _m: int, _a: int): pass)
	for t in LockstepSession.INITIAL_DELAY:
		Online._session.masks_for(t)
	Online._session.masks_for(LockstepSession.INITIAL_DELAY)
	check(Online.stall_seconds_left() == Online.RIVAL_TIMEOUT_S, "al empezar la espera quedan los %d s completos" % Online.RIVAL_TIMEOUT_S)
	for i in 60:
		Online._session.masks_for(LockstepSession.INITIAL_DELAY)
	check(Online.stall_seconds_left() == Online.RIVAL_TIMEOUT_S - 1, "tras un segundo esperando queda uno menos")
	for i in 20 * 60:
		Online._session.masks_for(LockstepSession.INITIAL_DELAY)
	check(Online.stall_seconds_left() == 0, "la cuenta atrás no baja de cero")
	Online.disconnect_from_server()

## En el combate real: sin botones del rival aparece la cuenta atrás y, al cerrar el servidor el duelo,
## la pelea termina dando la victoria al que no perdió la respuesta.
func _case_timeout_ends_the_fight() -> void:
	var old_mode := Game.mode
	Game.mode = Game.Mode.ONLINE
	Online.side = 1
	Online._session = LockstepSession.new(1, func() -> int: return 0, func(_f: int, _m: int, _a: int): pass)
	var combat := _new_combat()
	for i in 90:
		await get_tree().physics_frame
	check(combat._waiting_label.visible and combat._waiting_label.text == "CONEXIÓN LENTA...",
		"sin botones del rival se ve un aviso de conexión lenta, sin cuenta atrás al principio (%s)" % combat._waiting_label.text)
	for i in (Online.RIVAL_TIMEOUT_S - CombatManager.WAIT_COUNTDOWN_FROM) * 60:
		await get_tree().physics_frame
	check(combat._waiting_label.visible and combat._waiting_label.text.ends_with("%d" % Online.stall_seconds_left()),
		"en los últimos segundos se ve la cuenta atrás (%s)" % combat._waiting_label.text)
	Game.last_winner = -1
	Online._on_message('{"t":"timeout","loser":2}')
	check(combat.round_manager.phase == RoundManager.Phase.MATCH_END, "al cerrar el servidor el duelo, la pelea se detiene")
	var waited := 0
	while Game.last_winner != 1 and waited < 400:
		await get_tree().physics_frame
		waited += 1
	check(Game.last_winner == 1, "pierde quien dejó de responder: gana P1 (ganador %d)" % Game.last_winner)
	# Game.goto ya está cambiando a Resultados: se deja terminar y se limpia.
	await get_tree().create_timer(0.6).timeout
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
	if is_instance_valid(combat):
		combat.queue_free()
	Online.disconnect_from_server()
	Game.mode = old_mode
	await get_tree().physics_frame

## Cada segundo de pelea el combate online emite un punto de control con el resumen del estado (NET-01).
func _case_sync_points() -> void:
	Game.mode = Game.Mode.VERSUS
	var combat := _new_combat()
	var points: Array = []
	combat.sync_point.connect(func(tick: int, checksum: int, version: int) -> void: points.append([tick, checksum, version]))
	for i in 130:
		await get_tree().physics_frame
	check(points.is_empty(), "fuera del online no se emiten puntos de control")
	combat.sync_enabled = true
	var start := combat.tick_count
	while combat.tick_count < start + 130:
		await get_tree().physics_frame
	var ticks: Array = points.map(func(p: Array) -> int: return p[0])
	var expected: Array = []
	for t in range(start + 1, combat.tick_count + 1):
		if t % CombatManager.SYNC_EVERY == 0:
			expected.append(t)
	check(not ticks.is_empty() and ticks == expected, "emite uno cada %d ticks (%s de %s)" % [CombatManager.SYNC_EVERY, str(ticks), str(expected)])
	check(points[0][2] == CombatManager.SNAPSHOT_VERSION, "lleva la versión del resumen")
	combat.queue_free()
	await get_tree().physics_frame

## Si el servidor avisa de que las peleas se separaron, el duelo se anula y se vuelve al menú.
func _case_desync_ends_the_fight() -> void:
	var got: Array = []
	var on_desync := func(loser: int) -> void: got.append(loser)
	Online.desynced.connect(on_desync)
	Online._on_message('{"t":"desync"}')
	check(got.is_empty(), "fuera de una pelea se ignora el aviso de desincronización")
	Online.begin_fight()
	Online._on_message('{"t":"desync"}')
	Online._on_message('{"t":"desync","loser":2}')
	Online._on_message('{"t":"desync","loser":9}')
	check(got == [0, 2, 0], "el aviso dice quién pierde si se repite; sin dato válido, el duelo se anula (%s)" % [str(got)])
	Online.desynced.disconnect(on_desync)
	Online.disconnect_from_server()
	var old_mode := Game.mode
	Game.mode = Game.Mode.ONLINE
	Online.side = 1
	Online._session = LockstepSession.new(1, func() -> int: return 0, func(_f: int, _m: int, _a: int): pass)
	var combat := _new_combat()
	await get_tree().physics_frame
	Online._on_message('{"t":"desync"}')
	check(combat.round_manager.phase == RoundManager.Phase.MATCH_END, "al anularse por desincronización la pelea se detiene")
	await get_tree().create_timer(2.6).timeout
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
	if is_instance_valid(combat):
		combat.queue_free()
	Online.disconnect_from_server()
	Game.mode = old_mode
	await get_tree().physics_frame
