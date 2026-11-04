## Pantalla PARTIDAS GUARDADAS del modo Historia: una fila por luchador con partida (la más reciente arriba).
## Elegir una fila retoma esa partida; las demás se quedan como están. Se llega desde CONTINUAR del menú.
## ESC o VOLVER regresan al menú.
class_name StorySavesScreen
extends Control

const ROW_H := 42.0
const ROW_W := 336.0
const LIST_TOP := 32.0
const LIST_BOTTOM := 214.0
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "?"]
const DIFF_COLORS: Array[Color] = [Color("60d060"), Color("f0c040"), Color("e04a3a")]

var _list: VBoxContainer
var _first: Button
var _status: Label
var _header: Label
var _hint: Label

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

	_header = Label.new()
	_header.position = Vector2(0, 21)
	_header.size = Vector2(426, 10)
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_theme_color_override("font_color", HKTheme.MUTED.lightened(0.2))
	add_child(_header)

	_hint = Label.new()
	_hint.position = Vector2(BackButton.RIGHT_EDGE, 224)
	_hint.size = Vector2(426.0 - BackButton.RIGHT_EDGE - 6.0, 10)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", HKTheme.PAPER.darkened(0.15))
	add_child(_hint)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2((426.0 - ROW_W) * 0.5, LIST_TOP)
	scroll.size = Vector2(ROW_W + 6.0, LIST_BOTTOM - LIST_TOP)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.custom_minimum_size = Vector2(ROW_W, 0)
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
	var endings := 0
	for e in Unlocks.ENDINGS:
		if Unlocks.has("ending", str(e)):
			endings += 1
	if rows.is_empty():
		_header.text = ""
	else:
		_header.text = HKTheme.fold("%d PARTIDA%s · %d DE %d FINALES VISTOS" % [rows.size(),
			"" if rows.size() == 1 else "S", endings, Unlocks.ENDINGS.size()])
	var newest := true
	for s in rows:
		var d := FighterRegistry.get_by_id(StringName(str(s["fighter"])))   # válida: el luchador existe
		var ladder := Game.story_ladder_for(d.id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(ROW_W, ROW_H)
		b.pressed.connect(func():
			Sfx.play(&"confirm")
			_resume(s))
		b.focus_entered.connect(func():
			Sfx.play(&"select")
			_hint.text = _next_text(ladder, int(s["stage"])))
		var card := Control.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.set_anchors_preset(Control.PRESET_FULL_RECT)
		var face := AvatarFrame.new(Vector2(34, 34))
		face.position = Vector2(4, 4)
		face.set_fighter(str(d.id))
		card.add_child(face)
		var latest := newest
		card.draw.connect(func(): _draw_card(card, s, d, ladder, latest))
		b.add_child(card)
		newest = false
		_list.add_child(b)
		if _first == null:
			_first = b
	if _first:
		_first.grab_focus()
		_hint.text = _next_text(Game.story_ladder_for(StringName(str(rows[0]["fighter"]))), int(rows[0]["stage"]))

## Dibuja el contenido de una tarjeta: nombre, dificultad, época, barra de progreso, revanchas y antigüedad.
func _draw_card(c: Control, s: Dictionary, d: FighterData, ladder: Array[StringName], latest: bool) -> void:
	var stage := int(s["stage"])
	var total := ladder.size()
	var x := 44.0
	var right := ROW_W - 6.0
	var name_text := d.short_name.to_upper()
	HKTheme.draw_text(c, Vector2(x, 14), name_text, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	if latest:
		HKTheme.draw_text(c, Vector2(x + HKTheme.text_width(name_text, 8) + 6, 14), "ULTIMA", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var diff := int(s["difficulty"])
	var diff_ok := diff >= 0 and diff < Game.DIFFICULTY_NAMES.size()
	HKTheme.draw_text(c, Vector2(0, 14), Game.DIFFICULTY_NAMES[diff] if diff_ok else "?", 8,
		DIFF_COLORS[diff] if diff_ok else HKTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, right, 1)
	var chapter := Game.story_chapter_of(ladder[stage])
	var era := "%s · %s" % ["FINAL" if chapter >= ROMAN.size() - 1 else ROMAN[chapter], Game.story_chapter_name(chapter)]
	# Deja sitio al "C##/50" de la derecha: si la época no cabe, se recorta con puntos.
	var full := era
	while HKTheme.text_width(era, 8) > right - x - 58.0 and full.length() > 4:
		full = full.substr(0, full.length() - 1)
		era = full.strip_edges() + ".."
	HKTheme.draw_text(c, Vector2(x, 25), era, 8, HKTheme.MUTED.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	# Barra de progreso con una marca al empezar cada época.
	var bx := x
	var bw := 112.0
	var span := maxf(total - 1.0, 1.0)
	c.draw_rect(Rect2(bx, 31, bw, 4), Color(0.05, 0.02, 0.07))
	c.draw_rect(Rect2(bx, 31, bw * float(stage) / span, 4), HKTheme.GOLD)
	for i in range(1, total):
		if Game.story_chapter_of(ladder[i]) != Game.story_chapter_of(ladder[i - 1]):
			c.draw_rect(Rect2(bx + bw * float(i) / span, 30, 1, 6), HKTheme.MUTED)
	HKTheme.draw_text(c, Vector2(0, 25), "C%d/%d" % [stage + 1, total], 8, HKTheme.PAPER.darkened(0.2), HORIZONTAL_ALIGNMENT_RIGHT, right, 1)
	var info := "REV %d/%d · %s" % [int(s["continues"]), Game.ARCADE_CONTINUES, _ago(int(s["saved_at"]))]
	HKTheme.draw_text(c, Vector2(0, 37), info, 8, HKTheme.MUTED.lightened(0.15), HORIZONTAL_ALIGNMENT_RIGHT, right, 1)

## "SIGUE: <rival>" (y si es jefe de época, creador o el Nexo) para la partida elegida.
func _next_text(ladder: Array[StringName], stage: int) -> String:
	var id := ladder[stage]
	var who := "EL NEXO" if id == Game.STORY_NEXO_ID else FighterRegistry.get_by_id(id).short_name.to_upper()
	var tag := ""
	if id == Game.STORY_NEXO_ID:
		tag = " · JEFE FINAL"
	elif stage + 1 < ladder.size() and Game.story_chapter_of(ladder[stage + 1]) != Game.story_chapter_of(id):
		tag = " · JEFE DE LA EPOCA"
	elif StoryCampaign.CREATORS.has(id):
		tag = " · CREADOR DEL RELOJ"
	return HKTheme.fold("SIGUE: %s%s" % [who, tag])

## Hace cuánto se guardó, en palabras cortas.
static func _ago(saved_at: int) -> String:
	var secs := maxi(int(Time.get_unix_time_from_system()) - saved_at, 0)
	if secs < 60:
		return "AHORA"
	if secs < 3600:
		return "HACE %d MIN" % (secs / 60)
	if secs < 86400:
		return "HACE %d H" % (secs / 3600)
	if secs < 172800:
		return "AYER"
	return "HACE %d DIAS" % (secs / 86400)

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
