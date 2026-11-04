## Escena de diálogo del MODO HISTORIA: un panel oscuro abajo con el retrato de quien habla
## (o la esfera del Nexo) y su frase, que se escribe sola. Cualquier tecla o clic la completa y
## pasa a la siguiente; ESC salta toda la escena. `lines` = [[id, texto], ...] se asigna antes de
## añadirla al árbol. `finished` se emite al acabar.
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

var _i: int = 0
var _t: float = 0.0
var _done: bool = false
var _portrait: FighterRenderer
var _portrait_id: StringName = &""
var _wrapped: PackedStringArray = PackedStringArray()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lines.is_empty():
		_finish()
		return
	_show_line()

func _show_line() -> void:
	_t = 0.0
	var who: StringName = lines[_i][0]
	_wrapped = _wrap(str(lines[_i][1]), TEXT_W)
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
			_portrait.scale = Vector2(s, s)
			_portrait.position = Vector2(52.0, PANEL_Y + 62.0)

func _total_chars() -> int:
	var n := 0
	for l in _wrapped:
		n += l.length()
	return n

func _typed() -> int:
	return int(_t * CPS)

func _advance() -> void:
	if _typed() < _total_chars():
		_t = float(_total_chars()) / CPS   # completa la frase
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
	if event.is_action_pressed(&"ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		_advance()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_t += delta
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

func _draw() -> void:
	if _done or lines.is_empty():
		return
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.0, 0.04, 0.55))
	draw_rect(Rect2(0, PANEL_Y, W, H - PANEL_Y), Color(0.03, 0.01, 0.06, 0.92))
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
	HKTheme.draw_text(self, Vector2(TEXT_X, PANEL_Y + 16.0), name_text, 8, NEXO_GOLD if nexo else HKTheme.GOLD,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var left := _typed()
	for k in _wrapped.size():
		if left <= 0:
			break
		var shown := _wrapped[k].substr(0, mini(left, _wrapped[k].length()))
		left -= _wrapped[k].length()
		HKTheme.draw_text(self, Vector2(TEXT_X, PANEL_Y + 32.0 + k * 12.0), shown, 8, HKTheme.PAPER,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	if _typed() >= _total_chars() and int(_t * 2.0) % 2 == 0:
		HKTheme.draw_text(self, Vector2(0, H - 8.0), ">", 8, NEXO_GOLD, HORIZONTAL_ALIGNMENT_RIGHT, W - 8.0, 0)
	HKTheme.draw_text(self, Vector2(8, H - 8.0), "ESC: SALTAR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
