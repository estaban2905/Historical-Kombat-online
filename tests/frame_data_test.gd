## Prueba de frame data: mide cada ataque cuerpo a cuerpo contra un muñeco quieto.
## Para cada ataque (de pie y agachado) comprueba:
##   - en qué frame del ataque conecta (debería ser startup + 1),
##   - la ventaja al golpear y al bloquear: cuántos frames antes puede actuar el
##     atacante que el defensor (negativo = el defensor actúa primero),
##   - con qué normales enlaza (combo garantizado tras golpear).
## Usa la misma fuente de entradas que el online (máscaras por tick), así que
## mide el motor real, no los datos.
## Uso:  godot --headless --fixed-fps 60 --path . res://tests/FrameDataTest.tscn -- [--only=id1,id2] [--csv=ruta.csv]
extends Node

## Rival fijo para todas las mediciones (su ancho solo afecta a la distancia).
const DUMMY := &"napoleon"
const SETTLE_TICKS := 10
const MAX_WAIT := 240
const BIT_CROUCH := 3
const BIT_BLOCK := 4
const NORMALS: Array[StringName] = [&"punch_light", &"punch_heavy", &"kick_light", &"kick_heavy"]
const SHORT := {&"punch_light": "PD", &"punch_heavy": "PF", &"kick_light": "KD",
	&"kick_heavy": "KF", &"special_1": "E1", &"special_2": "E2"}

var _masks: Array = [0, 0]
## Último impacto registrado: {tick, frame, blocked}.
var _hit: Dictionary = {}
var _failures: int = 0
var _csv: PackedStringArray = ["fighter,slot,pose,startup,impact_frame,expected_frame,adv_hit,adv_block,links"]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func _run() -> void:
	print("\n=== HISTORY COMBAT · FRAME DATA ===")
	Game.mode = Game.Mode.VERSUS
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	Game.round_time = 9999
	var only := PackedStringArray()
	var csv_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--csv="):
			csv_path = arg.trim_prefix("--csv=")
	for data in FighterRegistry.all():
		if not only.is_empty() and not only.has(String(data.id)):
			continue
		await _measure_fighter(data)
	if csv_path != "":
		var file := FileAccess.open(csv_path, FileAccess.WRITE)
		if file:
			file.store_string("\n".join(_csv) + "\n")
			print("\nCSV escrito en ", csv_path)
	print("\n=== RESULTADO: %d ataques no conectan en el frame esperado ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)

func _measure_fighter(data: FighterData) -> void:
	Game.p1_fighter_id = data.id
	Game.p2_fighter_id = DUMMY
	var combat := load(Game.SCENE_FIGHT).instantiate() as CombatManager
	add_child(combat)
	combat.set_input_source(func(_tick: int) -> Array: return _masks)
	combat.hit_landed.connect(func(attacker: Fighter, _d: Fighter, _a: AttackData, result: Dictionary):
		if attacker == combat.p1 and _hit.is_empty():
			_hit = {"tick": combat.tick_count, "frame": attacker.attack_frame, "blocked": result.blocked})
	while combat.round_manager.phase != RoundManager.Phase.FIGHT:
		await combat.ticked

	print("\n%s" % data.display_name)
	print("  %-4s %-6s %4s %9s %8s %8s  %s" % ["ATQ", "POSE", "INI", "CONECTA", "V.GOLPE", "V.BLOQ", "ENLAZA CON"])
	for slot in FighterData.ATTACK_SLOTS:
		var atk := data.get_attack(slot)
		if atk == null or atk.is_projectile() or atk.is_power():
			continue
		for crouch in [false, true]:
			if crouch and not atk.usable_crouching:
				continue
			var on_hit := await _measure(combat, slot, crouch, false)
			var on_block := await _measure(combat, slot, crouch, true)
			_report(data, slot, atk, crouch, on_hit, on_block)
	# Salir del tick del combate antes de liberarlo (seguimos dentro de su señal).
	await get_tree().physics_frame
	remove_child(combat)
	combat.free()

## Lanza un ataque contra el muñeco y mide cuándo puede volver a actuar cada uno.
func _measure(combat: CombatManager, slot: StringName, crouch: bool, block: bool) -> Dictionary:
	var p1 := combat.p1
	var p2 := combat.p2
	var atk := p1.data.get_attack(slot)
	# El muñeco se coloca en el centro de la hitbox para que conecte en el primer frame activo.
	var off_x := atk.hitbox_offset.x + (atk.crouch_offset.x if crouch else 0.0)
	var min_dist := (p1.data.body_width + p2.data.body_width) * 0.5 * 0.8 + 0.5
	var dx := maxf(off_x, min_dist)
	var mid := (p1.bounds.x + p1.bounds.y) * 0.5
	p1.reset_for_round(mid - dx * 0.5, 1)
	p2.reset_for_round(mid + dx * 0.5, -1)
	p1.energy = Fighter.MAX_ENERGY
	combat.round_manager.time_left = 9999.0
	var base := (1 << BIT_CROUCH) if crouch else 0
	var dummy := (1 << BIT_BLOCK) if block else 0
	_masks = [base, dummy]
	for i in SETTLE_TICKS:
		await combat.ticked
	_hit = {}
	_masks = [base | (1 << InputManager.FRAME_ACTIONS.find(slot)), dummy]
	await combat.ticked
	_masks = [base, dummy]
	var waited := 0
	while _hit.is_empty() and waited < MAX_WAIT:
		await combat.ticked
		waited += 1
	if _hit.is_empty():
		return {"connected": false}
	# El atacante actúa en el mismo tick en que termina su ataque; el defensor,
	# en el tick siguiente a salir del aturdimiento (así funciona fighter.gd).
	var attacker_act := -1
	var defender_act := -1
	waited = 0
	while (attacker_act < 0 or defender_act < 0) and waited < MAX_WAIT:
		await combat.ticked
		waited += 1
		var t := combat.tick_count - 1
		if attacker_act < 0 and p1.state != Fighter.State.ATTACK and p1.hitstop_frames == 0:
			attacker_act = t
		var stunned := p2.state == Fighter.State.HIT or (p2.state == Fighter.State.BLOCK and p2.stun_frames > 0)
		if defender_act < 0 and not stunned and p2.hitstop_frames == 0:
			defender_act = t + 1
	return {"connected": true, "frame": _hit.frame, "blocked": _hit.blocked,
		"advantage": defender_act - attacker_act}

func _report(data: FighterData, slot: StringName, atk: AttackData, crouch: bool,
		on_hit: Dictionary, on_block: Dictionary) -> void:
	var expected := atk.startup + 1
	var pose := "agach." if crouch else "de pie"
	if not on_hit.connected:
		_failures += 1
		print("  %-4s %-6s %4d %9s  [FAIL] no conecta" % [SHORT[slot], pose, atk.startup, "-"])
		return
	var frame_ok: bool = on_hit.frame == expected
	if not frame_ok:
		_failures += 1
	var adv_hit: int = on_hit.advantage
	var adv_block := "-"
	if on_block.connected and on_block.blocked:
		adv_block = "%+d" % on_block.advantage
	# Enlaza si el siguiente golpe llega antes de que el defensor pueda actuar.
	var links := PackedStringArray()
	for next in NORMALS:
		var n := data.get_attack(next)
		if n and n.startup + 1 <= adv_hit - 1:
			links.append(SHORT[next])
	var impact := "%d" % on_hit.frame + ("" if frame_ok else " (esp %d)" % expected)
	print("  %-4s %-6s %4d %9s %+8d %8s  %s%s" % [SHORT[slot], pose, atk.startup, impact, adv_hit,
		adv_block, ",".join(links) if not links.is_empty() else "-", "" if frame_ok else "  [FAIL]"])
	_csv.append("%s,%s,%s,%d,%d,%d,%d,%s,%s" % [data.id, slot, "crouch" if crouch else "stand",
		atk.startup, on_hit.frame, expected, adv_hit, adv_block, " ".join(links)])
