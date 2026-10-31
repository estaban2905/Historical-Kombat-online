## Menú de pausa del combate (Esc o P). Funciona con el árbol en pausa.
extends CanvasLayer

var _panel: PanelContainer
var _first_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.theme = HKTheme.theme()
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", HKTheme.GOLD)
	box.add_child(title)
	_first_button = _add_button(box, "CONTINUAR", resume)
	_add_button(box, "REINICIAR COMBATE", func(): Game.goto(Game.SCENE_FIGHT))
	_add_button(box, "SELECCIÓN DE LUCHADOR", func(): Game.goto(Game.SCENE_SELECT))
	_add_button(box, "MENÚ PRINCIPAL", func(): Game.goto(Game.SCENE_MENU))
	visible = false

func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 16)
	b.pressed.connect(func():
		Sfx.play(&"confirm")
		cb.call())
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	parent.add_child(b)
	return b

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") and not Game.is_changing_scene():
		if visible:
			resume()
		else:
			open()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	get_tree().paused = true
	_first_button.grab_focus()

func resume() -> void:
	visible = false
	get_tree().paused = false
