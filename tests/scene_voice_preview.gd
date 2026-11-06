## Prueba de la escena de diálogo CON VOZ: el combate contra Einstein, con las voces de Einstein y del Nexo
## (assets/sounds/story/scenes/albert_einstein_N.wav) y la grieta en la realidad cuando habla el Nexo.
##   godot --path . res://tests/SceneVoicePreview.tscn -- [--player=napoleon] [--scene=albert_einstein]
## Las frases avanzan solas al acabar la voz; cualquier tecla pasa a la siguiente y ESC salta la escena.
extends Node

func _ready() -> void:
	# Las vistas previas no guardan en la partida real del jugador.
	Backend.story_path = "user://story_preview.cfg"
	var player := &"napoleon"
	var rival := &"albert_einstein"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player="):
			player = StringName(arg.trim_prefix("--player="))
		elif arg.begins_with("--scene="):
			rival = StringName(arg.trim_prefix("--scene="))
	Game.start_story(player)
	var idx := Game.arcade_ladder.find(rival)
	if idx < 0:
		push_error("El rival %s no está en la escalera de %s" % [rival, player])
		get_tree().quit()
		return
	Game.arcade_stage = idx
	Game.p2_fighter_id = rival
	add_child((load(Game.SCENE_STORY) as PackedScene).instantiate())
