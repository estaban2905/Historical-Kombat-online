## Pruebas del modo ENTRENAMIENTO: muñeco, recursos infinitos, ventaja medida,
## pausa de frames y que no haya rondas ni K.O.
## Uso:  godot --headless --fixed-fps 60 --path . res://tests/TrainingTest.tscn
extends Node

const BIT_LEFT := 0
const BIT_RIGHT := 1
const BIT_LP := 5

var passed: int = 0
var failed: int = 0
var combat: CombatManager
var training: TrainingMode
var _masks: Array = [0, 0]

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

func _ticks(n: int) -> void:
	for i in n:
		await combat.ticked

func _until(cond: Callable, max_ticks: int = 120) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		await combat.ticked
	return cond.call()

## Coloca a los dos a `dx` px y espera a que se estabilicen.
func _place(dx: float) -> void:
	var mid := (combat.p1.bounds.x + combat.p1.bounds.y) * 0.5
	combat.p1.reset_for_round(mid - dx * 0.5, 1)
	combat.p2.reset_for_round(mid + dx * 0.5, -1)
	_masks = [0, 0]
	await _ticks(8)

func _run() -> void:
	print("\n=== HISTORY COMBAT · PRUEBAS DE ENTRENAMIENTO ===")
	# El menú tiene el botón.
	var menu: Node = load(Game.SCENE_MENU).instantiate()
	add_child(menu)
	check(menu.get_node_or_null("Buttons/Training") is Button, "el menú principal tiene ENTRENAMIENTO")
	remove_child(menu)
	menu.free()

	Game.mode = Game.Mode.TRAINING
	Game.rounds_to_win = 99
	Game.round_time = 99
	Game.p1_fighter_id = &"napoleon"
	Game.p2_fighter_id = &"donald_trump"
	combat = load(Game.SCENE_FIGHT).instantiate() as CombatManager
	add_child(combat)
	combat.set_input_source(func(_t: int) -> Array: return _masks)
	training = combat.training
	await combat.ticked

	print("\n# Arranque")
	check(training != null, "el combate crea el modo entrenamiento")
	check(combat.round_manager.phase == RoundManager.Phase.FIGHT, "se pelea desde el primer frame (sin cuenta atrás)")
	check(combat.p1.controls_enabled and combat.p2.controls_enabled, "los controles están activos")
	check(combat.get_node("DebugOverlay").visible, "las cajas de colisión se ven por defecto")
	var p1 := combat.p1
	var p2 := combat.p2

	print("\n# Recursos infinitos y sin rondas")
	await _place(120.0)
	check(is_equal_approx(p1.energy, Fighter.MAX_ENERGY) and is_equal_approx(p2.energy, Fighter.MAX_ENERGY),
		"la energía de los dos está siempre al máximo")
	p2.health = 10.0
	await _ticks(2)
	check(is_equal_approx(p2.health, p2.data.max_health), "la vida baja de %d %% se rellena" % int(TrainingMode.REFILL_BELOW * 100))
	var t0 := combat.round_manager.time_left
	await _ticks(180)
	check(combat.round_manager.phase == RoundManager.Phase.FIGHT and is_equal_approx(combat.round_manager.time_left, t0),
		"no corre el reloj ni acaba la ronda")
	p2._knock_out(1)
	check(await _until(func(): return p2.state != Fighter.State.KO, TrainingMode.KO_RESET_TICKS + 30),
		"un K.O. reinicia las posiciones")
	check(is_equal_approx(p2.health, p2.data.max_health) and p2.controls_enabled, "tras el K.O. vuelve con la vida llena y controles")

	print("\n# Conductas del muñeco")
	await _place(120.0)
	training.set_dummy(TrainingMode.Dummy.CROUCH)
	await _ticks(4)
	check(p2.state == Fighter.State.CROUCH, "AGACHADO: el muñeco se agacha")
	training.set_dummy(TrainingMode.Dummy.BLOCK)
	await _ticks(4)
	check(p2.state == Fighter.State.BLOCK and not p2.crouch_blocking, "BLOQUEA: bloquea de pie")
	training.set_dummy(TrainingMode.Dummy.BLOCK_LOW)
	await _ticks(4)
	check(p2.state == Fighter.State.BLOCK and p2.crouch_blocking, "BLOQUEA AGACHADO: bloquea agachado")
	training.set_dummy(TrainingMode.Dummy.JUMP)
	check(await _until(func(): return p2.state == Fighter.State.JUMP, TrainingMode.JUMP_EVERY + 20), "SALTA: el muñeco salta solo")
	await _ticks(80)
	training.set_dummy(TrainingMode.Dummy.STAND)
	# Puede estar a mitad de un salto: se espera a que aterrice.
	check(await _until(func(): return p2.state == Fighter.State.IDLE, 80), "QUIETO: no hace nada")
	training.set_dummy(TrainingMode.Dummy.MANUAL)
	var x2 := p2.position.x
	_masks = [0, 1 << BIT_RIGHT]
	await _ticks(20)
	_masks = [0, 0]
	check(p2.position.x > x2 + 5.0, "MANUAL: el jugador 2 mueve al muñeco")
	training.set_dummy(TrainingMode.Dummy.CPU)
	check(training._ai != null, "CPU: se crea la IA")
	training.set_dummy(TrainingMode.Dummy.STAND)

	print("\n# Ventaja medida (igual que el test de frame data)")
	var pl := p1.data.get_attack(&"punch_light")
	await _place(30.0)
	_masks = [1 << BIT_LP, 0]
	await combat.ticked
	_masks = [0, 0]
	await _until(func(): return training.advantage(1, pl, "hit") != null, 80)
	var expect_hit := pl.hitstun - pl.recovery - 1
	check(training.advantage(1, pl, "hit") == expect_hit, "puño débil de Napoleón: ventaja al golpear %s (esperado %+d)" % [str(training.advantage(1, pl, "hit")), expect_hit])
	await _ticks(60)
	training.set_dummy(TrainingMode.Dummy.BLOCK)
	await _place(30.0)
	_masks = [1 << BIT_LP, 0]
	await combat.ticked
	_masks = [0, 0]
	await _until(func(): return training.advantage(1, pl, "block") != null, 80)
	var expect_block := pl.blockstun - pl.recovery - 1
	check(training.advantage(1, pl, "block") == expect_block, "puño débil de Napoleón: ventaja al bloquear %s (esperado %+d)" % [str(training.advantage(1, pl, "block")), expect_block])
	check(training._last_atk == pl and training._last_player == 1, "el panel recuerda el último ataque")
	await _ticks(60)
	training.set_dummy(TrainingMode.Dummy.STAND)

	print("\n# Pausa de frames")
	await _place(120.0)
	training.frozen = true
	var frozen_at := combat.tick_count
	for i in 6:
		await get_tree().physics_frame
	check(combat.tick_count == frozen_at, "con la pausa de frames no avanza el combate")
	training.step_one()
	await get_tree().physics_frame
	check(combat.tick_count == frozen_at + 1, "F6 avanza exactamente un frame")
	await get_tree().physics_frame
	check(combat.tick_count == frozen_at + 1, "y se vuelve a parar")
	training.frozen = false
	await _ticks(3)
	check(combat.tick_count > frozen_at + 1, "al quitar la pausa el combate sigue")

	await get_tree().physics_frame
	remove_child(combat)
	combat.free()
	Game.mode = Game.Mode.VERSUS
	print("\n=== RESULTADO: %d OK, %d FALLOS ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
