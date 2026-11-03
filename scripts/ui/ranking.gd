## Ranking de jugadores: los mejores por puntos. Abajo, una fila de botones (izquierda/derecha para moverse,
## ENTER o clic para usarlos): GLOBAL/AMIGOS (con sesión), SIEMPRE/7 DÍAS, LUCHADOR (abre la rejilla para
## filtrar por uno) y VOLVER. Con un filtro solo cuentan esos duelos y la columna de puntos dice lo ganado con
## ellos. Tu fila sale resaltada, con tu puesto fijo debajo si no entras en las primeras. Flecha arriba para
## entrar en la lista, arriba/abajo para moverte y ENTER (o un clic) para ver el perfil de ese jugador; abajo
## desde la última fila vuelve a los botones. ESC regresa al menú.
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
const FOOTER_Y := 204.0
## Retratos pequeños de cada fila: el avatar delante del nombre y el luchador más usado antes de los puntos.
const ICON := Vector2(12, 12)
const ICON_ZOOM := 0.55
const AVATAR_X := 77.0
const FAVORITE_X := 214.0
const NAME_X := 92.0
## Fila de botones de abajo.
const BUTTON_SIZE := Vector2(96, 14)
const BUTTON_GAP := 6.0
const BUTTONS_Y := 222.0

var _players: Array = []
## Listas ya pedidas, por filtro ("amigos|semana|luchador"): cambiar de filtro y volver no repite la petición.
var _cache: Dictionary = {}
var _loading: bool = true
var _back: Button
var _scope_btn: Button
var _period_btn: Button
var _fighter_btn: Button
var _buttons: Array[Button] = []
## Botón que tenía el foco al entrar en la lista (al salir de ella por abajo vuelve a él).
var _last_button: Button
## Fila elegida con el cursor (-1 = ninguna: el foco está en los botones).
var _sel: int = -1
## [avatar, más usado] por fila; la última pareja es la de tu fila fija abajo.
var _icons: Array = []
## La temporada en curso ({id, ends_at}; {} hasta que llegue o si no hay servidor).
var _season: Dictionary = {}

func _ready() -> void:
	theme = HKTheme.theme()
	for i in ROWS + 1:
		_icons.append([_new_icon(), _new_icon()])
	if not Backend.is_logged_in():
		Game.ranking_friends = false
	if Backend.is_logged_in():
		_scope_btn = _button(func(): _set_filter(not Game.ranking_friends, Game.ranking_week, Game.ranking_fighter))
	_period_btn = _button(func(): _set_filter(Game.ranking_friends, not Game.ranking_week, Game.ranking_fighter))
	_fighter_btn = _button(func():
		Game.picker_purpose = "ranking"
		Game.goto(Game.SCENE_AVATAR))
	_back = BackButton.add_to(self, func(): Game.goto(Game.SCENE_MENU))
	_back.focus_entered.connect(func(): _last_button = _back)
	# Primero en el anillo de foco: derecha desde VOLVER va a GLOBAL / SIEMPRE y izquierda da la vuelta a LUCHADOR.
	_buttons.push_front(_back)
	_layout_buttons()
	_refresh_labels()
	# Al volver de elegir luchador, el foco sigue en LUCHADOR.
	(_fighter_btn if Game.picker_purpose == "ranking" else _back).grab_focus()
	Game.picker_purpose = "avatar"
	_load_season()
	await _load()

func _load_season() -> void:
	var s := await Backend.fetch_season()
	if is_inside_tree():
		_season = s

func _button(on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = BUTTON_SIZE
	add_child(b)
	b.size = BUTTON_SIZE   # tras añadirlo: ya tiene el tema (ver profile.gd)
	b.pressed.connect(func():
		Sfx.play(&"confirm")
		on_press.call())
	b.focus_entered.connect(func():
		_last_button = b
		Sfx.play(&"select"))
	_buttons.append(b)
	return b

## Los botones de filtro centrados en una fila (VOLVER va aparte, en su esquina); izquierda/derecha pasa de uno
## a otro, VOLVER incluido (y da la vuelta).
func _layout_buttons() -> void:
	var row := _buttons.size() - 1
	var total := row * BUTTON_SIZE.x + (row - 1) * BUTTON_GAP
	var x := maxf((426.0 - total) * 0.5, BackButton.RIGHT_EDGE)
	for i in _buttons.size():
		var b := _buttons[i]
		if b != _back:
			b.position = Vector2(x, BUTTONS_Y)
			x += BUTTON_SIZE.x + BUTTON_GAP
		b.focus_neighbor_left = _buttons[posmod(i - 1, _buttons.size())].get_path()
		b.focus_neighbor_right = _buttons[posmod(i + 1, _buttons.size())].get_path()
		# Arriba/abajo los maneja _input (entrar y salir de la lista).
		b.focus_neighbor_top = b.get_path()
		b.focus_neighbor_bottom = b.get_path()

func _refresh_labels() -> void:
	if _scope_btn:
		_scope_btn.text = "AMIGOS" if Game.ranking_friends else "GLOBAL"
	_period_btn.text = HKTheme.fold("7 DÍAS" if Game.ranking_week else "SIEMPRE")
	var f := Game.ranking_fighter
	_fighter_btn.text = HKTheme.fold(FighterRegistry.get_by_id(StringName(f)).short_name.to_upper().left(12)) 		if f != "" and FighterRegistry.has(StringName(f)) else "LUCHADOR"

## ¿Hay algún filtro de duelos (semana o luchador)? Entonces la columna de puntos es lo ganado con ellos.
static func filtered() -> bool:
	return Game.ranking_week or Game.ranking_fighter != ""

func _set_filter(friends: bool, week: bool, fighter: String) -> void:
	Game.ranking_friends = friends and Backend.is_logged_in()
	Game.ranking_week = week
	Game.ranking_fighter = fighter
	_refresh_labels()
	await _load()

## Pide (o saca de la caché) la lista con los filtros actuales.
func _load() -> void:
	var key := "%s|%s|%s" % [Game.ranking_friends, Game.ranking_week, Game.ranking_fighter]
	_sel = -1
	if not _cache.has(key):
		_loading = true
		if Game.ranking_friends:
			_cache[key] = await Backend.fetch_friends_ranking(Game.ranking_week, Game.ranking_fighter)
		else:
			_cache[key] = await Backend.fetch_ranking(FETCH, Game.ranking_week, Game.ranking_fighter)
		if not is_inside_tree():
			return
	# Si mientras tanto se cambió de filtro, manda el último.
	if key == "%s|%s|%s" % [Game.ranking_friends, Game.ranking_week, Game.ranking_fighter]:
		_players = _cache[key]
		_loading = false

func _shown() -> int:
	return mini(_players.size(), ROWS)

## _input y no _unhandled_input: los botones se quedan las flechas y ENTER antes de que lleguen a _unhandled_input.
func _input(event: InputEvent) -> void:
	if _loading or _shown() == 0:
		return
	if event.is_action_pressed(&"ui_up") and _sel != 0:
		if _sel == -1:
			_sel = _shown() - 1
			var f := get_viewport().gui_get_focus_owner()
			if f is Button:
				_last_button = f
				f.release_focus()
		else:
			_sel -= 1
		Sfx.play(&"select")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down") and _sel >= 0:
		if _sel < _shown() - 1:
			_sel += 1
		else:
			_sel = -1
			_last_button.grab_focus()
		Sfx.play(&"select")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") and _sel >= 0:
		_open(_sel)
		get_viewport().set_input_as_handled()

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
	_place_icons()
	queue_redraw()

func _new_icon() -> AvatarFrame:
	var icon := AvatarFrame.new(ICON, ICON_ZOOM)
	icon.visible = false
	add_child(icon)
	return icon

## Pone los retratos de las filas que se ven (y de tu fila fija abajo, si sale) y oculta el resto.
func _place_icons() -> void:
	var my_index := _my_index()
	for slot in _icons.size():
		var p: Dictionary = {}
		var y := FIRST_ROW_Y + slot * ROW_STEP
		if _loading:
			pass
		elif slot < ROWS and slot < _shown():
			p = _players[slot]
		elif slot == ROWS and _sel < 0 and my_index >= ROWS:
			p = _players[my_index]
			y = FOOTER_Y
		var avatar: AvatarFrame = _icons[slot][0]
		var favorite: AvatarFrame = _icons[slot][1]
		avatar.visible = not p.is_empty()
		var fav := str(p.get("favorite_fighter", "")) if p.get("favorite_fighter") != null else ""
		favorite.visible = fav != ""
		if p.is_empty():
			continue
		var a: Variant = p.get("avatar")
		avatar.set_fighter(str(a) if a != null else "")
		avatar.position = Vector2(AVATAR_X, y - 10)
		if fav != "":
			favorite.set_fighter(fav)
			favorite.position = Vector2(FAVORITE_X, y - 10)

func _my_index() -> int:
	var me := Backend.username().to_lower() if Backend.is_logged_in() else ""
	if me == "":
		return -1
	for i in _players.size():
		if str(_players[i].get("username", "")).to_lower() == me:
			return i
	return -1

func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 240), HKTheme.INK)
	HKTheme.draw_text(self, Vector2(0, 24), "RANKING", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	if _loading:
		HKTheme.draw_text(self, Vector2(0, 110), "CARGANDO...", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	_draw_scope_tabs()
	_draw_season()
	if _players.is_empty():
		var empty := "NADIE HA JUGADO CON ESTOS FILTROS" if filtered() else "TODAVÍA NO HAY JUGADORES"
		HKTheme.draw_text(self, Vector2(0, 110), empty, 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	HKTheme.draw_text(self, Vector2(60, 46), "#", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(NAME_X, 46), "JUGADOR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	# Con filtros, la columna de puntos es lo ganado con esos duelos.
	HKTheme.draw_text(self, Vector2(230, 46), "+PTS" if filtered() else "PTS", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(268, 46), "LIGA", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(312, 46), "VICT/DERR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(390, 46), "%", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var me := Backend.username().to_lower() if Backend.is_logged_in() else ""
	var my_index := _my_index()
	var y := FIRST_ROW_Y
	for i in _shown():
		_draw_row(i, _players[i], y, i == my_index)
		if i == _sel:
			draw_rect(Rect2(51, y - 10, 364, 13), HKTheme.GOLD, false, 1.0)
		y += ROW_STEP
	_draw_footer(my_index, me)

## A los lados de GLOBAL/AMIGOS: la temporada y lo que le queda (los puntos se reinician a medias al acabar).
func _draw_season() -> void:
	if _season.is_empty():
		return
	var season_name := Season.name_of(str(_season.get("id", "")))
	if season_name == "":
		return
	HKTheme.draw_text(self, Vector2(8, 33), season_name, 8, HKTheme.GOLD_DARK.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(0, 33), Season.time_left_text(str(_season.get("ends_at", ""))), 8, HKTheme.MUTED,
		HORIZONTAL_ALIGNMENT_RIGHT, 418, 1)

## GLOBAL y AMIGOS bajo el título (solo con sesión): el elegido en dorado y subrayado.
func _draw_scope_tabs() -> void:
	if not Backend.is_logged_in():
		return
	var names := ["GLOBAL", "AMIGOS"]
	var x := 213.0 - (HKTheme.text_width("GLOBAL", 8) + HKTheme.text_width("AMIGOS", 8) + 24.0) * 0.5
	for i in 2:
		var w := HKTheme.text_width(names[i], 8)
		var on := i == int(Game.ranking_friends)
		HKTheme.draw_text(self, Vector2(x, 33), names[i], 8, HKTheme.GOLD if on else HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		if on:
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
		_draw_row(my_index, _players[my_index], FOOTER_Y, true)
	elif my_index >= 0:
		# Dentro de las filas visibles: en el hueco de abajo va lo que te falta para subir de liga.
		var league := League.info(int(_players[my_index].get("points", 0)))
		var next_name := str(league["next_name"])
		var text := "ERES EL PUESTO %d · %s" % [my_index + 1, league["name"]]
		if next_name != "":
			text += " · %d PARA %s" % [int(league["to_next"]), next_name]
		HKTheme.draw_text(self, Vector2(0, 204), text, 8, league["color"], HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	elif me != "":
		var why := "SIN DUELOS CON ESTOS FILTROS" if filtered() else "FUERA DEL TOP %d" % FETCH
		HKTheme.draw_text(self, Vector2(60, 204), "%s: %s" % [me.to_upper().left(16), why], 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

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
	HKTheme.draw_text(self, Vector2(NAME_X, y), str(p.get("username", "")).to_upper().left(12), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var streak := int(p.get("streak", 0))
	if streak >= STREAK_MARK:
		HKTheme.draw_text(self, Vector2(190, y), "x%d" % streak, 8, STREAK_COLOR, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var points := int(p.get("points", 0))
	if filtered():
		var gained := int(p.get("gained", 0))
		var gc := Color("60d060") if gained > 0 else (HKTheme.BLOOD if gained < 0 else color)
		HKTheme.draw_text(self, Vector2(230, y), "%+d" % gained, 8, gc, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	else:
		HKTheme.draw_text(self, Vector2(230, y), str(points), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var league := League.info(points)
	HKTheme.draw_text(self, Vector2(268, y), str(league["name"]).left(3), 8, league["color"] if played > 0 else HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(312, y), "%d / %d" % [wins, losses], 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var rate := "%d%%" % roundi(100.0 * wins / played) if played > 0 else "-"
	HKTheme.draw_text(self, Vector2(390, y), rate, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
