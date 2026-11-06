## Capturas del globo terráqueo del Modo Historia: la elección de villano y el viaje.
##   godot --path . res://tests/GlobeShots.tscn -- <carpeta> [--beaten=N] [--player=napoleon] [--pick=K]
## Necesita pantalla (no vale --headless). --beaten=N da por vencidos los N primeros combates; --pick=K elige el K-ésimo
## de la lista (0 = el primero) y sigue con el viaje. Guarda globe_<tiempo>.png (ampliadas x3).
extends Node

const SCALE := 3

func _ready() -> void:
	Backend.story_path = "user://story_preview.cfg"
	var out := ""
	var player := &"napoleon"
	var beaten := 0
	var pick := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player="):
			player = StringName(arg.trim_prefix("--player="))
		elif arg.begins_with("--beaten="):
			beaten = int(arg.trim_prefix("--beaten="))
		elif arg.begins_with("--pick="):
			pick = int(arg.trim_prefix("--pick="))
		elif not arg.begins_with("--"):
			out = arg
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://globe")
	DirAccess.make_dir_recursive_absolute(out)
	Game.start_story(player)
	for i in beaten:
		Game.story_beaten[i] = true
	Game.story_last_won = beaten - 1
	Game.arcade_stage = Game.story_default_pick()
	Game.p2_fighter_id = Game.arcade_ladder[Game.arcade_stage]
	var globe := StoryGlobeMap.new()
	add_child(globe)
	var done := false
	globe.finished.connect(func(): done = true)
	await get_tree().create_timer(1.0).timeout
	_save("%s/globe_select.png" % out)
	if pick >= 0:
		globe._select(pick)
		await get_tree().create_timer(0.9).timeout
		_save("%s/globe_picked.png" % out)
		globe._confirm()
		for i in 22:
			if done:
				break
			await get_tree().create_timer(0.3).timeout
			if not done:
				_save("%s/globe_go_%02d.png" % [out, i])
	print("Capturas en ", out)
	get_tree().quit()

func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
