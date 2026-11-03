## Benchmark de la simulación: cuánto tarda cada tick de combate (µs) sin dibujar nada.
## Solo registra los números para tener una línea base y ver si una versión los empeora; no falla
## salvo que se le pase un umbral:  godot --headless --path . res://tests/BenchmarkTest.tscn -- --max-p95-us=3000
## Mide el código de la simulación (luchadores, impactos, poderes, proyectiles, HUD y efectos como nodos),
## no la GPU ni el navegador: para eso hace falta el Profiler o Chrome DevTools.
##
## Los ticks se ejecutan a mano, uno tras otro, con entradas de semilla fija (incluyen ultimates).
extends Node

const TICKS := 3600   # 1 minuto de pelea
const WARMUP := 120
const MATCHUPS: Array = [
	[&"napoleon", &"donald_trump"],
	[&"vladimir_putin", &"kim_jong_un"],
	[&"nikola_tesla", &"albert_einstein"],
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func _run() -> void:
	print("\n=== HISTORY COMBAT · BENCHMARK DE LA SIMULACIÓN ===")
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	var max_p95 := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--max-p95-us="):
			max_p95 = int(arg.trim_prefix("--max-p95-us="))
	var worst_p95 := 0
	for m in MATCHUPS:
		Game.p1_fighter_id = m[0]
		Game.p2_fighter_id = m[1]
		var combat := load(Game.SCENE_FIGHT).instantiate() as CombatManager
		add_child(combat)
		await get_tree().physics_frame
		combat.set_physics_process(false)
		var script := ScriptedInputs.new(11)
		combat.set_input_source(func(tick: int) -> Array: return script.masks(tick))
		var hits := [0]
		combat.hit_landed.connect(func(_a: Fighter, _d: Fighter, _atk: AttackData, _r: Dictionary) -> void: hits[0] += 1)
		var times := PackedInt64Array()
		var delta := 1.0 / 60.0
		for i in WARMUP + TICKS:
			if combat.tick_count % 400 == 0:
				combat.p1.energy = Fighter.MAX_ENERGY
				combat.p2.energy = Fighter.MAX_ENERGY
			var t0 := Time.get_ticks_usec()
			combat._physics_process(delta)
			var dt := Time.get_ticks_usec() - t0
			if i >= WARMUP:
				times.append(dt)
		remove_child(combat)
		combat.free()
		times.sort()
		var total := 0
		for t in times:
			total += t
		var p95 := times[int(times.size() * 0.95)]
		worst_p95 = maxi(worst_p95, p95)
		print("  %s vs %s: media %d µs · p95 %d µs · p99 %d µs · máx %d µs (%d ticks, %d golpes)" % [
			m[0], m[1], total / times.size(), p95, times[int(times.size() * 0.99)], times[times.size() - 1], times.size(), hits[0]])
	print("  (un tick a 60 Hz dispone de 16667 µs)")
	var failed := max_p95 > 0 and worst_p95 > max_p95
	if failed:
		print("  [FAIL] p95 %d µs supera el umbral de %d µs" % [worst_p95, max_p95])
	print("\n=== RESULTADO: peor p95 %d µs ===" % worst_p95)
	get_tree().quit(1 if failed else 0)
