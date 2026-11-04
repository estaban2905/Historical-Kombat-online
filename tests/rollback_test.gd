## Prueba de la foto del estado (SimState): requisito del rollback online.
## Para cada pelea: juega, toma una foto en un tick, sigue W ticks anotando el resumen de cada uno,
## VUELVE a la foto y repite los W ticks. Los dos recorridos deben dar lo mismo en todos los ticks y
## el estado completo (no solo el resumen) debe coincidir al final. Si falta algún campo en la foto,
## aquí es donde se nota.
## Uso:  godot --headless --fixed-fps 60 --path . res://tests/RollbackTest.tscn [-- --quick]
extends Node

const WINDOW := 90
const WARMUP := 110
## Cada cuántos ticks se toma una foto de prueba, y hasta qué tick se juega.
const CHECK_EVERY := 150
const TICKS := 1800
const DELTA := 1.0 / 60.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func _run() -> void:
	print("\n=== HISTORY COMBAT · PRUEBA DE ROLLBACK (foto y restauración) ===")
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	var quick := "--quick" in OS.get_cmdline_user_args()
	var roster := FighterRegistry.all()
	var failures := 0
	var windows := 0
	var skipped := 0
	var step := 1 if not quick else roster.size()
	var i := 0
	while i < roster.size():
		var a := roster[i].id
		var b := roster[(i + roster.size() / 2) % roster.size()].id
		var r: Array = await _fight(a, b, 500 + i)
		failures += r[0]
		windows += r[1]
		skipped += r[2]
		i += step
		if quick:
			break
	failures += await _events_check()
	print("\n  %d ventanas comprobadas (%d descartadas por cambio de ronda)" % [windows, skipped])
	if windows == 0:
		failures += 1
		print("  [FAIL] no se comprobó ninguna ventana")
	print("\n=== RESULTADO: %d fallos ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)

## Una pelea completa con fotos de prueba. Devuelve [fallos, ventanas, descartadas].
func _fight(a: StringName, b: StringName, seed_value: int) -> Array:
	Game.p1_fighter_id = a
	Game.p2_fighter_id = b
	var combat := load(Game.SCENE_FIGHT).instantiate() as CombatManager
	add_child(combat)
	await get_tree().physics_frame
	combat.set_physics_process(false)
	# Los botones dependen solo del tick (no de cuántas veces se pregunte): hay que poder repetirlos.
	var script := ScriptedInputs.new(seed_value)
	var masks: Array = []
	for t in TICKS + WINDOW + 10:
		masks.append(script.masks(t))
	combat.set_input_source(func(tick: int) -> Array: return masks[tick])
	var failures := 0
	var windows := 0
	var skipped := 0
	while combat.tick_count < TICKS:
		if combat.tick_count >= WARMUP and combat.tick_count % CHECK_EVERY == 0:
			var res := _window(combat)
			if res == -2:
				skipped += 1
			else:
				windows += 1
				if res != -1:
					failures += 1
					print("  [FAIL] %s vs %s: la repetición se separa en el tick %d" % [a, b, res])
		_tick(combat)
	remove_child(combat)
	combat.free()
	if failures == 0:
		print("  [OK  ] %s vs %s" % [a, b])
	return [failures, windows, skipped]

## Un tick con el relleno de energía (depende solo del tick, para poder repetirlo).
func _tick(combat: CombatManager) -> void:
	if combat.tick_count % 200 == 0:
		combat.p1.energy = Fighter.MAX_ENERGY
		combat.p2.energy = Fighter.MAX_ENERGY
	combat._physics_process(DELTA)

## Foto, WINDOW ticks, restaurar, WINDOW ticks. -1 = igual; -2 = ventana descartada (cambió la ronda);
## otro valor = primer tick en que se separan.
func _window(combat: CombatManager) -> int:
	var snap := SimState.capture(combat)
	var phase0 := combat.round_manager.phase
	var first: Array = []
	for k in WINDOW:
		_tick(combat)
		SimState.purge_dead(combat)
		first.append(hash(combat.state_snapshot()))
	if combat.round_manager.phase == RoundManager.Phase.MATCH_END:
		# El rollback no deshace cambios de ronda: se deja el combate como estaba y se sigue.
		SimState.restore(combat, snap)
		return -2
	var end_a := SimState.capture(combat)
	SimState.restore(combat, snap)
	SimState.purge_dead(combat)
	# Recién restaurado debe verse idéntico al momento de la foto.
	var again := SimState.capture(combat)
	if not _same(snap, again, 0):
		return snap["tick"]
	for k in WINDOW:
		_tick(combat)
		SimState.purge_dead(combat)
		if hash(combat.state_snapshot()) != first[k]:
			return snap["tick"] + k + 1
	var end_b := SimState.capture(combat)
	if not _same(end_a, end_b, 0):
		print("    el resumen coincide pero el estado completo no (ventana en el tick %d)" % snap["tick"])
		return snap["tick"] + WINDOW
	return -1

## Comparación profunda. Los Resources se comparan por sus valores guardados (una entidad nueva
## puede traer una copia del ataque, no la misma referencia).
func _same(x: Variant, y: Variant, depth: int) -> bool:
	if x is Dictionary and y is Dictionary:
		if x.size() != y.size():
			return false
		for k in x:
			if not y.has(k) or not _same(x[k], y[k], depth):
				return false
		return true
	if x is Array and y is Array:
		if x.size() != y.size():
			return false
		for i in x.size():
			if not _same(x[i], y[i], depth):
				return false
		return true
	if x is Resource and y is Resource:
		if x == y:
			return true
		if depth > 3 or x.get_class() != y.get_class() or x.get_script() != y.get_script():
			return false
		for p in x.get_property_list():
			if (int(p["usage"]) & PROPERTY_USAGE_STORAGE) != 0 and not _same(x.get(p["name"]), y.get(p["name"]), depth + 1):
				return false
		return true
	return typeof(x) == typeof(y) and x == y

## Cola de presentación: los efectos de un tick esperan a que se confirme y se descartan al reescribirlo.
class Probe:
	extends RefCounted
	var calls: Array = []
	func hit(tag: int) -> void:
		calls.append(tag)

func _events_check() -> int:
	Game.p1_fighter_id = &"julio_cesar"
	Game.p2_fighter_id = &"adolf_hitler"
	var combat := load(Game.SCENE_FIGHT).instantiate() as CombatManager
	add_child(combat)
	await get_tree().physics_frame
	combat.set_physics_process(false)
	var probe := Probe.new()
	var bad := 0
	# 1) Offline (todo confirmado): un efecto anotado en un tick suena al terminar ese tick.
	combat._in_tick = true
	combat.present(probe, &"hit", [1])
	combat._in_tick = false
	combat._flush_events()
	bad += _expect(probe.calls == [1], "offline reproduce al terminar el tick")
	# 2) Con rollback: no suena hasta confirmar, y no si se descarta.
	combat.confirmed_tick = combat.tick_count
	combat._ev_tick = combat.tick_count
	combat._in_tick = true
	combat.present(probe, &"hit", [2])
	combat.present(probe, &"hit", [3], 5)
	combat._in_tick = false
	combat.tick_count += 1
	combat._flush_events()
	bad += _expect(probe.calls == [1], "sin confirmar no suena")
	combat.confirmed_tick = combat.tick_count
	combat._flush_events()
	bad += _expect(probe.calls == [1, 2], "al confirmar suena lo que toca ya")
	combat.tick_count += 5
	combat.discard_events_from(combat.tick_count - 6)
	combat.confirmed_tick = -1
	combat._flush_events()
	bad += _expect(probe.calls == [1, 2], "lo descartado no suena nunca")
	# 3) Efectos de pantalla del ultimate: se descartan con el tick que los creó.
	var atk: AttackData = combat.p1.data.ultimate if "ultimate" in combat.p1.data else null
	if atk != null and atk.ult_kind != &"":
		combat.start_ult_fx(atk)
		combat.ult_fx_at(10, &"flash")
		combat.discard_events_from(combat.tick_count)
		bad += _expect(not is_instance_valid(combat.ult_fx) or combat.ult_fx.is_queued_for_deletion(), "ultimate descartado")
	remove_child(combat)
	combat.free()
	return bad

func _expect(ok: bool, what: String) -> int:
	print("  [%s] cola de presentación: %s" % ["OK  " if ok else "FAIL", what])
	return 0 if ok else 1
