## Pantalla CRÉDITOS: texto que sube sobre el fondo animado del menú, como en un arcade.
##   ↓ / ESPACIO / ENTER acelera · ↑ retrocede · ESC o cualquier botón de ataque vuelve.
## El texto se arma en _build(); los nombres de los luchadores salen del registro, así que
## al añadir un personaje nuevo aparece solo.
extends Control

enum K { TITLE, SUB, HEAD, TEXT, MUTED, GAP, NAMES, END }

const SPEED := 20.0
const FAST := 4.0
const ROW_H := 11.0
const VIEW_W := 426.0
const VIEW_H := 240.0
const FADE_H := 34.0
const COL_W := 190.0

var _rows: Array = []         # [tipo, texto o lista]
var _height: float = 0.0
var _scroll: float = -VIEW_H  # empieza con el texto fuera de pantalla, por debajo
var _end_scroll: float = 0.0
var _btn_back: Button

func _ready() -> void:
	theme = HKTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	bg.show_title = false
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)
	_build()
	_btn_back = Button.new()
	_btn_back.text = "VOLVER"
	_btn_back.position = Vector2(176, 222)
	_btn_back.custom_minimum_size = Vector2(74, 16)
	_btn_back.pressed.connect(_close)
	_btn_back.focus_entered.connect(func(): Sfx.play(&"select"))
	add_child(_btn_back)
	_btn_back.grab_focus()

func _build() -> void:
	_rows = [
		[K.TITLE, "HISTORY COMBAT"],
		[K.SUB, "EL TORNEO DE LOS SIGLOS"],
		[K.MUTED, "VERSIÓN %s" % Game.VERSION],
		[K.GAP, 2],
		[K.HEAD, "EL JUEGO"],
		[K.TEXT, "UN JUEGO DE LUCHA 2D DONDE"],
		[K.TEXT, "LOS PERSONAJES DE LA HISTORIA"],
		[K.TEXT, "SE ENFRENTAN EN UN TORNEO"],
		[K.TEXT, "IMPOSIBLE ENTRE ÉPOCAS."],
		[K.GAP, 2],
		[K.HEAD, "MODOS"],
		[K.TEXT, "HISTORIA · VERSUS · ENTRENAMIENTO"],
		[K.TEXT, "DUELO ONLINE CON RANKING"],
		[K.GAP, 2],
		[K.HEAD, "LUCHADORES"],
		[K.NAMES, _fighter_names()],
		[K.GAP, 2],
		[K.HEAD, "ARTE Y SONIDO"],
		[K.TEXT, "GRÁFICOS Y SONIDOS ORIGINALES,"],
		[K.TEXT, "GENERADOS POR CÓDIGO"],
		[K.MUTED, "(PROVISIONALES)"],
		[K.GAP, 2],
		[K.HEAD, "TECNOLOGÍA"],
		[K.TEXT, "MOTOR: GODOT 4"],
		[K.TEXT, "SERVIDOR: NODE.JS Y POSTGRES"],
		[K.TEXT, "COMBATE ONLINE POR LOCKSTEP"],
		[K.GAP, 2],
		[K.HEAD, "FUENTE"],
		[K.TEXT, "PRESS START 2P"],
		[K.MUTED, "CODEMAN38 · SIL OPEN FONT LICENSE"],
		[K.GAP, 2],
		[K.HEAD, "AVISO"],
		[K.TEXT, "PARODIA DE FICCIÓN."],
		[K.TEXT, "NINGÚN PERSONAJE REAL"],
		[K.TEXT, "PARTICIPÓ EN EL TORNEO."],
		[K.TEXT, "NADA DE LO QUE SE VE AQUÍ"],
		[K.TEXT, "GLORIFICA A NADIE."],
		[K.GAP, 3],
		[K.END, "¡GRACIAS POR JUGAR!"],
	]
	_height = 0.0
	for r in _rows:
		_height += _row_height(r)
	# Se detiene cuando el último renglón queda a media pantalla.
	_end_scroll = _height - VIEW_H * 0.5 - 8.0

func _fighter_names() -> Array:
	var names := []
	for d in FighterRegistry.all():
		names.append(d.short_name.to_upper())
	return names

func _row_height(r: Array) -> float:
	match r[0]:
		K.TITLE: return 24.0
		K.SUB: return 16.0
		K.HEAD: return ROW_H + 8.0
		K.GAP: return ROW_H * float(r[1])
		K.NAMES: return ceilf(float((r[1] as Array).size()) / 2.0) * ROW_H
		K.END: return 20.0
	return ROW_H

func _close() -> void:
	Sfx.play(&"confirm")
	Game.goto(Game.SCENE_MENU)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not Game.is_changing_scene():
		_close()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var dir := 1.0
	if Input.is_key_pressed(KEY_UP):
		dir = -FAST
	elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_SPACE):
		dir = FAST
	_scroll = clampf(_scroll + SPEED * dir * delta, -VIEW_H, _end_scroll)
	queue_redraw()

# =========================================================================
#  Dibujo
# =========================================================================
func _draw() -> void:
	var y := -_scroll
	for r in _rows:
		var h := _row_height(r)
		# Solo se dibuja lo que está en pantalla.
		if y + h >= 0.0 and y <= VIEW_H:
			_draw_row(r, y)
		y += h
	# Degradado arriba y abajo: el texto aparece y desaparece suavemente.
	for i in int(FADE_H):
		var a := 0.9 * (1.0 - float(i) / FADE_H)
		draw_rect(Rect2(0, i, VIEW_W, 1), Color(0.07, 0.03, 0.09, a))
		draw_rect(Rect2(0, VIEW_H - 1 - i, VIEW_W, 1), Color(0.07, 0.03, 0.09, a))
	if _scroll >= _end_scroll:
		HKTheme.draw_text(self, Vector2(0, 216), "ESC: VOLVER", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 1)

func _draw_row(r: Array, y: float) -> void:
	match r[0]:
		K.TITLE:
			HKTheme.draw_text(self, Vector2(0, y + 16), r[1], 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 3)
		K.SUB:
			HKTheme.draw_text(self, Vector2(0, y + 9), r[1], 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 2)
		K.HEAD:
			var w := HKTheme.text_width(r[1], 8)
			var cx := VIEW_W * 0.5
			HKTheme.draw_text(self, Vector2(0, y + 15), r[1], 8, Color("5aa0ff"), HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 2)
			draw_rect(Rect2(cx - w * 0.5 - 14, y + 11, 8, 1), HKTheme.GOLD_DARK)
			draw_rect(Rect2(cx + w * 0.5 + 6, y + 11, 8, 1), HKTheme.GOLD_DARK)
		K.TEXT:
			HKTheme.draw_text(self, Vector2(0, y + 9), r[1], 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 2)
		K.MUTED:
			HKTheme.draw_text(self, Vector2(0, y + 9), r[1], 8, HKTheme.MUTED.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 2)
		K.NAMES:
			var names: Array = r[1]
			var rows := ceili(names.size() / 2.0)
			for i in names.size():
				var col := i / rows
				var x := VIEW_W * 0.5 - COL_W + col * COL_W
				HKTheme.draw_text(self, Vector2(x, y + (i % rows) * ROW_H + 9), names[i], 8, HKTheme.PAPER,
					HORIZONTAL_ALIGNMENT_CENTER, COL_W, 2)
		K.END:
			var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 250.0)
			HKTheme.draw_text(self, Vector2(0, y + 14), r[1], 8, HKTheme.GOLD * Color(pulse, pulse, pulse, 1.0), HORIZONTAL_ALIGNMENT_CENTER, VIEW_W, 2)
