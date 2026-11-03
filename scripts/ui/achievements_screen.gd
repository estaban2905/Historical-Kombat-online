## Logros: cada uno con su nombre, qué hay que hacer y cuánto llevas. Los cumplidos salen en dorado.
## El progreso lo calcula el servidor; al verlos se entregan los títulos que dan (Cosmetics).
## ESC o VOLVER regresa al perfil.
extends Control

const FIRST_ROW_Y := 56.0
const ROW_STEP := 13.0

var _rows: Array = []
var _loading: bool = true
var _failed: bool = false
var _back: Button

func _ready() -> void:
	theme = HKTheme.theme()
	if not Backend.is_logged_in():
		Game.goto.call_deferred(Game.SCENE_MENU)
		return
	_back = Button.new()
	_back.text = "VOLVER"
	_back.position = Vector2(163, 212)
	_back.custom_minimum_size = Vector2(100, 14)
	add_child(_back)
	_back.size = Vector2(100, 14)   # tras añadirlo: ya tiene el tema (ver profile.gd)
	_back.pressed.connect(func(): Game.goto(Game.SCENE_PROFILE))
	_back.focus_entered.connect(func(): Sfx.play(&"select"))
	_back.pressed.connect(func(): Sfx.play(&"confirm"))
	_back.grab_focus()
	var server: Variant = await Backend.fetch_achievements()
	_failed = server == null
	_rows = Achievements.merge([] if _failed else server)
	if not _failed:
		Cosmetics.grant_achievements(server)
	_loading = false
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Game.goto(Game.SCENE_PROFILE)
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 240), HKTheme.INK)
	if not Backend.is_logged_in():
		return
	HKTheme.draw_text(self, Vector2(0, 24), "LOGROS", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	if _loading:
		HKTheme.draw_text(self, Vector2(0, 120), "CARGANDO...", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	if _failed:
		HKTheme.draw_text(self, Vector2(0, 120), "NO SE PUDIERON CARGAR LOS LOGROS", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	HKTheme.draw_text(self, Vector2(0, 42), "%d / %d CUMPLIDOS" % [Achievements.done_count(_rows), _rows.size()], 8,
		HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	var y := FIRST_ROW_Y
	for a in _rows:
		_draw_row(a, y)
		y += ROW_STEP

func _draw_row(a: Dictionary, y: float) -> void:
	var done: bool = a["done"]
	var color := HKTheme.GOLD if done else HKTheme.MUTED
	draw_rect(Rect2(36, y - 7, 6, 6), color if done else Color(1, 1, 1, 0.12))
	HKTheme.draw_text(self, Vector2(48, y), a["name"], 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(190, y), a["desc"], 8, HKTheme.PAPER if done else HKTheme.MUTED.darkened(0.2), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var progress := "LISTO" if done else "%d/%d" % [a["progress"], a["goal"]]
	HKTheme.draw_text(self, Vector2(0, y), progress, 8, color, HORIZONTAL_ALIGNMENT_RIGHT, 392, 1)
