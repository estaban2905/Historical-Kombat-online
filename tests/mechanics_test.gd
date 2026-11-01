## Pruebas de mecánicas de combate (agarre, defensa, combos...).
## Mueven el combate real con máscaras de entrada por tick, igual que el online,
## así que cada caso es exacto y repetible.
## Uso:  godot --headless --fixed-fps 60 --path . res://tests/MechanicsTest.tscn
extends Node

const BIT_JUMP := 2
const BIT_BLOCK := 4
const BIT_LP := 5
const BIT_LK := 8
const GRAB := (1 << BIT_LP) | (1 << BIT_LK)

var passed: int = 0
var failed: int = 0
var combat: CombatManager
var _masks: Array = [0, 0]
## Impactos de la prueba en curso: [atacante, defensor, ataque, resultado].
var _hits: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  [OK]   ", label)
	else:
		failed += 1
		print("  [FAIL] ", label)

func _run() -> void:
	print("\n=== HISTORY COMBAT · PRUEBAS DE MECÁNICAS ===")
	Game.mode = Game.Mode.VERSUS
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	Game.round_time = 9999
	Game.p1_fighter_id = &"napoleon"
	Game.p2_fighter_id = &"donald_trump"
	combat = load(Game.SCENE_FIGHT).instantiate() as CombatManager
	add_child(combat)
	combat.set_input_source(func(_tick: int) -> Array: return _masks)
	combat.hit_landed.connect(func(a: Fighter, d: Fighter, atk: AttackData, r: Dictionary):
		_hits.append([a, d, atk, r]))
	while combat.round_manager.phase != RoundManager.Phase.FIGHT:
		await combat.ticked

	await _test_grab()

	await get_tree().physics_frame
	remove_child(combat)
	combat.free()
	print("\n=== RESULTADO: %d OK, %d FALLOS ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

# --- Utilidades -------------------------------------------------------------
## Coloca a los dos luchadores a `dx` px (P1 a la izquierda) con todo reiniciado.
func _place(dx: float, p2_mask: int = 0) -> void:
	var mid := (combat.p1.bounds.x + combat.p1.bounds.y) * 0.5
	combat.p1.reset_for_round(mid - dx * 0.5, 1)
	combat.p2.reset_for_round(mid + dx * 0.5, -1)
	combat.round_manager.time_left = 9999.0
	_masks = [0, p2_mask]
	await _ticks(8)
	_hits.clear()

func _ticks(n: int) -> void:
	for i in n:
		await combat.ticked

## Pulsa `mask` durante un tick para el jugador `player` (0 = P1) y vuelve a `rest`.
func _press(player: int, mask: int, rest: int = 0) -> void:
	_masks[player] = mask
	await combat.ticked
	_masks[player] = rest

## Espera hasta `max_ticks` a que `cond` sea true. Devuelve si se cumplió.
func _until(cond: Callable, max_ticks: int = 120) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		await combat.ticked
	return cond.call()

# --- Agarre -----------------------------------------------------------------
func _test_grab() -> void:
	print("\n# Agarre (puño débil + patada débil)")
	var p1 := combat.p1
	var p2 := combat.p2
	var grab := p1.data.get_attack(&"grab")
	var expected := grab.damage * p1.data.strength / p2.data.resistance

	# Gana al bloqueo y hace el daño completo.
	await _place(30.0, 1 << BIT_BLOCK)
	await _press(0, GRAB)
	var thrown := await _until(func(): return p2.state == Fighter.State.THROWN, 30)
	check(thrown, "el agarre atrapa a un rival que bloquea")
	await _until(func(): return not _hits.is_empty(), 60)
	check(_hits.size() == 1 and not _hits[0][3].blocked, "la llave no se puede bloquear")
	check(is_equal_approx(p2.data.max_health - p2.health, expected),
		"la llave hace el daño exacto (%.2f de %.2f)" % [p2.data.max_health - p2.health, expected])
	check(await _until(func(): return p1.state == Fighter.State.IDLE, 60), "el agarrador se recupera")

	# Segunda tecla un frame tarde: el golpe débil se convierte en agarre.
	await _place(30.0)
	await _press(0, 1 << BIT_LP)
	await _press(0, GRAB)
	check(await _until(func(): return p2.state == Fighter.State.THROWN, 30),
		"puño débil y patada débil 1 frame después también agarran")

	# Zafarse: la víctima pulsa las dos teclas dentro de la ventana.
	await _place(30.0)
	await _press(0, GRAB)
	await _until(func(): return p2.state == Fighter.State.THROWN, 30)
	await _ticks(3)
	await _press(1, GRAB)
	await _ticks(2)
	check(p1.state == Fighter.State.HIT and p2.state == Fighter.State.HIT, "zafarse separa a los dos")
	await _ticks(40)
	check(is_equal_approx(p2.health, p2.data.max_health), "zafarse evita el daño")

	# Fuera de la ventana ya no se zafa.
	await _place(30.0)
	await _press(0, GRAB)
	await _until(func(): return p2.state == Fighter.State.THROWN, 30)
	await _ticks(Fighter.THROW_TECH_FRAMES + 2)
	await _press(1, GRAB)
	await _ticks(Fighter.THROW_FRAMES)
	check(p2.health < p2.data.max_health, "zafarse tarde no sirve")

	# Agarre mutuo en el mismo frame.
	await _place(30.0)
	_masks = [GRAB, GRAB]
	await combat.ticked
	_masks = [0, 0]
	await _until(func(): return p1.state == Fighter.State.HIT, 20)
	check(p1.state == Fighter.State.HIT and p2.state == Fighter.State.HIT \
		and is_equal_approx(p1.health, p1.data.max_health) and is_equal_approx(p2.health, p2.data.max_health),
		"dos agarres a la vez se anulan")

	# Agarre fallado: lejos no atrapa y deja toda la recuperación.
	await _place(90.0)
	await _press(0, GRAB)
	# Ticks en ATTACK: el de la pulsación (frame 0) y los frames 1..total-1.
	var frames_in_grab := 0
	while p1.state == Fighter.State.ATTACK and p1.current_slot == &"grab" and frames_in_grab < 100:
		await combat.ticked
		frames_in_grab += 1
	check(p2.state != Fighter.State.THROWN and _hits.is_empty(), "lejos el agarre falla")
	check(frames_in_grab == grab.total_frames(),
		"el agarre fallado dura %d frames (esperado %d)" % [frames_in_grab, grab.total_frames()])

	# No atrapa a un rival en el aire.
	await _place(30.0)
	await _press(1, 1 << BIT_JUMP)
	await _ticks(6)
	await _press(0, GRAB)
	await _ticks(12)
	check(p2.state != Fighter.State.THROWN, "no se puede agarrar a un rival en el aire")
	await _ticks(40)

	# No atrapa a un rival en bloqueo forzado (blockstun).
	await _place(30.0, 1 << BIT_BLOCK)
	p2.stun_frames = 30
	await _press(0, GRAB, 0)
	_masks[1] = 1 << BIT_BLOCK
	await _ticks(10)
	check(p2.state != Fighter.State.THROWN, "no se puede agarrar durante el bloqueo forzado")

	# Golpe contra agarre en el mismo frame: gana el golpe.
	# Agarre: activo en el frame 6; puño débil de P2 (startup 4) pulsado 1 tick después: también en el 6.
	await _place(30.0)
	await _press(0, GRAB)
	await _press(1, 1 << BIT_LP)
	await _ticks(6)
	check(p1.state == Fighter.State.HIT and p2.state != Fighter.State.THROWN,
		"si el golpe y el agarre llegan a la vez, gana el golpe")
	await _ticks(40)
