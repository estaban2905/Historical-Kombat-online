## Juega el modo Historia con una cuenta, por las escenas de verdad, para llenar un servidor de datos (ver
## tests/populate_dev.sh): selección → línea del tiempo → combate contra la CPU → resultados → siguiente.
## Lo que se guarda (luchadores desbloqueados, partida guardada en la cuenta) lo guarda el propio juego.
## Para no tardar, en cada ronda el rival queda a 1 de vida y el jugador lo remata con su tecla (U); en el
## combate que se pierde (--lose-at) es el jugador el que queda a 1 de vida y la CPU lo remata.
## Uso:  godot --headless --fixed-fps 60 --path . res://tests/StorySim.tscn -- --url=ws://127.0.0.1:8787/ws
##         --email=max@sim.com --name=Max_Sim --fighter=napoleon --wins=6 [--lose-at=3]
extends Node

var _email := ""
var _name := ""
var _fighter: StringName = &"napoleon"
var _wins := 5
## Combate (empezando en 1) que se pierde una vez, para gastar una revancha.
var _lose_at := -1
var _lost := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Este nodo no es "la escena": así los cambios de escena del juego no lo borran.
	get_tree().current_scene = null
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--url="):
			ServerConfig.override_ws = arg.trim_prefix("--url=")
		elif arg.begins_with("--email="):
			_email = arg.trim_prefix("--email=")
		elif arg.begins_with("--name="):
			_name = arg.trim_prefix("--name=")
		elif arg.begins_with("--fighter="):
			_fighter = StringName(arg.trim_prefix("--fighter="))
		elif arg.begins_with("--wins="):
			_wins = int(arg.trim_prefix("--wins="))
		elif arg.begins_with("--lose-at="):
			_lose_at = int(arg.trim_prefix("--lose-at="))
	_run.call_deferred()

func scene() -> Node:
	return get_tree().current_scene

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Sin ventana los fotogramas van tan rápido como puede la CPU: las esperas son en segundos reales.
func seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame

func wait_scene(scene_name: String, timeout_s: float = 30.0) -> bool:
	var until := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		if scene() and scene().name == scene_name:
			return true
	return false

func tap(physical: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = physical
		ev.keycode = physical
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await frames(2)

func _run() -> void:
	# Archivos locales aparte: no se mezclan con los del juego de quien lo ejecuta.
	Backend.session_path = "user://sim_session_story.cfg"
	Backend.story_path = "user://sim_story.cfg"
	Unlocks.path = "user://sim_unlocks.cfg"
	if not await Backend.check_available():
		_finish("FALLO: el servidor no responde", 1)
		return
	var r := await Backend.sign_up(_email, "secreto1", _name)
	if not r.ok:
		r = await Backend.sign_in(_email, "secreto1")
	if not r.ok:
		_finish("FALLO de cuenta: %s" % r.error, 1)
		return
	await Backend.sync_unlocks()
	print("CUENTA %s" % Backend.username())
	Game.difficulty = Game.Difficulty.EASY
	Game.mode = Game.Mode.ARCADE
	Engine.time_scale = 4.0
	# Como CharacterSelect al confirmar: empieza la historia y la guarda.
	Game.start_story(_fighter)
	Game.story_autosave()
	Game.goto(Game.SCENE_STORY)
	var won := 0
	var fight_no := 1
	while won < _wins:
		if not await wait_scene("Story"):
			_finish("FALLO: no se llegó a la línea del tiempo", 1)
			return
		# La tarjeta del capítulo y la presentación del rival se saltan con ENTER; luego COMBATIR.
		for i in 40:
			await seconds(0.4)
			if scene() == null or scene().name != "Story":
				break
			await tap(KEY_ENTER)
		if not await wait_scene("Fight"):
			_finish("FALLO: COMBATIR no abrió el combate", 1)
			return
		var lose := fight_no == _lose_at and not _lost
		var rival := Game.p2_fighter_id
		await _play_fight(lose)
		if not await wait_scene("Results"):
			_finish("FALLO: no salió la pantalla de resultados", 1)
			return
		await seconds(0.5)
		var results := scene()
		var outcome: StringName = results._arcade
		print("COMBATE %d contra %s: %s" % [fight_no, rival, outcome])
		if lose:
			_lost = true
			if outcome != &"retry":
				_finish("FALLO: perder no ofreció CONTINUAR (%s)" % outcome, 1)
				return
			results.btn_rematch.pressed.emit()   # CONTINUAR: gasta una revancha y repite el combate
			if not await wait_scene("Fight"):
				_finish("FALLO: CONTINUAR no repitió el combate", 1)
				return
			await _play_fight(false)
			if not await wait_scene("Results"):
				_finish("FALLO: no salió la pantalla de resultados tras la revancha", 1)
				return
			await seconds(0.5)
			results = scene()
			outcome = results._arcade
			print("REVANCHA contra %s: %s" % [rival, outcome])
		if outcome != &"next":
			_finish("FALLO: tras ganar no se ofreció SIGUIENTE COMBATE (%s)" % outcome, 1)
			return
		won += 1
		fight_no += 1
		results.btn_rematch.pressed.emit()   # SIGUIENTE COMBATE
		await seconds(0.5)
	# Que la partida guardada y los desbloqueos lleguen a la cuenta antes de salir.
	await seconds(2.0)
	var saved := await Backend.load_story()
	print("PARTIDA combate=%d revanchas=%d" % [int(saved.get("stage", -1)) + 1, int(saved.get("continues", -1))])
	var remote: Variant = await Backend.fetch_unlocks()
	print("DESBLOQUEOS en la cuenta: %d" % (remote as Array).size() if remote is Array else -1)
	_finish("", 0)

## Juega rondas hasta que acabe el combate: en cada una, quien debe perder queda a 1 de vida y el otro lo
## golpea (el jugador con U; la CPU con su IA).
func _play_fight(lose: bool) -> void:
	for round_i in 12:
		var c := scene() as CombatManager
		if c == null:
			return
		var ready := false
		var until := Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < until:
			await frames(1)
			c = scene() as CombatManager
			if c == null:
				return
			if c.round_manager.phase == RoundManager.Phase.FIGHT:
				ready = true
				break
		if not ready:
			return
		c.p1.position.x = 190
		c.p2.position.x = 214
		if lose:
			c.p1.health = 1
		else:
			c.p2.health = 1
		var until_ko := Time.get_ticks_msec() + 30000
		while Time.get_ticks_msec() < until_ko:
			if scene() != c or c.round_manager.phase != RoundManager.Phase.FIGHT:
				break
			if not lose:
				await tap(KEY_U)
			await seconds(0.15)
		if scene() != c:
			return

func _finish(message: String, code: int) -> void:
	if message != "":
		print(message)
	Engine.time_scale = 1.0
	get_tree().quit(code)
