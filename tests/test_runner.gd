## Pruebas automáticas de extremo a extremo (sin ventana).
## Uso:  godot --headless --path . res://tests/TestRunner.tscn
## Simula pulsaciones REALES de teclado (InputEventKey con las teclas del
## Input Map) y recorre: menú -> selección -> combate -> rondas -> resultados.
extends Node

var passed: int = 0
var failed: int = 0
var log_lines: PackedStringArray = []

func _ready() -> void:
	# Las pruebas deben poder correr con la escena principal cambiando.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El runner deja de ser la "escena actual" para sobrevivir a los cambios de escena.
	get_tree().current_scene = null
	_run.call_deferred()

func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  [OK]   ", label)
	else:
		failed += 1
		print("  [FAIL] ", label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func key(physical: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical
	ev.keycode = physical
	ev.pressed = pressed
	Input.parse_input_event(ev)

func tap(physical: Key, hold_frames: int = 2) -> void:
	key(physical, true)
	await frames(hold_frames)
	key(physical, false)
	await frames(1)

func scene() -> Node:
	return get_tree().current_scene

func wait_scene(scene_name: String, max_frames: int = 120) -> bool:
	for i in max_frames:
		await frames(1)
		if scene() and scene().name == scene_name and not Game.is_changing_scene():
			return true
	return false

# ==========================================================================
func _run() -> void:
	print("\n=== HISTORY COMBAT · PRUEBAS AUTOMÁTICAS ===")
	_test_resources()
	await _test_menu_to_fight()
	await _test_fight()
	await _test_powers()
	await _test_ultimates()
	await _test_rounds_and_results()
	await _test_soak()
	await _test_arcade()
	print("\n=== RESULTADO: %d OK, %d FALLOS ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func _test_resources() -> void:
	print("\n# Datos y escenas")
	for path in ["res://scenes/MainMenu.tscn", "res://scenes/CharacterSelect.tscn", "res://scenes/Fight.tscn",
			"res://scenes/Results.tscn", "res://scenes/fighters/Fighter.tscn", "res://ui/HUD.tscn",
			"res://stages/colosseum/Colosseum.tscn"]:
		var ps := load(path) as PackedScene
		check(ps != null and ps.can_instantiate(), "escena carga: " + path)
	var roster := FighterRegistry.all()
	check(roster.size() == 39, "roster con 39 luchadores (%d)" % roster.size())
	var seen := {}
	for d in roster:
		check(not seen.has(d.id), "id único: %s" % d.id)
		seen[d.id] = true
	for d in roster:
		check(d.validate().is_empty(), "ficha completa: %s" % d.id)
	for d in roster:
		var sp := StageRegistry.scene_for(d.id)
		var ps := load(sp) as PackedScene
		check(ps != null and ps.can_instantiate(), "escenario de %s carga (%s)" % [d.id, sp.get_file()])
		check(d.id == &"julio_cesar" or not StageRegistry.def_for(d.id).is_empty(), "escenario propio definido: %s" % d.id)
	for a in ["p1_left", "p1_right", "p1_jump", "p1_crouch", "p1_block", "p1_punch_light", "p1_punch_heavy",
			"p1_special_1", "p1_kick_light", "p1_kick_heavy", "p1_special_2"]:
		var b: String = a.replace("p1_", "p2_")
		check(InputMap.has_action(a) and InputMap.has_action(b), "acciones registradas: %s / %s" % [a, b])
	# Los controles de P1 y P2 no comparten ninguna tecla.
	var keys1 := {}
	var shared := 0
	for a in InputMap.get_actions():
		if String(a).begins_with("p1_"):
			for e in InputMap.action_get_events(a):
				keys1[(e as InputEventKey).physical_keycode] = true
	for a in InputMap.get_actions():
		if String(a).begins_with("p2_"):
			for e in InputMap.action_get_events(a):
				if keys1.has((e as InputEventKey).physical_keycode):
					shared += 1
	check(shared == 0, "P1 y P2 no comparten teclas")

func _test_menu_to_fight() -> void:
	print("\n# Menú -> Selección -> Combate")
	get_tree().change_scene_to_file(Game.SCENE_MENU)
	check(await wait_scene("MainMenu"), "el juego arranca en el menú principal")
	var play := scene().get_node("Buttons/Play") as Button
	check(play.has_focus(), "ARCADE tiene el foco")
	# VERSUS LOCAL: foco y ENTER
	(scene().get_node("Buttons/Versus") as Button).grab_focus()
	await frames(2)
	await tap(KEY_ENTER)
	check(await wait_scene("CharacterSelect"), "VERSUS LOCAL abre la selección de luchador")
	check(Game.mode == Game.Mode.VERSUS and not Game.is_vs_cpu(), "versus local: sin CPU")
	await frames(5)
	await tap(KEY_U)        # P1 confirma
	await tap(KEY_KP_1)     # P2 confirma con el numpad
	check(await wait_scene("Fight", 240), "con ambos confirmados empieza el combate")

func _fight() -> CombatManager:
	return scene() as CombatManager

func _wait_fight_phase() -> bool:
	for i in 300:
		await frames(1)
		var c := _fight()
		if c and c.round_manager.phase == RoundManager.Phase.FIGHT:
			return true
	return false

## Coloca a los luchadores a una distancia, con vida y energía llenas.
func _setup_duel(distance: float) -> void:
	var c := _fight()
	c.reset_round()
	c.p1.position.x = 160
	c.p2.position.x = 160 + distance
	c.p1.energy = 100.0
	c.p2.energy = 100.0
	c.set_controls(true)
	await frames(3)

func _test_fight() -> void:
	print("\n# Combate")
	check(await _wait_fight_phase(), "ROUND 1 / FIGHT! y se habilitan los controles")
	var c := _fight()
	var p1 := c.p1
	var p2 := c.p2
	check(p1.data.id == &"donald_trump" and p2.data.id == &"napoleon", "P1=Trump, P2=Napoleón")
	check(p1.facing == 1 and p2.facing == -1, "se miran el uno al otro")

	# --- Movimiento P1 (WASD) ---
	await _setup_duel(120)
	var x0 := p1.position.x
	key(KEY_D, true); await frames(20); key(KEY_D, false); await frames(2)
	check(p1.position.x > x0 + 15, "P1 camina a la derecha con D (%.1f -> %.1f)" % [x0, p1.position.x])
	x0 = p1.position.x
	key(KEY_A, true); await frames(20); key(KEY_A, false); await frames(2)
	check(p1.position.x < x0 - 10, "P1 camina a la izquierda con A")
	key(KEY_W, true); await frames(12)
	check(p1.position.y < p1.floor_y - 20 and p1.state == Fighter.State.JUMP, "P1 salta con W")
	key(KEY_W, false); await frames(60)
	check(p1.is_on_ground() and p1.state == Fighter.State.IDLE, "P1 aterriza y vuelve a IDLE")
	key(KEY_S, true); await frames(3)
	check(p1.state == Fighter.State.CROUCH, "P1 se agacha con S")
	check(p1._hurt_shape.size.y < p1.data.stand_height, "hurtbox más baja al agacharse")
	key(KEY_S, false); await frames(2)
	key(KEY_SPACE, true); await frames(3)
	check(p1.state == Fighter.State.BLOCK, "P1 bloquea con ESPACIO")
	key(KEY_U, true); await frames(3); key(KEY_U, false); await frames(3)
	check(p1.state == Fighter.State.BLOCK, "bloqueando no se puede atacar")
	key(KEY_SPACE, false); await frames(3)

	# --- Abajo + ataque: barrido, aunque se pulsen a la vez ---
	await _setup_duel(60)
	key(KEY_S, true); key(KEY_J, true); await frames(3)
	check(p1.state == Fighter.State.ATTACK and p1.attack_crouching and p1.get_pose_name() == &"sweep",
		"↓ + patada pulsadas a la vez: barrido")
	key(KEY_J, false); key(KEY_S, false); await frames(40)
	await _setup_duel(60)
	key(KEY_S, true); await frames(5); key(KEY_U, true); await frames(3)
	check(p1.state == Fighter.State.ATTACK and p1.attack_crouching, "↓ mantenido + puño: ataque agachado")
	key(KEY_U, false); key(KEY_S, false); await frames(40)

	# --- Correr: doble toque adelante y atrás ---
	await _setup_duel(200)
	var walk_dx := 0.0
	x0 = p1.position.x
	key(KEY_D, true); await frames(10); key(KEY_D, false)
	walk_dx = p1.position.x - x0
	await frames(30)
	check(not p1.running, "un solo toque no corre")
	x0 = p1.position.x
	key(KEY_D, true); await frames(3); key(KEY_D, false); await frames(3)
	key(KEY_D, true); await frames(10)
	check(p1.running and p1.get_pose_name() == &"run", "doble toque adelante: P1 corre")
	key(KEY_D, false); await frames(3)
	check(not p1.running, "soltar la dirección corta la carrera")
	check(p1.position.x - x0 > walk_dx * 1.4, "correr avanza más que caminar (%.1f vs %.1f)" % [p1.position.x - x0, walk_dx])
	await frames(30)
	x0 = p1.position.x
	key(KEY_A, true); await frames(3); key(KEY_A, false); await frames(3)
	key(KEY_A, true); await frames(10)
	check(p1.state == Fighter.State.BACKDASH and not p1.running and p1.position.x < x0 - 15,
		"doble toque atrás: P1 hace un backdash")
	key(KEY_A, false); await frames(30)
	key(KEY_D, true); await frames(3); key(KEY_D, false); await frames(25)
	key(KEY_D, true); await frames(5)
	check(not p1.running, "toques demasiado separados no corren")
	key(KEY_D, false); await frames(10)
	await _setup_duel(120)

	# --- Movimiento P2 (flechas + numpad) ---
	var x2 := p2.position.x
	key(KEY_LEFT, true); await frames(20); key(KEY_LEFT, false); await frames(2)
	check(p2.position.x < x2 - 15, "P2 camina a la izquierda con ←")
	x2 = p2.position.x
	key(KEY_RIGHT, true); await frames(20); key(KEY_RIGHT, false); await frames(2)
	check(p2.position.x > x2 + 10, "P2 camina a la derecha con →")
	key(KEY_UP, true); await frames(12)
	check(p2.state == Fighter.State.JUMP, "P2 salta con ↑")
	key(KEY_UP, false); await frames(60)
	key(KEY_DOWN, true); await frames(3)
	check(p2.state == Fighter.State.CROUCH, "P2 se agacha con ↓")
	key(KEY_DOWN, false); await frames(2)
	key(KEY_KP_0, true); await frames(3)
	check(p2.state == Fighter.State.BLOCK, "P2 bloquea con Numpad 0")
	key(KEY_KP_0, false); await frames(3)

	# --- Los seis ataques de cada jugador hacen daño exactamente una vez ---
	var p1_keys := {&"punch_light": KEY_U, &"punch_heavy": KEY_I, &"special_1": KEY_O,
		&"kick_light": KEY_J, &"kick_heavy": KEY_K, &"special_2": KEY_L}
	var p2_keys := {&"punch_light": KEY_KP_1, &"punch_heavy": KEY_KP_2, &"special_1": KEY_KP_3,
		&"kick_light": KEY_KP_4, &"kick_heavy": KEY_KP_5, &"special_2": KEY_KP_6}
	for slot in p1_keys:
		await _attack_test(p1, p2, slot, p1_keys[slot])
	for slot in p2_keys:
		await _attack_test(p2, p1, slot, p2_keys[slot])

	# --- Bloqueo reduce el daño ---
	await _setup_duel(40)
	key(KEY_KP_0, true); await frames(3)
	var hp := p2.health
	await tap(KEY_I)
	await frames(30)
	var blocked_dmg := hp - p2.health
	var full := p1.data.punch_heavy.damage * p1.data.strength / p2.data.resistance
	check(blocked_dmg > 0.0 and blocked_dmg < full * 0.3, "bloqueo reduce el daño (%.2f de %.2f)" % [blocked_dmg, full])
	key(KEY_KP_0, false); await frames(3)

	# --- Ataques simultáneos: intercambio de golpes ---
	await _setup_duel(40)
	var h1 := p1.health
	var h2 := p2.health
	# Los puños débiles de cada luchador tienen su propio startup: se adelanta al más lento
	# para que los dos golpes lleguen en el mismo frame.
	var d1 := p1.data.punch_light.startup
	var d2 := p2.data.punch_light.startup
	if d2 > d1:
		key(KEY_KP_1, true); await frames(d2 - d1); key(KEY_U, true)
	else:
		key(KEY_U, true); await frames(d1 - d2); key(KEY_KP_1, true)
	await frames(2)
	key(KEY_U, false); key(KEY_KP_1, false)
	await frames(30)
	check(p1.health < h1 and p2.health < h2, "ambos atacan a la vez y ambos reciben daño (%.1f / %.1f)" % [h1 - p1.health, h2 - p2.health])

	# --- Energía: sin energía no hay especial ---
	await _setup_duel(60)
	p1.energy = 0.0
	await tap(KEY_O)
	await frames(2)
	check(p1.state != Fighter.State.ATTACK, "sin energía no se lanza el especial")

	# --- Nadie atraviesa al rival ni sale de la arena ---
	await _setup_duel(40)
	key(KEY_D, true); key(KEY_LEFT, true)
	await frames(60)
	key(KEY_D, false); key(KEY_LEFT, false)
	await frames(2)
	check(p1.position.x < p2.position.x, "los cuerpos no se atraviesan caminando")
	p1.position.x = 30
	key(KEY_A, true); await frames(40); key(KEY_A, false); await frames(2)
	check(p1.position.x >= p1.bounds.x, "P1 no sale por el borde izquierdo")
	# Salto cruzado: puede pasar por encima y no quedarse atascado
	await _setup_duel(36)
	key(KEY_D, true); key(KEY_W, true)
	await frames(6)
	key(KEY_W, false)
	await frames(60)
	key(KEY_D, false)
	await frames(10)
	check(p1.is_on_ground() and absf(p1.position.x - p2.position.x) >= (p1.data.body_width + p2.data.body_width) * 0.39,
		"tras un salto encima del rival nadie queda superpuesto")
	check(p1.state == Fighter.State.IDLE, "P1 no queda bloqueado tras el salto (estado %s)" % p1.state_name())

func _attack_test(attacker: Fighter, defender: Fighter, slot: StringName, k: Key) -> void:
	var atk := attacker.data.get_attack(slot)
	var dist := 70.0 if (atk.is_projectile() or atk.is_power()) else 34.0
	if atk.dash_speed > 0.0:
		dist = 80.0
	await _setup_duel(dist)
	if attacker.player_id == 2:
		# Intercambiar lados: P2 a la izquierda mirando a P1
		attacker.position.x = 160
		defender.position.x = 160 + dist
		await frames(2)
	var hp := defender.health
	var hits := 0
	key(k, true); await frames(2); key(k, false)
	var last := hp
	for i in 90:
		await frames(1)
		if defender.health < last - 0.001:
			hits += 1
			last = defender.health
	var expected := atk.damage * attacker.data.strength / defender.data.resistance
	var dealt := hp - defender.health
	if atk.is_power():
		# Los poderes pueden repartir el daño en varios impactos (ráfagas).
		check(hits >= 1 and dealt > 0.0 and dealt <= expected + 0.05,
			"P%d %s (%s): %d impactos, daño %.2f (máx. %.2f)" % [attacker.player_id, slot, atk.display_name, hits, dealt, expected])
		return
	check(hits == 1 and absf(dealt - expected) < 0.05,
		"P%d %s (%s): %d impacto, daño %.2f (esperado %.2f)" % [attacker.player_id, slot, atk.display_name, hits, dealt, expected])

## Lanza el poder especial (special_2) de los 39 luchadores contra un rival
## parado y comprueba que conecta, que su efecto especial ocurre y que las
## entidades desaparecen solas.
func _test_powers() -> void:
	print("\n# Poderes especiales de los 39 luchadores")
	var c := _fight()
	Engine.time_scale = 3.0
	for d in FighterRegistry.all():
		var atk := d.special_2
		c.round_manager.time_left = 99.0   # que no acabe la ronda por tiempo
		await _setup_duel(70)
		c.p1.setup(d, 1, c.p1.input)
		c.p1.position.x = 160
		c.p1.energy = 100.0
		c.p1.controls_enabled = true
		c.p2.position.x = 160 + (40 if not (atk.is_power() or atk.is_projectile()) else 70)
		await frames(3)
		var hp2 := c.p2.health
		var energy_before := c.p1.energy
		var min_y1 := 0.0
		var min_y2 := 0.0
		var max_slow := 0
		var max_invert := 0
		var max_root := 0
		var max_shield := 0
		var max_back := 0.0
		var swapped := false
		c.p1.input.press(&"special_2")
		for i in 150:
			await frames(1)
			min_y1 = minf(min_y1, c.p1.position.y - c.p1.floor_y)
			min_y2 = minf(min_y2, c.p2.position.y - c.p2.floor_y)
			max_slow = maxi(max_slow, c.p2.slow_frames)
			max_invert = maxi(max_invert, c.p2.invert_frames)
			max_root = maxi(max_root, c.p2.root_frames)
			max_shield = maxi(max_shield, c.p1.shield_frames)
			max_back = maxf(max_back, 160.0 - c.p2.position.x)
			if c.p1.position.x > c.p2.position.x:
				swapped = true
		var dealt := hp2 - c.p2.health
		var cap := atk.damage * d.strength / c.p2.data.resistance + 0.05
		if atk.power == &"chilean_way":
			# El escudo no hace daño: se comprueba que se activa (la onda devuelta se prueba en MechanicsTest).
			check(max_shield > 0, "%s: «%s» activa el escudo" % [d.id, atk.display_name])
		else:
			check(dealt > 0.0 and dealt <= cap, "%s: «%s» conecta (daño %.1f, máx. %.1f, hp0 %.1f, hp1 %.1f)" % [d.id, atk.display_name, dealt, cap, hp2, c.p2.health])
		match atk.power:
			&"relativity": check(max_slow > 0, "%s: ralentiza al rival" % d.id)
			&"state_siege": check(max_root > 0, "%s: inmoviliza al rival" % d.id)
			&"andean_quake": check(min_y2 < -5.0, "%s: el terremoto lanza al rival (%.1f px)" % [d.id, min_y2])
			&"dark_hypnosis": check(max_invert > 0, "%s: invierte los controles del rival" % d.id)
			&"gravity_flip": check(min_y2 < -5.0, "%s: el rival flota (%.1f px)" % [d.id, min_y2])
			&"enlightenment": check(min_y1 < -5.0, "%s: se eleva (%.1f px)" % [d.id, min_y1])
			&"desert_ghost": check(swapped, "%s: reaparece detrás del rival" % d.id)
			&"divine_light": check(c.p1.energy > energy_before - atk.energy_cost + 20.0, "%s: recupera energía (%.0f)" % [d.id, c.p1.energy])
		# Todas las entidades deben desaparecer solas.
		for i in 200:
			if c.projectiles_root.get_child_count() == 0:
				break
			await frames(1)
		check(c.projectiles_root.get_child_count() == 0, "%s: no quedan efectos en pantalla" % d.id)
	Engine.time_scale = 1.0
	# Las rondas ganadas por tiempo durante la prueba ensucian el marcador: se recarga el combate.
	get_tree().change_scene_to_file(Game.SCENE_FIGHT)
	await wait_scene("Fight", 240)
	await _wait_fight_phase()

## Lanza el ultimate de los 39 luchadores contra un rival parado: tiene que ser una escena
## de varios golpes que no pase de su daño base, con su ambiente de pantalla, y todo debe
## desaparecer solo.
func _test_ultimates() -> void:
	print("
# Ultimates de los 39 luchadores")
	var c := _fight()
	Engine.time_scale = 3.0
	var kinds := {}
	for d in FighterRegistry.all():
		var atk := d.ultimate
		c.round_manager.time_left = 99.0
		await _setup_duel(70)
		c.p1.setup(d, 1, c.p1.input)
		c.p1.position.x = 160
		c.p1.energy = 100.0
		c.p1.controls_enabled = true
		c.p2.position.x = 230
		await frames(3)
		var hp2 := c.p2.health
		var fx_seen := false
		c.p1.input.press(&"special_1")
		c.p1.input.press(&"special_2")
		for i in 420:
			await frames(1)
			fx_seen = fx_seen or is_instance_valid(c.ult_fx)
		var dealt := hp2 - c.p2.health
		var cap := atk.damage * d.strength / c.p2.data.resistance + 0.05
		kinds[atk.ult_kind] = true
		check(atk.is_power() and atk.ult_kind != &"", "%s: «%s» es un ultimate de tipo %s" % [d.id, atk.display_name, atk.ult_kind])
		check(dealt > 0.0 and dealt <= cap, "%s: «%s» conecta (daño %.1f, máx. %.1f)" % [d.id, atk.display_name, dealt, cap])
		check(fx_seen and not is_instance_valid(c.ult_fx), "%s: el ambiente aparece y se retira solo" % d.id)
		check(c.projectiles_root.get_child_count() == 0, "%s: no quedan efectos en pantalla" % d.id)
		c.p2.health = c.p2.data.max_health
	check(kinds.size() >= 9, "hay %d tipos distintos de ultimate" % kinds.size())
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(Game.SCENE_FIGHT)
	await wait_scene("Fight", 240)
	await _wait_fight_phase()

func _test_rounds_and_results() -> void:
	print("\n# Rondas y resultados")
	var c := _fight()
	var rm := c.round_manager
	rm.pause_scale = 0.05
	# Ronda 1: P1 gana por K.O.
	await _setup_duel(34)
	c.p2.health = 1.0
	await tap(KEY_U)
	var saw_ko := false
	for i in 20:
		await frames(1)
		if c.p2.state == Fighter.State.KO:
			saw_ko = true
			break
	check(saw_ko, "con 0 de vida el luchador queda K.O.")
	await frames(10)
	check(rm.wins[1] == 1, "la ronda 1 se suma a P1")
	for i in 200:
		await frames(1)
		if rm.phase == RoundManager.Phase.INTRO or rm.round_number == 2:
			break
	check(rm.round_number == 2, "empieza la ronda 2")
	check(Game.stage_owner(1) == Game.p1_fighter_id and Game.stage_owner(2) == Game.p2_fighter_id and Game.stage_owner(3) == Game.p1_fighter_id, "escenarios: R1 de P1, R2 de P2, R3 de P1")
	check(c.stage_name() == StageRegistry.name_for(Game.p2_fighter_id), "la ronda 2 se juega en el escenario de P2 (%s)" % c.stage_name())
	check(c.stage_holder.get_child_count() == 1, "solo hay un escenario cargado")
	check(c.p1.health == c.p1.data.max_health and c.p2.health == c.p2.data.max_health, "la ronda 2 empieza con vida llena")
	check(await _wait_fight_phase(), "ronda 2 en juego")
	# Ronda 2: se agota el tiempo y P2 tiene más vida -> gana P2
	c.p1.health = c.p1.data.max_health * 0.4
	rm.time_left = 0.2
	await frames(20)
	check(rm.wins[2] == 1, "tiempo agotado: gana quien tiene más vida (P2)")
	check(await _wait_fight_phase(), "ronda 3 en juego")
	check(rm.round_number == 3, "contador de rondas = 3")
	# Ronda 3: empate por tiempo con la misma vida
	rm.time_left = 0.2
	await frames(20)
	check(rm.wins[1] == 1 and rm.wins[2] == 1, "misma vida al acabar el tiempo = empate")
	check(await _wait_fight_phase(), "ronda 4 en juego")
	# Ronda 4: P1 gana el combate por K.O.
	await _setup_duel(34)
	c.p2.health = 1.0
	await tap(KEY_U)
	check(await wait_scene("Results", 400), "al ganar 2 rondas aparece la pantalla de victoria")
	check(Game.last_winner == 1 and Game.last_p1_rounds == 2 and Game.last_p2_rounds == 1, "resultado guardado: P1 gana 2-1")
	await frames(5)
	await tap(KEY_ENTER)   # REVANCHA tiene el foco
	check(await wait_scene("Fight"), "REVANCHA reinicia el combate")
	var c2 := _fight()
	check(c2.round_manager.round_number == 1 and c2.round_manager.wins[1] == 0, "la revancha empieza de cero")

## Prueba de resistencia: dos "jugadores" aleatorios pelean miles de frames.
## Comprueba que nadie sale de la arena ni queda atascado en un estado.
func _test_soak() -> void:
	print("\n# Prueba de resistencia (entradas aleatorias)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var frames_run := 0
	var out_of_bounds := 0
	var stuck := 0
	var attacks := 0
	var counter := {"hits": 0}
	var matches := 0
	var c := _fight()
	c.round_manager.pause_scale = 0.05
	c.hit_landed.connect(func(_a, _d, _k, _r): counter.hits += 1)
	var moves: Array[StringName] = [&"left", &"right", &"jump", &"crouch", &"block"]
	while frames_run < 6000:
		var cur := _fight()
		if cur == null:
			# Pantalla de resultados: volver a pelear.
			if scene() and scene().name == "Results":
				matches += 1
				get_tree().change_scene_to_file(Game.SCENE_FIGHT)
				await frames(5)
				cur = _fight()
				if cur:
					cur.round_manager.pause_scale = 0.05
					cur.hit_landed.connect(func(_a, _d, _k, _r): counter.hits += 1)
			else:
				await frames(1)
			continue
		for f in cur.fighters:
			var inp := f.input
			if rng.randf() < 0.08:
				inp.release_all()
				if rng.randf() < 0.7:
					inp.hold(moves[rng.randi() % moves.size()])
			if rng.randf() < 0.06:
				inp.press(InputManager.ATTACK_ACTIONS[rng.randi() % 6])
			if f.state == Fighter.State.ATTACK and f.state_frames == 1:
				attacks += 1
			if f.position.x < f.bounds.x - 0.5 or f.position.x > f.bounds.y + 0.5 or f.position.y > f.floor_y + 0.5:
				out_of_bounds += 1
			if f.state in [Fighter.State.ATTACK, Fighter.State.HIT] and f.state_frames > 240:
				stuck += 1
		await frames(1)
		frames_run += 1
	check(out_of_bounds == 0, "nadie sale de la arena (%d frames)" % frames_run)
	check(stuck == 0, "nadie queda atascado en ATAQUE/DAÑO")
	check(attacks > 50 and counter.hits > 10, "hubo combate real: %d ataques, %d impactos, %d combates completos" % [attacks, counter.hits, matches])

## Modo arcade: menú -> selección de J1 -> combate contra la CPU -> escalera
## de rivales, continuaciones y fin de partida.
func _test_arcade() -> void:
	print("\n# Arcade (1 jugador contra la CPU)")
	Game.difficulty = Game.Difficulty.NORMAL
	get_tree().change_scene_to_file(Game.SCENE_MENU)
	check(await wait_scene("MainMenu"), "vuelve al menú principal")
	var diff := scene().get_node("Buttons/Difficulty") as Button
	check(diff.text == "DIFICULTAD: NORMAL", "el botón muestra la dificultad")
	diff.grab_focus()
	await frames(2)
	await tap(KEY_ENTER)
	check(Game.difficulty == Game.Difficulty.HARD and diff.text == "DIFICULTAD: DIFÍCIL", "DIFICULTAD pasa a DIFÍCIL")
	await tap(KEY_ENTER)
	await tap(KEY_ENTER)
	check(Game.difficulty == Game.Difficulty.NORMAL, "DIFICULTAD da la vuelta a NORMAL")
	(scene().get_node("Buttons/Play") as Button).grab_focus()
	await frames(2)
	await tap(KEY_ENTER)
	check(await wait_scene("CharacterSelect"), "ARCADE abre la selección de luchador")
	check(Game.is_vs_cpu() and scene().confirmed[2], "en arcade solo elige J1 (la CPU ya está lista)")
	await frames(5)
	await tap(KEY_U)
	check(await wait_scene("Fight", 240), "con J1 confirmado empieza el combate")
	var c := _fight()
	var ladder := Game.arcade_ladder
	check(ladder.size() == Game.ARCADE_RIVALS, "el arcade tiene %d rivales" % Game.ARCADE_RIVALS)
	var seen := {}
	for id in ladder:
		seen[id] = true
	check(seen.size() == ladder.size() and not seen.has(Game.p1_fighter_id), "rivales sin repetir y sin incluir al jugador")
	check(c.p2.data.id == ladder[0] and Game.arcade_stage == 0, "el primer rival es el primero de la escalera")
	check(c.stage_name() == StageRegistry.name_for(ladder[0]) and Game.stage_owner(2) == ladder[0], "arcade: el rival aparece en su propio escenario")
	check(c.ai != null and not c.p2.input.use_keyboard, "P2 lo maneja la CPU y no el teclado")
	check(absf(c.ai.level - 0.5) < 0.001, "nivel de IA NORMAL = 0.5 (%.2f)" % c.ai.level)
	check(await _wait_fight_phase(), "ROUND 1 / FIGHT!")

	Engine.time_scale = 3.0
	# --- La CPU ataca y hace daño a un jugador quieto ---
	var stats := {"cpu_hits": 0, "cpu_attacks": 0, "blocked": 0}
	c.hit_landed.connect(func(a, _d, _k, r):
		if a == c.p2:
			stats.cpu_hits += 1
		elif r.blocked:
			stats.blocked += 1)
	c.p2.attack_started.connect(func(_f, _a): stats.cpu_attacks += 1)
	c.round_manager.pause_scale = 0.05
	var start_x := c.p2.position.x
	for i in 1500:
		await frames(1)
		if stats.cpu_hits > 0:
			break
	check(stats.cpu_attacks > 0 and stats.cpu_hits > 0, "la CPU se acerca y golpea (%d ataques, %d impactos)" % [stats.cpu_attacks, stats.cpu_hits])
	check(absf(c.p2.position.x - start_x) > 10.0 or stats.cpu_hits > 0, "la CPU se mueve sola")

	# --- La CPU bloquea (nivel máximo, golpes fuertes de P1) ---
	c.ai = AIController.new(c.p2, c.p1, 1.0)
	stats.blocked = 0
	for i in 25:
		await _setup_duel(34)
		c.p1.input.press(&"punch_heavy")
		await frames(45)
		if stats.blocked > 0:
			break
	check(stats.blocked > 0, "la CPU de nivel máximo bloquea golpes (%d bloqueados)" % stats.blocked)

	# --- Resistencia: la CPU contra entradas aleatorias ---
	var saved_rounds := Game.rounds_to_win
	var saved_max := Game.max_rounds
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out_of_bounds := 0
	var stuck := 0
	stats.cpu_attacks = 0
	var moves: Array[StringName] = [&"left", &"right", &"jump", &"crouch", &"block"]
	for i in 3000:
		var inp := c.p1.input
		if rng.randf() < 0.08:
			inp.release_all()
			if rng.randf() < 0.7:
				inp.hold(moves[rng.randi() % moves.size()])
		if rng.randf() < 0.06:
			inp.press(InputManager.ATTACK_ACTIONS[rng.randi() % 6])
		for f in c.fighters:
			if f.position.x < f.bounds.x - 0.5 or f.position.x > f.bounds.y + 0.5 or f.position.y > f.floor_y + 0.5:
				out_of_bounds += 1
			if f.state in [Fighter.State.ATTACK, Fighter.State.HIT] and f.state_frames > 240:
				stuck += 1
		await frames(1)
	check(out_of_bounds == 0, "con la CPU peleando nadie sale de la arena")
	check(stuck == 0, "con la CPU peleando nadie queda atascado")
	check(stats.cpu_attacks > 30, "la CPU pelea de verdad (%d ataques)" % stats.cpu_attacks)
	Game.rounds_to_win = saved_rounds
	Game.max_rounds = saved_max
	Engine.time_scale = 1.0

	# --- Escalera: ganar pasa al siguiente rival y sube el nivel ---
	Game.set_match_result(1, 2, 0)
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	check(await wait_scene("Results"), "pantalla de resultados del arcade")
	var rematch := scene().get_node("Buttons/Rematch") as Button
	check(Game.arcade_outcome() == &"next" and rematch.text == "SIGUIENTE COMBATE", "tras ganar se ofrece SIGUIENTE COMBATE")
	check(not (scene().get_node("Buttons/Select") as Button).visible, "en arcade no se puede cambiar de luchador")
	await frames(5)
	await tap(KEY_ENTER)
	check(await wait_scene("Fight", 240), "SIGUIENTE COMBATE abre el combate")
	c = _fight()
	check(Game.arcade_stage == 1 and c.p2.data.id == ladder[1], "el segundo combate es contra el segundo rival")
	check(absf(c.ai.level - 0.54) < 0.001, "la CPU sube de nivel: %.2f" % c.ai.level)

	# --- Perder: continuar gasta una revancha y repite rival ---
	Game.set_match_result(2, 0, 2)
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	check(await wait_scene("Results"), "resultados tras perder")
	rematch = scene().get_node("Buttons/Rematch") as Button
	check(rematch.text == "CONTINUAR (3)", "tras perder se ofrece CONTINUAR (%s)" % rematch.text)
	await frames(5)
	await tap(KEY_ENTER)
	check(await wait_scene("Fight", 240), "CONTINUAR repite el combate")
	check(Game.arcade_continues == 2 and Game.arcade_stage == 1 and _fight().p2.data.id == ladder[1], "gasta una revancha y repite el mismo rival")

	# --- Sin revanchas: fin de la partida ---
	Game.arcade_continues = 0
	Game.set_match_result(2, 0, 2)
	check(Game.arcade_outcome() == &"over", "sin revanchas el arcade termina")
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	check(await wait_scene("Results"), "resultados con partida terminada")
	rematch = scene().get_node("Buttons/Rematch") as Button
	check(not rematch.visible and (scene().get_node("Buttons/Menu") as Button).has_focus(), "solo queda volver al menú")
	await frames(5)
	await tap(KEY_ENTER)
	check(await wait_scene("MainMenu"), "vuelve al menú principal")

	# --- Ganar el último combate completa el arcade ---
	Game.arcade_stage = ladder.size() - 1
	Game.set_match_result(1, 2, 0)
	check(Game.arcade_outcome() == &"complete", "ganar al último rival completa el arcade")
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	check(await wait_scene("Results"), "resultados del arcade completado")
	check(not (scene().get_node("Buttons/Rematch") as Button).visible, "arcade completado: solo menú")
	Game.mode = Game.Mode.VERSUS
