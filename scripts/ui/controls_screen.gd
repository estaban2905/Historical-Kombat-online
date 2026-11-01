## Pantalla CONTROLES, con tres páginas (botón o TAB para cambiar):
##   TECLAS       qué hace cada tecla y, a la derecha, un luchador que ejecuta lo
##                que se pulsa (en cámara lenta) y explica cómo se bloquea.
##   MOVIMIENTOS  cómo se hacen los movimientos (correr, backdash, salto, barrido,
##                ataque aéreo, antiaéreo, especiales).
##   DEFENSA      bloqueo de pie y agachado, guardia, combos, counter-hit, agarre.
## Las teclas se leen del Input Map, así que siempre coinciden con el juego, y
## se pueden ver las del jugador 1 o las del 2.
## Se abre desde el menú principal (escena) o desde la pausa (overlay = true).
extends Control

signal closed

enum Page { KEYS, MOVES, DEFENSE }

const PANEL_Y := 24.0
const PANEL_BOTTOM := 204.0
const KEYS_X := 6.0
const KEYS_W := 240.0
const STAGE_X := 250.0
const STAGE_W := 170.0
const MOVES_X := 6.0
const MOVES_W := 414.0
const FLOOR_Y := 168.0
## El muñeco se dibuja inclinado hacia delante: se corre un poco a la izquierda para centrarlo.
const FIGHTER_X := STAGE_X + STAGE_W * 0.5 - 10.0
## Columna de los textos en la página de teclas.
const KEY_LABEL_X := KEYS_X + 82.0
const FIGHTER_SCALE := 1.25
## Altura de las teclas dibujadas y de cada fila de las listas.
const CAP_H := 12.0
const KEY_ROW_H := 14.0
const MOVE_ROW_H := 13.0

## Cámara lenta de la demo: multiplicador de los frames de cada fase del ataque.
const SLOW_STARTUP := 4.0
const SLOW_ACTIVE := 4.0
const SLOW_RECOVERY := 3.0
const MIN_ACTIVE := 10.0
const JUMP_TIME := 0.7
const JUMP_HEIGHT := 46.0
const DOUBLE_TAP_MSEC := 250
const DASH_TIME := 0.45
const DASH_DISTANCE := 26.0
## Puño débil y patada débil pulsados con menos de este margen = agarre.
const GRAB_MSEC := 100

const RED := Color("c03838")
const BLUE := Color("3a6ec0")
const GREEN := Color("38a050")
const GRAY := Color("6a6270")
const PURPLE := Color("8a58c0")
const BLUE_TEXT := Color("5aa0ff")
const ARROWS := {KEY_UP: "ARR_U", KEY_DOWN: "ARR_D", KEY_LEFT: "ARR_L", KEY_RIGHT: "ARR_R"}

## Acciones que reaccionan al pulsarlas (no al mantenerlas).
const ATTACKS: Array[StringName] = [&"punch_light", &"punch_heavy", &"special_1", &"kick_light", &"kick_heavy", &"special_2"]

## Página TECLAS: [acciones, texto, color]. Una fila por tecla.
const KEY_ROWS := [
	[[&"jump"], "SALTAR", GREEN],
	[[&"crouch"], "AGACHARSE", GREEN],
	[[&"left", &"right"], "MOVERSE", GREEN],
	[[&"block"], "BLOQUEAR", GRAY],
	[[&"punch_light"], "PUÑO DÉBIL", RED],
	[[&"punch_heavy"], "PUÑO FUERTE", RED],
	[[&"kick_light"], "PATADA DÉBIL", BLUE],
	[[&"kick_heavy"], "PATADA FUERTE", BLUE],
	[[&"special_1"], "ESPECIAL 1", HKTheme.GOLD],
	[[&"special_2"], "ESPECIAL 2", HKTheme.GOLD],
]

const PAGE_NAMES: Array[String] = ["TECLAS", "MOVIMIENTOS", "DEFENSA"]

## Si es true, se muestra encima de otra pantalla y VOLVER emite `closed`.
var overlay: bool = false

var _page: Page = Page.KEYS
## Jugador cuyas teclas se muestran y que maneja la demo (1 o 2).
var _player: int = 1
var _btn_page: Button
var _btn_player: Button
var _btn_fighter: Button
var _btn_back: Button
var _fighter: FighterRenderer
var _roster: Array[FighterData]
var _roster_idx: int = 0

# Estado de la demo
var _attack: AttackData
var _attack_pose: StringName = &""
var _attack_frames: float = 0.0
var _jump_t: float = -1.0
var _caption: String = ""
## Segunda línea bajo el nombre del movimiento: cómo se bloquea, qué gasta...
var _hint: String = ""
var _hint_color: Color = HKTheme.PAPER
## Doble toque para correr: última dirección pulsada (-1/1) y cuándo (ms).
var _tap_dir: int = 0
var _tap_msec: int = -10000
var _run_dir: int = 0
## Progreso (0..1) de la demo del backdash; -1 = sin backdash.
var _dash_t: float = -1.0
## Cuándo se pulsó por última vez puño débil y patada débil (para el agarre).
var _light_msec := {&"punch_light": -10000, &"kick_light": -10000}
## Partículas de la demo (polvo, chispas, estela...) y lo que recuerdan del frame anterior.
var _fx: ParticleFX
var _fx_t: float = 0.0
var _was_airborne: bool = false
var _was_active: bool = false
var _was_block: bool = false

func _ready() -> void:
	theme = HKTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	bg.show_title = false
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Un hijo se dibuja encima del padre; así el fondo queda detrás de los paneles.
	bg.show_behind_parent = true
	add_child(bg)

	_roster = FighterRegistry.all()
	var current := Game.p1_data()
	_roster_idx = maxi(_roster.find(current), 0)
	_fighter = FighterRenderer.new()
	_fighter.position = Vector2(FIGHTER_X, FLOOR_Y)
	_fighter.scale = Vector2(FIGHTER_SCALE, FIGHTER_SCALE)
	add_child(_fighter)
	_fighter.setup(_roster[_roster_idx])
	_fx = ParticleFX.new()
	_fx.floor_y = FLOOR_Y
	add_child(_fx)

	var row := HBoxContainer.new()
	row.position = Vector2(14, 222)
	row.size = Vector2(398, 16)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_btn_page = _add_button(row, "", 124)
	_btn_page.pressed.connect(_toggle_page)
	_btn_player = _add_button(row, "", 84)
	_btn_player.pressed.connect(_toggle_player)
	_btn_fighter = _add_button(row, "", 104)
	_btn_fighter.pressed.connect(_next_fighter)
	_btn_back = _add_button(row, "VOLVER", 72)
	_btn_back.pressed.connect(_close)
	_refresh()
	_btn_back.grab_focus()

func _add_button(parent: Control, text: String, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 16)
	b.clip_text = true
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	b.pressed.connect(func(): Sfx.play(&"confirm"))
	parent.add_child(b)
	return b

func _toggle_page() -> void:
	_page = ((int(_page) + 1) % PAGE_NAMES.size()) as Page
	_refresh()

func _toggle_player() -> void:
	_player = 2 if _player == 1 else 1
	_reset_demo()
	_refresh()

func _next_fighter() -> void:
	_roster_idx = (_roster_idx + 1) % _roster.size()
	_fighter.setup(_roster[_roster_idx])
	_reset_demo()
	_refresh()

func _reset_demo() -> void:
	_attack = null
	_caption = ""
	_hint = ""
	_jump_t = -1.0
	_run_dir = 0
	_dash_t = -1.0

func _refresh() -> void:
	# El botón nombra la página a la que lleva.
	_btn_page.text = PAGE_NAMES[(int(_page) + 1) % PAGE_NAMES.size()]
	_btn_player.text = "JUGADOR %d" % _player
	_btn_fighter.text = "< %s >" % _roster[_roster_idx].short_name.to_upper()
	# El luchador de prueba y sus partículas solo están en la página de teclas.
	_fighter.visible = _page == Page.KEYS
	_fx.visible = _page == Page.KEYS

func _close() -> void:
	if overlay:
		closed.emit()
		queue_free()
	else:
		Game.goto(Game.SCENE_MENU)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not Game.is_changing_scene():
		_close()
		get_viewport().set_input_as_handled()

## Se usa _input (y no _unhandled_input) para que ESPACIO (bloqueo) no active
## también el botón que tenga el foco.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code := key.physical_keycode
	if code == KEY_TAB:
		_toggle_page()
		Sfx.play(&"select")
		get_viewport().set_input_as_handled()
		return
	if _page != Page.KEYS:
		return
	for action in ATTACKS:
		if code == _key_for(action):
			_on_attack_key(action)
			get_viewport().set_input_as_handled()
			return
	# Las flechas del jugador 2 también mueven el foco de los botones: no se consumen.
	var consume := not ARROWS.has(code)
	if code == _key_for(&"jump") and _jump_t < 0.0:
		_jump_t = 0.0
	elif code == _key_for(&"left") or code == _key_for(&"right"):
		var dir := -1 if code == _key_for(&"left") else 1
		var now := Time.get_ticks_msec()
		if dir == _tap_dir and now - _tap_msec <= DOUBLE_TAP_MSEC:
			_attack = null
			if dir > 0:
				_run_dir = dir
				_caption = "CORRER"
				_set_hint("DOBLE TOQUE+MANTENER", HKTheme.GOLD)
			else:
				# Hacia atrás el doble toque es un backdash (no se corre hacia atrás).
				_run_dir = 0
				_dash_t = 0.0
				_caption = "BACKDASH"
				_set_hint("ESQUIVA UNOS FRAMES", HKTheme.GOLD)
			_tap_dir = 0
		else:
			_run_dir = 0
			_tap_dir = dir
			_tap_msec = now
	elif not code in [_key_for(&"crouch"), _key_for(&"block")]:
		return
	if consume:
		get_viewport().set_input_as_handled()

func _held(action: StringName) -> bool:
	var code := _key_for(action)
	return code != KEY_NONE and Input.is_physical_key_pressed(code as Key)

# =========================================================================
#  Demo del luchador
# =========================================================================
func _on_attack_key(action: StringName) -> void:
	var now := Time.get_ticks_msec()
	if _light_msec.has(action):
		_light_msec[action] = now
		var other := &"kick_light" if action == &"punch_light" else &"punch_light"
		if now - _light_msec[other] <= GRAB_MSEC and _jump_t < 0.0:
			_start_grab()
			return
	_start_attack(action)

func _start_grab() -> void:
	var atk := _fighter.data.get_attack(&"grab")
	_attack = atk
	_attack_frames = 0.0
	_attack_pose = atk.anim
	_caption = "AGARRE"
	_set_hint("ROMPE EL BLOQUEO", PURPLE.lightened(0.4))

func _start_attack(action: StringName) -> void:
	var atk := _fighter.data.get_attack(action)
	if atk == null:
		return
	_attack = atk
	_attack_frames = 0.0
	_caption = atk.display_name.to_upper()
	_attack_pose = atk.anim
	var airborne := _jump_t >= 0.0
	var crouching := _held(&"crouch") and not airborne
	if crouching and action == &"punch_heavy":
		_caption = "ANTIAÉREO"
		_set_hint("GANA A LOS SALTOS", RED.lightened(0.4))
		return
	if atk.kind == AttackData.Kind.KICK:
		if airborne:
			_attack_pose = &"air_kick"
		elif crouching:
			_attack_pose = &"sweep"
	elif atk.kind == AttackData.Kind.PUNCH and airborne:
		_attack_pose = &"air_punch"
	# Mismas reglas de nivel que Fighter.current_hit_level().
	var level := atk.hit_level
	if airborne:
		level = AttackData.HitLevel.OVERHEAD
	elif crouching and atk.kind == AttackData.Kind.KICK:
		level = AttackData.HitLevel.LOW
	if atk.energy_cost > 0.0:
		_set_hint("GASTA %d DE ENERGÍA" % int(atk.energy_cost), HKTheme.GOLD)
	elif level == AttackData.HitLevel.LOW:
		_set_hint("BAJO: CUBRE AGACHADO", BLUE.lightened(0.4))
	elif level == AttackData.HitLevel.OVERHEAD:
		_set_hint("ALTO: CUBRE DE PIE", RED.lightened(0.4))
	else:
		_set_hint("MEDIO: CUBRE IGUAL", HKTheme.PAPER)

func _set_hint(text: String, color: Color) -> void:
	_hint = text
	_hint_color = color

func _process(delta: float) -> void:
	if _page == Page.KEYS:
		_update_fighter(delta)
		_update_fx(delta)
	queue_redraw()

## Efectos de la demo: los mismos que en combate, disparados por la pose del luchador.
func _update_fx(delta: float) -> void:
	var f := _fighter
	var feet := Vector2(f.position.x, FLOOR_Y)
	var airborne := f.airborne
	if _was_airborne and not airborne:
		_fx.dust_land(feet)
	_was_airborne = airborne
	_fx_t += delta
	var pose := f.pose_name
	if not airborne and (pose == &"walk" or pose == &"run"):
		var every := 0.09 if pose == &"run" else 0.22
		if _fx_t >= every:
			_fx_t = 0.0
			_fx.dust_step(feet, 1 if f.moving_back else -1, pose == &"run")
			if pose == &"run":
				_fx.speed_lines(feet, -1 if f.moving_back else 1)
	var block := pose == &"block"
	if block and not _was_block:
		_fx.sparks(feet + Vector2(22, -50), 1)
	_was_block = block
	var active := _attack != null and f.phase == &"active"
	if active:
		var at := f.position + _attack.hitbox_offset * FIGHTER_SCALE
		if not _was_active:
			HitEffect.spawn(self, at + Vector2(8, 0), HitEffect.Type.HIT, _attack.effect_scale)
			if _attack.damage >= 10.0:
				_fx.hit_burst(at + Vector2(8, 0), 1, 1)
		if _attack.kind != AttackData.Kind.PUNCH and _fx_t >= 0.04:
			_fx_t = 0.0
			_fx.trail(at, Color("ffd040") if _attack.kind == AttackData.Kind.KICK else Color("ff7020"))
		if _attack_pose == &"sweep" and _fx_t >= 0.1:
			_fx_t = 0.0
			_fx.dust_sweep(feet, 1)
	_was_active = active

func _update_fighter(delta: float) -> void:
	var f := _fighter
	# Siempre mira a la derecha (hacia un rival imaginario): izquierda = retroceder.
	var dir := int(_held(&"right")) - int(_held(&"left"))
	if dir == 0 or dir != _run_dir:
		_run_dir = 0
	f.moving_back = dir < 0

	var height := 0.0
	if _jump_t >= 0.0:
		_jump_t += delta / JUMP_TIME
		if _jump_t >= 1.0:
			_jump_t = -1.0
		else:
			height = JUMP_HEIGHT * 4.0 * _jump_t * (1.0 - _jump_t)
	var airborne := _jump_t >= 0.0
	f.airborne = airborne
	var dash_x := 0.0
	if _dash_t >= 0.0:
		_dash_t += delta / DASH_TIME
		if _dash_t >= 1.0:
			_dash_t = -1.0
		else:
			# Se desliza hacia atrás y vuelve (solo es una demostración).
			dash_x = -DASH_DISTANCE * sin(_dash_t * PI)
	f.position.x = FIGHTER_X + dash_x
	f.crouched = _held(&"crouch") and not airborne
	f.height_above_floor = height
	f.position.y = FLOOR_Y - height * FIGHTER_SCALE
	f.phase = &""

	if _attack:
		var su := _attack.startup * SLOW_STARTUP
		var ac := maxf(_attack.active * SLOW_ACTIVE, MIN_ACTIVE)
		var re := _attack.recovery * SLOW_RECOVERY
		_attack_frames += delta * 60.0
		f.pose_name = _attack_pose
		if _attack_frames <= su:
			f.phase = &"startup"
			f.phase_t = _attack_frames / maxf(su, 1.0)
		elif _attack_frames <= su + ac:
			f.phase = &"active"
			f.phase_t = 1.0
		elif _attack_frames <= su + ac + re:
			f.phase = &"recovery"
			f.phase_t = (_attack_frames - su - ac) / maxf(re, 1.0)
		else:
			_attack = null
		if _attack:
			return
	if _dash_t >= 0.0:
		f.pose_name = &"run"
		f.moving_back = true
	elif _held(&"block") and not airborne:
		f.pose_name = &"block"
		if f.crouched:
			_caption = "BLOQUEO AGACHADO"
			_set_hint("PARA MEDIOS Y BAJOS", BLUE.lightened(0.4))
		else:
			_caption = "BLOQUEO DE PIE"
			_set_hint("PARA MEDIOS Y ALTOS", RED.lightened(0.4))
	elif airborne:
		f.pose_name = &"jump"
	elif f.crouched:
		f.pose_name = &"crouch"
	elif dir != 0:
		f.pose_name = &"run" if _run_dir != 0 else &"walk"
	else:
		f.pose_name = &"idle"

# =========================================================================
#  Datos de las teclas
# =========================================================================
## Código físico de la tecla de una acción del jugador mostrado.
func _key_for(action: StringName) -> int:
	return _key_of("p%d_%s" % [_player, action])

func _key_of(action_name: String) -> int:
	if not InputMap.has_action(action_name):
		return KEY_NONE
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return KEY_NONE

## Teclas de la pausa (comunes a los dos jugadores).
func _pause_keys() -> Array:
	var keys: Array = []
	for ev in InputMap.action_get_events(&"pause"):
		if ev is InputEventKey:
			keys.append((ev as InputEventKey).physical_keycode)
	return keys

func _label_for(code: int) -> String:
	if ARROWS.has(code):
		return ARROWS[code]
	match code:
		KEY_SPACE: return "ESPACIO"
		KEY_ENTER: return "ENTER"
		KEY_ESCAPE: return "ESC"
		KEY_NONE: return "?"
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return "NUM%d" % (code - KEY_KP_0)
	return OS.get_keycode_string(code).to_upper()

# =========================================================================
#  Dibujo
# =========================================================================
func _draw() -> void:
	HKTheme.draw_text(self, Vector2(0, 16), "CONTROLES", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	match _page:
		Page.KEYS:
			_draw_keys_page()
			_footer("PRUEBA LAS TECLAS  ·  TAB: SIGUIENTE PÁGINA", HKTheme.MUTED.lightened(0.3))
		Page.MOVES:
			_draw_rows_page("MOVIMIENTOS", _move_rows())
			_footer("SALTA AL PULSAR: MANTENER NO REPITE EL SALTO", HKTheme.PAPER)
		Page.DEFENSE:
			_draw_rows_page("DEFENSA Y COMBOS", _defense_rows())
			_footer("ALTO: CUBRE DE PIE · BAJO: AGACHADO · MEDIO: IGUAL", HKTheme.PAPER)

func _footer(text: String, color: Color) -> void:
	HKTheme.draw_text(self, Vector2(0, 215), text, 8, color, HORIZONTAL_ALIGNMENT_CENTER, 426, 2)

func _draw_panel(x: float, w: float, title: String) -> void:
	var r := Rect2(x, PANEL_Y, w, PANEL_BOTTOM - PANEL_Y)
	draw_rect(r, HKTheme.PANEL)
	draw_rect(r, HKTheme.GOLD_DARK, false, 1.0)
	HKTheme.draw_text(self, Vector2(x + 6, PANEL_Y + 11), title, 8, BLUE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	draw_rect(Rect2(x + 4, PANEL_Y + 15, w - 8, 1), HKTheme.GOLD_DARK)

# --- Página TECLAS ------------------------------------------------------------
func _draw_keys_page() -> void:
	_draw_panel(KEYS_X, KEYS_W, "TECLAS · JUGADOR %d" % _player)
	var y := PANEL_Y + 20.0
	for row in KEY_ROWS:
		var parts: Array = []
		for action in row[0]:
			if not parts.is_empty():
				parts.append(" ")
			parts.append(_key_for(action))
		_combo(Vector2(KEYS_X + 8, y), parts, row[2])
		HKTheme.draw_text(self, Vector2(KEY_LABEL_X, y + 9), row[1], 8, (row[2] as Color).lightened(0.45),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
		y += KEY_ROW_H
	var pause := _pause_keys()
	var parts: Array = []
	for code in pause:
		if not parts.is_empty():
			parts.append(" ")
		parts.append(code)
	_combo(Vector2(KEYS_X + 8, y), parts, GRAY)
	HKTheme.draw_text(self, Vector2(KEY_LABEL_X, y + 9), "PAUSA", 8, HKTheme.MUTED.lightened(0.45),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	_draw_stage()

func _draw_stage() -> void:
	_draw_panel(STAGE_X, STAGE_W, _fighter.data.short_name.to_upper().left(19))
	# Suelo de piedra
	draw_rect(Rect2(STAGE_X + 1, FLOOR_Y, STAGE_W - 2, PANEL_BOTTOM - FLOOR_Y - 1), Color("2a1a20"))
	draw_rect(Rect2(STAGE_X + 1, FLOOR_Y, STAGE_W - 2, 1), HKTheme.GOLD_DARK)
	var cx := STAGE_X + STAGE_W * 0.5
	if _caption == "":
		_caption_at(Vector2(cx, FLOOR_Y + 20), "PULSA UNA TECLA", HKTheme.MUTED)
		return
	_caption_at(Vector2(cx, FLOOR_Y + 15), _caption.left(20), HKTheme.GOLD)
	if _hint != "":
		_caption_at(Vector2(cx, FLOOR_Y + 28), _hint.left(20), _hint_color)

# --- Página MOVIMIENTOS -------------------------------------------------------
## Teclas del jugador mostrado, para armar las filas de las tablas.
func _row_keys() -> Dictionary:
	var keys := {}
	for action in [&"jump", &"crouch", &"left", &"right", &"block", &"punch_light", &"punch_heavy",
			&"kick_light", &"kick_heavy", &"special_1", &"special_2"]:
		keys[action] = _key_for(action)
	return keys

## Filas de la página MOVIMIENTOS: [movimiento, teclas (códigos y textos), nota, color].
func _move_rows() -> Array:
	var k := _row_keys()
	var data := _fighter.data
	return [
		["CAMINAR", [k.left, " ", k.right], "ATRÁS = MÁS LENTO", GREEN],
		["CORRER", [k.right, k.right], "DOBLE TOQUE ADELANTE", GREEN],
		["BACKDASH", [k.left, k.left], "DOBLE TOQUE ATRÁS: ESQUIVA", GREEN],
		["SALTAR", [k.jump, " +", k.right, "/", k.left], "PULSA, NO MANTENGAS", GREEN],
		["AGACHARSE", [k.crouch], "", GREEN],
		["BARRIDO (BAJO)", [k.crouch, "+", k.kick_light, "/", k.kick_heavy], "PATADA AGACHADO", BLUE],
		["AÉREO (ALTO)", [k.jump, " LUEGO ", k.punch_light, k.punch_heavy, k.kick_light, k.kick_heavy], "UNO POR SALTO", RED],
		["ANTIAÉREO", [k.crouch, "+", k.punch_heavy], "GANA A LOS SALTOS", RED],
		["ESPECIAL 1", [k.special_1], _energy_note(data.special_1), HKTheme.GOLD],
		["ESPECIAL 2", [k.special_2], _energy_note(data.special_2), HKTheme.GOLD],
	]

## Filas de la página DEFENSA Y COMBOS.
func _defense_rows() -> Array:
	var k := _row_keys()
	return [
		["BLOQUEAR DE PIE", [k.block], "PARA MEDIOS Y ALTOS", GRAY],
		["BLOQUEAR AGACHADO", [k.crouch, "+", k.block], "PARA MEDIOS Y BAJOS", GRAY],
		["GUARDIA", [], "SE ROMPE SI BLOQUEAS MUCHO", GRAY],
		["COMBO", [k.punch_light, ">", k.punch_heavy, ">", k.kick_heavy], "CANCELA AL CONECTAR", RED],
		["COUNTER", [], "GOLPEA ANTES DE QUE ATAQUE", RED],
		["AGARRE", [k.punch_light, "+", k.kick_light], "ROMPE EL BLOQUEO", PURPLE],
		["ZAFARSE", [k.punch_light, "+", k.kick_light], "AL SER AGARRADO", PURPLE],
	]

func _energy_note(atk: AttackData) -> String:
	if atk == null or atk.energy_cost <= 0.0:
		return ""
	return "GASTA %d DE ENERGÍA" % int(atk.energy_cost)

func _draw_rows_page(title: String, rows: Array) -> void:
	_draw_panel(MOVES_X, MOVES_W, "%s · JUGADOR %d" % [title, _player])
	var name_x := MOVES_X + 8.0
	var keys_x := MOVES_X + 152.0
	var y := PANEL_Y + 19.0
	for row in rows:
		var color: Color = row[3]
		HKTheme.draw_text(self, Vector2(name_x, y + 9), row[0], 8, color.lightened(0.45), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
		var end := _combo(Vector2(keys_x, y), row[1], color)
		if row[2] != "":
			HKTheme.draw_text(self, Vector2(end + 8, y + 9), row[2], 8, HKTheme.MUTED.lightened(0.3),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
		y += MOVE_ROW_H

# --- Teclas dibujadas ---------------------------------------------------------
## Dibuja una secuencia de teclas (códigos) y textos ("+", "/", " LUEGO "...)
## desde `pos` (esquina superior izquierda). Devuelve la x donde termina.
func _combo(pos: Vector2, parts: Array, color: Color) -> float:
	var x := pos.x
	for part in parts:
		if part is String:
			var text: String = part
			HKTheme.draw_text(self, Vector2(x, pos.y + 9), text, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
			x += HKTheme.text_width(text, 8)
		else:
			x += _cap(Vector2(x, pos.y), part, color) + 2.0
	return x

## Tecla de píxeles con relieve; se hunde y se ilumina mientras se mantiene
## pulsada. `pos` es la esquina superior izquierda. Devuelve su ancho.
func _cap(pos: Vector2, code: int, color: Color) -> float:
	var label := _label_for(code)
	var arrow := label.begins_with("ARR_")
	var w := 16.0 if arrow else maxf(16.0, HKTheme.text_width(label, 8) + 6.0)
	var down := code != KEY_NONE and Input.is_physical_key_pressed(code as Key)
	var x := roundf(pos.x)
	var y := roundf(pos.y) + (1.0 if down else 0.0)
	var h := CAP_H - (1.0 if down else 2.0)
	var body := Color("fff0a0") if down else color
	if not down:
		draw_rect(Rect2(x, y + h, w, 2), color.darkened(0.55))
	draw_rect(Rect2(x, y, w, h), body)
	draw_rect(Rect2(x, y, w, 1), body.lightened(0.35))
	if arrow:
		_draw_arrow(Vector2(x + w * 0.5, y + h * 0.5), label, HKTheme.INK)
	else:
		HKTheme.draw_text(self, Vector2(x + (w - HKTheme.text_width(label, 8)) * 0.5, y + 9), label, 8,
			HKTheme.INK, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	return w

func _draw_arrow(c: Vector2, token: String, color: Color) -> void:
	var pts: PackedVector2Array
	match token:
		"ARR_U": pts = [c + Vector2(0, -3), c + Vector2(4, 2), c + Vector2(-4, 2)]
		"ARR_D": pts = [c + Vector2(0, 3), c + Vector2(4, -2), c + Vector2(-4, -2)]
		"ARR_L": pts = [c + Vector2(-4, 0), c + Vector2(2, -3), c + Vector2(2, 3)]
		_: pts = [c + Vector2(4, 0), c + Vector2(-2, -3), c + Vector2(-2, 3)]
	draw_colored_polygon(pts, color)

## Texto de 8 px centrado en `center.x`; `center.y` es la línea base.
func _caption_at(center: Vector2, text: String, color: Color) -> void:
	HKTheme.draw_text(self, center - Vector2(HKTheme.text_width(text, 8) * 0.5, 0), text, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
