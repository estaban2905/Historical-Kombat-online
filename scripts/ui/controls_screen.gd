## Pantalla CONTROLES: a la izquierda las teclas del jugador 1 dibujadas como en
## un arcade (movimiento, bloqueo, puños, patadas, especiales); a la derecha un
## luchador que ejecuta el movimiento de la tecla que se pulsa, en cámara lenta.
## Las teclas se leen del Input Map, así que siempre coinciden con el juego.
## Se abre desde el menú principal (escena) o desde la pausa (overlay = true).
extends Control

signal closed

const PANEL_Y := 24.0
const PANEL_H := 164.0
const KEYS_X := 6.0
const KEYS_W := 202.0
const STAGE_X := 214.0
const STAGE_W := 206.0
const FLOOR_Y := 172.0
const FIGHTER_SCALE := 1.5

## Cámara lenta de la demo: multiplicador de los frames de cada fase del ataque.
const SLOW_STARTUP := 4.0
const SLOW_ACTIVE := 4.0
const SLOW_RECOVERY := 3.0
const MIN_ACTIVE := 10.0
const JUMP_TIME := 0.7
const JUMP_HEIGHT := 46.0
const DOUBLE_TAP_MSEC := 250

const RED := Color("c03838")
const BLUE := Color("3a6ec0")
const GREEN := Color("38a050")
const GRAY := Color("6a6270")
const ARROWS := {KEY_UP: "ARR_U", KEY_DOWN: "ARR_D", KEY_LEFT: "ARR_L", KEY_RIGHT: "ARR_R"}

## Acciones del jugador 1 que reaccionan al pulsarlas (no al mantenerlas).
const ATTACKS: Array[StringName] = [&"punch_light", &"punch_heavy", &"special_1", &"kick_light", &"kick_heavy", &"special_2"]

## [acción, línea 1, línea 2, color]; el orden es el de las teclas U I O / J K L.
const GRID := [
	[&"punch_light", "PUÑO", "DÉBIL", RED],
	[&"punch_heavy", "PUÑO", "FUERTE", RED],
	[&"special_1", "ESPECIAL", "1", HKTheme.GOLD],
	[&"kick_light", "PATADA", "DÉBIL", BLUE],
	[&"kick_heavy", "PATADA", "FUERTE", BLUE],
	[&"special_2", "ESPECIAL", "2", HKTheme.GOLD],
]

## Si es true, se muestra encima de otra pantalla y VOLVER emite `closed`.
var overlay: bool = false

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
## Doble toque para correr: última dirección pulsada (-1/1) y cuándo (ms).
var _tap_dir: int = 0
var _tap_msec: int = -10000
var _run_dir: int = 0

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
	_fighter.position = Vector2(STAGE_X + STAGE_W * 0.5, FLOOR_Y)
	_fighter.scale = Vector2(FIGHTER_SCALE, FIGHTER_SCALE)
	add_child(_fighter)
	_fighter.setup(_roster[_roster_idx])

	var row := HBoxContainer.new()
	row.position = Vector2(76, 222)
	row.size = Vector2(274, 16)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_btn_fighter = _add_button(row, "", 150)
	_btn_fighter.pressed.connect(_next_fighter)
	_btn_back = _add_button(row, "VOLVER", 118)
	_btn_back.pressed.connect(_close)
	_refresh_fighter_button()
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

func _next_fighter() -> void:
	_roster_idx = (_roster_idx + 1) % _roster.size()
	_fighter.setup(_roster[_roster_idx])
	_attack = null
	_caption = ""
	_refresh_fighter_button()

func _refresh_fighter_button() -> void:
	_btn_fighter.text = "LUCHADOR: %s" % _roster[_roster_idx].short_name.to_upper()

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
	for action in ATTACKS:
		if key.physical_keycode == _key_for(1, action):
			_start_attack(action)
			get_viewport().set_input_as_handled()
			return
	if key.physical_keycode == _key_for(1, &"jump") and _jump_t < 0.0:
		_jump_t = 0.0
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == _key_for(1, &"left") or key.physical_keycode == _key_for(1, &"right"):
		var dir := -1 if key.physical_keycode == _key_for(1, &"left") else 1
		var now := Time.get_ticks_msec()
		if dir == _tap_dir and now - _tap_msec <= DOUBLE_TAP_MSEC:
			_run_dir = dir
			_caption = "CORRER ADELANTE" if dir > 0 else "CORRER ATRÁS"
			_tap_dir = 0
		else:
			_run_dir = 0
			_tap_dir = dir
			_tap_msec = now
		get_viewport().set_input_as_handled()
	elif key.physical_keycode in [_key_for(1, &"crouch"), _key_for(1, &"block")]:
		get_viewport().set_input_as_handled()

func _held(action: StringName) -> bool:
	var code := _key_for(1, action)
	return code != KEY_NONE and Input.is_physical_key_pressed(code as Key)

# =========================================================================
#  Demo del luchador
# =========================================================================
func _start_attack(action: StringName) -> void:
	var atk := _fighter.data.get(String(action)) as AttackData
	if atk == null:
		return
	_attack = atk
	_attack_frames = 0.0
	_caption = atk.display_name.to_upper()
	_attack_pose = atk.anim
	var airborne := _jump_t >= 0.0
	var crouching := _held(&"crouch") and not airborne
	if atk.kind == AttackData.Kind.KICK:
		if airborne:
			_attack_pose = &"air_kick"
		elif crouching:
			_attack_pose = &"sweep"
	elif atk.kind == AttackData.Kind.PUNCH and airborne:
		_attack_pose = &"air_punch"

func _process(delta: float) -> void:
	_update_fighter(delta)
	queue_redraw()

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
	if _held(&"block") and not airborne:
		f.pose_name = &"block"
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
## Código físico de la tecla de una acción del jugador.
func _key_for(player: int, action: StringName) -> int:
	var events := InputMap.action_get_events("p%d_%s" % [player, action])
	if events.is_empty():
		return KEY_NONE
	return (events[0] as InputEventKey).physical_keycode

func _label_for(code: int) -> String:
	if ARROWS.has(code):
		return ARROWS[code]
	match code:
		KEY_SPACE: return "ESPACIO"
		KEY_ENTER: return "ENTER"
		KEY_NONE: return "?"
	return OS.get_keycode_string(code).to_upper()

# =========================================================================
#  Dibujo
# =========================================================================
func _draw() -> void:
	HKTheme.draw_text(self, Vector2(0, 16), "CONTROLES", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	_draw_keys(KEYS_X)
	_draw_stage()
	HKTheme.draw_text(self, Vector2(0, 198), "ABAJO+ATAQUE = BARRIDO · SALTO+ATAQUE = AÉREO",
		8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
	HKTheme.draw_text(self, Vector2(0, 207), "DOBLE TOQUE %s / %s = CORRER (ADELANTE Y ATRÁS)" % [
		_label_for(_key_for(1, &"left")), _label_for(_key_for(1, &"right"))],
		8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
	HKTheme.draw_text(self, Vector2(0, 216), "J2: FLECHAS Y NUMPAD · ESC / P = PAUSA",
		8, HKTheme.MUTED.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, 426, 2)

func _draw_panel(x: float, w: float) -> void:
	draw_rect(Rect2(x, PANEL_Y, w, PANEL_H), HKTheme.PANEL)
	draw_rect(Rect2(x, PANEL_Y, w, PANEL_H), HKTheme.GOLD_DARK, false, 1.0)

func _draw_stage() -> void:
	_draw_panel(STAGE_X, STAGE_W)
	HKTheme.draw_text(self, Vector2(STAGE_X + 6, PANEL_Y + 11), _fighter.data.display_name.to_upper().left(22),
		8, Color("5aa0ff"), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	draw_rect(Rect2(STAGE_X + 4, PANEL_Y + 15, STAGE_W - 8, 1), HKTheme.GOLD_DARK)
	# Suelo de piedra
	draw_rect(Rect2(STAGE_X + 1, FLOOR_Y, STAGE_W - 2, PANEL_Y + PANEL_H - FLOOR_Y - 1), Color("2a1a20"))
	draw_rect(Rect2(STAGE_X + 1, FLOOR_Y, STAGE_W - 2, 1), HKTheme.GOLD_DARK)
	var text := _caption if _caption != "" else "PULSA UNA TECLA"
	var color := HKTheme.GOLD if _caption != "" else HKTheme.MUTED
	_caption_at(Vector2(STAGE_X + STAGE_W * 0.5, PANEL_Y + PANEL_H - 6), text.left(24), color)

func _draw_keys(px: float) -> void:
	_draw_panel(px, KEYS_W)
	HKTheme.draw_text(self, Vector2(px + 6, PANEL_Y + 11), "JUGADOR 1", 8, Color("5aa0ff"), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	draw_rect(Rect2(px + 4, PANEL_Y + 15, KEYS_W - 8, 1), HKTheme.GOLD_DARK)

	# Movimiento: cruceta con salto arriba, agacharse abajo.
	var cx := px + 40.0
	var top := PANEL_Y + 21.0
	_draw_cap(Vector2(cx, top), _key_for(1, &"jump"), GREEN)
	_draw_cap(Vector2(cx - 25, top + 21), _key_for(1, &"left"), GREEN)
	_draw_cap(Vector2(cx, top + 21), _key_for(1, &"crouch"), GREEN)
	_draw_cap(Vector2(cx + 25, top + 21), _key_for(1, &"right"), GREEN)
	_caption_at(Vector2(cx, top + 51), "MOVER·SALTAR", HKTheme.PAPER)
	_caption_at(Vector2(cx, top + 60), "AGACHAR", HKTheme.PAPER)

	# Bloqueo
	var bx := px + 142.0
	_draw_cap(Vector2(bx, top + 10), _key_for(1, &"block"), GRAY)
	_caption_at(Vector2(bx, top + 41), "BLOQUEAR", HKTheme.PAPER)

	# Ataques: dos filas de tres, como los botones de un arcade.
	for i in GRID.size():
		var g: Array = GRID[i]
		var gx := px + 36.0 + 64.0 * (i % 3)
		var gy := PANEL_Y + 94.0 + 38.0 * (i / 3)
		_draw_cap(Vector2(gx, gy), _key_for(1, g[0]), g[3])
		_caption_at(Vector2(gx, gy + 28), g[1], g[3].lightened(0.45))
		_caption_at(Vector2(gx, gy + 37), g[2], g[3].lightened(0.45))

## Texto de 8 px centrado en `center.x`; `center.y` es la línea base.
func _caption_at(center: Vector2, text: String, color: Color) -> void:
	HKTheme.draw_text(self, center - Vector2(HKTheme.text_width(text, 8) * 0.5, 0), text, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)

## Tecla dibujada en 3D de píxeles. `pos` es el centro-superior; se hunde y se
## ilumina mientras se mantiene pulsada.
func _draw_cap(pos: Vector2, code: int, color: Color) -> void:
	var label := _label_for(code)
	var arrow := label.begins_with("ARR_")
	var w := 22.0 if arrow else maxf(22.0, HKTheme.text_width(label, 8) + 8.0)
	var h := 18.0
	var down := code != KEY_NONE and Input.is_physical_key_pressed(code as Key)
	var x := roundf(pos.x - w * 0.5)
	var y := roundf(pos.y) + (2.0 if down else 0.0)
	var body := Color("fff0a0") if down else color
	if not down:
		draw_rect(Rect2(x, y + 2, w, h), color.darkened(0.55))
	draw_rect(Rect2(x, y, w, h - (2.0 if down else 0.0)), body.darkened(0.25))
	draw_rect(Rect2(x + 1, y + 1, w - 2, h - 5), body)
	draw_rect(Rect2(x + 1, y + 1, w - 2, 1), body.lightened(0.35))
	var ink := HKTheme.INK
	if arrow:
		_draw_arrow(Vector2(x + w * 0.5, y + 7.0), label, ink)
	else:
		HKTheme.draw_text(self, Vector2(x + (w - HKTheme.text_width(label, 8)) * 0.5, y + 12), label, 8, ink, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)

func _draw_arrow(c: Vector2, token: String, color: Color) -> void:
	var pts: PackedVector2Array
	match token:
		"ARR_U": pts = [c + Vector2(0, -4), c + Vector2(5, 3), c + Vector2(-5, 3)]
		"ARR_D": pts = [c + Vector2(0, 4), c + Vector2(5, -3), c + Vector2(-5, -3)]
		"ARR_L": pts = [c + Vector2(-5, 0), c + Vector2(3, -4), c + Vector2(3, 4)]
		_: pts = [c + Vector2(5, 0), c + Vector2(-3, -4), c + Vector2(-3, 4)]
	draw_colored_polygon(pts, color)
