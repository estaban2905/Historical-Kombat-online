## Prueba de determinismo (requisito del juego online).
## Juega la MISMA pelea varias veces con entradas pseudoaleatorias de semilla
## fija y compara un checksum del estado cada pocos ticks. Si alguna partida
## diverge, dos PCs con los mismos inputs verían peleas distintas.
## Uso:  godot --headless --path . res://tests/DeterminismTest.tscn
extends Node

const TICKS := 2400          # 40 s de combate
const SAMPLE_EVERY := 20
const SEEDS: Array[int] = [1, 7, 42]
const MATCHUPS: Array = [[&"donald_trump", &"napoleon"], [&"napoleon", &"donald_trump"]]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func _run() -> void:
	print("\n=== HISTORY COMBAT · PRUEBA DE DETERMINISMO ===")
	# Que ninguna ronda/partida termine y cambie de escena durante la prueba.
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	var failures := 0
	# --quick: un solo enfrentamiento y semilla (para ejecuciones en tiempo real).
	var quick := "--quick" in OS.get_cmdline_user_args()
	for matchup in (MATCHUPS.slice(0, 1) if quick else MATCHUPS):
		Game.p1_fighter_id = matchup[0]
		Game.p2_fighter_id = matchup[1]
		for s in (SEEDS.slice(0, 1) if quick else SEEDS):
			var a: Array = await _play(s)
			var b: Array = await _play(s)
			var diverge := -1
			for i in mini(a.size(), b.size()):
				if hash(a[i]) != hash(b[i]):
					diverge = a[i][0]
					print("    run A: ", a[i])
					print("    run B: ", b[i])
					break
			var ok := diverge == -1 and a.size() == b.size()
			# Vida final: comprueba que la pelea tuvo golpes de verdad (no dos luchadores quietos).
			var last: Array = a.back()
			print("  [%s] %s vs %s semilla %d: %d muestras, vida final %.0f / %.0f%s" % [
				"OK  " if ok else "FAIL", matchup[0], matchup[1], s, a.size(),
				last[5][2], last[6][2],
				"" if ok else " · primera divergencia en el tick %d" % diverge])
			if not ok:
				failures += 1
	print("\n=== RESULTADO: %d divergencias ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)

## Juega TICKS ticks y devuelve la lista de checksums.
func _play(seed_value: int) -> Array:
	var combat := load(Game.SCENE_FIGHT).instantiate() as CombatManager
	add_child(combat)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var held: Array[int] = [0, 0]
	combat.set_input_source(func(tick: int) -> Array:
		for p in 2:
			# Cada 12 ticks se elige un movimiento nuevo; los ataques se pulsan al azar.
			if tick % 12 == 0:
				held[p] = _random_movement(rng, p)
		var masks: Array = []
		for p in 2:
			var m: int = held[p]
			if rng.randf() < 0.12:
				m |= 1 << (5 + rng.randi_range(0, 5))
			masks.append(m)
		return masks)
	var samples: Array = []
	while combat.tick_count < TICKS:
		await get_tree().physics_frame
		if combat.tick_count % SAMPLE_EVERY == 0 and combat.tick_count > 0:
			samples.append(combat.state_snapshot())
	remove_child(combat)
	combat.free()
	return samples

## Máscara de movimiento: avanza hacia el rival casi siempre, con saltos y bloqueos.
func _random_movement(rng: RandomNumberGenerator, player: int) -> int:
	var m := 0
	var toward := 1 if player == 0 else 0   # bit 0 = izquierda, bit 1 = derecha
	var r := rng.randf()
	if r < 0.55:
		m |= 1 << toward
	elif r < 0.7:
		m |= 1 << (1 - toward)
	if rng.randf() < 0.12:
		m |= 1 << 2   # salto
	if rng.randf() < 0.1:
		m |= 1 << 3   # agacharse
	if rng.randf() < 0.1:
		m |= 1 << 4   # bloqueo
	return m
