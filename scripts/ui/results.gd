## Pantalla de victoria: ganador en pose triunfal, marcador de rondas,
## frase de victoria y opciones de REVANCHA / CAMBIAR LUCHADOR / MENÚ.
extends Control

@onready var btn_rematch: Button = $Buttons/Rematch
@onready var btn_select: Button = $Buttons/Select
@onready var btn_menu: Button = $Buttons/Menu

## Segundos que se espera la confirmación de puntos antes de rendirse.
const SETTLE_WAIT := 40.0
## Online: lo que tardan en contarse los puntos y en avanzar la barra de liga.
const COUNT_TIME := 1.0
## Online: los botones bajan para dejar sitio a los puntos y la liga.
const ONLINE_BUTTONS_Y := 192.0

var _t: float = 0.0
var _winner_data: FighterData
## Modo Historia: qué toca después (next | complete | retry | over). Vacío en versus.
var _arcade: StringName = &""
## Online: lo que confirmó el servidor ({} mientras espera) y un aviso si no llegó.
var _settled: Dictionary = {}
var _online_note: String = ""
## Momento (_t) en que llegaron los puntos, para animarlos, y si ya sonó el aviso de cambio de liga.
var _settled_t: float = 0.0
var _league_sounded: bool = false
## Títulos de logros ganados con este duelo (se anuncian arriba).
var _new_titles: Array[String] = []
## Online con cuenta: qué hace el botón de revancha: "challenge" (reto de nuevo), "accept" (el rival ya me retó),
## "add" (todavía no somos amigos) o "" (no se ofrece).
var _rematch_mode: String = ""
var _incoming_code: String = ""
var _poll: float = 0.0
var _polling: bool = false

func _ready() -> void:
	theme = HKTheme.theme()
	get_tree().paused = false
	if Game.is_vs_cpu():
		_arcade = Game.arcade_outcome()
	_setup_buttons()
	if Game.is_online():
		$Buttons.position.y = ONLINE_BUTTONS_Y
		_finish_online()
		_setup_online_rematch()
	for b in [btn_rematch, btn_select, btn_menu]:
		b.text = HKTheme.fold(b.text)   # "MENÚ PRINCIPAL": la fuente no tiene la Ú mayúscula
		b.focus_entered.connect(func(): Sfx.play(&"select"))
		b.pressed.connect(func(): Sfx.play(&"confirm"))
	if Game.last_winner == 0:
		# Empate: los dos luchadores, en pose normal.
		_add_figure(Game.p1_data(), Vector2(70, 200), 1, &"idle")
		_add_figure(Game.p2_data(), Vector2(150, 200), -1, &"idle")
	else:
		_winner_data = Game.p1_data() if Game.last_winner == 1 else Game.p2_data()
		_add_figure(_winner_data, Vector2(104, 214), 2, &"victory")
	if btn_rematch.visible:
		btn_rematch.grab_focus()
	else:
		btn_menu.grab_focus()

## Versus: revancha / cambiar luchador. Arcade: siguiente combate, continuar
## (gasta una revancha) o solo volver al menú si se acabó la partida.
func _setup_buttons() -> void:
	btn_menu.pressed.connect(func(): Game.goto(Game.SCENE_MENU))
	if Game.is_online():
		# Sin revancha online todavía: hay que volver a buscar rival desde el menú.
		btn_rematch.visible = false
		btn_select.visible = false
		return
	if _arcade == &"":
		btn_rematch.pressed.connect(func(): Game.goto(Game.SCENE_FIGHT))
		btn_select.pressed.connect(func(): Game.goto(Game.SCENE_SELECT))
		return
	btn_select.visible = false
	match _arcade:
		&"next":
			# Se guarda ya, al ganar: si se recarga aquí, se retoma en el combate siguiente.
			Game.story_autosave_next()
			Game.story_record_win()
			btn_rematch.text = "SIGUIENTE COMBATE"
			btn_rematch.pressed.connect(func():
				Game.arcade_advance()
				Game.goto(Game.SCENE_STORY))
		&"complete":
			btn_rematch.text = "EL DESTINO"
			btn_rematch.pressed.connect(func(): Game.goto(Game.SCENE_STORY_ENDING))
		&"retry":
			# La revancha se descuenta ya, al perder: recargar no la devuelve.
			Game.story_autosave_retry()
			btn_rematch.text = "CONTINUAR (%d)" % Game.arcade_continues
			btn_rematch.pressed.connect(func():
				Game.arcade_use_continue()
				Game.goto(Game.SCENE_FIGHT))
		_:
			# Sin revanchas: la historia terminó, no queda nada que retomar.
			Backend.clear_story(str(Game.p1_fighter_id))
			btn_rematch.visible = false

## Duelo online: dice al servidor cómo terminó y espera a que confirme los puntos.
## La conexión se mantiene hasta entonces: el rival puede ir unos ticks por detrás y el
## servidor necesita los dos reportes para guardar el duelo.
func _finish_online() -> void:
	Online.report_result(Game.last_winner, Game.last_p1_rounds, Game.last_p2_rounds)
	if not Online.last_settled.is_empty():
		_on_settled(Online.last_settled)   # p. ej. el rival abandonó y ya se resolvió
		return
	if Online.state == Online.State.IDLE:
		_online_note = "SIN CONEXIÓN CON EL SERVIDOR"
		return
	Online.settled.connect(_on_settled, CONNECT_ONE_SHOT)
	await get_tree().create_timer(SETTLE_WAIT).timeout
	if is_inside_tree() and _settled.is_empty():
		_online_note = "SIN CONFIRMACIÓN DEL SERVIDOR"
		Online.disconnect_from_server()

## Con cuenta y un rival que también la tiene: REVANCHA (reto privado, amistoso) si ya sois amigos, o AGREGAR AMIGO.
func _setup_online_rematch() -> void:
	var rival := Online.opponent_name
	if not Backend.is_logged_in() or rival == "" or rival == "INVITADO":
		return
	await Backend.fetch_friends()
	if not is_inside_tree():
		return
	match Backend.friend_status(rival):
		"friend": _set_rematch("challenge", "REVANCHA")
		"outgoing": _set_rematch("", "SOLICITUD ENVIADA")
		"incoming": _set_rematch("add", "ACEPTAR AMISTAD")
		_: _set_rematch("add", "AGREGAR AMIGO")
	btn_rematch.visible = true
	btn_rematch.pressed.connect(_on_online_rematch)
	btn_rematch.focus_entered.connect(func(): Sfx.play(&"select"))
	btn_rematch.pressed.connect(func(): Sfx.play(&"confirm"))

func _set_rematch(mode: String, text: String) -> void:
	_rematch_mode = mode
	btn_rematch.text = text
	btn_rematch.disabled = mode == ""

func _on_online_rematch() -> void:
	var rival := Online.opponent_name
	match _rematch_mode:
		"accept":
			_enter_challenge(_incoming_code, rival)
		"challenge":
			var r := await Backend.create_challenge(rival)
			if not r.ok:
				_online_note = r.error
				return
			_enter_challenge(r.code, rival)
		"add":
			var r := await Backend.request_friend(rival)
			if not r.ok:
				_online_note = r.error
			elif r.result == "accepted" or r.result == "already_friends":
				_set_rematch("challenge", "REVANCHA")
			else:
				_set_rematch("", "SOLICITUD ENVIADA")

## Pasa a elegir luchador para el reto (amistoso, sin puntos).
func _enter_challenge(code: String, rival: String) -> void:
	Online.disconnect_from_server()
	Game.challenge_code = code
	Game.challenge_opponent = rival
	Game.mode = Game.Mode.ONLINE
	Game.goto(Game.SCENE_SELECT)

## Mira si el rival ya me ha retado a la revancha (con espera larga: el botón cambia en cuanto me reta).
func _check_rematch_challenge() -> void:
	_polling = true
	var list := await Backend.fetch_challenges(Backend.CHALLENGE_WAIT)
	if not is_inside_tree():
		return
	_polling = false
	if _rematch_mode != "challenge":
		return
	for c in list:
		if str(c.get("from", "")).to_lower() == Online.opponent_name.to_lower():
			_incoming_code = str(c.get("code", ""))
			_set_rematch("accept", "ACEPTAR REVANCHA")
			return

func _on_settled(msg: Dictionary) -> void:
	_settled = msg
	_settled_t = _t
	Backend.apply_settled(msg)
	Online.disconnect_from_server()
	if Backend.is_logged_in() and msg.get("ranked", false) and msg.get("ok", false):
		var fresh := await Cosmetics.refresh_achievements()
		if is_inside_tree():
			_new_titles = fresh

func _add_figure(d: FighterData, pos: Vector2, s: int, pose: StringName) -> void:
	var r := FighterRenderer.new()
	add_child(r)
	move_child(r, 1)
	r.setup(d)
	r.position = pos
	r.scale = Vector2(s, absi(s))
	r.pose_name = pose

func _process(delta: float) -> void:
	_t += delta
	_poll += delta
	if _poll >= 3.0 and _rematch_mode == "challenge" and not _polling:
		_poll = 0.0
		_check_rematch_challenge()
	queue_redraw()

func _draw() -> void:
	var x0 := 208.0
	var w := 210.0
	if Game.last_winner == 0:
		HKTheme.draw_text(self, Vector2(x0, 40), "DRAW", 24, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, w, 4)
		HKTheme.draw_text(self, Vector2(x0, 56), "¡EMPATE HISTÓRICO!", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
	else:
		var pulse := HKTheme.GOLD.lerp(Color("fff0a0"), 0.5 + 0.5 * sin(_t * 4.0))
		var title := "PLAYER %d WINS" % Game.last_winner
		if _arcade != &"":
			title = "YOU WIN" if Game.last_winner == 1 else "CPU WINS"
		elif Game.is_online():
			title = "YOU WIN" if Game.last_winner == Online.side else "YOU LOSE"
		HKTheme.draw_text(self, Vector2(x0, 36), title, 16, pulse, HORIZONTAL_ALIGNMENT_CENTER, w, 4)
		HKTheme.draw_text(self, Vector2(x0, 54), _winner_data.display_name, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, w)
		_draw_wrapped(Vector2(x0 + 8, 92), "\"%s\"" % _winner_data.victory_quote, w - 16, Color("e8d8b8"))
	HKTheme.draw_text(self, Vector2(x0, 74), "RONDAS  %d - %d" % [Game.last_p1_rounds, Game.last_p2_rounds], 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)
	if _arcade != &"":
		HKTheme.draw_text(self, Vector2(x0, 18), _arcade_status(), 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
		var epilogue := _epilogue()
		for i in epilogue.size():
			HKTheme.draw_text(self, Vector2(x0, 150 + i * 11), epilogue[i], 8, Color("fff0a0"), HORIZONTAL_ALIGNMENT_CENTER, w, 1)
	if Game.is_online():
		_draw_online_points(x0, w)
		if not _new_titles.is_empty():
			var names := _new_titles.map(func(k): return Cosmetics.title_name(k))
			HKTheme.draw_text(self, Vector2(0, 14), "¡TÍTULO NUEVO! %s" % " · ".join(PackedStringArray(names)), 8,
				HKTheme.GOLD.lerp(Color.WHITE, 0.3 + 0.3 * sin(_t * 6.0)), HORIZONTAL_ALIGNMENT_CENTER, 426, 2)

## Puntos del duelo online: pendiente, no registrado o amistoso; o los puntos ganados/perdidos contándose,
## la barra de liga avanzando desde los puntos de antes y, al acabar, el aviso si se cambió de liga.
func _draw_online_points(x0: float, w: float) -> void:
	var y := 136.0
	if _settled.is_empty():
		var text := _online_note if _online_note != "" else "GUARDANDO RESULTADO..."
		HKTheme.draw_text(self, Vector2(x0, y), text, 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w, 1)
		return
	if not _settled.get("ranked", false):
		HKTheme.draw_text(self, Vector2(x0, y), "AMISTOSO · SIN PUNTOS", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w, 1)
		return
	if not _settled.get("ok", false):
		HKTheme.draw_text(self, Vector2(x0, y), "DUELO NO REGISTRADO", 8, HKTheme.BLOOD, HORIZONTAL_ALIGNMENT_CENTER, w, 1)
		HKTheme.draw_text(self, Vector2(x0, y + 11), _not_saved_reason(str(_settled.get("reason", ""))), 8,
			HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w, 1)
		return
	var delta := int(_settled.get("delta", 0))
	var points := int(_settled.get("points", 0))
	var k := clampf((_t - _settled_t) / COUNT_TIME, 0.0, 1.0)
	var shown := roundi(delta * k)
	var now := points - delta + shown
	var color := Color("60d060") if delta > 0 else (HKTheme.BLOOD if delta < 0 else HKTheme.PAPER)
	HKTheme.draw_text(self, Vector2(x0, y), "%+d PUNTOS" % shown, 16, color, HORIZONTAL_ALIGNMENT_CENTER, w, 3)
	# Por abandono, el aviso ocupa el sitio del récord (los dos no caben en una línea).
	var record := "%dV %dD" % [int(_settled.get("wins", 0)), int(_settled.get("losses", 0))]
	if _settled.get("reason", "") == "forfeit":
		record = "POR ABANDONO"
	HKTheme.draw_text(self, Vector2(x0, y + 13), "TOTAL %d · %s" % [now, record], 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, w, 1)
	# Barra de liga con los puntos que se van contando.
	var league := League.info(now)
	var bar := Rect2(x0 + 16, y + 26, w - 32, 4)
	draw_rect(bar, HKTheme.INK)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(league["progress"]), bar.size.y)), league["color"])
	HKTheme.draw_text(self, Vector2(bar.position.x, y + 40), league["name"], 8, league["color"], HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var next_name := str(league["next_name"])
	HKTheme.draw_text(self, Vector2(bar.position.x, y + 40), "%d PARA %s" % [int(league["to_next"]), next_name] if next_name != "" else "LIGA MÁXIMA",
		8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x, 1)
	# Al terminar de contar: el aviso de cambio de liga, que late si se sube.
	var change := League.change_text(points - delta, points)
	if k < 1.0 or change == "":
		return
	if not _league_sounded:
		_league_sounded = true
		Sfx.play(&"round" if delta > 0 else &"denied")
	var up := delta > 0
	var c: Color = league["color"].lerp(Color.WHITE, 0.35 + 0.35 * sin(_t * 6.0)) if up else HKTheme.MUTED
	HKTheme.draw_text(self, Vector2(x0, y + 52), change, 8, c, HORIZONTAL_ALIGNMENT_CENTER, w, 2)

func _not_saved_reason(reason: String) -> String:
	match reason:
		"mismatch": return "LOS RESULTADOS NO COINCIDEN"
		"timeout": return "EL RIVAL NO CONFIRMÓ A TIEMPO"
		"too_short": return "DUELO DEMASIADO CORTO"
		"stalled": return "NADIE RESPONDIÓ: DUELO ANULADO"
	return "ERROR DEL SERVIDOR"

## Líneas finales al ganar el último combate del modo Historia.
func _epilogue() -> PackedStringArray:
	match _arcade:
		&"complete":
			return PackedStringArray(["¡VENCISTE AL NEXO!", "EL TIEMPO ESPERA TU DECISIÓN"])
	return PackedStringArray()

func _arcade_status() -> String:
	var fight := "COMBATE %d/%d" % [Game.arcade_stage + 1, Game.arcade_ladder.size()]
	match _arcade:
		&"complete":
			return "¡HISTORIA COMPLETADA!"
		&"over":
			return "FIN DEL JUEGO · %s" % fight
	return "%s · %s" % [fight, Game.difficulty_name()]

func _draw_wrapped(pos: Vector2, text: String, width: float, color: Color) -> void:
	var line := ""
	var y := pos.y
	for word in text.split(" "):
		var test: String = word if line.is_empty() else line + " " + word
		if HKTheme.text_width(test, 8) > width and not line.is_empty():
			HKTheme.draw_text(self, Vector2(pos.x, y), line, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
			y += 11
			line = word
		else:
			line = test
	if not line.is_empty():
		HKTheme.draw_text(self, Vector2(pos.x, y), line, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
