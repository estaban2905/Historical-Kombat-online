## Escena de diálogo del MODO HISTORIA: un panel oscuro abajo con el retrato de quien habla
## (o la esfera del Nexo) y su frase, que se escribe sola. Enter la completa y
## pasa a la siguiente (solo Enter: ESC y el ratón no la saltan). `lines` = [[id, texto], ...] se asigna antes de
## añadirla al árbol. `finished` se emite al acabar.
## Si existe assets/sounds/story/scenes/<scene_id>_<n>.wav (tools/gen_scene_voice.py), cada frase suena con
## la voz de quien habla: el texto se escribe al ritmo de la voz y la escena avanza sola al acabar.
## Cuando habla el Nexo, la realidad se rompe: una grieta cruza la pantalla y su esfera emerge de ella.
class_name StoryDialogue
extends Control

signal finished

const W := 426.0
const H := 240.0
const PANEL_Y := 160.0
const TEXT_X := 104.0
const TEXT_W := 306.0
const CPS := 45.0
const NEXO_GOLD := Color("ffd24a")
const VIOLET := Color("9a4dff")

var lines: Array = []
## Id de la escena, para buscar sus voces (el id del rival).
var scene_id: StringName = &""

var _i: int = 0
var _t: float = 0.0
var _done: bool = false
var _portrait: FighterRenderer
var _portrait_id: StringName = &""
## Quien habla está a la derecha (el villano y los creadores); el jugador y el Nexo, a la izquierda.
var _right: bool = false
var _wrapped: PackedStringArray = PackedStringArray()
var _voice: AudioStreamPlayer
var _has_voice: bool = false
var _cps: float = CPS
## Cuánto está abierta la grieta del Nexo (0 cerrada, 1 abierta) y desde cuándo habla.
var _breach: float = 0.0
var _after_voice: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lines.is_empty():
		_finish()
		return
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = 2.0
	add_child(_voice)
	_show_line()

func _show_line() -> void:
	_t = 0.0
	_after_voice = 0.0
	var who: StringName = lines[_i][0]
	_right = who != StoryScenes.NEXO and who != Game.p1_fighter_id
	_wrapped = _wrap(str(lines[_i][1]), TEXT_W)
	_voice.stop()
	_has_voice = false
	_cps = CPS
	var path := "res://assets/sounds/story/scenes/%s_%d.wav" % [scene_id, _i + 1]
	var own_voice: bool = lines[_i].size() > 2   # la línea trae su propia voz (el luchador del jugador)
	if own_voice:
		path = str(lines[_i][2])
	if (scene_id != &"" or own_voice) and ResourceLoader.exists(path):
		_voice.stream = load(path) as AudioStream
		_has_voice = true
		# El texto termina un poco antes que la voz.
		_cps = maxf(float(_total_chars()) / maxf(_voice.stream.get_length() * 0.85, 0.5), 8.0)
		_voice.play()
	if who != _portrait_id:
		_portrait_id = who
		if _portrait:
			_portrait.queue_free()
			_portrait = null
		if who != StoryScenes.NEXO:
			_portrait = FighterRenderer.new()
			add_child(_portrait)
			_portrait.setup(FighterRegistry.get_by_id(who))
			_portrait.pose_name = &"idle"
			var s := clampf(110.0 / maxf(_portrait.approx_height(), 1.0), 0.8, 1.6)
			# A la derecha mira hacia la izquierda (hacia el jugador).
			_portrait.scale = Vector2(-s if _right else s, s)
			_portrait.position = Vector2(W - 52.0 if _right else 52.0, PANEL_Y + 62.0)

## Dónde empieza el texto: junto al retrato de quien habla.
func _text_x() -> float:
	return 16.0 if _right else TEXT_X

func _total_chars() -> int:
	var n := 0
	for l in _wrapped:
		n += l.length()
	return n

func _typed() -> int:
	return int(_t * _cps)

func _advance() -> void:
	if _typed() < _total_chars():
		_t = float(_total_chars()) / _cps   # completa la frase
		return
	_i += 1
	if _i >= lines.size():
		_finish()
	else:
		_show_line()

func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if HKTheme.is_enter(event):
		_advance()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_t += delta
	# La grieta se abre mientras habla el Nexo y se cierra cuando habla otro.
	var nexo: bool = not lines.is_empty() and not _done and lines[_i][0] == StoryScenes.NEXO
	_breach = move_toward(_breach, 1.0 if nexo else 0.0, delta * (2.2 if nexo else 1.6))
	# Con voz, la escena avanza sola poco después de que acabe de hablar.
	if _has_voice and not _done and not _voice.playing and _t > 0.3:
		_after_voice += delta
		if _after_voice >= 0.7:
			_advance()
	queue_redraw()

func _wrap(text: String, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var test: String = word if line.is_empty() else line + " " + word
		if HKTheme.text_width(test, 8) > width and not line.is_empty():
			out.append(line)
			line = word
		else:
			line = test
	if not line.is_empty():
		out.append(line)
	return out

## Grieta en la realidad: una raja violeta y dorada que baja desde arriba y, de ella, la esfera del Nexo.
func _draw_breach() -> void:
	if _breach <= 0.01:
		return
	var open := _breach * _breach * (3.0 - 2.0 * _breach)
	var cx := 300.0
	var now := Time.get_ticks_msec() * 0.001
	var pts := PackedVector2Array()
	for i in 15:
		var k := float(i) / 14.0
		var jitter := (fposmod(sin((4.0 + i * 1.7) * 12.9898) * 43758.5453, 1.0) - 0.5) * 26.0 * (0.4 + k)
		pts.append(Vector2(cx + jitter, (PANEL_Y + 2.0) * k * open))
	var wob := 0.7 + 0.3 * sin(now * 9.0)
	draw_polyline(pts, Color(VIOLET, 0.25 * wob * open), 18.0)
	draw_polyline(pts, Color(VIOLET, 0.6 * open), 8.0)
	draw_polyline(pts, Color(NEXO_GOLD, open), 4.0)
	draw_polyline(pts, Color("02000a"), 2.0)
	# La esfera crece en el centro de la grieta y late al hablar.
	var c := Vector2(cx, 62.0 + sin(now * 1.1) * 2.0)
	var r := 24.0 * open * (1.0 + 0.06 * sin(now * 6.0))
	for k in 5:
		draw_circle(c, r * (2.4 - k * 0.35), Color(NEXO_GOLD, 0.05 + 0.02 * k))
	draw_circle(c, r + 3.0, Color(VIOLET, 0.7))
	draw_circle(c, r, NEXO_GOLD)
	draw_circle(c, r * 0.72, Color("fff0a0"))
	draw_circle(c, r * 0.38, Color.WHITE)
	for k in 3:
		var a0 := now * (1.2 + k * 0.5) + k * 2.1
		draw_arc(c, r * (1.25 + k * 0.18), a0, a0 + 2.2, 24, [Color("35e6ff"), VIOLET, Color("35e6ff")][k] as Color, 2.0)
	# Destello al abrirse.
	if _breach < 0.5 and _breach > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 0.9, 0.25 * (0.5 - _breach) * 2.0))

func _draw() -> void:
	if _done or lines.is_empty():
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.0, 0.04, 0.55))
	_draw_breach()
	draw_rect(Rect2(0, PANEL_Y, W, H - PANEL_Y), Color(0.03, 0.01, 0.06, 1.0))
	draw_rect(Rect2(0, PANEL_Y, W, 2), NEXO_GOLD)
	var who: StringName = lines[_i][0]
	var nexo := who == StoryScenes.NEXO
	var name_text := "EL NEXO" if nexo else FighterRegistry.get_by_id(who).short_name.to_upper()
	if nexo:
		var c := Vector2(52.0, PANEL_Y + 38.0)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		for k in 4:
			draw_circle(c, 14.0 + k * 9.0 + pulse * 2.0, Color(NEXO_GOLD, 0.06))
		draw_circle(c, 17.0, Color(VIOLET, 0.7))
		draw_circle(c, 14.0, NEXO_GOLD)
		draw_circle(c, 6.0, Color.WHITE)
	HKTheme.draw_text(self, Vector2(_text_x(), PANEL_Y + 16.0), name_text, 8, NEXO_GOLD if nexo else HKTheme.GOLD,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var left := _typed()
	for k in _wrapped.size():
		if left <= 0:
			break
		var shown := _wrapped[k].substr(0, mini(left, _wrapped[k].length()))
		left -= _wrapped[k].length()
		HKTheme.draw_text(self, Vector2(_text_x(), PANEL_Y + 32.0 + k * 12.0), shown, 8, HKTheme.PAPER,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	if _typed() >= _total_chars() and int(_t * 2.0) % 2 == 0:
		HKTheme.draw_text(self, Vector2(0, H - 8.0), ">", 8, NEXO_GOLD, HORIZONTAL_ALIGNMENT_RIGHT, W - 8.0, 0)
	HKTheme.draw_text(self, Vector2(8, H - 8.0), "ENTER: CONTINUAR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
