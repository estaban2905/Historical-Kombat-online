## Ranking de jugadores: los mejores por puntos. Con sesión, izquierda/derecha (con VOLVER elegido) alterna
## entre GLOBAL y AMIGOS. Tu fila sale resaltada, con tu puesto fijo debajo si no entras en las primeras. Flecha arriba para entrar en la lista, arriba/abajo para moverte y ENTER (o un
## clic) para ver el perfil de ese jugador; abajo desde la última fila vuelve a VOLVER. ESC regresa al menú.
extends Control

const ROWS := 10
## Cuántos jugadores se piden: para saber tu puesto aunque no entres en las ROWS primeras filas.
const FETCH := 100
## Oro, plata y bronce para los tres primeros.
const PODIUM: Array[Color] = [Color("f0c040"), Color("c8ccd8"), Color("d08850")]
## Desde cuántas victorias seguidas se marca la racha junto al nombre.
const STREAK_MARK := 3
const STREAK_COLOR := Color("ff9030")
const FIRST_ROW_Y := 62.0
const ROW_STEP := 13.0

var _players: Array = []
## Lo que se muestra: GLOBAL (los mejores de todos) o AMIGOS (mis amigos y yo). Cada lista se pide una vez.
var _scope: int = 0
var _global: Array = []
var _friends_list: Array = []
var _friends_loaded: bool = false
var _loading: bool = true
var _back: Button
## Fila elegida con el cursor (-1 = ninguna: el foco está en VOLVER).
var _sel: int = -1

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
	_global = await Backend.fetch_ranking(FETCH)
	_players = _global
	_loading = false

func _shown() -> int:
	return mini(_players.size(), ROWS)

## _input y no _unhandled_input: los botones se quedan las flechas y ENTER antes de que lleguen a _unhandled_input.
func _input(event: InputEvent) -> void:
	if _loading:
		return
	if _sel == -1 and Backend.is_logged_in() and (event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right")):
		_set_scope(0 if event.is_action_pressed(&"ui_left") else 1)
		get_viewport().set_input_as_handled()
		return
	if _shown() == 0:
		return
	if event.is_action_pressed(&"ui_up") and _sel != 0:
		if _sel == -1:
			_sel = _shown() - 1
			_back.release_focus()
		else:
			_sel -= 1
		Sfx.play(&"select")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down") and _sel >= 0:
		if _sel < _shown() - 1:
			_sel += 1
		else:
			_sel = -1
			_back.grab_focus()
		Sfx.play(&"select")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") and _sel >= 0:
		_open(_sel)
		get_viewport().set_input_as_handled()

func _set_scope(scope: int) -> void:
	if scope == _scope:
		return
	_scope = scope
	_sel = -1
	Sfx.play(&"select")
	if scope == 1 and not _friends_loaded:
		_loading = true
		_friends_list = await Backend.fetch_friends_ranking()
		_friends_loaded = true
		_loading = false
	_players = _friends_list if _scope == 1 else _global

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT or _loading:
		return
	var i := int(floor((click.position.y - FIRST_ROW_Y + 9.0) / ROW_STEP))
	if i >= 0 and i < _shown() and click.position.x >= 52.0 and click.position.x <= 414.0:
		_open(i)

func _open(i: int) -> void:
	Sfx.play(&"confirm")
	Game.view_player(str(_players[i].get("username", "")), Game.SCENE_RANKING)

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
	_draw_scope_tabs()
	HKTheme.draw_text(self, Vector2(60, 46), "#", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(90, 46), "JUGADOR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(230, 46), "PTS", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(268, 46), "LIGA", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(312, 46), "VICT/DERR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(390, 46), "%", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var me := Backend.username().to_lower() if Backend.is_logged_in() else ""
	var my_index := -1
	for i in _players.size():
		if str(_players[i].get("username", "")).to_lower() == me:
			my_index = i
	var y := FIRST_ROW_Y
	for i in _shown():
		_draw_row(i, _players[i], y, i == my_index)
		if i == _sel:
			draw_rect(Rect2(51, y - 10, 364, 13), HKTheme.GOLD, false, 1.0)
		y += ROW_STEP
	_draw_footer(my_index, me)

## GLOBAL y AMIGOS bajo el título (solo con sesión): el elegido en dorado y subrayado.
func _draw_scope_tabs() -> void:
	if not Backend.is_logged_in():
		return
	var names := ["GLOBAL", "AMIGOS"]
	var x := 213.0 - (HKTheme.text_width("GLOBAL", 8) + HKTheme.text_width("AMIGOS", 8) + 24.0) * 0.5
	for i in 2:
		var w := HKTheme.text_width(names[i], 8)
		HKTheme.draw_text(self, Vector2(x, 33), names[i], 8, HKTheme.GOLD if i == _scope else HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		if i == _scope:
			draw_rect(Rect2(x, 35, w, 1), HKTheme.GOLD)
		x += w + 24.0

## Debajo de la lista: lo del jugador elegido; si no hay ninguno, tu puesto (fijo si no entras en las filas) o lo que te falta.
func _draw_footer(my_index: int, me: String) -> void:
	if _sel >= 0:
		var p: Dictionary = _players[_sel]
		var parts: Array[String] = []
		var fav := MatchRow.fighter_name(str(p.get("favorite_fighter", "")))
		if fav != "":
			parts.append("MÁS USADO %s" % fav)
		if int(p.get("streak", 0)) > 0:
			parts.append("RACHA %d" % int(p.get("streak", 0)))
		parts.append("ENTER: VER PERFIL")
		HKTheme.draw_text(self, Vector2(0, 204), " · ".join(parts), 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	elif my_index >= ROWS:
		# Fuera de las primeras filas: tu puesto queda fijo debajo de la lista.
		_draw_row(my_index, _players[my_index], 204.0, true)
	elif my_index >= 0:
		# Dentro de las filas visibles: en el hueco de abajo va lo que te falta para subir de liga.
		var league := League.info(int(_players[my_index].get("points", 0)))
		var next_name := str(league["next_name"])
		var text := "ERES EL PUESTO %d · %s" % [my_index + 1, league["name"]]
		if next_name != "":
			text += " · %d PARA %s" % [int(league["to_next"]), next_name]
		HKTheme.draw_text(self, Vector2(0, 204), text, 8, league["color"], HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	elif me != "":
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
	HKTheme.draw_text(self, Vector2(90, y), str(p.get("username", "")).to_upper().left(12), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var streak := int(p.get("streak", 0))
	if streak >= STREAK_MARK:
		HKTheme.draw_text(self, Vector2(190, y), "x%d" % streak, 8, STREAK_COLOR, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var points := int(p.get("points", 0))
	HKTheme.draw_text(self, Vector2(230, y), str(points), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var league := League.info(points)
	HKTheme.draw_text(self, Vector2(268, y), str(league["name"]).left(3), 8, league["color"] if played > 0 else HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(312, y), "%d / %d" % [wins, losses], 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var rate := "%d%%" % roundi(100.0 * wins / played) if played > 0 else "-"
	HKTheme.draw_text(self, Vector2(390, y), rate, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
