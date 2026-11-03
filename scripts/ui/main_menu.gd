## Menú principal en dos niveles:
##   arriba, grandes  MODO HISTORIA, DUELO ONLINE, ENTRENAMIENTO y el selector DIFICULTAD < > ;
##   abajo, en fila   PERSONAJES · CONTROLES · AJUSTES · CRÉDITOS.
## MODO HISTORIA (1 jugador contra la CPU, de hoy al origen) y DUELO ONLINE (contra otra persona por
## internet) llevan a la selección de luchador. DIFICULTAD se cambia con izquierda/derecha (o pulsándolo).
## ENTRENAMIENTO solo aparece en el editor (desarrollo).
## Un solo botón resaltado (el ratón mueve el foco) con un cursor que rebota; de fondo, un duelo
## entre dos luchadores al azar que cambia cada pocos segundos (MenuDuel).
extends Control

@onready var btn_continue: Button = $Buttons/Continue
@onready var btn_play: Button = $Buttons/Play
@onready var btn_online: Button = $Buttons/Online
@onready var btn_training: Button = $Buttons/Training
@onready var btn_difficulty: Button = $Buttons/Difficulty
@onready var btn_roster: Button = $Buttons/Extras/Roster
@onready var btn_controls: Button = $Buttons/Extras/Controls
@onready var btn_settings: Button = $Buttons/Extras/Settings
@onready var btn_credits: Button = $Buttons/Extras/Credits
@onready var footer: Label = $Footer

## Capa por encima de todo donde se dibuja el cursor del botón con foco.
var _cursor_layer: Control
var _t: float = 0.0
## Botón que tenía el foco en el fotograma anterior (para el rebote al cambiar).
var _last_focus: Control
var _bounce: float = 0.0
## Botón AMIGOS de la esquina (con sesión): avisa de las solicitudes por contestar.
var _friends_btn: Button
## Aviso de reto de un amigo (encima de todo). Se pregunta al servidor con espera larga (contesta en cuanto
## alguien me reta); CHALLENGE_POLL es lo mínimo entre una pregunta y la siguiente (si el servidor no espera).
const CHALLENGE_POLL := 5.0
var _challenge_box: Control
var _challenge_until: float = 0.0
var _poll_t: float = CHALLENGE_POLL   # la primera pregunta, nada más abrir el menú
var _polling: bool = false

func _ready() -> void:
	theme = HKTheme.theme()
	get_tree().paused = false
	footer.text = "v%s" % Game.VERSION
	btn_continue.pressed.connect(_continue_story)
	btn_play.pressed.connect(func(): _go_select(Game.Mode.ARCADE))
	btn_online.pressed.connect(func(): _go_select(Game.Mode.ONLINE))
	btn_training.pressed.connect(func(): _go_select(Game.Mode.TRAINING))
	btn_difficulty.pressed.connect(_cycle_difficulty)
	btn_roster.pressed.connect(_show_roster)
	btn_controls.pressed.connect(func(): Game.goto(Game.SCENE_CONTROLS))
	btn_settings.pressed.connect(func(): Game.goto(Game.SCENE_SETTINGS))
	btn_credits.pressed.connect(_show_credits)
	btn_credits.text = HKTheme.fold(btn_credits.text)   # la fuente no tiene la É mayúscula
	_refresh_difficulty()
	# ENTRENAMIENTO es una herramienta de desarrollo: solo se ve al correr desde el editor.
	btn_training.visible = OS.has_feature("editor")
	for b in [btn_continue, btn_play, btn_online, btn_training, btn_difficulty, btn_roster, btn_controls, btn_settings, btn_credits]:
		_single_highlight(b)
	btn_difficulty.gui_input.connect(_on_difficulty_input)
	_spawn_duel()
	_build_account_button()
	_cursor_layer = Control.new()
	_cursor_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cursor_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_layer.draw.connect(_draw_cursor)
	add_child(_cursor_layer)
	btn_play.grab_focus()
	_show_saved_story(Backend.story_local())
	if Backend.is_logged_in():
		# La partida de la cuenta puede ser más nueva que la de este equipo (otro PC).
		_show_saved_story(await Backend.load_story())
		await Backend.sync_unlocks()
		# Títulos de logros cumplidos en otro equipo (los de aquí se dan al terminar el duelo).
		await Cosmetics.refresh_achievements()
		await _check_season_end()
		await _refresh_friends_badge()

## Un solo botón resaltado: pasar el ratón por encima le da el foco, y el estilo "hover"
## es el normal, así nunca hay dos botones con marco dorado a la vez.
func _single_highlight(b: Button) -> void:
	b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))
	b.add_theme_color_override("font_hover_color", HKTheme.PAPER)
	b.mouse_entered.connect(func():
		if b.is_visible_in_tree() and not b.has_focus():
			b.grab_focus())
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	b.pressed.connect(func(): Sfx.play(&"confirm"))

func _process(delta: float) -> void:
	_t += delta
	_poll_t += delta
	if Backend.is_logged_in() and _challenge_box == null and not _polling and _poll_t >= CHALLENGE_POLL:
		_poll_t = 0.0
		_check_challenges()
	if _challenge_box != null and _t > _challenge_until:
		_close_challenge()
	var f := get_viewport().gui_get_focus_owner()
	if f != _last_focus:
		_last_focus = f
		_bounce = 1.0
	_bounce = maxf(_bounce - delta * 5.0, 0.0)
	_cursor_layer.queue_redraw()

## Cursor ">" que late a la izquierda del botón con foco (y "<" a la derecha). En la fila de
## abajo los botones van pegados, así que ahí es una marca dorada bajo el botón.
func _draw_cursor() -> void:
	var f := get_viewport().gui_get_focus_owner() as Control
	if f == null or not f.is_visible_in_tree():
		return
	var r := f.get_global_rect()
	if f.get_parent() is HBoxContainer:
		var w := r.size.x * (0.5 + 0.15 * sin(_t * 8.0)) + _bounce * 8.0
		_cursor_layer.draw_rect(Rect2(r.get_center().x - w * 0.5, r.end.y + 2.0, w, 2.0), HKTheme.GOLD)
		return
	var off := 3.0 + sin(_t * 8.0) * 1.5 + _bounce * 6.0
	var y := r.position.y + r.size.y * 0.5 + 4.0
	HKTheme.draw_text(_cursor_layer, Vector2(r.position.x - 9.0 - off, y), ">", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	HKTheme.draw_text(_cursor_layer, Vector2(r.end.x + 2.0 + off, y), "<", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)

## Izquierda / derecha sobre DIFICULTAD cambian el nivel sin mover el foco.
func _on_difficulty_input(event: InputEvent) -> void:
	var step := 0
	if event.is_action_pressed(&"ui_left"):
		step = -1
	elif event.is_action_pressed(&"ui_right"):
		step = 1
	if step != 0:
		Game.cycle_difficulty(step)
		_refresh_difficulty()
		Sfx.play(&"select")
		_bounce = 1.0
		btn_difficulty.accept_event()

## Botones cortos en las esquinas de arriba (el título ocupa el centro): RANKING a la izquierda
## y PERFIL / ENTRAR a la derecha. Con sesión, abajo a la derecha se lee "NOMBRE · PUNTOS".
## Solo existen si el servidor responde y tiene cuentas.
func _build_account_button() -> void:
	if not Backend.is_configured():
		return
	_corner_button("RANKING", Vector2(4, 4), func(): Game.goto(Game.SCENE_RANKING))
	if Backend.is_logged_in():
		_friends_btn = _corner_button("AMIGOS", Vector2(4, 22), func(): Game.goto(Game.SCENE_FRIENDS))
	_corner_button("PERFIL" if Backend.is_logged_in() else "ENTRAR", Vector2(338, 4), _on_account_pressed)
	if Backend.is_logged_in():
		var who := Label.new()
		who.text = "%s · %d PTS" % [Backend.username().to_upper().left(14), int(Backend.profile.get("points", 0))]
		who.position = Vector2(196, 228)
		who.size = Vector2(226, 10)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		who.add_theme_color_override("font_color", HKTheme.GOLD)
		add_child(who)

## Pregunta si algún amigo me ha retado y, si es así, lo avisa.
func _check_challenges() -> void:
	_polling = true
	var list := await Backend.fetch_challenges(Backend.CHALLENGE_WAIT)
	if not is_inside_tree():
		return
	_polling = false
	if list.is_empty() or _challenge_box != null:
		return
	_show_challenge(list[0])

## Caja sobre el menú: "ANA TE RETA" con ACEPTAR y RECHAZAR. El menú de debajo se apaga mientras tanto.
func _show_challenge(c: Dictionary) -> void:
	_open_box(78.0, float(c.get("expires_in", 60)))
	var who := str(c.get("from", "")).to_upper()
	_box_label("%s TE RETA A UN DUELO" % who, 94, HKTheme.GOLD)
	_box_label("AMISTOSO: NO MUEVE PUNTOS", 110, HKTheme.MUTED)
	var accept := _box_button("ACEPTAR", Vector2(108, 134))
	var reject := _box_button("RECHAZAR", Vector2(218, 134))
	accept.pressed.connect(func():
		Game.challenge_code = str(c.get("code", ""))
		Game.challenge_opponent = str(c.get("from", ""))
		Game.mode = Game.Mode.ONLINE
		Game.goto(Game.SCENE_SELECT))
	reject.pressed.connect(func():
		Backend.cancel_challenge(str(c.get("code", "")))
		_close_challenge())
	Sfx.play(&"confirm")
	accept.grab_focus()

## Si terminó una temporada desde la última vez, avisa de cómo acabaste y lo que ganaste (una vez por cuenta).
func _check_season_end() -> void:
	var list: Variant = await Backend.fetch_my_seasons()
	if not list is Array or (list as Array).is_empty() or not is_inside_tree() or _challenge_box != null:
		return
	var last: Dictionary = list[0]
	var season := str(last.get("season", ""))
	# "AAAA-MM" se ordena bien como texto.
	if season <= Season.last_seen(Backend.user_id):
		return
	Season.mark_seen(Backend.user_id, season)
	_show_season_end(last)

func _show_season_end(r: Dictionary) -> void:
	_open_box(104.0, 3600.0)
	# Dos líneas: con un mes largo ("NOVIEMBRE") el título en una sola no cabe en la caja.
	_box_label("FIN DE LA TEMPORADA", 92, HKTheme.GOLD)
	_box_label(Season.name_of(str(r.get("season", ""))), 103, HKTheme.GOLD)
	var y := 117.0
	for line in Season.summary(r):
		_box_label(line, y, HKTheme.PAPER)
		y += 12.0
	_box_label("TUS PUNTOS SE ACERCAN A 1000", 152, HKTheme.MUTED)
	var ok := _box_button("ACEPTAR", Vector2(163, 166))
	ok.pressed.connect(_close_challenge)
	Sfx.play(&"round")
	ok.grab_focus()

## Abre la caja (alto `height`) sobre el menú, que se apaga mientras tanto; se cierra sola a los `seconds`.
func _open_box(height: float, seconds: float) -> void:
	$Buttons.process_mode = Node.PROCESS_MODE_DISABLED
	_challenge_until = _t + seconds
	_challenge_box = Control.new()
	_challenge_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_challenge_box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_challenge_box.add_child(dim)
	# Un recuadro sólido para que el menú de detrás no se mezcle con el texto.
	var border := ColorRect.new()
	border.color = HKTheme.GOLD_DARK
	border.position = Vector2(79, 83)
	border.size = Vector2(268, height)
	_challenge_box.add_child(border)
	var inner := ColorRect.new()
	inner.color = HKTheme.INK
	inner.position = Vector2(80, 84)
	inner.size = Vector2(266, height - 2.0)
	_challenge_box.add_child(inner)

func _box_label(text: String, y: float, color: Color) -> void:
	var l := Label.new()
	l.text = HKTheme.fold(text)   # la fuente no tiene mayúsculas acentuadas
	l.position = Vector2(0, y)
	l.size = Vector2(426, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	_challenge_box.add_child(l)

func _box_button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(100, 14)
	_challenge_box.add_child(b)
	b.size = Vector2(100, 14)   # tras añadirlo: ya tiene el tema
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	return b

func _close_challenge() -> void:
	if _challenge_box != null:
		_challenge_box.queue_free()
		_challenge_box = null
	$Buttons.process_mode = Node.PROCESS_MODE_INHERIT
	btn_play.grab_focus()

## "AMIGOS (2)" si hay solicitudes de amistad por contestar.
func _refresh_friends_badge() -> void:
	var list: Variant = await Backend.fetch_friends()
	if list == null or _friends_btn == null or not is_instance_valid(_friends_btn):
		return
	var pending := FriendsScreen.pending_count(list)
	_friends_btn.text = "AMIGOS (%d)" % pending if pending > 0 else "AMIGOS"

func _corner_button(text: String, pos: Vector2, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(84, 14)
	b.pressed.connect(func():
		Sfx.play(&"confirm")
		on_press.call())
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	add_child(b)
	b.size = Vector2(84, 14)   # tras añadirlo: ya tiene el tema
	return b

func _on_account_pressed() -> void:
	if Backend.is_logged_in():
		Game.goto(Game.SCENE_PROFILE)
		return
	Backend.guest = false
	Game.goto(Game.SCENE_LOGIN)

## Duelo de fondo con dos luchadores al azar (detrás de los botones).
func _spawn_duel() -> void:
	var duel := MenuDuel.new()
	add_child(duel)
	move_child(duel, 1)

## Muestra CONTINUAR HISTORIA si hay una partida guardada válida ({} = no hay).
func _show_saved_story(save: Dictionary) -> void:
	if not is_inside_tree():
		return
	var valid := _story_is_valid(save)
	btn_continue.visible = valid
	btn_play.text = "NUEVA HISTORIA" if valid else "MODO HISTORIA"
	if not valid:
		return
	btn_continue.text = "CONTINUAR · COMBATE %d/%d" % [int(save["stage"]) + 1, FighterRegistry.all().size()]
	if not btn_continue.has_focus() and get_viewport().gui_get_focus_owner() == btn_play:
		btn_continue.grab_focus()

func _story_is_valid(save: Dictionary) -> bool:
	if save.is_empty():
		return false
	for d in FighterRegistry.all():
		if str(d.id) == str(save.get("fighter", "")):
			# Un combate por rival y el Nexo al final.
			return int(save.get("stage", -1)) >= 0 and int(save["stage"]) < FighterRegistry.all().size()
	return false

func _continue_story() -> void:
	var save := Backend.story_local() if not Backend.is_logged_in() else await Backend.load_story()
	if Game.story_resume(save):
		Game.goto(Game.SCENE_STORY)
	else:
		# La partida ya no sirve (versión distinta del juego): se descarta y se vuelve a empezar.
		Backend.clear_story()
		_show_saved_story({})

func _go_select(mode: Game.Mode) -> void:
	Game.mode = mode
	Game.goto(Game.SCENE_SELECT)

func _cycle_difficulty() -> void:
	Game.cycle_difficulty()
	_refresh_difficulty()

func _refresh_difficulty() -> void:
	btn_difficulty.text = "DIFICULTAD  < %s >" % Game.difficulty_name()

func _show_roster() -> void:
	Game.goto(Game.SCENE_ROSTER)

func _show_credits() -> void:
	Game.goto(Game.SCENE_CREDITS)
