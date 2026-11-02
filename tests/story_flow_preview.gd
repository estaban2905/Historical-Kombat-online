## Recorrido de continuidad del Modo Historia, sin combatir:
## mini-intro del Nexo -> por cada época: animación, tarjeta y pantalla del primer rival -> final.
##   godot --path . res://tests/StoryFlowPreview.tscn -- [--player=napoleon]
## Cualquier tecla salta la animación y la tarjeta en curso; la pantalla del rival dura 2,5 s.
extends Node

const VS_TIME := 2.5
## Revanchas gastadas al abrir cada época, para ver también las reacciones del Nexo.
const CONTINUES: Array[int] = [0, 0, 0, 1, 1, 2]

func _ready() -> void:
	var player := &"napoleon"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player="):
			player = StringName(arg.trim_prefix("--player="))
	Game.start_story(player)
	var starts: Array[int] = []
	for i in Game.arcade_ladder.size():
		if Game.story_chapter_start(i):
			starts.append(i)
	for k in starts.size():
		Game.arcade_stage = starts[k]
		Game.p2_fighter_id = Game.arcade_ladder[starts[k]]
		Game.story_continues_used = CONTINUES[mini(k, CONTINUES.size() - 1)]
		var scene := (load(Game.SCENE_STORY) as PackedScene).instantiate()
		add_child(scene)
		while is_instance_valid(scene) and (scene._intro != null or scene._card):
			await get_tree().process_frame
		await get_tree().create_timer(VS_TIME).timeout
		scene.queue_free()
		await get_tree().process_frame
	add_child((load(Game.SCENE_STORY_ENDING) as PackedScene).instantiate())
