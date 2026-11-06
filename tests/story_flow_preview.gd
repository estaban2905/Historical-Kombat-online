## Recorrido de continuidad del Modo Historia, sin combatir, con todo lo que se ve y se oye, en orden:
## mini-intro del Nexo -> por cada época: animación, tarjeta, pantalla del primer rival, escena de diálogo
## de sus creadores del Reloj y de su jefe (con voz) y los resultados de vencerlo (despedida y fragmento del Reloj) -> el Nexo -> final.
##   godot --path . res://tests/StoryFlowPreview.tscn -- [--player=napoleon] [--scenes]
## Cualquier tecla salta la animación, la tarjeta o la escena en curso; cada pantalla fija dura unos segundos.
extends Node

const VS_TIME := 2.5
const RESULTS_TIME := 4.5
## Revanchas gastadas al abrir cada época, para ver también las reacciones del Nexo.
const CONTINUES: Array[int] = [0, 0, 0, 1, 1, 2]

func _ready() -> void:
	# Las vistas previas no guardan en la partida real del jugador.
	Backend.story_path = "user://story_preview.cfg"
	var player := &"napoleon"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player="):
			player = StringName(arg.trim_prefix("--player="))
	Game.start_story(player)
	if OS.get_cmdline_user_args().has("--scenes"):
		await _all_scenes(player)
		get_tree().quit()
		return
	var starts: Array[int] = []
	for i in Game.arcade_ladder.size():
		if Game.story_chapter_start(i):
			starts.append(i)
	for k in starts.size():
		Game.story_continues_used = CONTINUES[mini(k, CONTINUES.size() - 1)]
		# El primer rival de la época: animación, tarjeta y, si tiene, su escena de diálogo.
		await _show_stage(starts[k])
		# El jefe de la época (el Nexo ya es el único de la suya): su escena y los resultados de vencerlo.
		var boss := starts[k]
		while boss + 1 < Game.arcade_ladder.size() and Game.story_chapter_of(Game.arcade_ladder[boss + 1]) == k:
			boss += 1
		# Los creadores del Reloj que aparecen a mitad de la época (su escena de diálogo, con voz).
		for stage in range(starts[k] + 1, boss):
			if Game.story_is_creator(stage):
				await _show_stage(stage)
		if boss != starts[k]:
			await _show_stage(boss)
			await _show_results(boss)
	add_child((load(Game.SCENE_STORY_ENDING) as PackedScene).instantiate())

## Modo --scenes: solo las escenas de diálogo de cada rival (sin animaciones de época), una tras otra, en orden de escalera.
func _all_scenes(player: StringName) -> void:
	for stage in Game.arcade_ladder.size():
		if not StoryScenes.lines(Game.arcade_ladder[stage], player).is_empty():
			await _show_stage(stage, true)

## La pantalla de historia de ese combate, esperando a que acaben animaciones, tarjeta y diálogo.
func _show_stage(stage: int, skip_intros: bool = false) -> void:
	Game.arcade_stage = stage
	Game.p2_fighter_id = Game.arcade_ladder[stage]
	var scene := (load(Game.SCENE_STORY) as PackedScene).instantiate()
	scene._skip_intros = skip_intros
	add_child(scene)
	var waited := 0.0
	while is_instance_valid(scene) and waited < 90.0:
		var busy: bool = scene._intro != null or scene._card or not scene._btn.visible
		if not busy:
			break
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().create_timer(VS_TIME).timeout
	if is_instance_valid(scene):
		scene.queue_free()
	await get_tree().process_frame

## Los resultados de vencer a ese rival.
func _show_results(stage: int) -> void:
	Game.arcade_stage = stage
	Game.p2_fighter_id = Game.arcade_ladder[stage]
	Game.set_match_result(1, 2, 0)
	var results := (load("res://scenes/Results.tscn") as PackedScene).instantiate()
	add_child(results)
	await get_tree().create_timer(RESULTS_TIME).timeout
	results.queue_free()
	await get_tree().process_frame
