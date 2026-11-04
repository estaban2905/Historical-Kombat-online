## Prueba del online con ROLLBACK, sin red real: DOS PCs simulados, cada uno con su combate completo y su
## RollbackSession, unidos por un "cable" con latencia, variación y "pérdidas" (un WebSocket sobre TCP
## no pierde mensajes: el paquete perdido se retransmite y llega tarde, junto con los que iban detrás).
## Comprueba que, con red mala:
##   - los dos combates avanzan sin congelarse (no esperan al rival salvo pasarse del límite de adelanto);
##   - se vuelve atrás (rollback) cuando la predicción falla, y la pelea sigue;
##   - los resúmenes de estado que cada PC da por definitivos son IDÉNTICOS en los dos.
## Uso:  godot --headless --fixed-fps 60 --path . res://tests/RollbackNetTest.tscn
extends Node

const TICKS := 900

var _failures := 0
var _frame := 0
var _wire: Array[Dictionary] = []
var _last_arrival: Dictionary = {}
var _latency := 0
var _jitter := 0
var _loss := 0.0
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
	print("\n=== HISTORY COMBAT · PRUEBA DE ROLLBACK ONLINE (2 PCs simulados) ===")
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	Game.p1_fighter_id = &"donald_trump"
	Game.p2_fighter_id = &"napoleon"
	for pair in [[&"napoleon", &"cleopatra"], [&"julio_cesar", &"juana_de_arco"], [&"nikola_tesla", &"genghis_khan"]]:
		if not FighterRegistry.has(pair[0]) or not FighterRegistry.has(pair[1]):
			continue
		Game.p1_fighter_id = pair[0]
		Game.p2_fighter_id = pair[1]
		await _case("%s vs %s, ping 150 ms" % [pair[0], pair[1]], 5, 2, 0.03)
	Game.p1_fighter_id = &"donald_trump"
	Game.p2_fighter_id = &"napoleon"
	await _case("rival que carga 1 s más tarde", 3, 1, 0.0, 60)
	await _case("sin lag", 0, 0, 0.0)
	await _case("lag 4 frames", 4, 1, 0.0)
	await _case("ping 150 ms (ida 75), variación 40 ms, 3% de pérdidas", 5, 2, 0.03)
	await _case("lag duro: ping 300 ms con variación", 9, 3, 0.03)
	# Rondas de 6 s y 1500 ticks: cruza varios fines de ronda (y el cambio de escenario) con rollbacks profundos.
	Game.round_time = 6
	await _case("cambio de ronda con ping 150 ms", 5, 2, 0.03, 0, 1500)
	await _case("cambio de ronda con lag duro", 9, 3, 0.03, 0, 1500)
	await _case("cambio de ronda, rival que carga 1 s más tarde", 3, 1, 0.0, 60, 1500)
	Game.round_time = 99
	print("\n=== RESULTADO: %d fallos ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

# -------------------------------------------------------------------------
#  Cable simulado
# -------------------------------------------------------------------------
func _physics_process(_delta: float) -> void:
	_frame += 1
	while not _wire.is_empty() and _wire[0].at <= _frame:
		var msg: Dictionary = _wire.pop_front()
		(msg.to as RollbackSession).receive(msg.f, msg.m, msg.a)

func _sender(to_ref: Array) -> Callable:
	return func(frame: int, mask: int, ack: int) -> void:
		var to: RollbackSession = to_ref[0]
		var at := _frame + _latency + (_net_rng.randi_range(0, _jitter) if _jitter > 0 else 0)
		# Pérdida + retransmisión: llega mucho más tarde (y TCP no deja pasar a los siguientes).
		if _loss > 0.0 and _net_rng.randf() < _loss:
			at += 12
		at = maxi(at, _last_arrival.get(to, 0))
		_last_arrival[to] = at
		_wire.append({"to": to, "at": at, "f": frame, "m": mask, "a": ack})

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

func _new_combat(session: RollbackSession, sums: Dictionary) -> CombatManager:
	var combat := load(Game.SCENE_FIGHT).instantiate() as CombatManager
	add_child(combat)
	combat.sync_enabled = true
	session.sync_out = func(t: int, c: int) -> void: sums[t] = c
	combat.set_rollback(session)
	return combat

# -------------------------------------------------------------------------
func _case(label: String, latency: int, jitter: int, loss: float, late_b: int = 0, ticks: int = TICKS) -> void:
	_wire.clear()
	_last_arrival.clear()
	_latency = latency
	_jitter = jitter
	_loss = loss
	_net_rng.seed = 99
	var ref_a := [null]
	var ref_b := [null]
	var sess_a := RollbackSession.new(1, _scripted_sampler(11, 0), _sender(ref_b), _clock)
	var sess_b := RollbackSession.new(2, _scripted_sampler(22, 1), _sender(ref_a), _clock)
	ref_a[0] = sess_a
	ref_b[0] = sess_b
	var sums_a := {}
	var sums_b := {}
	var a := _new_combat(sess_a, sums_a)
	var b := _new_combat(sess_b, sums_b)

	if late_b > 0:
		b.set_physics_process(false)
	var frames := 0
	var stalled_frames := 0
	while (a.tick_count < ticks or b.tick_count < ticks) and frames < ticks * 6:
		await get_tree().physics_frame
		frames += 1
		if late_b > 0 and frames == late_b:
			b.set_physics_process(true)
		if sess_a.stalled_ticks > 0 or sess_b.stalled_ticks > 0:
			stalled_frames += 1

	var common := 0
	var diverge := -1
	for t in sums_a:
		if sums_b.has(t):
			common += 1
			if sums_a[t] != sums_b[t] and diverge == -1:
				diverge = t
	# Los botones que cada PC usó de ÉL y de SU RIVAL en cada tick definitivo deben ser los mismos.
	var bad_inputs := 0
	var first_bad := -1
	for t in sess_a.trace:
		if t < mini(sess_a.confirmed_tick(), sess_b.confirmed_tick()) - 20 and sess_b.trace.has(t):
			if sess_a.trace[t][0] != sess_b.trace[t][1] or sess_a.trace[t][1] != sess_b.trace[t][0]:
				bad_inputs += 1
				if bad_inputs <= 6:
					print("      t=%d A=%s B=%s" % [t, sess_a.trace[t], sess_b.trace[t]])
				if first_bad == -1 or t < first_bad:
					first_bad = t
	check(bad_inputs == 0, "%s: los dos usaron los mismos botones en cada tick definitivo (%d distintos, primero %d)" % [label, bad_inputs, first_bad])
	var hurt: bool = a.p1.health < a.p1.data.max_health or a.p2.health < a.p2.data.max_health
	check(a.tick_count >= ticks and b.tick_count >= ticks, "%s: los dos llegan al tick %d en %d frames (A %d, B %d)" % [
		label, ticks, frames, a.tick_count, b.tick_count])
	check(common > 0 and diverge == -1, "%s: %d resúmenes definitivos idénticos%s" % [
		label, common, "" if diverge == -1 else " · primera divergencia en el tick %d" % diverge])
	check(hurt, "%s: hubo golpes de verdad" % label)
	print("      rollbacks A/B: %d/%d · profundidad máx. %d/%d · re-simulados %d/%d · frames parados %d" % [
		sess_a.rollbacks, sess_b.rollbacks, sess_a.max_depth, sess_b.max_depth,
		sess_a.resimulated_ticks, sess_b.resimulated_ticks, stalled_frames])
	if latency >= 4:
		check(sess_a.rollbacks + sess_b.rollbacks > 0, "%s: hubo rollbacks (la predicción falló alguna vez)" % label)
	if latency <= 5:
		check(stalled_frames * 10 <= frames, "%s: casi sin parones (%d de %d frames)" % [label, stalled_frames, frames])
	remove_child(a)
	remove_child(b)
	a.free()
	b.free()
