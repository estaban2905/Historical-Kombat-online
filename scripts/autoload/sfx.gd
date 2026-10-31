## Autoload "Sfx": efectos de sonido con un pequeño grupo de reproductores
## para que varios sonidos puedan sonar a la vez.
## Uso: Sfx.play(&"hit_heavy")
extends Node

const SOUNDS := {
	&"hit_light": "res://assets/sounds/hit_light.wav",
	&"hit_heavy": "res://assets/sounds/hit_heavy.wav",
	&"block": "res://assets/sounds/block.wav",
	&"whoosh": "res://assets/sounds/whoosh.wav",
	&"ko": "res://assets/sounds/ko.wav",
	&"select": "res://assets/sounds/select.wav",
	&"confirm": "res://assets/sounds/confirm.wav",
	&"denied": "res://assets/sounds/denied.wav",
	&"round": "res://assets/sounds/round.wav",
	&"fight": "res://assets/sounds/fight.wav",
	&"cannon": "res://assets/sounds/cannon.wav",
	&"megaphone": "res://assets/sounds/megaphone.wav",
}
const POOL_SIZE := 8

var volume_db: float = -6.0
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS:
		var stream := load(SOUNDS[key]) as AudioStream
		if stream:
			_streams[key] = stream
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func play(sound: StringName, pitch_variation: float = 0.0) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	p.play()
