## Perfil del jugador: nombre, liga y récord arriba, y cuatro pestañas debajo: DUELOS (últimos
## resultados), PERSONAJES (con quién y contra quién gano), PUNTOS (gráfica) e HISTORIA (partida guardada).
## CERRAR SESIÓN vuelve a la pantalla de entrada. ESC o VOLVER regresa al menú.
extends Control

enum Tab { DUELOS, PERSONAJES, PUNTOS, HISTORIA }
const TAB_NAMES: Array[String] = ["DUELOS", "PERSONAJES", "PUNTOS", "HISTORIA"]
## El servidor devuelve como mucho 50 duelos; con todos se calculan las estadísticas.
const MAX_MATCHES := 50
## Filas que caben en la pestaña DUELOS.
const SHOWN_MATCHES := 7
const WIN_COLOR := Color("60d060")

var _matches: Array = []
var _story: Dictionary = {}
var _tab: int = Tab.DUELOS
var _loading: bool = true
var _back: Button
var _avatar_btn: Button
var _logout: Button
var _continue_btn: Button
var _tab_buttons: Array[Button] = []
var _portrait: AvatarFrame

func _ready() -> void:
	theme = HKTheme.theme()
	if not Backend.is_logged_in():
		Game.goto.call_deferred(Game.SCENE_MENU)
		return
	_back = _button("VOLVER", 40)
	_avatar_btn = _button("AVATAR", 150)
	_logout = _button(HKTheme.fold("CERRAR SESIÓN"), 260)
	_back.pressed.connect(func(): Game.goto(Game.SCENE_MENU))
	_avatar_btn.pressed.connect(func(): Game.goto(Game.SCENE_AVATAR))
	_logout.pressed.connect(_on_logout)
	_portrait = AvatarFrame.new(Vector2(40, 40))
	_portrait.position = Vector2(46, 30)
	add_child(_portrait)
	_portrait.set_fighter(Backend.avatar())
	for b in [_back, _avatar_btn, _logout]:
		b.focus_entered.connect(func(): Sfx.play(&"select"))
		b.pressed.connect(func(): Sfx.play(&"confirm"))
	_build_tabs()
	_continue_btn = _button("CONTINUAR HISTORIA", 150)
	_continue_btn.position.y = 180
	_continue_btn.size.x = 126
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_continue_story)
	_continue_btn.focus_entered.connect(func(): Sfx.play(&"select"))
	_continue_btn.pressed.connect(func(): Sfx.play(&"confirm"))
	_back.grab_focus()
	Backend.session_changed.connect(queue_redraw)
	await Backend.fetch_profile()
	_portrait.set_fighter(Backend.avatar())
	_matches = await Backend.fetch_matches(MAX_MATCHES)
	_story = await Backend.load_story()
	_loading = false
	_select_tab(_tab)

## Las pestañas son botones: se mueven con las flechas y se eligen con ENTER como todo el menú.
func _build_tabs() -> void:
	for i in TAB_NAMES.size():
		var b := Button.new()
		b.text = TAB_NAMES[i]
		b.position = Vector2(40 + i * 92, 95)
		b.custom_minimum_size = Vector2(88, 14)
		add_child(b)
		b.size = Vector2(88, 14)
		b.pressed.connect(_select_tab.bind(i))
		b.focus_entered.connect(func(): Sfx.play(&"select"))
		b.pressed.connect(func(): Sfx.play(&"confirm"))
		_tab_buttons.append(b)

func _select_tab(tab: int) -> void:
	_tab = tab
	_continue_btn.visible = tab == Tab.HISTORIA and not _loading and _story_is_valid()
	queue_redraw()

func _story_is_valid() -> bool:
	var stage := int(_story.get("stage", -1))
	return FighterRegistry.has(StringName(str(_story.get("fighter", "")))) \
		and stage >= 0 and stage < FighterRegistry.all().size()

func _continue_story() -> void:
	if Game.story_resume(_story):
		Game.goto(Game.SCENE_STORY)

func _button(text: String, x: float) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(x, 212)
	b.custom_minimum_size = Vector2(100, 14)
	add_child(b)
	# Con el tema ya aplicado: si se fija antes, el botón nace con la altura de la fuente por defecto.
	b.size = Vector2(100, 14)
	return b

func _on_logout() -> void:
	await Backend.sign_out()
	Backend.guest = false
	Game.goto(Game.SCENE_LOGIN)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Game.goto(Game.SCENE_MENU)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 240), HKTheme.INK)
	if not Backend.is_logged_in():
		return
	HKTheme.draw_text(self, Vector2(0, 24), "PERFIL", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	var wins := int(Backend.profile.get("wins", 0))
	var losses := int(Backend.profile.get("losses", 0))
	HKTheme.draw_text(self, Vector2(0, 48), Backend.username().to_upper(), 16, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	var points := int(Backend.profile.get("points", 0))
	var league := League.info(points)
	HKTheme.draw_text(self, Vector2(0, 68), "%d PUNTOS · %s" % [points, league["name"]], 8,
		league["color"], HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	_draw_league_bar(league)
	var total := wins + losses
	var rate := "%d%%" % roundi(100.0 * wins / total) if total > 0 else "-"
	HKTheme.draw_text(self, Vector2(0, 81), "%d %s · %d %s · %s" % [
		wins, "VICTORIA" if wins == 1 else "VICTORIAS", losses, "DERROTA" if losses == 1 else "DERROTAS", rate], 8,
		HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)

	# Subrayado de la pestaña elegida.
	draw_rect(Rect2(40 + _tab * 92, 110, 88, 2), HKTheme.GOLD)
	if _loading:
		_draw_empty("CARGANDO...")
		return
	match _tab:
		Tab.DUELOS: _draw_duels()
		Tab.PERSONAJES: _draw_fighters()
		Tab.PUNTOS: _draw_points()
		Tab.HISTORIA: _draw_story()

func _draw_empty(text: String) -> void:
	HKTheme.draw_text(self, Vector2(0, 156), text, 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)

func _draw_duels() -> void:
	if _matches.is_empty():
		_draw_empty("TODAVÍA NO HAS JUGADO NINGÚN DUELO CON RANKING")
		return
	var y := 126.0
	for m in _matches.slice(0, SHOWN_MATCHES):
		_draw_match(m, y)
		y += 12.0

## Con qué luchadores gano (barra verde = victorias, roja = derrotas) y contra cuáles me va mejor y peor.
func _draw_fighters() -> void:
	if _matches.is_empty():
		_draw_empty("TODAVÍA NO HAS JUGADO NINGÚN DUELO CON RANKING")
		return
	HKTheme.draw_text(self, Vector2(40, 126), "TUS LUCHADORES", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var y := 140.0
	for row in ProfileStats.by_fighter(_matches).slice(0, 5):
		HKTheme.draw_text(self, Vector2(40, y), _fighter_name(row["id"]), 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		var bar := Rect2(130, y - 7, 90, 7)
		draw_rect(bar, HKTheme.BLOOD)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ProfileStats.win_rate(row), bar.size.y)), WIN_COLOR)
		HKTheme.draw_text(self, Vector2(228, y), "%d-%d" % [row["wins"], row["losses"]], 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		y += 14.0
	var matchups := ProfileStats.best_and_worst(ProfileStats.by_fighter(_matches, "opponent_fighter"))
	_draw_matchup(290, 126, "MEJOR RIVAL", WIN_COLOR, matchups["best"])
	_draw_matchup(290, 166, "PEOR RIVAL", HKTheme.BLOOD, matchups["worst"])

func _draw_matchup(x: float, y: float, title: String, color: Color, row: Dictionary) -> void:
	HKTheme.draw_text(self, Vector2(x, y), title, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	if row.is_empty():
		HKTheme.draw_text(self, Vector2(x, y + 13), "2 DUELOS PARA SABER", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		return
	HKTheme.draw_text(self, Vector2(x, y + 13), _fighter_name(row["id"]), 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(x, y + 25), "%d-%d  (%d%%)" % [row["wins"], row["losses"], roundi(100.0 * ProfileStats.win_rate(row))],
		8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

## Línea de mis puntos en los últimos 20 duelos: un punto verde por victoria y rojo por derrota.
func _draw_points() -> void:
	var series := ProfileStats.points_series(_matches, int(Backend.profile.get("points", 0)))
	if series.size() < 3:
		_draw_empty("JUEGA MÁS DUELOS PARA VER LA GRÁFICA")
		return
	var lo := series[0]
	var hi := series[0]
	for v in series:
		lo = mini(lo, v)
		hi = maxi(hi, v)
	var area := Rect2(80, 132, 306, 64)
	var span := maxf(float(hi - lo), 1.0)
	draw_rect(area, Color(1, 1, 1, 0.04))
	HKTheme.draw_text(self, Vector2(40, area.position.y + 8), str(hi), 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(40, area.end.y), str(lo), 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var pts := PackedVector2Array()
	for i in series.size():
		pts.append(Vector2(area.position.x + area.size.x * i / float(series.size() - 1),
			area.end.y - area.size.y * (series[i] - lo) / span))
	draw_polyline(pts, HKTheme.GOLD, 1.0)
	# La serie va del más antiguo al más reciente; _matches viene al revés (el más reciente primero).
	var shown := series.size() - 1
	for i in series.size():
		var color := HKTheme.PAPER
		if i > 0:
			var result := str(_matches[shown - i].get("result", ""))
			color = WIN_COLOR if result == "win" else (HKTheme.BLOOD if result == "loss" else HKTheme.PAPER)
		draw_rect(Rect2(pts[i] - Vector2(1, 1), Vector2(3, 3)), color)
	HKTheme.draw_text(self, Vector2(0, 206), "TUS ÚLTIMOS %d DUELOS" % shown, 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)

## La partida guardada del modo Historia (la misma que ofrece CONTINUAR HISTORIA en el menú).
func _draw_story() -> void:
	if not _story_is_valid():
		_draw_empty("NO TIENES UNA PARTIDA DEL MODO HISTORIA")
		return
	var fighter := FighterRegistry.get_by_id(StringName(str(_story["fighter"])))
	var diff := clampi(int(_story.get("difficulty", 1)), 0, Game.DIFFICULTY_NAMES.size() - 1)
	var total := FighterRegistry.all().size()
	var stage := int(_story["stage"])
	var lines := [
		["LUCHADOR", fighter.display_name.to_upper().left(20)],
		["COMBATE", "%d / %d" % [stage + 1, total]],
		["DIFICULTAD", Game.DIFFICULTY_NAMES[diff]],
		["REVANCHAS", "%d (USADAS: %d)" % [int(_story.get("continues", 0)), int(_story.get("continues_used", 0))]],
	]
	var y := 132.0
	for line in lines:
		HKTheme.draw_text(self, Vector2(100, y), line[0], 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		HKTheme.draw_text(self, Vector2(220, y), line[1], 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		y += 13.0
	var bar := Rect2(100, 200, 226, 4)
	draw_rect(bar, Color(1, 1, 1, 0.10))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(stage + 1) / float(total), bar.size.y)), HKTheme.GOLD)

func _draw_match(m: Dictionary, y: float) -> void:
	var result := str(m.get("result", ""))
	var delta := int(m.get("delta", 0))
	var color := WIN_COLOR if result == "win" else (HKTheme.BLOOD if result == "loss" else HKTheme.PAPER)
	var label := {"win": "VICTORIA", "loss": "DERROTA", "draw": "EMPATE"}.get(result, "?") as String
	if str(m.get("reason", "")) == "forfeit":
		label += "*"
	draw_rect(Rect2(34, y - 9, 384, 11), Color(color.r, color.g, color.b, 0.10))
	HKTheme.draw_text(self, Vector2(40, y), label, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(112, y), "%+d" % delta, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(150, y), "VS %s" % str(m.get("opponent", "")).to_upper().left(10), 8,
		HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(262, y), format_ago(str(m.get("played_at", ""))), 8,
		HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(306, y), _fighter_name(str(m.get("my_fighter", ""))), 8,
		HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(390, y), "%d-%d" % [int(m.get("my_rounds", 0)), int(m.get("opponent_rounds", 0))], 8,
		HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

## Barra de progreso hacia la siguiente liga, con lo que falta a la derecha.
func _draw_league_bar(league: Dictionary) -> void:
	var bar := Rect2(143, 86, 140, 4)
	draw_rect(bar, Color(1, 1, 1, 0.10))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(league["progress"]), bar.size.y)), league["color"])
	var next_name := str(league["next_name"])
	HKTheme.draw_text(self, Vector2(290, 91), "%d PARA %s" % [int(league["to_next"]), next_name] if next_name != "" else "LIGA MÁXIMA",
		8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

## "AHORA", "15M", "3H", "2D", "3SEM" o "2MES": hace cuánto se jugó (played_at es ISO en UTC).
## "" si la fecha no se entiende. now_unix permite probarlo con una hora fija.
static func format_ago(played_at: String, now_unix: float = -1.0) -> String:
	if played_at.length() < 19:
		return ""
	var then := Time.get_unix_time_from_datetime_string(played_at.left(19))
	var secs := int((now_unix if now_unix >= 0.0 else Time.get_unix_time_from_system()) - then)
	if secs < 60:
		return "AHORA"
	if secs < 3600:
		return "%dM" % (secs / 60)
	if secs < 86400:
		return "%dH" % (secs / 3600)
	if secs < 7 * 86400:
		return "%dD" % (secs / 86400)
	if secs < 30 * 86400:
		return "%dSEM" % (secs / (7 * 86400))
	return "%dMES" % (secs / (30 * 86400))

func _fighter_name(id: String) -> String:
	if not FighterRegistry.has(StringName(id)):
		return ""
	return FighterRegistry.get_by_id(StringName(id)).short_name.left(10)
