## Pruebas de mecánicas de combate (agarre, defensa, combos...).
## Mueven el combate real con máscaras de entrada por tick, igual que el online,
## así que cada caso es exacto y repetible.
## Uso:  godot --headless --fixed-fps 60 --path . res://tests/MechanicsTest.tscn
extends Node

const BIT_LEFT := 0
const BIT_JUMP := 2
const BIT_CROUCH := 3
const BIT_BLOCK := 4
const BIT_LP := 5
const BIT_HP := 6
const BIT_S1 := 7
const BIT_LK := 8
const BIT_HK := 9
const BIT_S2 := 10
const GRAB := (1 << BIT_LP) | (1 << BIT_LK)
const STAND_BLOCK := 1 << BIT_BLOCK
const CROUCH_BLOCK := (1 << BIT_BLOCK) | (1 << BIT_CROUCH)

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
	await _test_hit_levels()
	await _test_guard()
	await _test_combos()
	await _test_movement()
	await _test_knockdown()
	await _test_ultimate()
	await _test_ai()
	await _test_perfect_block()
	await _test_new_powers()
	_test_profiles()
	_test_balance()

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
	_masks = [GRAB, 1 << BIT_LP]
	await combat.ticked
	_masks = [0, 0]
	await _ticks(6)
	check(p1.state == Fighter.State.HIT and p2.state != Fighter.State.THROWN,
		"si el golpe y el agarre llegan a la vez, gana el golpe")
	await _ticks(40)

# --- Bloqueo alto / bajo ----------------------------------------------------
## Resultado del primer impacto de P1 en la prueba en curso: "hit", "block" o "none".
func _first_hit_result() -> String:
	for h in _hits:
		if h[0] == combat.p1:
			return "block" if h[3].blocked else "hit"
	return "none"

## P1 lanza `mask` (manteniendo `hold` antes y después) contra P2 con la guardia `guard`.
func _attack_vs_guard(dx: float, guard: int, mask: int, hold: int = 0) -> String:
	await _place(dx, guard)
	_masks[0] = hold
	await _ticks(4)
	await _press(0, hold | mask, hold)
	await _until(func(): return _first_hit_result() != "none", 60)
	var r := _first_hit_result()
	_masks = [0, 0]
	await _ticks(40)
	return r

## Salta en vertical y lanza la patada fuerte en el aire contra la guardia `guard`.
func _air_attack_vs_guard(dx: float, guard: int) -> String:
	await _place(dx, guard)
	await _press(0, 1 << BIT_JUMP)
	await _until(func(): return combat.p1.state == Fighter.State.JUMP, 20)
	# Se lanza en la bajada: en lo alto del salto la patada pasa por encima de un rival agachado.
	await _ticks(15)
	await _press(0, 1 << BIT_HK)
	await _until(func(): return _first_hit_result() != "none", 40)
	var r := _first_hit_result()
	_masks = [0, 0]
	await _ticks(50)
	return r

func _test_hit_levels() -> void:
	print("\n# Bloqueo alto / bajo")
	var crouch := 1 << BIT_CROUCH
	var r := await _attack_vs_guard(34.0, STAND_BLOCK, 1 << BIT_LK, crouch)
	check(r == "hit", "patada agachada (baja) atraviesa la guardia de pie (%s)" % r)
	r = await _attack_vs_guard(34.0, CROUCH_BLOCK, 1 << BIT_LK, crouch)
	check(r == "block", "patada agachada se bloquea agachado (%s)" % r)
	r = await _attack_vs_guard(34.0, CROUCH_BLOCK, 1 << BIT_LP)
	check(r == "block", "puño de pie (medio) se bloquea agachado (%s)" % r)
	r = await _attack_vs_guard(34.0, STAND_BLOCK, 1 << BIT_LP)
	check(r == "block", "puño de pie (medio) se bloquea de pie (%s)" % r)
	r = await _air_attack_vs_guard(34.0, CROUCH_BLOCK)
	check(r == "hit", "ataque aéreo (alto) atraviesa la guardia agachada (%s)" % r)
	r = await _air_attack_vs_guard(34.0, STAND_BLOCK)
	check(r == "block", "ataque aéreo se bloquea de pie (%s)" % r)
	combat.p1.energy = Fighter.MAX_ENERGY
	r = await _attack_vs_guard(130.0, CROUCH_BLOCK, 1 << BIT_S1)
	check(r != "hit", "un proyectil (medio) no atraviesa la guardia agachada (%s)" % r)

# --- Guardia ------------------------------------------------------------------
## Daño de un ataque de P1 sobre P2 antes de reducirlo por el bloqueo.
func _full_damage(atk: AttackData) -> float:
	return atk.damage * combat.p1.data.strength / combat.p2.data.resistance

func _test_guard() -> void:
	print("
# Guardia")
	var p1 := combat.p1
	var p2 := combat.p2
	var jab := p1.data.get_attack(&"punch_light")

	# Cada golpe bloqueado gasta guardia.
	await _place(34.0, STAND_BLOCK)
	check(is_equal_approx(p2.guard, Fighter.MAX_GUARD), "la guardia empieza llena")
	await _press(0, 1 << BIT_LP)
	await _until(func(): return not _hits.is_empty(), 30)
	var expected := Fighter.MAX_GUARD - _full_damage(jab) * Fighter.GUARD_DRAIN
	check(_hits[0][3].blocked and is_equal_approx(p2.guard, expected),
		"un golpe bloqueado gasta guardia (%.1f de %.1f)" % [p2.guard, expected])

	# No se recupera antes del retraso y sí después.
	var after_hit := p2.guard
	await _ticks(Fighter.GUARD_REGEN_DELAY - 12)
	check(is_equal_approx(p2.guard, after_hit), "la guardia no se recupera durante el retraso")
	await _ticks(50)
	check(p2.guard > after_hit + 5.0 and p2.guard <= Fighter.MAX_GUARD, "después del retraso se recupera (%.1f)" % p2.guard)

	# Guardia rota: aturdimiento, el siguiente golpe ya no se bloquea.
	await _place(34.0, STAND_BLOCK)
	p2.guard = 5.0
	var health_before := p2.health
	await _press(0, 1 << BIT_LP)
	await _until(func(): return not _hits.is_empty(), 30)
	check(p2.guard_is_broken and p2.state == Fighter.State.HIT, "con la guardia a 0 se rompe y queda aturdido")
	check(is_equal_approx(p2.guard, Fighter.GUARD_AFTER_BREAK), "tras romperse la guardia vuelve al %d %%" % int(Fighter.GUARD_AFTER_BREAK))
	check(is_equal_approx(health_before - p2.health, _full_damage(jab) * Fighter.BLOCK_DAMAGE_FACTOR),
		"el golpe que la rompe solo hace daño de bloqueo")
	check(p2.stun_frames > Fighter.GUARD_BREAK_STUN - 5, "el aturdimiento dura ~%d frames (%d)" % [Fighter.GUARD_BREAK_STUN, p2.stun_frames])
	await _until(func(): return p1.state == Fighter.State.IDLE, 40)
	await _press(0, 1 << BIT_LP)
	await _until(func(): return _hits.size() >= 2, 30)
	check(_hits.size() >= 2 and not _hits[1][3].blocked, "con la guardia rota el siguiente golpe entra completo")
	await _until(func(): return p2.state != Fighter.State.HIT, 120)
	check(not p2.guard_is_broken, "el aviso de guardia rota termina con el aturdimiento")

	# Chip: los golpes normales no matan, los especiales sí.
	await _place(34.0, STAND_BLOCK)
	p2.health = 1.0
	await _press(0, 1 << BIT_LP)
	await _until(func(): return not _hits.is_empty(), 30)
	check(p2.state != Fighter.State.KO and p2.health >= 1.0, "un golpe normal bloqueado no mata")
	await _place(130.0, STAND_BLOCK)
	p1.energy = Fighter.MAX_ENERGY
	p2.health = 1.0
	await _press(0, 1 << BIT_S1)
	await _until(func(): return p2.state == Fighter.State.KO, 120)
	check(p2.state == Fighter.State.KO, "un especial bloqueado puede rematar con el daño de rozadura")

	# Una ronda nueva devuelve la guardia.
	p2.guard = 10.0
	await _place(60.0)
	check(is_equal_approx(p2.guard, Fighter.MAX_GUARD), "cada ronda empieza con la guardia llena")

# --- Combos -------------------------------------------------------------------
## Coloca a P1 y P2 pegados a la pared derecha (el rival no se aleja al recibir
## golpes), con la distancia `dx` entre ellos.
func _place_in_corner(dx: float) -> void:
	var wall := combat.p1.bounds.y
	combat.p1.reset_for_round(wall - dx, 1)
	combat.p2.reset_for_round(wall, -1)
	combat.round_manager.time_left = 9999.0
	_masks = [0, 0]
	await _ticks(8)
	_hits.clear()

## Pulsa cada ranura en cuanto el golpe anterior conecta (cancelando). Devuelve
## cuántos golpes de la cadena conectaron.
func _chain(bits: Array) -> int:
	for i in bits.size():
		await _press(0, 1 << bits[i])
		if not await _until(func(): return _hits.size() > i, 60):
			return i
	return bits.size()

func _test_combos() -> void:
	print("
# Combos")
	# La prueba anterior termina con un K.O.: se espera a la ronda siguiente.
	await _until(func(): return combat.round_manager.phase == RoundManager.Phase.FIGHT, 900)
	var p1 := combat.p1
	var p2 := combat.p2
	var pl := p1.data.get_attack(&"punch_light")
	var ph := p1.data.get_attack(&"punch_heavy")
	var kh := p1.data.get_attack(&"kick_heavy")
	var lk := p1.data.get_attack(&"kick_light")

	# Cancelar al conectar: débil → débil.
	await _place(24.0)
	await _press(0, 1 << BIT_LP)
	await _until(func(): return _hits.size() >= 1, 30)
	await _press(0, 1 << BIT_LK)
	await _until(func(): return _hits.size() >= 2, 60)
	check(_hits.size() >= 2 and _hits[1][2] == lk, "puño débil cancela en patada débil al conectar")
	check(p2.combo_hits_taken == 2, "los dos golpes cuentan como un combo (%d)" % p2.combo_hits_taken)
	check(_hits.size() >= 2 and is_equal_approx(_hits[1][3].damage, _full_damage(lk) * (1.0 - Fighter.COMBO_SCALE_STEP)),
		"el segundo golpe hace un %d %% menos de daño" % int(Fighter.COMBO_SCALE_STEP * 100))
	check(p2.stun_frames == lk.hitstun - Fighter.HITSTUN_DECAY,
		"el segundo golpe acorta el aturdimiento (%d frames)" % p2.stun_frames)

	# Cancelar bloqueado.
	await _place(24.0, STAND_BLOCK)
	await _press(0, 1 << BIT_LP)
	await _until(func(): return _hits.size() >= 1, 30)
	await _press(0, 1 << BIT_LK)
	await _until(func(): return _hits.size() >= 2, 60)
	check(_hits.size() >= 2 and _hits[0][3].blocked and _hits[1][2] == lk, "también se cancela cuando el golpe es bloqueado")

	# No se cancela si el golpe falla.
	await _place(90.0)
	await _press(0, 1 << BIT_LP)
	await _ticks(6)
	var instance := p1.attack_instance
	await _press(0, 1 << BIT_HP)
	await _ticks(3)
	check(p1.attack_instance == instance and p1.current_slot == &"punch_light", "un golpe que falla no se puede cancelar")
	await _ticks(40)

	# Sin repetir el mismo golpe ni bajar de rango.
	await _place(24.0)
	await _press(0, 1 << BIT_LP)
	await _until(func(): return _hits.size() >= 1, 30)
	instance = p1.attack_instance
	await _press(0, 1 << BIT_LP)
	await _ticks(9)
	check(p1.attack_instance == instance, "no se puede cancelar en el mismo golpe")
	await _ticks(40)
	await _place(24.0)
	await _press(0, 1 << BIT_HP)
	await _until(func(): return _hits.size() >= 1, 30)
	instance = p1.attack_instance
	await _press(0, 1 << BIT_LP)
	await _ticks(12)
	check(p1.attack_instance == instance, "un golpe fuerte no se cancela en uno débil")
	await _ticks(40)

	# Cancelar en un especial (cuesta energía y no se cancela desde él).
	await _place(24.0)
	p1.energy = Fighter.MAX_ENERGY
	await _press(0, 1 << BIT_LP)
	await _until(func(): return _hits.size() >= 1, 30)
	await _press(0, 1 << BIT_S2)
	await _ticks(8)
	check(p1.current_slot == &"special_2", "un golpe débil se cancela en el especial 2")
	await _ticks(80)

	# Escalado mínimo y aturdimiento mínimo (golpes directos al motor).
	await _place(60.0)
	p2._set_state(Fighter.State.HIT)
	p2.combo_hits_taken = 9
	var r := p2.receive_hit(p1, pl, 1)
	check(is_equal_approx(r.damage, _full_damage(pl) * Fighter.COMBO_SCALE_MIN),
		"el daño nunca baja del %d %%" % int(Fighter.COMBO_SCALE_MIN * 100))
	check(p2.stun_frames == Fighter.HITSTUN_MIN, "el aturdimiento nunca baja de %d frames" % Fighter.HITSTUN_MIN)

	# Counter-hit: golpear a un rival en su startup.
	await _place(34.0)
	_masks = [1 << BIT_LP, 1 << BIT_HP]
	await combat.ticked
	_masks = [0, 0]
	await _until(func(): return _hits.size() >= 1, 30)
	check(_hits.size() >= 1 and _hits[0][3].counter, "golpear en el startup del rival es counter-hit")
	check(is_equal_approx(_hits[0][3].damage, _full_damage(pl) * Fighter.COUNTER_DAMAGE),
		"el counter-hit hace un %d %% más de daño" % roundi((Fighter.COUNTER_DAMAGE - 1.0) * 100.0))
	check(p2.stun_frames == pl.hitstun + Fighter.COUNTER_HITSTUN, "el counter-hit alarga el aturdimiento (%d)" % p2.stun_frames)
	await _ticks(50)
	await _place(34.0)
	await _press(0, 1 << BIT_LP)
	await _until(func(): return _hits.size() >= 1, 30)
	check(_hits.size() >= 1 and not _hits[0][3].counter, "un golpe normal no es counter-hit")

	# Límite de golpes en el aire.
	await _place(60.0)
	p2.position.y = p2.floor_y - 60.0
	p2.velocity.y = -200.0
	p2._set_state(Fighter.State.HIT)
	for i in Fighter.JUGGLE_LIMIT:
		p2.receive_hit(p1, pl, 1)
	check(p2.juggle_hits == Fighter.JUGGLE_LIMIT and not p2.can_be_hit(),
		"tras %d golpes en el aire no se le puede golpear más" % Fighter.JUGGLE_LIMIT)
	p2.position.y = p2.floor_y
	p2.velocity.y = 120.0
	await _ticks(2)
	check(p2.juggle_hits == 0 and p2.can_be_hit(), "al aterrizar se puede volver a golpear")

	# Combos con nombre: hay que enlazarlos con cancelaciones.
	var c := p1.data.get_combos()[0]
	var seq := c.sequence
	var good: Array = []
	for i in seq.size():
		good.append({"slot": seq[i], "frame": i * 10, "chained": i > 0})
	check(c.matches(good), "ComboData acepta la secuencia enlazada")
	good[1]["chained"] = false
	check(not c.matches(good), "ComboData rechaza la secuencia sin cancelar")
	good[1]["chained"] = true
	good[1]["frame"] = c.max_gap_frames + 5
	check(not c.matches(good), "ComboData rechaza una pausa demasiado larga")

	var names: Array = []
	p1.combo_performed.connect(func(_f, combo): names.append(combo.display_name))
	var bit_of := {&"punch_light": BIT_LP, &"punch_heavy": BIT_HP, &"kick_light": BIT_LK,
		&"kick_heavy": BIT_HK, &"special_1": BIT_S1, &"special_2": BIT_S2}
	var all_combos := p1.data.get_combos()
	for ci in all_combos.size():
		var cmb := all_combos[ci]
		names.clear()
		await _place_in_corner(24.0)
		p1.energy = Fighter.MAX_ENERGY
		var bits: Array = []
		for slot in cmb.sequence:
			bits.append(bit_of[slot])
		var n := await _chain(bits)
		check(n == bits.size(), "la cadena de %s conecta sus %d golpes (%d)" % [cmb.display_name, bits.size(), n])
		check(names.has(cmb.display_name) and _hits.size() >= bits.size() and _hits[bits.size() - 1][3].combo_name == cmb.display_name,
			"completar la cadena es el combo %s" % cmb.display_name)
		await _ticks(80)

# --- Movimiento ------------------------------------------------------------------
var _landings: int = 0

func _wait_round() -> void:
	await _until(func(): return combat.round_manager.phase == RoundManager.Phase.FIGHT, 900)

func _test_movement() -> void:
	print("\n# Movimiento")
	var p1 := combat.p1
	var p2 := combat.p2
	await _wait_round()
	p1.landed.connect(func(_f): _landings += 1)

	# Saltar: 3 frames de preparación y solo al pulsar (mantener no repite).
	await _place(120.0)
	await _press(0, 1 << BIT_JUMP)
	await _ticks(1)
	check(p1.state == Fighter.State.PREJUMP and is_equal_approx(p1.position.y, p1.floor_y), "saltar empieza con una preparación en el suelo")
	await _ticks(Fighter.PREJUMP_FRAMES + 1)
	check(p1.state == Fighter.State.JUMP and p1.position.y < p1.floor_y, "tras %d frames despega" % Fighter.PREJUMP_FRAMES)
	await _ticks(60)
	await _place(120.0)
	_landings = 0
	_masks = [1 << BIT_JUMP, 0]
	await _ticks(110)
	_masks = [0, 0]
	check(_landings == 1, "mantener la tecla de salto da un solo salto (%d)" % _landings)

	# El búfer de salto: una pulsación justo antes de acabar un ataque no se pierde.
	await _place(120.0)
	await _press(0, 1 << BIT_LP)
	await _ticks(11)
	await _press(0, 1 << BIT_JUMP)
	var jumped := await _until(func(): return p1.state == Fighter.State.PREJUMP or p1.state == Fighter.State.JUMP, 12)
	check(jumped, "saltar pulsado 2-3 frames antes de acabar un golpe sale al terminar")
	await _ticks(70)

	# Un ataque aéreo por salto, y recuperación al aterrizar si se usó.
	await _place(120.0)
	await _press(0, 1 << BIT_JUMP)
	await _until(func(): return p1.state == Fighter.State.JUMP, 20)
	await _ticks(1)
	await _press(0, 1 << BIT_LP)
	check(await _until(func(): return p1.state == Fighter.State.ATTACK and p1.attack_airborne, 6), "se puede atacar en el aire")
	await _until(func(): return p1.state == Fighter.State.JUMP, 40)
	check(p1.state == Fighter.State.JUMP and not p1.is_on_ground(), "el golpe aéreo acaba antes de aterrizar")
	await _press(0, 1 << BIT_LK)
	await _ticks(3)
	check(p1.state == Fighter.State.JUMP, "no se puede dar un segundo ataque aéreo en el mismo salto")
	var landed := await _until(func(): return p1.state == Fighter.State.LAND, 80)
	check(landed, "aterrizar tras un ataque aéreo deja una recuperación")
	var land_frames := 0
	while p1.state == Fighter.State.LAND and land_frames < 40:
		await combat.ticked
		land_frames += 1
	check(land_frames == Fighter.AIR_LANDING_FRAMES, "la recuperación dura %d frames (%d)" % [Fighter.AIR_LANDING_FRAMES, land_frames])
	await _place(120.0)
	await _press(0, 1 << BIT_JUMP)
	var saw_land := false
	for i in 70:
		await combat.ticked
		if p1.state == Fighter.State.LAND:
			saw_land = true
	check(not saw_land and p1.state == Fighter.State.IDLE, "un salto sin atacar aterriza sin recuperación")

	# Antiaéreo: puño fuerte agachado.
	await _place(24.0)
	_masks = [1 << BIT_CROUCH, 0]
	await _ticks(4)
	await _press(0, (1 << BIT_CROUCH) | (1 << BIT_HP), 1 << BIT_CROUCH)
	await _ticks(1)
	check(p1.current_attack != null and p1.current_attack.id == &"uppercut", "puño fuerte agachado es el antiaéreo")
	check(p1.is_anti_air_invulnerable(), "el antiaéreo esquiva ataques aéreos al empezar")
	await _until(func(): return not _hits.is_empty(), 30)
	check(_hits.size() >= 1 and _hits[0][2].id == &"uppercut" and p2.velocity.y < -200.0,
		"el antiaéreo lanza al rival hacia arriba (%.0f)" % p2.velocity.y)
	_masks = [0, 0]
	await _ticks(80)

	# El antiaéreo le gana a un salto con patada: en alguna sincronización lo para.
	var wins := 0
	for delay in range(0, 28, 2):
		await _place(70.0)
		# P2 salta hacia P1 (manteniendo la dirección) y lanza la patada en el aire.
		await _press(1, (1 << BIT_JUMP) | (1 << BIT_LEFT), 1 << BIT_LEFT)
		await _until(func(): return p2.state == Fighter.State.JUMP, 20)
		await _ticks(6)
		await _press(1, (1 << BIT_HK) | (1 << BIT_LEFT), 1 << BIT_LEFT)
		_masks[0] = 1 << BIT_CROUCH
		await _ticks(delay)
		await _press(0, (1 << BIT_CROUCH) | (1 << BIT_HP), 1 << BIT_CROUCH)
		await _until(func(): return not _hits.is_empty(), 50)
		if not _hits.is_empty() and _hits[0][2].id == &"uppercut":
			wins += 1
		_masks = [0, 0]
		await _ticks(10)
	check(wins >= 1, "el antiaéreo para un salto con patada en %d sincronizaciones" % wins)
	await _ticks(60)

	# Backdash: doble toque hacia atrás.
	await _place(150.0)
	var x0 := p1.position.x
	_masks = [1 << BIT_LEFT, 0]
	await _ticks(3)
	_masks = [0, 0]
	await _ticks(3)
	_masks = [1 << BIT_LEFT, 0]
	await _ticks(2)
	check(p1.state == Fighter.State.BACKDASH and not p1.running, "doble toque hacia atrás es un backdash")
	var invulnerable_first := not p1.can_be_hit()
	await _ticks(Fighter.BACKDASH_INVULN_FRAMES + 2)
	check(invulnerable_first and p1.can_be_hit(), "no se le puede golpear los primeros %d frames del backdash" % Fighter.BACKDASH_INVULN_FRAMES)
	_masks = [0, 0]
	await _ticks(Fighter.BACKDASH_FRAMES)
	check(p1.state == Fighter.State.IDLE and x0 - p1.position.x > 25.0, "el backdash retrocede (%.0f px)" % (x0 - p1.position.x))
	# Hacia delante el doble toque sigue siendo correr.
	await _place(150.0)
	_masks = [1 << 1, 0]
	await _ticks(3)
	_masks = [0, 0]
	await _ticks(3)
	_masks = [1 << 1, 0]
	await _ticks(4)
	check(p1.running and p1.state == Fighter.State.WALK, "doble toque hacia delante sigue siendo correr")
	_masks = [0, 0]
	await _ticks(20)

# --- Derribo ----------------------------------------------------------------
func _launch_p2() -> void:
	var p1 := combat.p1
	var up := p1._uppercut_for(p1.data.get_attack(&"punch_heavy"))
	combat.p2.receive_hit(p1, up, 1)

func _test_knockdown() -> void:
	print("\n# Derribo")
	var p1 := combat.p1
	var p2 := combat.p2
	await _wait_round()

	# Un lanzamiento tumba al rival al aterrizar; tumbado no se le puede golpear.
	await _place(60.0)
	_launch_p2()
	check(p2.knockdown_pending, "un golpe que lanza marca el derribo")
	var down := await _until(func(): return p2.state == Fighter.State.KNOCKDOWN, 80)
	check(down, "tras el lanzamiento queda derribado al aterrizar")
	check(not p2.can_be_hit() and not p2.can_be_grabbed(), "tumbado no se le puede golpear ni agarrar")
	var hp := p2.health
	p2.input.release_all()
	await _ticks(Fighter.KNOCKDOWN_FRAMES - 3)
	check(p2.state == Fighter.State.KNOCKDOWN and is_equal_approx(p2.health, hp), "sigue tumbado %d frames sin perder vida" % Fighter.KNOCKDOWN_FRAMES)
	await _ticks(6)
	check(p2.state == Fighter.State.WAKEUP and not p2.wake_rolling, "después se levanta")
	check(not p2.can_be_hit(), "al levantarse es invulnerable los primeros %d frames" % Fighter.WAKEUP_INVULN)
	await _ticks(Fighter.WAKEUP_INVULN + 1)
	check(p2.state == Fighter.State.WAKEUP and p2.can_be_hit(), "pasada la invulnerabilidad se le puede golpear")
	await _ticks(Fighter.WAKEUP_FRAMES)
	check(p2.state == Fighter.State.IDLE, "y vuelve a actuar")

	# Evitar el derribo: bloqueo pulsado justo antes de caer.
	await _place(60.0)
	_launch_p2()
	var seen_knockdown := false
	await _until(func(): return p2.velocity.y > 0.0 and p2.position.y > p2.floor_y - 25.0, 80)
	await _press(1, STAND_BLOCK)
	for i in 40:
		seen_knockdown = seen_knockdown or p2.state == Fighter.State.KNOCKDOWN
		await combat.ticked
	check(not seen_knockdown, "pulsar bloqueo al caer evita el derribo")
	await _place(60.0)
	_launch_p2()
	await _press(1, STAND_BLOCK)
	await _until(func(): return p2.state == Fighter.State.KNOCKDOWN, 80)
	check(p2.state == Fighter.State.KNOCKDOWN, "pulsar el bloqueo demasiado pronto no sirve")

	# Voltereta hacia atrás: manteniendo atrás al final del derribo.
	await _place(60.0)
	_launch_p2()
	await _until(func(): return p2.state == Fighter.State.KNOCKDOWN, 80)
	var x_down := p2.position.x
	_masks = [0, 1 << 1]
	await _until(func(): return p2.state == Fighter.State.WAKEUP, Fighter.KNOCKDOWN_FRAMES + 5)
	_masks = [0, 0]
	check(p2.wake_rolling, "manteniendo atrás se levanta rodando")
	await _ticks(Fighter.ROLL_MOVE_FRAMES - 2)
	check(p2.position.x - x_down > 35.0, "la voltereta se aleja (%.0f px)" % (p2.position.x - x_down))
	check(p2.state == Fighter.State.WAKEUP and not p2.can_be_hit() , "sigue invulnerable rodando")
	await _ticks(Fighter.ROLL_FRAMES)
	check(p2.state == Fighter.State.IDLE and p2.can_be_hit(), "al terminar de rodar vuelve a actuar")

	# Barrido (patada agachada): derriba.
	var swept := false
	for dx in [34.0, 40.0, 46.0, 52.0]:
		await _place(dx)
		await _press(0, (1 << BIT_CROUCH) | (1 << BIT_LK), 1 << BIT_CROUCH)
		await _until(func(): return not _hits.is_empty(), 40)
		if not _hits.is_empty():
			swept = true
			break
	_masks = [0, 0]
	check(swept, "el barrido conecta")
	check(await _until(func(): return p2.state == Fighter.State.KNOCKDOWN, 60), "el barrido derriba")

	# Agarre: la llave derriba.
	await _place(30.0)
	await _press(0, GRAB)
	await _until(func(): return p2.state == Fighter.State.THROWN, 30)
	check(await _until(func(): return p2.state == Fighter.State.KNOCKDOWN, 100), "el agarre derriba")

	# Un golpe normal no derriba.
	await _place(34.0)
	await _press(0, 1 << BIT_LP)
	await _until(func(): return not _hits.is_empty(), 30)
	await _ticks(40)
	check(p2.state != Fighter.State.KNOCKDOWN and not p2.knockdown_pending, "un golpe débil no derriba")

	# El K.O. manda sobre el derribo.
	await _place(60.0)
	p2.health = 1.0
	_launch_p2()
	check(p2.state == Fighter.State.KO, "si el lanzamiento remata, es K.O. y no derribo")
	await _ticks(60)

# --- Ultimate ---------------------------------------------------------------
const BOTH_SPECIALS := (1 << BIT_S1) | (1 << BIT_S2)

func _test_ultimate() -> void:
	print("\n# Ultimate")
	var p1 := combat.p1
	var p2 := combat.p2
	var ult := p1.data.ultimate
	await _wait_round()

	# Sin la energía llena no sale; pulsar los dos especiales lanza el especial normal.
	await _place(60.0)
	p1.energy = Fighter.MAX_ENERGY - 1.0
	await _press(0, BOTH_SPECIALS)
	await _ticks(2)
	check(p1.current_slot != &"ultimate" and combat.cinematic_frames == 0, "con menos de 100 de energía no sale el ultimate")
	await _ticks(90)

	# Especial 1 + Especial 2 con la energía llena.
	await _place(60.0)
	p1.energy = Fighter.MAX_ENERGY
	await _press(0, BOTH_SPECIALS)
	check(p1.state == Fighter.State.ATTACK and p1.current_slot == &"ultimate", "los dos especiales a la vez lanzan el ultimate")
	check(p1.energy < 5.0, "gasta toda la energía (%.0f)" % p1.energy)
	check(combat.cinematic_frames == CombatManager.ULT_CINEMATIC_FRAMES, "empieza la cinemática")
	var time0 := combat.round_manager.time_left
	var frame0 := p1.attack_frame
	var tick0 := combat.tick_count
	for i in 12:
		await get_tree().physics_frame
	check(p1.attack_frame == frame0 and combat.tick_count == tick0 and is_equal_approx(combat.round_manager.time_left, time0),
		"durante la cinemática el combate y el reloj están parados")
	check(combat.cinematic_frames < CombatManager.ULT_CINEMATIC_FRAMES and combat.camera.zoom.x > 1.0, "la cámara se acerca")
	await _until(func(): return not _hits.is_empty(), 120)
	check(combat.cinematic_frames == 0 and is_equal_approx(combat.camera.zoom.x, 1.0), "al acabar la cámara vuelve")
	check(not _hits.is_empty() and is_equal_approx(_hits[0][3].damage, _full_damage(ult)),
		"el ultimate hace su daño (%.1f)" % (0.0 if _hits.is_empty() else _hits[0][3].damage))
	await _ticks(100)

	# Bloqueado: daño de rozadura y la guardia se gasta.
	await _place(60.0, STAND_BLOCK)
	p1.energy = Fighter.MAX_ENERGY
	await _press(0, BOTH_SPECIALS)
	await _until(func(): return not _hits.is_empty(), 120)
	check(not _hits.is_empty() and _hits[0][3].blocked, "se puede bloquear")
	check(p2.guard < Fighter.MAX_GUARD or p2.guard_is_broken, "y gasta la guardia")
	await _ticks(100)

	# Segunda tecla un instante tarde: el especial recién empezado pasa a ultimate.
	await _place(60.0)
	p1.energy = Fighter.MAX_ENERGY
	await _press(0, 1 << BIT_S1)
	await _press(0, 1 << BIT_S2)
	await _ticks(2)
	check(p1.current_slot == &"ultimate" and p1.energy < 5.0, "la segunda tecla un frame tarde también vale")
	await _until(func(): return not _hits.is_empty(), 120)
	await _ticks(100)

	# Con poca energía la segunda tecla tarde no le quita el especial.
	await _place(60.0)
	p1.energy = 60.0
	await _press(0, 1 << BIT_S1)
	await _press(0, 1 << BIT_S2)
	await _ticks(2)
	check(p1.current_slot == &"special_1" or p1.current_slot == &"special_2", "sin energía para el ultimate sigue el especial")
	await _ticks(100)

	# No se lanza en el aire.
	await _place(60.0)
	p1.energy = Fighter.MAX_ENERGY
	p1.position.y = p1.floor_y - 60.0
	p1.velocity.y = -100.0
	p1._set_state(Fighter.State.JUMP)
	await _press(0, BOTH_SPECIALS)
	await _ticks(2)
	check(p1.current_slot != &"ultimate", "no se puede lanzar en el aire")
	await _ticks(60)

	# La energía no pasa de una ronda a otra.
	p1.energy = Fighter.MAX_ENERGY
	p1.reset_for_round(p1.position.x, 1)
	check(is_equal_approx(p1.energy, Fighter.ROUND_START_ENERGY), "cada ronda empieza con %d de energía" % int(Fighter.ROUND_START_ENERGY))

# --- IA ---------------------------------------------------------------------
## Pone una IA de nivel máximo (con semilla, para que el resultado sea repetible) en P2.
func _ai_on(seed_value: int) -> AIController:
	var ai := AIController.new(combat.p2, combat.p1, 1.0)
	ai._rng.seed = seed_value
	combat.ai = ai
	return ai

func _ai_off() -> void:
	combat.ai = null
	combat.p2.input.release_all()

func _test_ai() -> void:
	print("
# IA")
	var p1 := combat.p1
	var p2 := combat.p2
	await _wait_round()

	# Ultimate con la energía llena y el rival a tiro.
	await _place(60.0)
	var ai := _ai_on(11)
	p2.energy = Fighter.MAX_ENERGY
	check(await _until(func(): return p2.current_slot == &"ultimate", 200), "la CPU lanza el ultimate con la energía llena")
	_ai_off()
	await _ticks(160)

	# Antiaéreo contra un salto cercano.
	await _place(50.0)
	ai = _ai_on(12)
	var anti := false
	for i in 90:
		p1.position.y = p1.floor_y - 60.0
		p1.velocity.y = -10.0
		p1._set_state(Fighter.State.JUMP)
		await combat.ticked
		if p2.current_attack != null and p2.current_attack.id == &"uppercut":
			anti = true
			break
	check(anti, "la CPU usa el antiaéreo contra un salto cercano")
	_ai_off()
	await _ticks(60)

	# Castigo: elige un golpe que llega antes de que el rival se recupere.
	await _place(30.0)
	ai = _ai_on(13)
	var heavy := p1.data.kick_heavy
	p1._set_state(Fighter.State.ATTACK)
	p1.current_attack = heavy
	p1.current_slot = &"kick_heavy"
	p1.attack_frame = heavy.startup + heavy.active + 1
	var pick := ai._punish_slot(30.0)
	check(pick != &"", "la CPU ve cómo castigar un ataque en recuperación (%s)" % pick)
	p1.attack_frame = heavy.total_frames() - 1
	check(ai._punish_slot(30.0) == &"", "pero no si ya no le da tiempo")
	_ai_off()
	await _ticks(60)

	# Cancelaciones: tras conectar un golpe débil, encadena otro.
	var chained := false
	ai = _ai_on(14)
	for t in 10:
		await _place(34.0)
		ai = _ai_on(14 + t)
		p2.energy = 0.0
		await _press(1, 1 << BIT_LP)
		for i in 40:
			await combat.ticked
			if p2.chain_slots.size() >= 2:
				chained = true
				break
		if chained:
			break
	check(chained, "la CPU cancela un golpe que conecta en otro")
	_ai_off()
	await _ticks(60)

	# Backdash para escapar de la presión.
	var dashed := false
	for t in 40:
		await _place(36.0)
		await _press(0, 1 << BIT_LP)
		ai = _ai_on(100 + t)
		for i in 30:
			await combat.ticked
			if p2.state == Fighter.State.BACKDASH:
				dashed = true
				break
		if dashed:
			break
	check(dashed, "la CPU se escapa con un backdash")
	_ai_off()
	await _ticks(60)

	# Evitar el derribo pulsando bloqueo al caer.
	var teched := false
	for t in 12:
		await _place(60.0)
		ai = _ai_on(200 + t)
		_launch_p2()
		var down := false
		for i in 60:
			await combat.ticked
			down = down or p2.state == Fighter.State.KNOCKDOWN
		if not down:
			teched = true
			break
	check(teched, "la CPU evita el derribo a veces")
	_ai_off()
	await _ticks(60)

	# Tumbada, a veces se levanta rodando.
	var rolled := false
	for t in 12:
		await _place(60.0)
		ai = _ai_on(300 + t)
		_launch_p2()
		for i in 120:
			await combat.ticked
			if p2.state == Fighter.State.WAKEUP and p2.wake_rolling:
				rolled = true
				break
		if rolled:
			break
	check(rolled, "la CPU se levanta con voltereta a veces")
	_ai_off()
	await _ticks(60)

# --- Balance ----------------------------------------------------------------
func _test_balance() -> void:
	print("
# Balance")
	var lo := INF
	var hi := 0.0
	var lo_id := ""
	var hi_id := ""
	for d in FighterRegistry.all():
		var ehp := d.max_health * d.resistance
		if ehp < lo:
			lo = ehp
			lo_id = d.id
		if ehp > hi:
			hi = ehp
			hi_id = d.id
	check(hi / lo <= 1.4, "la vida efectiva va de %.0f (%s) a %.0f (%s): como mucho 1,4 veces" % [lo, lo_id, hi, hi_id])
	var inv := Fighter.new()
	inv.invert_frames = 100
	inv.invert_grace = Fighter.INVERT_WARNING
	check(not inv.is_inverted(), "los controles invertidos avisan antes de invertirse")
	inv.invert_grace = 0
	check(inv.is_inverted(), "y luego se invierten")
	inv.free()

# --- Bloqueo perfecto -------------------------------------------------------
func _test_perfect_block() -> void:
	print("
# Bloqueo perfecto")
	var p1 := combat.p1
	var p2 := combat.p2
	await _wait_round()
	var jab := p1.data.punch_light
	# Bloqueo mantenido de sobra: daño de rozadura normal.
	await _place(34.0, STAND_BLOCK)
	await _ticks(10)
	var hp := p2.health
	var guard := p2.guard
	await _press(0, 1 << BIT_LP)
	await _until(func(): return not _hits.is_empty(), 30)
	check(not _hits.is_empty() and _hits[0][3].blocked and not _hits[0][3].perfect, "un bloqueo mantenido no es perfecto")
	check(p2.health < hp and p2.guard < guard, "y gasta vida y guardia")
	await _ticks(60)
	# Bloqueo pulsado justo a tiempo.
	await _place(34.0)
	await _press(0, 1 << BIT_LP)
	_masks[1] = STAND_BLOCK
	await _until(func(): return not _hits.is_empty(), 30)
	_masks[1] = 0
	check(not _hits.is_empty() and _hits[0][3].blocked and _hits[0][3].perfect, "pulsar el bloqueo justo antes del golpe es perfecto")
	check(is_equal_approx(p2.health, p2.data.max_health) and is_equal_approx(p2.guard, Fighter.MAX_GUARD), "no hay rozadura ni gasto de guardia")
	await _ticks(60)

# --- Poderes de los personajes nuevos ---------------------------------------
func _set_fighters(a: StringName, b: StringName) -> void:
	combat.p1.setup(FighterRegistry.get_by_id(a), 1, combat.p1.input)
	combat.p2.setup(FighterRegistry.get_by_id(b), 2, combat.p2.input)

func _test_new_powers() -> void:
	print("
# Poderes nuevos")
	var p1 := combat.p1
	var p2 := combat.p2
	await _wait_round()

	# Escudo de Allende: absorbe el primer golpe sin daño y devuelve una onda.
	_set_fighters(&"salvador_allende", &"napoleon")
	await _place(34.0)
	p1.energy = Fighter.MAX_ENERGY
	await _press(0, 1 << BIT_S2)
	await _until(func(): return p1.shield_frames > 0, 60)
	check(p1.shield_frames > 0, "el escudo de Allende se activa")
	var hp := p1.health
	_hits.clear()
	await _press(1, 1 << BIT_LP)
	await _until(func(): return not _hits.is_empty(), 60)
	check(not _hits.is_empty() and _hits[0][3].absorbed and is_equal_approx(p1.health, hp), "absorbe el golpe sin daño")
	check(p1.shield_frames == 0, "y el escudo se consume")
	var p2_hp := p2.data.max_health
	await _until(func(): return p2.health < p2_hp, 120)
	check(p2.health < p2_hp, "devuelve una onda al atacante (%.1f de daño)" % (p2_hp - p2.health))
	await _ticks(90)

	# Estado de Sitio: el rival queda inmovilizado.
	_set_fighters(&"augusto_pinochet", &"napoleon")
	await _place(70.0)
	p1.energy = Fighter.MAX_ENERGY
	await _press(0, 1 << BIT_S2)
	await _until(func(): return p2.root_frames > 0, 80)
	check(p2.root_frames > 0, "la barrera inmoviliza al rival")
	var x0 := p2.position.x
	_masks[1] = 1 << 1
	await _ticks(20)
	_masks[1] = 0
	check(absf(p2.position.x - x0) < 3.0, "y no puede caminar mientras dura")
	await _ticks(160)

	# Ancla de la Esmeralda: arrastra al rival hacia Prat.
	_set_fighters(&"arturo_prat", &"napoleon")
	await _place(110.0)
	p1.energy = Fighter.MAX_ENERGY
	var d0 := p2.position.x - p1.position.x
	await _press(0, 1 << BIT_S2)
	await _until(func(): return not _hits.is_empty(), 90)
	await _ticks(20)
	check(not _hits.is_empty() and p2.position.x - p1.position.x < d0 - 15.0, "el ancla acerca al rival (%.0f → %.0f px)" % [d0, p2.position.x - p1.position.x])
	await _ticks(120)

	_set_fighters(&"napoleon", &"donald_trump")

# --- Perfiles de los luchadores ---------------------------------------------
## Cada luchador tiene su ritmo, un golpe alto o bajo propio y dos combos que se pueden enlazar.
func _test_profiles() -> void:
	print("
# Perfiles de los luchadores")
	var bad_links: Array[String] = []
	var no_special_hit: Array[String] = []
	var startups := {}
	var unique := {}
	var with_level := 0
	for d in FighterRegistry.all():
		var sig := ""
		var has_level := false
		for slot in [&"punch_light", &"punch_heavy", &"kick_light", &"kick_heavy"]:
			var a := d.get_attack(slot)
			sig += "%d/%d/%d/%.0f;" % [a.startup, a.recovery, a.hitbox_size.x, a.damage]
			startups[a.startup] = true
			if a.hit_level != AttackData.HitLevel.MID:
				has_level = true
		unique[sig] = true
		if has_level:
			with_level += 1
		else:
			no_special_hit.append(String(d.id))
		var combos := d.get_combos()
		if combos.size() != 2:
			bad_links.append("%s tiene %d combos" % [d.id, combos.size()])
		for cmb in combos:
			for i in range(1, cmb.sequence.size()):
				var prev := d.get_attack(cmb.sequence[i - 1])
				var nxt := d.get_attack(cmb.sequence[i])
				if nxt.hit_level == AttackData.HitLevel.OVERHEAD:
					bad_links.append("%s: %s lleva un golpe alto" % [d.id, cmb.display_name])
				# Para enlazar, el siguiente golpe debe llegar antes de que acabe el aturdimiento.
				if nxt.startup + 2 > prev.hitstun - Fighter.HITSTUN_DECAY * (i - 1):
					bad_links.append("%s: %s no enlaza %s → %s" % [d.id, cmb.display_name, cmb.sequence[i - 1], cmb.sequence[i]])
	check(bad_links.is_empty(), "todos los combos son enlazables (%s)" % ", ".join(bad_links))
	check(with_level == FighterRegistry.all().size(), "todos tienen un golpe alto o bajo propio (faltan: %s)" % ", ".join(no_special_hit))
	check(unique.size() >= FighterRegistry.all().size() - 6, "los golpes normales son distintos entre luchadores (%d perfiles distintos de %d)" % [unique.size(), FighterRegistry.all().size()])
	check(startups.size() >= 8, "hay %d startups distintos entre los golpes normales" % startups.size())
