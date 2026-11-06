## Capturas del mapa del mundo del Modo Historia durante el viaje hasta un combate.
##   godot --path . res://tests/WorldMapShots.tscn -- <carpeta> [--stage=N] [--player=napoleon]
## Necesita pantalla (no vale --headless). Guarda map_<tiempo>.png (ampliadas x3). Con --stage=0 se ve la llegada
## por el rayo de la Torre del Reloj; con otro, el viaje desde el combate anterior.
extends Node

const SCALE := 3
const TIMES: Array[float] = [0.35, 1.0, 1.6, 2.4, 3.2, 4.0, 4.6, 5.2, 5.7, 6.0]

func _ready() -> void:
	Backend.story_path = "user://story_preview.cfg"
	var out := ""
	var player := &"napoleon"
	var stage := 5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player="):
			player = StringName(arg.trim_prefix("--player="))
		elif arg.begins_with("--stage="):
			stage = int(arg.trim_prefix("--stage="))
		elif not arg.begins_with("--"):
			out = arg
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://world_map")
	DirAccess.make_dir_recursive_absolute(out)
	Game.start_story(player)
	Game.arcade_stage = stage
	Game.p2_fighter_id = Game.arcade_ladder[stage]
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var map := StoryWorldMap.new()
	add_child(map)
	var done := false
	map.finished.connect(func(): done = true)
	var t0 := Time.get_ticks_msec()
	for t in TIMES:
		while (Time.get_ticks_msec() - t0) / 1000.0 < t and not done:
			await get_tree().process_frame
		if done:
			break
		_save("%s/map_%.2f.png" % [out, t])
	print("Capturas en ", out)
	get_tree().quit()

func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
