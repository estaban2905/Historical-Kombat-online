## Perfil de otro jugador (Game.viewed_player): puesto, liga, récord, racha, luchador más usado y sus
## últimos duelos. Se abre desde el ranking o desde los duelos del perfil. ESC o VOLVER regresa a donde estabas.
extends Control

const SHOWN_MATCHES := 7

var _data: Dictionary = {}
var _loading: bool = true
var _back: Button
var _portrait: AvatarFrame

func _ready() -> void:
	theme = HKTheme.theme()
	_back = Button.new()
	_back.text = "VOLVER"
	_back.position = Vector2(163, 212)
	_back.custom_minimum_size = Vector2(100, 14)
	add_child(_back)
	_back.size = Vector2(100, 14)   # tras añadirlo: ya tiene el tema (ver profile.gd)
	_back.pressed.connect(_go_back)
	_back.focus_entered.connect(func(): Sfx.play(&"select"))
	_back.pressed.connect(func(): Sfx.play(&"confirm"))
	_back.grab_focus()
	_portrait = AvatarFrame.new(Vector2(40, 40))
	_portrait.position = Vector2(46, 30)
	add_child(_portrait)
	_data = await Backend.fetch_player(Game.viewed_player)
	var avatar: Variant = _data.get("avatar")
	_portrait.set_fighter(str(avatar) if avatar != null else "")
	var frame: Variant = _data.get("frame")
	_portrait.set_frame(str(frame) if frame != null else "")
	_loading = false

func _go_back() -> void:
	Game.goto(Game.viewed_return)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 240), HKTheme.INK)
	HKTheme.draw_text(self, Vector2(0, 24), "JUGADOR", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	if _loading:
		HKTheme.draw_text(self, Vector2(0, 120), "CARGANDO...", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	if _data.is_empty():
		HKTheme.draw_text(self, Vector2(0, 120), "NO SE PUDO CARGAR A %s" % Game.viewed_player.to_upper().left(16), 8,
			HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	HKTheme.draw_text(self, Vector2(0, 44), str(_data.get("username", "")).to_upper(), 16, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	var title_key: Variant = _data.get("title")
	var title := Cosmetics.title_name(str(title_key)) if title_key != null else ""
	if title != "":
		HKTheme.draw_text(self, Vector2(0, 57), title, 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	var points := int(_data.get("points", 0))
	var league := League.info(points)
	HKTheme.draw_text(self, Vector2(0, 68), "%d PUNTOS · %s" % [points, league["name"]], 8,
		league["color"], HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	var wins := int(_data.get("wins", 0))
	var losses := int(_data.get("losses", 0))
	var total := wins + losses
	var rate := "%d%%" % roundi(100.0 * wins / total) if total > 0 else "-"
	HKTheme.draw_text(self, Vector2(0, 81), "%d %s · %d %s · %s" % [
		wins, "VICTORIA" if wins == 1 else "VICTORIAS", losses, "DERROTA" if losses == 1 else "DERROTAS", rate], 8,
		HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	HKTheme.draw_text(self, Vector2(0, 93), _summary(), 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)

	HKTheme.draw_text(self, Vector2(40, 112), "ÚLTIMOS DUELOS", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var recent: Array = _data.get("recent", [])
	if recent.is_empty():
		HKTheme.draw_text(self, Vector2(0, 156), "TODAVÍA NO HA JUGADO NINGÚN DUELO CON RANKING", 8,
			HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	var y := 128.0
	for m in recent.slice(0, SHOWN_MATCHES):
		MatchRow.draw(self, m, y)
		y += 12.0

## "PUESTO 4 · RACHA 3 · TESLA": solo lo que se sabe (sin duelos no hay racha ni luchador favorito).
func _summary() -> String:
	var parts: Array[String] = ["PUESTO %d" % int(_data.get("rank", 0))]
	var streak := int(_data.get("streak", 0))
	if streak > 0:
		parts.append("RACHA %d" % streak)
	var fav := MatchRow.fighter_name(str(_data.get("favorite_fighter", "")))
	if fav != "":
		parts.append("MÁS USADO %s" % fav)
	return " · ".join(parts)
