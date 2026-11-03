## Pantalla PARTIDAS GUARDADAS del modo Historia: una fila por luchador con partida (la más reciente arriba).
## Elegir una fila retoma esa partida; las demás se quedan como están. Se llega desde CONTINUAR del menú.
## ESC o VOLVER regresan al menú.
class_name StorySavesScreen
extends Control

const ROW_H := 16.0
const LIST_TOP := 28.0
const LIST_BOTTOM := 216.0

var _list: VBoxContainer
var _first: Button
var _status: Label

func _ready() -> void:
	theme = HKTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	bg.show_title = false
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)

	var title := Label.new()
	title.text = "PARTIDAS GUARDADAS"
	title.position = Vector2(0, 10)
	title.size = Vector2(426, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", HKTheme.GOLD)
	add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(60, LIST_TOP)
	scroll.size = Vector2(306, LIST_BOTTOM - LIST_TOP)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.custom_minimum_size = Vector2(296, 0)
	scroll.add_child(_list)

	_status = Label.new()
	_status.position = Vector2(0, 108)
	_status.size = Vector2(426, 12)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", HKTheme.MUTED)
	add_child(_status)

	var back := BackButton.add_to(self, _close)
	back.grab_focus()
	_load()

func _load() -> void:
	_status.text = "CARGANDO..."
	var saves: Dictionary = Backend.stories_local()
	if Backend.is_logged_in():
		saves = await Backend.load_stories()
	if not is_inside_tree():
		return
	_fill(saves)

## Las partidas válidas, de la más reciente a la más antigua.
static func sorted_saves(saves: Dictionary) -> Array:
	var out: Array = []
	for f in saves:
		var s: Dictionary = saves[f]
		if valid(s):
			out.append(s)
	out.sort_custom(func(a, b): return int(a["saved_at"]) > int(b["saved_at"]))
	return out

## ¿La partida sirve en esta versión del juego? (el luchador existe y el combate está dentro de la escalera)
static func valid(s: Dictionary) -> bool:
	for d in FighterRegistry.all():
		if str(d.id) == str(s.get("fighter", "")):
			return int(s.get("stage", -1)) >= 0 and int(s["stage"]) < FighterRegistry.all().size()
	return false

func _fill(saves: Dictionary) -> void:
	for c in _list.get_children():
		c.queue_free()
	_first = null
	var rows := sorted_saves(saves)
	_status.text = "" if not rows.is_empty() else "NO HAY PARTIDAS GUARDADAS"
	for s in rows:
		var d := FighterRegistry.get_by_id(StringName(str(s["fighter"])))   # válida: el luchador existe
		var diff := int(s["difficulty"])
		var b := Button.new()
		b.custom_minimum_size = Vector2(296, ROW_H)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = HKTheme.fold("%s  C%d/%d  %s" % [d.short_name.to_upper(), int(s["stage"]) + 1,
			FighterRegistry.all().size(), Game.DIFFICULTY_NAMES[diff] if diff >= 0 and diff < Game.DIFFICULTY_NAMES.size() else "?"])
		b.focus_entered.connect(func(): Sfx.play(&"select"))
		b.pressed.connect(func():
			Sfx.play(&"confirm")
			_resume(s))
		_list.add_child(b)
		if _first == null:
			_first = b
	if _first:
		_first.grab_focus()

func _resume(save: Dictionary) -> void:
	if Game.is_changing_scene():
		return
	if Game.story_resume(save):
		Game.goto(Game.SCENE_STORY)
	else:
		# La partida ya no sirve (versión distinta del juego): se descarta.
		await Backend.clear_story(str(save.get("fighter", "")))
		if is_inside_tree():
			_fill(await Backend.load_stories())

func _close() -> void:
	Game.goto(Game.SCENE_MENU)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not Game.is_changing_scene():
		_close()
		get_viewport().set_input_as_handled()
