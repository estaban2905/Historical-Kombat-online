## Autoload "Music": música de fondo según la escena actual.
## Selección de partida -> select.ogg; combate -> fight.ogg; el resto de escenas, sin música
## (la intro y la historia llevan la suya). Cambia con un fundido corto; el bucle no se reinicia
## si la pista ya suena (p. ej. al repetir combate).
extends Node

const TRACKS := {
	"res://scenes/CharacterSelect.tscn": "res://assets/music/select.ogg",
	"res://scenes/Fight.tscn": "res://assets/music/fight.ogg",
}
const VOLUME_DB := -10.0
const FADE_DB_PER_SEC := 60.0

var _player: AudioStreamPlayer
var _streams: Dictionary = {}
var _current: String = ""   # pista que suena o debe sonar
var _target: String = ""    # pista deseada por la escena actual

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = -80.0
	add_child(_player)

func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	_target = TRACKS.get(scene.scene_file_path, "") if scene else ""
	if _target != _current:
		# Baja el volumen y, al silenciar, cambia de pista.
		_player.volume_db = move_toward(_player.volume_db, -80.0, FADE_DB_PER_SEC * delta)
		if _player.volume_db <= -79.0:
			_switch(_target)
	elif _current != "":
		_player.volume_db = move_toward(_player.volume_db, VOLUME_DB, FADE_DB_PER_SEC * 0.5 * delta)

func _switch(path: String) -> void:
	_current = path
	_player.stop()
	if path == "":
		return
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		stream = load(path) as AudioStream
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_streams[path] = stream
	if stream:
		_player.stream = stream
		_player.play()
