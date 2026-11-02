## Capturas de la tarjeta de cada época del Modo Historia (y de la placa del primer rival).
##   godot --path . res://tests/StoryCardsShots.tscn -- <carpeta> [--player=napoleon]
## Necesita pantalla (no vale --headless). Guarda card_N.png y vs_N.png, ampliadas x3.
extends Node

const SCALE := 3

func _ready() -> void:
	var out := ""
	var player := &"napoleon"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player="):
			player = StringName(arg.trim_prefix("--player="))
		elif not arg.begins_with("--"):
			out = arg
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://story_cards")
	DirAccess.make_dir_recursive_absolute(out)
	Game.start_story(player)
	var starts: Array[int] = []
	for i in Game.arcade_ladder.size():
		if Game.story_chapter_start(i):
			starts.append(i)
	for k in starts.size():
		Game.arcade_stage = starts[k]
		Game.p2_fighter_id = Game.arcade_ladder[starts[k]]
		Game.story_continues_used = [0, 0, 1, 2, 4, 4][mini(k, 5)]
		var scene := (load(Game.SCENE_STORY) as PackedScene).instantiate()
		add_child(scene)
		scene._skip_intros = true
		if scene._intro:
			scene._intro.skip()
		await get_tree().create_timer(1.0).timeout
		_save("%s/card_%d.png" % [out, k + 1])
		scene._t = scene.CARD_TIME
		await get_tree().create_timer(0.4).timeout
		_save("%s/vs_%d.png" % [out, k + 1])
		scene.queue_free()
		await get_tree().process_frame
	print("Capturas en ", out)
	get_tree().quit()

func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
