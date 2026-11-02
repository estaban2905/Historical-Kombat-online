## Capturas de la animación de cada época del Modo Historia en varios instantes.
##   godot --path . res://tests/StoryEraShots.tscn -- <carpeta>
## Necesita pantalla (no vale --headless). Guarda era_<época>_<segundo>.png, ampliadas x2.
extends Node

const TIMES: Array[float] = [2.0, 4.0, 6.0]
const SCALE := 2

func _ready() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			out = arg
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://era_shots")
	DirAccess.make_dir_recursive_absolute(out)
	for idx in StoryEraIntro.ERAS.size():
		for t in TIMES:
			var era := StoryEraIntro.new()
			era.chapter = idx
			era.preview_time = t
			add_child(era)
			await get_tree().process_frame
			await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
			img.save_png("%s/era_%d_%d.png" % [out, idx + 1, int(t)])
			era.queue_free()
			await get_tree().process_frame
	print("Capturas en ", out)
	get_tree().quit()
