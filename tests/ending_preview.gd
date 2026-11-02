## Atajo para ver el final del Modo Historia sin combatir.
##   godot --path . res://tests/EndingPreview.tscn -- [--player=napoleon] [--ending=repair|rewrite|free]
##        [--continues=N] [--shots=<carpeta>]
## Sin --ending muestra el final completo desde el principio. Con --ending salta a esa animación.
## --continues=N simula N revanchas gastadas (con 0 aparece la tercera opción, LIBERAR).
## --shots=<carpeta> guarda capturas de cada animación (necesita pantalla) y cierra.
extends Node

const SHOT_TIMES: Array[float] = [2.0, 4.0, 6.0, 8.0]
const SCALE := 2

func _ready() -> void:
	var player := &"napoleon"
	var ending := &""
	var continues := 0
	var shots := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player="):
			player = StringName(arg.trim_prefix("--player="))
		elif arg.begins_with("--ending="):
			ending = StringName(arg.trim_prefix("--ending="))
		elif arg.begins_with("--continues="):
			continues = int(arg.trim_prefix("--continues="))
		elif arg.begins_with("--shots="):
			shots = arg.trim_prefix("--shots=")
	Game.start_story(player)
	Game.story_continues_used = continues
	if not shots.is_empty():
		await _shots(shots)
		get_tree().quit()
		return
	var scene := StoryEnding.new()
	add_child(scene)
	if ending != &"":
		scene._choose(ending)

func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for ending in [&"repair", &"rewrite", &"free"]:
		for t in SHOT_TIMES:
			var scene := StoryEnding.new()
			add_child(scene)
			scene._choose(ending)
			scene._voice.stop()
			scene._voice_started = true
			scene._anim_end = 99.0
			scene._t = t
			await get_tree().process_frame
			await get_tree().process_frame
			scene._t = t
			await get_tree().process_frame
			var img := get_viewport().get_texture().get_image()
			img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
			img.save_png("%s/%s_%d.png" % [dir, ending, int(t)])
			scene.queue_free()
			await get_tree().process_frame
	print("Capturas en ", dir)
