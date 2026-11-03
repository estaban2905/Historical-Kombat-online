## Perfil del jugador: nombre, puntos, victorias y derrotas, y sus últimos duelos.
## CERRAR SESIÓN vuelve a la pantalla de entrada. ESC o VOLVER regresa al menú.
extends Control

const MAX_MATCHES := 8

var _matches: Array = []
var _favorite: String = ""
var _loading: bool = true
var _back: Button
var _avatar_btn: Button
var _logout: Button
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
	_back.grab_focus()
	Backend.session_changed.connect(queue_redraw)
	await Backend.fetch_profile()
	_portrait.set_fighter(Backend.avatar())
	_matches = await Backend.fetch_matches(MAX_MATCHES)
	_favorite = _most_used_fighter()
	_loading = false

## El luchador que más aparece en los últimos duelos ("" si no hay ninguno).
func _most_used_fighter() -> String:
	var counts := {}
	for m in _matches:
		var fname := _fighter_name(str(m.get("my_fighter", "")))
		if fname != "":
			counts[fname] = int(counts.get(fname, 0)) + 1
	var best := ""
	for fname in counts:
		if best == "" or counts[fname] > counts[best]:
			best = fname
	return best

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

	HKTheme.draw_text(self, Vector2(40, 108), "ÚLTIMOS DUELOS", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	if not _loading and not _favorite.is_empty():
		HKTheme.draw_text(self, Vector2(0, 108), "MÁS USADO: %s" % _favorite, 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 386, 1)
	if _loading:
		HKTheme.draw_text(self, Vector2(0, 156), "CARGANDO...", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	if _matches.is_empty():
		HKTheme.draw_text(self, Vector2(0, 156), "TODAVÍA NO HAS JUGADO NINGÚN DUELO CON RANKING", 8,
			HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	var y := 122.0
	for m in _matches:
		_draw_match(m, y)
		y += 12.0

func _draw_match(m: Dictionary, y: float) -> void:
	var result := str(m.get("result", ""))
	var delta := int(m.get("delta", 0))
	var color := Color("60d060") if result == "win" else (HKTheme.BLOOD if result == "loss" else HKTheme.PAPER)
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
