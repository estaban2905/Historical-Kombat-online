## Perfil de otro jugador (Game.viewed_player): puesto, liga, récord, racha, luchador más usado y sus
## últimos duelos. Se abre desde el ranking, los amigos o los duelos del perfil. Con sesión, abajo salen las
## acciones según vuestra relación: AGREGAR AMIGO, ACEPTAR / RECHAZAR, CANCELAR SOLICITUD, o RETAR / QUITAR AMIGO.
## ESC o VOLVER regresa a donde estabas.
extends Control

const SHOWN_MATCHES := 7
const BUTTON_Y := 212.0

var _data: Dictionary = {}
var _loading: bool = true
var _message: String = ""
var _busy: bool = false
var _back: Button
var _actions: Array[Button] = []
var _portrait: AvatarFrame

func _ready() -> void:
	theme = HKTheme.theme()
	_back = _make_button("VOLVER")
	_back.pressed.connect(_go_back)
	_layout_buttons()
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
	await _refresh_actions()

func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(70, 14)
	add_child(b)
	b.size = Vector2(70, 14)   # tras añadirlo: ya tiene el tema (ver profile.gd)
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	b.pressed.connect(func(): Sfx.play(&"confirm"))
	return b

## Es la persona que estoy viendo (no hay amistad ni reto consigo mismo).
func _is_me() -> bool:
	return Backend.is_logged_in() and Game.viewed_player.to_lower() == Backend.username().to_lower()

## Vuelve a pedir la lista de amigos y reconstruye los botones según la relación de ahora.
func _refresh_actions() -> void:
	for b in _actions:
		b.queue_free()
	_actions.clear()
	if not Backend.is_logged_in() or _is_me() or _data.is_empty():
		_layout_buttons()
		return
	await Backend.fetch_friends()
	var who := str(_data.get("username", Game.viewed_player))
	var specs: Array = []
	match Backend.friend_status(who):
		"friend": specs = [["RETAR", _challenge], ["QUITAR AMIGO", _remove]]
		"incoming": specs = [["ACEPTAR", _add], ["RECHAZAR", _remove]]
		"outgoing": specs = [["CANCELAR SOLICITUD", _remove]]
		_: specs = [["AGREGAR AMIGO", _add]]
	for spec in specs:
		var b := _make_button(spec[0])
		b.pressed.connect(spec[1])
		_actions.append(b)
	_layout_buttons()

## VOLVER y las acciones en una fila centrada abajo, cada botón del ancho de su texto.
func _layout_buttons() -> void:
	var all: Array[Button] = [_back]
	all.append_array(_actions)
	var total := 0.0
	for b in all:
		total += maxf(HKTheme.text_width(b.text, 8) + 18.0, 70.0)
	total += 6.0 * (all.size() - 1)
	var x := (426.0 - total) * 0.5
	for b in all:
		var w := maxf(HKTheme.text_width(b.text, 8) + 18.0, 70.0)
		b.custom_minimum_size = Vector2(w, 14)
		b.position = Vector2(x, BUTTON_Y)
		b.size = Vector2(w, 14)
		x += w + 6.0

func _set_busy(busy: bool) -> void:
	_busy = busy
	for b in _actions:
		b.disabled = busy

func _add() -> void:
	if _busy:
		return
	var who := str(_data.get("username", Game.viewed_player))
	_set_busy(true)
	_message = "ENVIANDO..."
	var r := await Backend.request_friend(who)
	_set_busy(false)
	if not r.ok:
		_message = r.error
		Sfx.play(&"denied")
		return
	_message = {"requested": "SOLICITUD ENVIADA", "accepted": "¡YA SOIS AMIGOS!",
		"already_friends": "YA SOIS AMIGOS", "already_requested": "YA LE PEDISTE AMISTAD"}.get(r.result, "HECHO")
	await _refresh_actions()
	_back.grab_focus()

func _remove() -> void:
	if _busy:
		return
	var who := str(_data.get("username", Game.viewed_player))
	_set_busy(true)
	_message = "..."
	var ok := await Backend.remove_friend(who)
	_set_busy(false)
	_message = "HECHO" if ok else "NO SE PUDO, REINTENTA"
	await _refresh_actions()
	_back.grab_focus()

## Reta a este amigo: abre una sala privada y pasa a elegir luchador; el duelo es amistoso (sin puntos).
func _challenge() -> void:
	if _busy:
		return
	var who := str(_data.get("username", Game.viewed_player))
	_set_busy(true)
	_message = "CREANDO RETO..."
	var r := await Backend.create_challenge(who)
	_set_busy(false)
	if not r.ok:
		_message = r.error
		Sfx.play(&"denied")
		return
	Game.challenge_code = r.code
	Game.challenge_opponent = who
	Game.mode = Game.Mode.ONLINE
	Game.goto(Game.SCENE_SELECT)

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
	if _message != "":
		HKTheme.draw_text(self, Vector2(0, 112), _message, 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 386, 1)
	var recent: Array = _data.get("recent", [])
	if recent.is_empty():
		HKTheme.draw_text(self, Vector2(0, 156), "TODAVÍA NO HA JUGADO NINGÚN DUELO CON RANKING", 8,
			HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	var y := 128.0
	for m in recent.slice(0, SHOWN_MATCHES - 1):
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
