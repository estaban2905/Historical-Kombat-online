## Ranking de jugadores: los mejores por puntos. Tu fila sale resaltada.
## ESC o VOLVER regresa al menú.
extends Control

const ROWS := 10

var _players: Array = []
var _loading: bool = true
var _back: Button

func _ready() -> void:
	theme = HKTheme.theme()
	_back = Button.new()
	_back.text = "VOLVER"
	_back.position = Vector2(163, 212)
	_back.custom_minimum_size = Vector2(100, 14)
	add_child(_back)
	_back.size = Vector2(100, 14)   # tras añadirlo: ya tiene el tema (ver profile.gd)
	_back.pressed.connect(func(): Game.goto(Game.SCENE_MENU))
	_back.focus_entered.connect(func(): Sfx.play(&"select"))
	_back.pressed.connect(func(): Sfx.play(&"confirm"))
	_back.grab_focus()
	_players = await Backend.fetch_ranking(ROWS)
	_loading = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Game.goto(Game.SCENE_MENU)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 240), HKTheme.INK)
	HKTheme.draw_text(self, Vector2(0, 24), "RANKING", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	if _loading:
		HKTheme.draw_text(self, Vector2(0, 110), "CARGANDO...", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	if _players.is_empty():
		HKTheme.draw_text(self, Vector2(0, 110), "TODAVÍA NO HAY JUGADORES", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	HKTheme.draw_text(self, Vector2(60, 46), "#", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(90, 46), "JUGADOR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(230, 46), "PUNTOS", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(310, 46), "V / D", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var me := Backend.username().to_lower() if Backend.is_logged_in() else ""
	var y := 62.0
	for i in _players.size():
		var p: Dictionary = _players[i]
		var mine := str(p.get("username", "")).to_lower() == me
		var color := HKTheme.GOLD if mine else (HKTheme.PAPER if i > 2 else Color("f0d890"))
		if mine:
			draw_rect(Rect2(52, y - 9, 322, 12), Color(1, 1, 1, 0.08))
		HKTheme.draw_text(self, Vector2(60, y), str(i + 1), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		HKTheme.draw_text(self, Vector2(90, y), str(p.get("username", "")).to_upper().left(16), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		HKTheme.draw_text(self, Vector2(230, y), str(int(p.get("points", 0))), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		HKTheme.draw_text(self, Vector2(310, y), "%d / %d" % [int(p.get("wins", 0)), int(p.get("losses", 0))], 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		y += 13.0
