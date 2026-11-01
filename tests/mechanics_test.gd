## Pruebas de mecánicas de combate (agarre, defensa, combos...).
## Mueven el combate real con máscaras de entrada por tick, igual que el online,
## así que cada caso es exacto y repetible.
## Uso:  godot --headless --fixed-fps 60 --path . res://tests/MechanicsTest.tscn
extends Node

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
	await _ticks(8)
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

	# Cancelar al conectar: débil → fuerte.
	await _place(24.0)
	await _press(0, 1 << BIT_LP)
	await _until(func(): return _hits.size() >= 1, 30)
	await _press(0, 1 << BIT_HP)
	await _until(func(): return _hits.size() >= 2, 60)
	check(_hits.size() >= 2 and _hits[1][2] == ph, "puño débil cancela en puño fuerte al conectar")
	check(p2.combo_hits_taken == 2, "los dos golpes cuentan como un combo (%d)" % p2.combo_hits_taken)
	check(_hits.size() >= 2 and is_equal_approx(_hits[1][3].damage, _full_damage(ph) * (1.0 - Fighter.COMBO_SCALE_STEP)),
		"el segundo golpe hace un %d %% menos de daño" % int(Fighter.COMBO_SCALE_STEP * 100))
	check(p2.stun_frames == ph.hitstun - Fighter.HITSTUN_DECAY,
		"el segundo golpe acorta el aturdimiento (%d frames)" % p2.stun_frames)

	# Cancelar bloqueado.
	await _place(24.0, STAND_BLOCK)
	await _press(0, 1 << BIT_LP)
	await _until(func(): return _hits.size() >= 1, 30)
	await _press(0, 1 << BIT_HP)
	await _until(func(): return _hits.size() >= 2, 60)
	check(_hits.size() >= 2 and _hits[0][3].blocked and _hits[1][2] == ph, "también se cancela cuando el golpe es bloqueado")

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
	await _place_in_corner(24.0)
	var n := await _chain([BIT_LP, BIT_LK, BIT_HP, BIT_HK])
	check(n == 4, "la cadena débil-débil-fuerte-fuerte conecta los 4 golpes (%d)" % n)
	check(names.has("CUARTETO") and _hits.size() >= 4 and _hits[3][3].combo_name == "CUARTETO",
		"completar la cadena de 4 es el combo CUARTETO")
	var bonus := p1.data.get_combos()[1].bonus_damage * p1.data.strength / p2.data.resistance
	var last_damage: float = _hits[3][3].damage if _hits.size() >= 4 else -1.0
	check(is_equal_approx(last_damage, _full_damage(kh) * 0.7 + bonus),
		"el último golpe suma el bono del combo (%.2f)" % last_damage)
	await _ticks(60)
	names.clear()
	await _place_in_corner(24.0)
	n = await _chain([BIT_LP, BIT_HP, BIT_HK])
	check(n == 3 and names.has("TRÍO") and _hits.size() >= 3 and _hits[2][3].combo_name == "TRÍO",
		"débil-fuerte-fuerte es el combo TRÍO")
	await _ticks(60)
