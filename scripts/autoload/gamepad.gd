## Soporte de mando (joystick) para P1. Se añade al Input Map por código.
## Mandos genéricos ("Twin USB Joystick") numeran los botones de forma distinta,
## así que hay un asistente de calibración: la primera vez que se pulsa un botón
## del mando pide pulsar cada acción y guarda el resultado. F10 lo repite.
extends Node

const DEADZONE := 0.5
const CONFIG_PATH := "user://gamepad_v2.cfg"
## Los índices >= 11 son el D-pad (hat), no se calibran.
const FIRST_DPAD_BUTTON := 11

## Direcciones (D-pad y stick izquierdo). No se calibran.
const DPAD := {
	&"left": JOY_BUTTON_DPAD_LEFT,
	&"right": JOY_BUTTON_DPAD_RIGHT,
	&"jump": JOY_BUTTON_DPAD_UP,
	&"crouch": JOY_BUTTON_DPAD_DOWN,
}
const AXES := {
	&"left": [JOY_AXIS_LEFT_X, -1.0],
	&"right": [JOY_AXIS_LEFT_X, 1.0],
	&"jump": [JOY_AXIS_LEFT_Y, -1.0],
	&"crouch": [JOY_AXIS_LEFT_Y, 1.0],
}

## Pasos del asistente: [acción, texto]. "pause" no lleva prefijo de jugador.
const STEPS := [
	[&"block", "CUBRIRSE (bloquear)"],
	[&"punch_light", "PUNO LIGERO"],
	[&"punch_heavy", "PUNO FUERTE"],
	[&"kick_light", "PATADA LIGERA"],
	[&"kick_heavy", "PATADA FUERTE"],
	[&"special_1", "ESPECIAL 1"],
	[&"special_2", "ESPECIAL 2"],
	[&"pause", "PAUSA (Start)"],
]

## Valores por defecto (numeración habitual de mandos tipo PlayStation) hasta calibrar.
const DEFAULTS := {
	&"block": 9, &"punch_light": 0, &"punch_heavy": 2, &"kick_light": 1,
	&"kick_heavy": 3, &"special_1": 10, &"special_2": -1, &"pause": 6,
}

var _map: Dictionary = {}
var _learning: bool = false
var _step: int = 0
var _learned: Dictionary = {}
var _skipped: bool = false
var _has_config: bool = false
var _layer: CanvasLayer
var _text: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_map = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		_has_config = true
		for step: Array in STEPS:
			var a: StringName = step[0]
			_map[a] = int(cfg.get_value("map", String(a), _map[a]))
	_apply_map()
	# Al conectar o quitar un mando se reparten de nuevo (1 mando: P1; 2 mandos: P1 y P2).
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _apply_map())
	# Selección de personaje: L1 / R1 cambian de época (pestañas).
	for pair: Array in [[&"gp_era_prev", 9], [&"gp_era_next", 10]]:
		var act: StringName = pair[0]
		if not InputMap.has_action(act):
			InputMap.add_action(act)
		var eb := InputEventJoypadButton.new()
		eb.device = -1
		eb.button_index = int(pair[1]) as JoyButton
		InputMap.action_add_event(act, eb)
	# Atrás en menús: B (botón 1), explícito por si el mapeo por defecto de Godot no aplica a este mando.
	var back := InputEventJoypadButton.new()
	back.device = -1
	back.button_index = JOY_BUTTON_B
	if InputMap.has_action(&"ui_cancel"):
		for old in InputMap.action_get_events(&"ui_cancel"):
			if old is InputEventJoypadButton:
				InputMap.action_erase_event(&"ui_cancel", old)
		InputMap.action_add_event(&"ui_cancel", back)
	# Aceptar en menús: solo A (botón 0) y Start. B (botón 1) es "atrás" (ui_cancel de Godot).
	for b: int in [0, int(_map[&"pause"])]:
		var acc := InputEventJoypadButton.new()
		acc.device = -1
		acc.button_index = b as JoyButton
		_add("ui_accept", acc)

func _action_path(action: StringName) -> String:
	return "pause" if action == &"pause" else "p1_%s" % action

## Reparte los mandos: con 2 o más, el de menor id es P1 y el siguiente P2 (cada uno solo
## controla a su luchador). Con 1 mando, P1 escucha a cualquier dispositivo (-1) y P2 usa teclado.
func _apply_map() -> void:
	var pads := Input.get_connected_joypads()
	pads.sort()
	var dev1 := -1
	var dev2 := -2   # -2 = P2 sin mando
	if pads.size() >= 2:
		dev1 = pads[0]
		dev2 = pads[1]
	for prefix: String in ["p1", "p2"]:
		for act: String in ["left", "right", "jump", "crouch", "block", "punch_light", "punch_heavy",
				"kick_light", "kick_heavy", "special_1", "special_2"]:
			_clear_joy("%s_%s" % [prefix, act])
	_clear_joy("pause")
	_bind_player("p1", dev1)
	if dev2 != -2:
		_bind_player("p2", dev2)
	# Pausa: cualquiera de los dos mandos.
	if int(_map[&"pause"]) >= 0:
		var pb := InputEventJoypadButton.new()
		pb.device = -1
		pb.button_index = int(_map[&"pause"]) as JoyButton
		_add("pause", pb)

func _clear_joy(action: String) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
			InputMap.action_erase_event(action, ev)

func _bind_player(prefix: String, dev: int) -> void:
	for action: StringName in DPAD:
		var ev := InputEventJoypadButton.new()
		ev.device = dev
		ev.button_index = DPAD[action] as JoyButton
		_add("%s_%s" % [prefix, action], ev)
	for action: StringName in AXES:
		var m := InputEventJoypadMotion.new()
		m.device = dev
		m.axis = AXES[action][0] as JoyAxis
		m.axis_value = AXES[action][1] as float
		_add("%s_%s" % [prefix, action], m)
	for step: Array in STEPS:
		var a: StringName = step[0]
		if a == &"pause" or int(_map[a]) < 0:
			continue
		var nb := InputEventJoypadButton.new()
		nb.device = dev
		nb.button_index = int(_map[a]) as JoyButton
		_add("%s_%s" % [prefix, a], nb)
	# Bloqueo extra con el gatillo izquierdo analógico, si existe.
	var trig := InputEventJoypadMotion.new()
	trig.device = dev
	trig.axis = JOY_AXIS_TRIGGER_LEFT
	trig.axis_value = 1.0
	_add("%s_block" % prefix, trig)
	# Especial 2 por defecto: gatillo derecho analógico (L2/R2 son ejes en mandos estándar).
	var trig2 := InputEventJoypadMotion.new()
	trig2.device = dev
	trig2.axis = JOY_AXIS_TRIGGER_RIGHT
	trig2.axis_value = 1.0
	_add("%s_special_2" % prefix, trig2)

func _add(action: String, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_set_deadzone(action, DEADZONE)
	InputMap.action_add_event(action, ev)

# --- Asistente ------------------------------------------------------------
func _start_wizard() -> void:
	_learning = true
	_step = 0
	_learned.clear()
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 101
		var bg := ColorRect.new()
		bg.color = Color(0, 0, 0, 0.8)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		_layer.add_child(bg)
		_text = Label.new()
		_text.set_anchors_preset(Control.PRESET_FULL_RECT)
		_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_text.add_theme_font_size_override("font_size", 14)
		_layer.add_child(_text)
		add_child(_layer)
	_layer.visible = true
	_refresh_text("")

func _refresh_text(extra: String) -> void:
	var step: Array = STEPS[_step]
	_text.text = "CALIBRAR MANDO  (%d/%d)\n\nPulsa el boton para:\n%s\n\n%s\n\nESC = cancelar" % [
		_step + 1, STEPS.size(), step[1], extra]

func _finish_wizard() -> void:
	_learning = false
	_layer.visible = false
	_map = _learned.duplicate()
	var cfg := ConfigFile.new()
	for a: StringName in _map:
		cfg.set_value("map", String(a), _map[a])
	cfg.save(CONFIG_PATH)
	_has_config = true
	_apply_map()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _learning and event.keycode == KEY_ESCAPE:
			_learning = false
			_skipped = true
			_layer.visible = false
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F10:
			_start_wizard()
			get_viewport().set_input_as_handled()
			return
	if not (event is InputEventJoypadButton and event.pressed):
		return
	var btn: int = event.button_index
	if btn >= FIRST_DPAD_BUTTON:
		return
	# La calibración ya no salta sola: se abre solo con F10 (hasta entonces valen los botones por defecto).
	if not _learning:
		return
	get_viewport().set_input_as_handled()
	if _learned.values().has(btn):
		_refresh_text("Ese boton ya se uso, pulsa otro")
		return
	var step: Array = STEPS[_step]
	_learned[step[0]] = btn
	_step += 1
	if _step >= STEPS.size():
		_finish_wizard()
	else:
		_refresh_text("")
