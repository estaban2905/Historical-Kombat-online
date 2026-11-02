## Reproduce las animaciones de arranque de época del Modo Historia, con voz y música.
##   godot --path . res://tests/EraPreview.tscn -- [--era=N]
## Sin argumentos pasa las seis seguidas (I a V y el Nexo). Con --era=N (0-5) repite solo esa.
## Cualquier tecla salta a la siguiente; ESC cierra.
extends Node

var _only: int = -1
var _next: int = 0
var _current: StoryEraIntro

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--era="):
			_only = int(arg.trim_prefix("--era="))
	_play(maxi(_only, 0))

func _play(idx: int) -> void:
	_next = idx + 1
	_current = StoryEraIntro.new()
	_current.chapter = idx
	add_child(_current)
	_current.finished.connect(_on_finished)

func _on_finished() -> void:
	_current = null
	if _only >= 0:
		_play(_only)   # repite la misma
	elif _next < StoryEraIntro.ERAS.size():
		_play(_next)
	else:
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif _current:
			_current.skip()
