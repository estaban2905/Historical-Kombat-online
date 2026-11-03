## Ajustes: volumen general y de efectos (izquierda/derecha para cambiarlos), acceso a CONTROLES y VOLVER.
## Los cambios se guardan al momento. ESC o VOLVER regresa al menú.
extends Control

var _master: Button
var _effects: Button
var _controls: Button
var _back: Button

func _ready() -> void:
	theme = HKTheme.theme()
	_master = _button("", 70)
	_effects = _button("", 92)
	_controls = _button("CONTROLES", 124)
	_back = _button("VOLVER", 158)
	_master.gui_input.connect(_on_volume_input.bind(_master, "master"))
	_effects.gui_input.connect(_on_volume_input.bind(_effects, "effects"))
	_master.pressed.connect(_cycle.bind("master"))
	_effects.pressed.connect(_cycle.bind("effects"))
	_controls.pressed.connect(func(): Game.goto(Game.SCENE_CONTROLS))
	_back.pressed.connect(func(): Game.goto(Game.SCENE_MENU))
	for b in [_master, _effects, _controls, _back]:
		b.focus_entered.connect(func(): Sfx.play(&"select"))
	_controls.pressed.connect(func(): Sfx.play(&"confirm"))
	_back.pressed.connect(func(): Sfx.play(&"confirm"))
	_refresh()
	_master.grab_focus()

func _button(text: String, y: float) -> Button:
	var b := Button.new()
	b.text = text
	b.position = Vector2(113, y)
	b.custom_minimum_size = Vector2(200, 16)
	add_child(b)
	# Con el tema ya aplicado: si se fija antes, el botón nace con la altura de la fuente por defecto.
	b.size = Vector2(200, 16)
	return b

## Pulsar el volumen lo sube de uno en uno y, al llegar al máximo, vuelve a 0.
func _cycle(which: String) -> void:
	_set_volume(which, (_get_volume(which) + 1) % (Settings.STEPS + 1))

func _on_volume_input(event: InputEvent, button: Button, which: String) -> void:
	var step := 0
	if event.is_action_pressed(&"ui_left"):
		step = -1
	elif event.is_action_pressed(&"ui_right"):
		step = 1
	if step != 0:
		_set_volume(which, clampi(_get_volume(which) + step, 0, Settings.STEPS))
		button.accept_event()

func _get_volume(which: String) -> int:
	return Settings.master if which == "master" else Settings.effects

func _set_volume(which: String, value: int) -> void:
	if which == "master":
		Settings.master = value
	else:
		Settings.effects = value
	Settings.apply()
	Settings.save()
	_refresh()
	# Un sonido de prueba para oír el nivel nuevo.
	Sfx.play(&"hit_light")

func _refresh() -> void:
	_master.text = "VOLUMEN  < %s >" % _bar(Settings.master)
	_effects.text = "EFECTOS  < %s >" % _bar(Settings.effects)

## "||||||....": un trazo por paso.
func _bar(value: int) -> String:
	return "|".repeat(value) + ".".repeat(Settings.STEPS - value)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Game.goto(Game.SCENE_MENU)
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 240), HKTheme.INK)
	HKTheme.draw_text(self, Vector2(0, 36), "AJUSTES", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	HKTheme.draw_text(self, Vector2(0, 205), "IZQUIERDA / DERECHA: CAMBIAR   ESC: VOLVER", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
