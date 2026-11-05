## Estilo visual común de la interfaz (fuente pixel y tema de botones).
## Fuente: "Silkscreen" (SIL Open Font License, ver assets/fonts): pixel, más estrecha y nítida que Press Start 2P.
class_name HKTheme
extends RefCounted

const FONT_PATH := "res://assets/fonts/Silkscreen-Regular.ttf"

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
		_font = _plain_capitals(load(FONT_PATH) as FontFile)
		if _font:
			_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			_font.hinting = TextServer.HINTING_NONE
			_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			_font.generate_mipmaps = false
	return _font

## Mayúsculas acentuadas → la misma letra sin tilde (como fold, pero para todo texto: botones, Labels, errores
## del servidor, lo que escribe el jugador).
const PLAIN_CAPITALS := {"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ü": "U"}

## Press Start 2P dibuja Á, É, Í, Ó y Ú encogiendo la letra para que quepa la tilde y parecen minúsculas ("MENú").
## Aquí, en memoria, esas letras pasan a usar el glifo de la letra sin tilde (tabla cmap). El archivo de la fuente
## no se toca. Si la tabla no es como se espera, se devuelve la fuente tal cual.
static func _plain_capitals(src: FontFile) -> FontFile:
	if src == null or src.data.is_empty():
		return src
	var bytes := src.data.duplicate()
	if not _remap_cmap(bytes, PLAIN_CAPITALS):
		return src
	var f := FontFile.new()
	f.data = bytes
	f.allow_system_fallback = src.allow_system_fallback
	return f

## Cambia en la subtabla cmap de formato 4 el glifo de cada carácter de `pairs` por el de su pareja. Solo si el
## carácter va por glyphIdArray (cambiar 2 bytes, sin mover nada). true si cambió todos.
static func _remap_cmap(b: PackedByteArray, pairs: Dictionary) -> bool:
	var u16 := func(i: int) -> int: return (b[i] << 8) | b[i + 1]
	var u32 := func(i: int) -> int: return (u16.call(i) << 16) | u16.call(i + 2)
	var cmap := -1
	for t in u16.call(4):
		var rec: int = 12 + 16 * t
		if b.slice(rec, rec + 4).get_string_from_ascii() == "cmap":
			cmap = u32.call(rec + 8)
	if cmap < 0:
		return false
	for s in u16.call(cmap + 2):
		var p: int = cmap + u32.call(cmap + 4 + 8 * s + 4)
		if u16.call(p) != 4:
			continue
		var seg_x2: int = u16.call(p + 6)
		var ends := p + 14
		var starts := ends + seg_x2 + 2
		var deltas := starts + seg_x2
		var offsets := deltas + seg_x2
		# Segmento de un carácter: [dirección de su entrada en glyphIdArray (-1 si no tiene), delta, glifo].
		var lookup := func(c: int) -> Array:
			for k in seg_x2 / 2:
				if u16.call(starts + 2 * k) <= c and c <= u16.call(ends + 2 * k):
					var delta: int = u16.call(deltas + 2 * k)
					var ro: int = u16.call(offsets + 2 * k)
					if ro == 0:
						return [-1, delta, (c + delta) & 0xFFFF]
					var at: int = offsets + 2 * k + ro + 2 * (c - u16.call(starts + 2 * k))
					var g: int = u16.call(at)
					return [at, delta, (g + delta) & 0xFFFF if g != 0 else 0]
			return [-1, 0, 0]
		var ok := true
		for accented in pairs:
			var target: Array = lookup.call(String(accented).unicode_at(0))
			var plain: Array = lookup.call(String(pairs[accented]).unicode_at(0))
			if target[0] < 0 or plain[2] == 0:
				ok = false
				continue
			var g: int = (plain[2] - target[1]) & 0xFFFF
			b[target[0]] = g >> 8
			b[target[0] + 1] = g & 0xFF
		return ok
	return false

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
	# El ratón mueve el foco (ver Game._on_node_added): hover igual que normal, así nunca hay dos botones resaltados.
	t.set_stylebox("hover", "Button", _box(Color(0.12, 0.06, 0.1, 0.85), Color("4a2a30")))
	t.set_stylebox("focus", "Button", _box(Color(0.45, 0.1, 0.1, 0.95), GOLD))
	t.set_stylebox("pressed", "Button", _box(Color(0.6, 0.15, 0.1, 1), PAPER))
	t.set_stylebox("disabled", "Button", _box(Color(0.08, 0.06, 0.08, 0.7), Color("2a2026")))
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", PAPER)
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
## Las minúsculas acentuadas sí las tiene y se dejan ("televisión", no "televisiOn").
static func fold(text: String) -> String:
	for pair in [["Á", "A"], ["É", "E"], ["Í", "I"], ["Ó", "O"], ["Ú", "U"], ["Ü", "U"]]:
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
