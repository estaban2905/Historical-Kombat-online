## Estilo visual común de la interfaz (fuente pixel y tema de botones).
## Fuente: "Press Start 2P" (SIL Open Font License, ver assets/fonts).
class_name HKTheme
extends RefCounted

const FONT_PATH := "res://assets/fonts/PressStart2P-Regular.ttf"

const GOLD := Color("f0c040")
const GOLD_DARK := Color("a06818")
const BLOOD := Color("c02028")
const INK := Color("120a14")
const PAPER := Color("f4ead0")
const MUTED := Color("8a7a70")
const PANEL := Color(0.07, 0.04, 0.09, 0.92)

static var _font: FontFile
static var _theme: Theme

## Fuente pixel sin suavizado (nítida a 426x240).
static func font() -> Font:
	if _font == null:
		_font = load(FONT_PATH) as FontFile
		if _font:
			_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			_font.hinting = TextServer.HINTING_NONE
			_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			_font.generate_mipmaps = false
	return _font

static func _box(bg: Color, border: Color, border_w: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_content_margin_all(3)
	sb.anti_aliasing = false
	return sb

## Tema para menús: botones con borde dorado al tener el foco.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 8
	t.set_stylebox("normal", "Button", _box(Color(0.12, 0.06, 0.1, 0.85), Color("4a2a30")))
	t.set_stylebox("hover", "Button", _box(Color(0.35, 0.08, 0.1, 0.95), GOLD))
	t.set_stylebox("focus", "Button", _box(Color(0.45, 0.1, 0.1, 0.95), GOLD))
	t.set_stylebox("pressed", "Button", _box(Color(0.6, 0.15, 0.1, 1), PAPER))
	t.set_stylebox("disabled", "Button", _box(Color(0.08, 0.06, 0.08, 0.7), Color("2a2026")))
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("5a4e50"))
	t.set_color("font_color", "Label", PAPER)
	t.set_color("font_outline_color", "Label", INK)
	t.set_constant("outline_size", "Label", 0)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, GOLD_DARK, 1))
	t.set_stylebox("normal", "LineEdit", _box(Color(0.05, 0.03, 0.06, 0.95), Color("4a2a30")))
	t.set_stylebox("focus", "LineEdit", _box(Color(0.1, 0.05, 0.08, 0.98), GOLD))
	t.set_stylebox("read_only", "LineEdit", _box(Color(0.08, 0.06, 0.08, 0.7), Color("2a2026")))
	t.set_color("font_color", "LineEdit", PAPER)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", GOLD_DARK)
	_theme = t
	return t

## Dibuja texto con contorno de 1 px (para HUD y títulos dibujados a mano).
## La fuente no tiene mayúsculas acentuadas (Ó se dibuja como una "ó" pequeña): se quita el acento.
static func fold(text: String) -> String:
	for pair in [["Á", "A"], ["É", "E"], ["Í", "I"], ["Ó", "O"], ["Ú", "U"], ["Ü", "U"],
			["á", "A"], ["é", "E"], ["í", "I"], ["ó", "O"], ["ú", "U"], ["ü", "U"]]:
		text = text.replace(pair[0], pair[1])
	return text

static func draw_text(ci: CanvasItem, pos: Vector2, text: String, size: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, outline: int = 2) -> void:
	var f := font()
	if f == null:
		return
	text = fold(text)
	if outline > 0:
		ci.draw_string_outline(f, pos.round(), text, align, width, size, outline, INK)
	ci.draw_string(f, pos.round(), text, align, width, size, color)

static func text_width(text: String, size: int) -> float:
	var f := font()
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if f else 0.0

static func clear_cache() -> void:
	_font = null
	_theme = null
