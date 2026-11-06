## Ver el GLOBO del Modo Historia en vivo, sin combatir: eliges villano, viaja la nave, y al llegar da el combate por
## ganado y vuelve a mostrar el globo para que elijas al siguiente (así se recorren todas las épocas).
##   godot --path . res://tests/GlobePreview.tscn -- [--player=napoleon] [--beaten=N]
## ← → elige · ENTER ataca / salta la animación · ESC cierra.   --beaten=N empieza con los N primeros ya vencidos.
extends Node

var _globe: StoryGlobeMap

func _ready() -> void:
	Backend.story_path = "user://story_preview.cfg"
	var player := &"napoleon"
	var beaten := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player="):
			player = StringName(arg.trim_prefix("--player="))
		elif arg.begins_with("--beaten="):
			beaten = int(arg.trim_prefix("--beaten="))
	Game.start_story(player)
	for i in beaten:
		Game.story_beaten[i] = true
	Game.story_last_won = beaten - 1
	Game.arcade_stage = Game.story_default_pick()
	Game.p2_fighter_id = Game.arcade_ladder[Game.arcade_stage]
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_next()

func _next() -> void:
	_globe = StoryGlobeMap.new()
	add_child(_globe)
	_globe.cancelled.connect(func(): get_tree().quit())
	_globe.finished.connect(func():
		# Da por ganado ese combate (y el creador poseído, si entra) y muestra el globo otra vez.
		Game.arcade_advance()
		if Game.story_is_creator(Game.arcade_stage):
			Game.arcade_advance()
		_next())
