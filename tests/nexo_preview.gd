## Atajo para ver el combate final del Modo Historia (el Nexo) sin pasar por los demás.
## Ejecutar la escena tests/NexoPreview.tscn (F6 en el editor) o:
##   godot --path . res://tests/NexoPreview.tscn -- [--player=napoleon] [--stage=N]
## --stage=N salta al combate N de la escalera (por defecto el último: el Nexo).
extends Node

const DEFAULT_PLAYER := &"napoleon"

func _ready() -> void:
	var player := DEFAULT_PLAYER
	var stage := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player="):
			player = StringName(arg.trim_prefix("--player="))
		elif arg.begins_with("--stage="):
			stage = int(arg.trim_prefix("--stage="))
	Game.start_story(player)
	Game.arcade_stage = Game.arcade_ladder.size() - 1 if stage < 0 else clampi(stage, 0, Game.arcade_ladder.size() - 1)
	Game.p2_fighter_id = Game.arcade_ladder[Game.arcade_stage]
	Game.goto(Game.SCENE_FIGHT)
