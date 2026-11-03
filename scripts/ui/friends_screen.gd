## AMIGOS: tus amigos y las solicitudes (las que te hacen primero). Flecha arriba entra en la lista, arriba/abajo
## se mueve y ENTER (o un clic) abre el perfil de esa persona, donde se acepta, se rechaza, se quita o se reta.
## Abajo se escribe un nombre para pedir amistad. ESC o VOLVER regresa al menú.
class_name FriendsScreen
extends Control

const FIRST_ROW_Y := 58.0
const ROW_STEP := 14.0
const VISIBLE := 8
## Primero las solicitudes que me hacen (hay que contestarlas), luego los amigos y al final las que envié.
const STATUS_ORDER := {"incoming": 0, "friend": 1, "outgoing": 2}
const STATUS_TEXT := {"incoming": "TE PIDE AMISTAD", "friend": "AMIGO", "outgoing": "PENDIENTE"}
const INCOMING_COLOR := Color("60d060")

var _entries: Array = []
var _loading: bool = true
var _failed: bool = false
var _busy: bool = false
var _message: String = ""
## Fila elegida con el cursor (-1 = ninguna: el foco está abajo, en el campo o en VOLVER) y primera fila visible.
var _sel: int = -1
var _top: int = 0
var _name: LineEdit
var _back: Button

func _ready() -> void:
	theme = HKTheme.theme()
	if not Backend.is_logged_in():
		Game.goto.call_deferred(Game.SCENE_MENU)
		return
	_name = LineEdit.new()
	_name.placeholder_text = "AÑADIR AMIGO POR NOMBRE"
	_name.max_length = 16
	_name.position = Vector2(113, 190)
	_name.custom_minimum_size = Vector2(200, 15)
	add_child(_name)
	_name.size = Vector2(200, 15)
	_name.text_submitted.connect(_on_add)
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
	await _reload()

func _reload() -> void:
	var list: Variant = await Backend.fetch_friends()
	_failed = list == null
	_entries = sort_entries([] if _failed else list)
	_sel = clampi(_sel, -1, _entries.size() - 1)
	_loading = false

## Las solicitudes que me hacen primero, luego los amigos y luego las que envié; dentro de cada grupo, por nombre.
static func sort_entries(list: Array) -> Array:
	var out := list.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var oa: int = STATUS_ORDER.get(str(a.get("status", "")), 9)
		var ob: int = STATUS_ORDER.get(str(b.get("status", "")), 9)
		if oa != ob:
			return oa < ob
		return str(a.get("username", "")).to_lower() < str(b.get("username", "")).to_lower())
	return out

## Cuántas solicitudes hay por contestar.
static func pending_count(list: Array) -> int:
	var n := 0
	for f in list:
		if str(f.get("status", "")) == "incoming":
			n += 1
	return n

func _on_add(text: String) -> void:
	var chosen := text.strip_edges()
	if _busy:
		return
	var bad := Backend.validate_username(chosen)
	if bad != "":
		_message = bad
		Sfx.play(&"denied")
		return
	_busy = true
	_message = "ENVIANDO..."
	var r := await Backend.request_friend(chosen)
	_busy = false
	if not r.ok:
		_message = r.error
		Sfx.play(&"denied")
		return
	_message = {
		"requested": "SOLICITUD ENVIADA A %s",
		"accepted": "YA SOIS AMIGOS: %s",
		"already_friends": "YA ERES AMIGO DE %s",
		"already_requested": "YA LE PEDISTE AMISTAD A %s",
	}.get(r.result, "HECHO: %s") % chosen.to_upper()
	Sfx.play(&"confirm")
	_name.text = ""
	await _reload()

## _input y no _unhandled_input: el campo y el botón se quedan las flechas y ENTER antes de que lleguen allí.
func _input(event: InputEvent) -> void:
	if _loading or _entries.is_empty():
		return
	if event.is_action_pressed(&"ui_up") and _sel != 0:
		if _sel == -1:
			_sel = _entries.size() - 1
			get_viewport().gui_release_focus()
		else:
			_sel -= 1
		_after_move()
	elif event.is_action_pressed(&"ui_down") and _sel >= 0:
		if _sel < _entries.size() - 1:
			_sel += 1
		else:
			_sel = -1
			_back.grab_focus()
		_after_move()
	elif event.is_action_pressed(&"ui_accept") and _sel >= 0:
		_open(_sel)
		get_viewport().set_input_as_handled()

func _after_move() -> void:
	if _sel >= 0:
		_top = clampi(_top, maxi(_sel - VISIBLE + 1, 0), _sel)
	Sfx.play(&"select")
	get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT or _loading:
		return
	var i := _top + int(floor((click.position.y - FIRST_ROW_Y + 9.0) / ROW_STEP))
	if click.position.y >= FIRST_ROW_Y - 9.0 and i >= 0 and i < mini(_entries.size(), _top + VISIBLE) \
			and click.position.x >= 50.0 and click.position.x <= 376.0:
		_open(i)

func _open(i: int) -> void:
	Sfx.play(&"confirm")
	Game.view_player(str(_entries[i].get("username", "")), Game.SCENE_FRIENDS)

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
	HKTheme.draw_text(self, Vector2(0, 24), "AMIGOS", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	if _loading:
		HKTheme.draw_text(self, Vector2(0, 110), "CARGANDO...", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	if _failed:
		HKTheme.draw_text(self, Vector2(0, 110), "NO SE PUDO CARGAR LA LISTA", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	elif _entries.is_empty():
		HKTheme.draw_text(self, Vector2(0, 100), "TODAVÍA NO TIENES AMIGOS", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		HKTheme.draw_text(self, Vector2(0, 114), "ESCRIBE UN NOMBRE ABAJO PARA PEDIRLE AMISTAD", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	else:
		var pending := pending_count(_entries)
		HKTheme.draw_text(self, Vector2(0, 40), "%d POR CONTESTAR" % pending if pending > 0 else "%d EN TU LISTA" % _entries.size(),
			8, INCOMING_COLOR if pending > 0 else HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		var y := FIRST_ROW_Y
		for i in range(_top, mini(_entries.size(), _top + VISIBLE)):
			_draw_row(_entries[i], y, i == _sel)
			y += ROW_STEP
		# Flechas si hay más filas fuera de la vista.
		if _top > 0:
			HKTheme.draw_text(self, Vector2(0, FIRST_ROW_Y - 14), "^", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 372, 1)
		if _top + VISIBLE < _entries.size():
			HKTheme.draw_text(self, Vector2(0, y - 2), "v", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 372, 1)
	if _message != "":
		HKTheme.draw_text(self, Vector2(0, 184), _message, 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)

func _draw_row(f: Dictionary, y: float, selected: bool) -> void:
	var status := str(f.get("status", ""))
	var color: Color = INCOMING_COLOR if status == "incoming" else (HKTheme.PAPER if status == "friend" else HKTheme.MUTED)
	if status == "incoming":
		draw_rect(Rect2(50, y - 9, 326, 12), Color(color.r, color.g, color.b, 0.10))
	var points := int(f.get("points", 0))
	var league := League.info(points)
	HKTheme.draw_text(self, Vector2(56, y), str(f.get("username", "")).to_upper().left(12), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(160, y), str(points), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(206, y), str(league["name"]).left(3), 8, league["color"], HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(self, Vector2(250, y), STATUS_TEXT.get(status, ""), 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	if selected:
		draw_rect(Rect2(49, y - 10, 328, 13), HKTheme.GOLD, false, 1.0)
