## Simulador de balance: IA contra IA en todos los cruces del plantel, sin dibujar nada.
## Cada pelea es UNA ronda (gana quien deja al otro K.O. o con más vida al acabar el tiempo) y guarda una
## línea CSV:  p1,p2,ganador(0 empate/1/2),ticks,ko(1/0),vida1,vida2,daño1,daño2
## Para repartir el trabajo entre procesos se parte la lista de cruces en trozos (--shard / --shards).
##
## Uso:  godot --headless --fixed-fps 60 --path . res://tests/BalanceSim.tscn -- --out=<archivo.csv>
##         [--shard=0 --shards=8] [--games=2] [--level=0.8] [--no-passives]
##         [--tweaks=<archivo.json>] [--only=id1,id2] [--reach-shrink=0.5]
## --tweaks aplica cambios sin tocar los .tres: {"napoleon": {"strength": 1.05, "max_health": 100, "reach_shift": -3}}
## --reach-shrink=k acerca el alcance de los 4 golpes normales de cada luchador a la media del plantel
## (k=0: nada; k=1: todos igual). Desplaza el hitbox, no cambia su tamaño ni sus fotogramas.
## --only juega solo los cruces donde participa alguno de esos luchadores (para probar un ajuste rápido).
##
## La IA usa azar sin semilla (AIController), así que cada corrida da números algo distintos: sirve para
## estadística (tasas de victoria con decenas de peleas por luchador), no para comparar tick a tick.
extends Node

const MAX_TICKS := 6000        # tope de seguridad por ronda (la ronda dura Game.round_time)
const ROUND_SECONDS := 45

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func _run() -> void:
	var out_path := ""
	var shard := 0
	var shards := 1
	var games := 2
	var level := 0.8
	var no_passives := false
	var tweaks_path := ""
	var reach_shrink := 0.0
	var only: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--shard="):
			shard = int(arg.trim_prefix("--shard="))
		elif arg.begins_with("--shards="):
			shards = int(arg.trim_prefix("--shards="))
		elif arg.begins_with("--games="):
			games = int(arg.trim_prefix("--games="))
		elif arg.begins_with("--level="):
			level = float(arg.trim_prefix("--level="))
		elif arg == "--no-passives":
			no_passives = true
		elif arg.begins_with("--tweaks="):
			tweaks_path = arg.trim_prefix("--tweaks=")
		elif arg.begins_with("--reach-shrink="):
			reach_shrink = float(arg.trim_prefix("--reach-shrink="))
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	if out_path.is_empty():
		print("FALLO: falta --out=<archivo.csv>")
		get_tree().quit(1)
		return
	Game.mode = Game.Mode.VERSUS
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	Game.round_time = ROUND_SECONDS
	var roster := FighterRegistry.all()
	if no_passives:
		for d in roster:
			d.passive = &""
	if reach_shrink > 0.0:
		for slot in [&"punch_light", &"punch_heavy", &"kick_light", &"kick_heavy"]:
			var mean := 0.0
			for d in roster:
				var a := d.get_attack(slot)
				mean += a.hitbox_offset.x + a.hitbox_size.x * 0.5
			mean /= roster.size()
			for d in roster:
				var a := d.get_attack(slot)
				var reach := a.hitbox_offset.x + a.hitbox_size.x * 0.5
				a.hitbox_offset = Vector2(a.hitbox_offset.x - reach_shrink * (reach - mean), a.hitbox_offset.y)
	if tweaks_path != "":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(tweaks_path))
		if parsed is Dictionary:
			for id in parsed:
				var data := FighterRegistry.get_by_id(StringName(id))
				if data == null:
					print("AVISO: luchador desconocido en --tweaks: ", id)
					continue
				for field in parsed[id]:
					if field == "reach_shift":
						# Desplaza el hitbox de los 4 golpes normales (px; + = más alcance).
						for slot in [&"punch_light", &"punch_heavy", &"kick_light", &"kick_heavy"]:
							var a := data.get_attack(slot)
							a.hitbox_offset = Vector2(a.hitbox_offset.x + float(parsed[id][field]), a.hitbox_offset.y)
					else:
						data.set(field, float(parsed[id][field]))
	var pairs: Array = []
	for a in roster:
		for b in roster:
			if a.id == b.id:
				continue
			if not only.is_empty() and not (str(a.id) in only or str(b.id) in only):
				continue
			pairs.append([a.id, b.id])
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		print("FALLO: no se puede escribir en ", out_path)
		get_tree().quit(1)
		return
	var done := 0
	for i in pairs.size():
		if i % shards != shard:
			continue
		for g in games:
			var line := await _fight(pairs[i][0], pairs[i][1], level)
			file.store_line(line)
			done += 1
		file.flush()
	file.close()
	print("listo: %d peleas (shard %d/%d, pasivas %s)" % [done, shard, shards, "NO" if no_passives else "SI"])
	get_tree().quit()

func _fight(a_id: StringName, b_id: StringName, level: float) -> String:
	Game.p1_fighter_id = a_id
	Game.p2_fighter_id = b_id
	var combat := load(Game.SCENE_FIGHT).instantiate() as CombatManager
	add_child(combat)
	await get_tree().physics_frame
	combat.set_physics_process(false)
	var ai1 := AIController.new(combat.p1, combat.p2, level)
	var ai2 := AIController.new(combat.p2, combat.p1, level)
	var dmg := [0.0, 0.0]
	combat.hit_landed.connect(func(att: Fighter, _d: Fighter, _atk: AttackData, r: HitResult) -> void:
		dmg[att.player_id - 1] += r.damage)
	var delta := 1.0 / 60.0
	var started := false
	var ticks := 0
	for i in MAX_TICKS:
		ai1.think()
		ai2.think()
		combat._physics_process(delta)
		var phase := combat.round_manager.phase
		if phase == RoundManager.Phase.FIGHT:
			started = true
			ticks += 1
		elif started:
			break   # la ronda terminó por tiempo
		# Un K.O. cierra la ronda con una llamada diferida que no corre mientras avanzamos los ticks a mano:
		# se corta aquí (el ganador se decide igual que en RoundManager: por vida restante).
		if started and (combat.p1.state == Fighter.State.KO or combat.p2.state == Fighter.State.KO):
			break
	var h1 := combat.p1.health / combat.p1.data.max_health
	var h2 := combat.p2.health / combat.p2.data.max_health
	var winner := 0
	if h1 > h2 + 0.0001:
		winner = 1
	elif h2 > h1 + 0.0001:
		winner = 2
	var ko := 1 if (combat.p1.state == Fighter.State.KO or combat.p2.state == Fighter.State.KO) else 0
	remove_child(combat)
	combat.free()
	return "%s,%s,%d,%d,%d,%.3f,%.3f,%.1f,%.1f" % [a_id, b_id, winner, ticks, ko, h1, h2, dmg[0], dmg[1]]
