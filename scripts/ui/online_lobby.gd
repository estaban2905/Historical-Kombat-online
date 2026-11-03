## Sala de espera del duelo online: conecta con el servidor, hace cola hasta que
## otra persona busca partida y muestra el VS antes de empezar el combate.
##   ESC: cancelar y volver a la selección · ENTER / U: reintentar tras un fallo
extends Control

const VS_SECONDS := 1.6
## Cuánto se espera a que el amigo acepte un reto (un poco más que lo que vive en el servidor).
const CHALLENGE_WAIT := 125.0

var _t: float = 0.0
var _error: String = ""
var _matched: bool = false
var _my_id: StringName
var _previews: Array[FighterRenderer] = []

func _ready() -> void:
	theme = HKTheme.theme()
	get_tree().paused = false
	_my_id = Game.p1_fighter_id
	Online.matched.connect(_on_matched)
	Online.failed.connect(_on_failed)
	_search()

func _exit_tree() -> void:
	if Online.matched.is_connected(_on_matched):
		Online.matched.disconnect(_on_matched)
	if Online.failed.is_connected(_on_failed):
		Online.failed.disconnect(_on_failed)

func _search() -> void:
	_error = ""
	# Con cuenta se juega con puntos; sin cuenta, de invitado (amistoso).
	var token := ""
	if Backend.is_logged_in():
		if not await Backend.ensure_fresh_token():
			_error = "TU SESIÓN CADUCÓ, ENTRA DE NUEVO"
			return
		token = Backend.access_token
	Online.find_match(_my_id, Backend.username(), token, Game.challenge_code)

func _on_failed(message: String) -> void:
	# Si el rival se va durante el VS, se cancela el inicio y se puede reintentar.
	_matched = false
	for r in _previews:
		r.queue_free()
	_previews.clear()
	_error = message

func _on_matched() -> void:
	if FighterRegistry.index_of(Online.opponent_fighter) < 0:
		Online.disconnect_from_server()
		_error = "TU RIVAL USA UNA VERSIÓN DISTINTA DEL JUEGO"
		return
	_matched = true
	# El código del reto ya se gastó al emparejarse: la próxima búsqueda es una partida normal.
	Game.challenge_code = ""
	Game.challenge_opponent = ""
	# P1 y P2 son los mismos en los dos PC: el servidor decide quién es cada uno.
	if Online.side == 1:
		Game.p1_fighter_id = _my_id
		Game.p2_fighter_id = Online.opponent_fighter
	else:
		Game.p1_fighter_id = Online.opponent_fighter
		Game.p2_fighter_id = _my_id
	_show_versus()
	Sfx.play(&"fight")
	await get_tree().create_timer(VS_SECONDS).timeout
	if is_inside_tree() and _matched:
		Game.goto(Game.SCENE_FIGHT)

func _show_versus() -> void:
	for side in [1, 2]:
		var r := FighterRenderer.new()
		add_child(r)
		r.setup(Game.p1_data() if side == 1 else Game.p2_data())
		r.position = Vector2(100 if side == 1 else 326, 190)
		r.scale.x = 1 if side == 1 else -1
		_previews.append(r)

func _unhandled_input(event: InputEvent) -> void:
	if _matched:
		return
	if event.is_action_pressed(&"ui_cancel"):
		Online.cancel()
		Game.drop_challenge()
		Game.goto(Game.SCENE_SELECT)
		get_viewport().set_input_as_handled()
	elif _error != "" and (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"p1_punch_light")):
		_search()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_t += delta
	# Un reto que el amigo no contesta no se espera para siempre.
	if Game.challenge_code != "" and not _matched and _error == "" and _t > CHALLENGE_WAIT:
		Online.cancel()
		Online.disconnect_from_server()
		Game.drop_challenge()
		_error = "%s NO RESPONDIÓ AL RETO" % Game.challenge_opponent.to_upper() if Game.challenge_opponent != "" else "NADIE RESPONDIÓ AL RETO"
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 240), HKTheme.INK)
	if _matched:
		HKTheme.draw_text(self, Vector2(0, 40), "¡RIVAL ENCONTRADO!", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
		HKTheme.draw_text(self, Vector2(0, 62), "DUELO CON RANKING" if Online.ranked else "AMISTOSO · SIN PUNTOS", 8,
			HKTheme.PAPER if Online.ranked else HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		HKTheme.draw_text(self, Vector2(0, 124), "VS", 32, HKTheme.BLOOD, HORIZONTAL_ALIGNMENT_CENTER, 426, 4)
		var mine := Game.p1_data() if Online.side == 1 else Game.p2_data()
		var theirs := Game.p2_data() if Online.side == 1 else Game.p1_data()
		HKTheme.draw_text(self, Vector2(0, 214), "TÚ: %s" % mine.short_name, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, 213, 1)
		HKTheme.draw_text(self, Vector2(213, 214), "%s: %s" % [Online.opponent_name, theirs.short_name], 8,
			HKTheme.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, 213, 1)
		return
	if _error != "":
		HKTheme.draw_text(self, Vector2(0, 84), "NO SE PUDO JUGAR ONLINE", 16, HKTheme.BLOOD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
		HKTheme.draw_text(self, Vector2(0, 116), _error, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		HKTheme.draw_text(self, Vector2(0, 150), "ENTER: REINTENTAR", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		HKTheme.draw_text(self, Vector2(0, 164), "ESC: VOLVER", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	var dots := ".".repeat(int(_t * 2.0) % 4)
	var connecting := Online.state == Online.State.CONNECTING
	var challenge := Game.challenge_code != ""
	HKTheme.draw_text(self, Vector2(0, 92), "RETO ENTRE AMIGOS" if challenge else "DUELO ONLINE", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	var waiting_for := "ESPERANDO A %s" % Game.challenge_opponent.to_upper() if Game.challenge_opponent != "" else "ESPERANDO AL AMIGO"
	HKTheme.draw_text(self, Vector2(0, 124), ("CONECTANDO" if connecting else (waiting_for if challenge else "BUSCANDO RIVAL")) + dots,
		8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	HKTheme.draw_text(self, Vector2(0, 150), "TU LUCHADOR: %s" % FighterRegistry.get_by_id(_my_id).short_name,
		8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	var who := "JUEGAS COMO: %s" % Backend.username().to_upper() if Backend.is_logged_in() else "INVITADO · SIN PUNTOS"
	if challenge:
		who = "AMISTOSO · SIN PUNTOS"
	HKTheme.draw_text(self, Vector2(0, 164), who, 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	HKTheme.draw_text(self, Vector2(0, 234), "ESC: CANCELAR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
