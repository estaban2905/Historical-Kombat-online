## Ranking de jugadores: los mejores por puntos. Tu fila sale resaltada.
## ESC o VOLVER regresa al menú.
extends Control

const ROWS := 10
## Cuántos jugadores se piden: para saber tu puesto aunque no entres en las ROWS primeras filas.
const FETCH := 100
## Oro, plata y bronce para los tres primeros.
const PODIUM: Array[Color] = [Color("f0c040"), Color("c8ccd8"), Color("d08850")]

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
	_players = await Backend.fetch_ranking(FETCH)
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
	HKTheme.draw_text(self, Vector2(304, 46), "VICT/DERR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(390, 46), "%", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var me := Backend.username().to_lower() if Backend.is_logged_in() else ""
	var my_index := -1
	for i in _players.size():
		if str(_players[i].get("username", "")).to_lower() == me:
			my_index = i
	var y := 62.0
	for i in mini(_players.size(), ROWS):
		_draw_row(i, _players[i], y, i == my_index)
		y += 13.0
	# Fuera de las primeras filas: tu puesto queda fijo debajo de la lista.
	if my_index >= ROWS:
		_draw_row(my_index, _players[my_index], 204.0, true)
	elif me != "" and my_index < 0:
		HKTheme.draw_text(self, Vector2(60, 204), "%s: FUERA DEL TOP %d" % [me.to_upper().left(16), FETCH], 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

func _draw_row(i: int, p: Dictionary, y: float, mine: bool) -> void:
	var wins := int(p.get("wins", 0))
	var losses := int(p.get("losses", 0))
	var played := wins + losses
	var color: Color = PODIUM[i] if i < PODIUM.size() else HKTheme.PAPER
	if played == 0:
		color = HKTheme.MUTED   # todavía sin duelos: sin mérito que destacar
	elif mine and i >= PODIUM.size():
		color = HKTheme.GOLD
	if mine:
		draw_rect(Rect2(52, y - 9, 362, 12), Color(1, 1, 1, 0.08))
	HKTheme.draw_text(self, Vector2(60, y), str(i + 1), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(90, y), str(p.get("username", "")).to_upper().left(16), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(230, y), str(int(p.get("points", 0))), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(304, y), "%d / %d" % [wins, losses], 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var rate := "%d%%" % roundi(100.0 * wins / played) if played > 0 else "-"
	HKTheme.draw_text(self, Vector2(390, y), rate, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
