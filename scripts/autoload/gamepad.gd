## Soporte de mando (joystick) para P1 y P2. Se añade al Input Map por código.
## Los mandos genéricos ("Twin USB Joystick") y los navegadores (versión web) numeran los botones
## y la cruceta de forma distinta, así que hay un asistente de calibración: la primera vez que se
## pulsa un botón del mando (si no hay calibración guardada en ese equipo/navegador) pide pulsar
## cada acción y las 4 direcciones de la cruceta, y guarda el resultado. F10 lo repite.
extends Node

const DEADZONE := 0.5
const CONFIG_PATH := "user://gamepad_v2.cfg"
## Los botones con índice >= 11 son la cruceta por defecto: no se usan para las acciones.
const FIRST_DPAD_BUTTON := 11

## Direcciones que se calibran tras los botones: [acción, texto]. Valen un botón o un eje (cruceta como hat).
const DIR_STEPS := [
	[&"left", "CRUCETA IZQUIERDA"],
	[&"right", "CRUCETA DERECHA"],
	[&"jump", "CRUCETA ARRIBA (salto)"],
	[&"crouch", "CRUCETA ABAJO (agacharse)"],
]

## Direcciones por defecto (D-pad y stick izquierdo), mientras no se calibre la cruceta.
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
## Cruceta calibrada: acción -> {"b": botón} o {"a": eje, "v": signo}. Vacía = valores por defecto.
var _dirs: Dictionary = {}
var _learned_dirs: Dictionary = {}   # acción -> texto "b:12" / "a:9:1" (para comparar y guardar)
## Eje que acaba de capturar el asistente: se ignora hasta que vuelva al centro.
var _wait_axis: int = -1
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
		_load_dirs(cfg)
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

func _load_dirs(cfg: ConfigFile) -> void:
	_dirs.clear()
	for d: Array in DIR_STEPS:
		var parsed := _parse_dir(str(cfg.get_value("dirs", String(d[0]), "")))
		if not parsed.is_empty():
			_dirs[d[0]] = parsed

## "b:12" -> {"b": 12}; "a:9:1" -> {"a": 9, "v": 1.0}; otra cosa -> {}.
func _parse_dir(s: String) -> Dictionary:
	var p := s.split(":")
	if p.size() == 2 and p[0] == "b":
		return {"b": int(p[1])}
	if p.size() == 3 and p[0] == "a":
		return {"a": int(p[1]), "v": float(p[2])}
	return {}

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
		if _dirs.has(action):
			continue   # esta dirección está calibrada: se enlaza abajo
		var ev := InputEventJoypadButton.new()
		ev.device = dev
		ev.button_index = DPAD[action] as JoyButton
		_add("%s_%s" % [prefix, action], ev)
	for action: StringName in _dirs:
		var d: Dictionary = _dirs[action]
		if d.has("b"):
			var db := InputEventJoypadButton.new()
			db.device = dev
			db.button_index = int(d["b"]) as JoyButton
			_add("%s_%s" % [prefix, action], db)
		else:
			var dm := InputEventJoypadMotion.new()
			dm.device = dev
			dm.axis = int(d["a"]) as JoyAxis
			dm.axis_value = float(d["v"])
			_add("%s_%s" % [prefix, action], dm)
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
	_learned_dirs.clear()
	_wait_axis = -1
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

func _total_steps() -> int:
	return STEPS.size() + DIR_STEPS.size()

func _refresh_text(extra: String) -> void:
	var is_dir := _step >= STEPS.size()
	var step: Array = DIR_STEPS[_step - STEPS.size()] if is_dir else STEPS[_step]
	var verb := "Pulsa la cruceta hacia:" if is_dir else "Pulsa el boton para:"
	_text.text = "CALIBRAR MANDO  (%d/%d)\n\n%s\n%s\n\n%s\n\nESC = cancelar" % [
		_step + 1, _total_steps(), verb, step[1], extra]

func _next_step() -> void:
	_step += 1
	if _step >= _total_steps():
		_finish_wizard()
	else:
		_refresh_text("")

func _finish_wizard() -> void:
	_learning = false
	_layer.visible = false
	_map = _learned.duplicate()
	var cfg := ConfigFile.new()
	for a: StringName in _map:
		cfg.set_value("map", String(a), _map[a])
	for a: StringName in _learned_dirs:
		cfg.set_value("dirs", String(a), _learned_dirs[a])
	cfg.save(CONFIG_PATH)
	_load_dirs(cfg)
	_has_config = true
	_apply_map()

## Un paso de cruceta captura `enc` ("b:12" botón o "a:9:1" eje y sentido), salvo que ya se usara.
func _learn_dir(enc: String) -> void:
	if _learned_dirs.values().has(enc):
		_refresh_text("Eso ya se uso, pulsa otra direccion")
		return
	_learned_dirs[DIR_STEPS[_step - STEPS.size()][0]] = enc
	_next_step()

## Cruceta que el mando reporta como eje (hat) o stick: se captura al empujarlo a fondo en un paso de cruceta.
func _learn_axis(event: InputEventJoypadMotion) -> void:
	if event.axis == _wait_axis:
		if absf(event.axis_value) < 0.3:
			_wait_axis = -1   # volvió al centro: ya se puede capturar el siguiente
		return
	if not _learning or _step < STEPS.size() or absf(event.axis_value) < 0.8:
		return
	_wait_axis = event.axis
	get_viewport().set_input_as_handled()
	_learn_dir("a:%d:%d" % [event.axis, 1 if event.axis_value > 0.0 else -1])

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
	if event is InputEventJoypadMotion:
		_learn_axis(event)
		return
	if not (event is InputEventJoypadButton and event.pressed):
		return
	var btn: int = event.button_index
	if not _learning:
		# Sin calibración guardada (primer uso en este equipo o navegador) se ofrece al pulsar un botón.
		# La cruceta (índices altos) no la dispara.
		if btn < FIRST_DPAD_BUTTON and not _has_config and not _skipped:
			_start_wizard()
			get_viewport().set_input_as_handled()
		return
	if _step >= STEPS.size():
		get_viewport().set_input_as_handled()
		_learn_dir("b:%d" % btn)
		return
	if btn >= FIRST_DPAD_BUTTON:
		return
	get_viewport().set_input_as_handled()
	if _learned.values().has(btn):
		_refresh_text("Ese boton ya se uso, pulsa otro")
		return
	var step: Array = STEPS[_step]
	_learned[step[0]] = btn
	_next_step()
