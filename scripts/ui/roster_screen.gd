## Pantalla PERSONAJES: ficha de cada luchador sobre SU escenario.
##   Fondo      el escenario del personaje (el mismo del combate), con él de pie en el suelo.
##   Arriba izq. placa con nombre completo, país y época.
##   Derecha    panel con tres pestañas (TAB o botón para cambiar):
##                HISTORIA  estadísticas, quién fue y qué hizo.
##                PODERES   sus dos especiales, con coste y daño, y sus combos.
##                ULTIMATE  su ataque definitivo (o fatality) y cómo se lanza.
##   ← → cambian de personaje, ESC vuelve al menú.
## Los textos largos salen de RosterLore; los números, de la propia ficha.
extends Control

enum Page { STORY, POWERS, ULTIMATE }

const PANEL_X := 154.0
const PANEL_Y := 26.0
const PANEL_W := 266.0
const PANEL_BOTTOM := 204.0
const TEXT_X := PANEL_X + 8.0
const TEXT_W := PANEL_W - 16.0
const LINE_H := 10.0   # la fuente es de 8 px: menos de 10 hace que las líneas se pisen
const SPRITE_X := 78.0
const SPRITE_MAX_H := 104.0   # deja sitio a la placa (nombre, país, época y escenario)
## Ancho de la placa del nombre.
const PLATE_W := 142.0

const PAGE_NAMES: Array[String] = ["HISTORIA", "PODERES", "ULTIMATE"]
const BLUE_TEXT := Color("5aa0ff")
const BAR_BG := Color("2a1a20")
const SHADE := Color(0.05, 0.02, 0.07, 0.72)

var _roster: Array[FighterData] = []
var _idx: int = 0
var _page: Page = Page.STORY
var _fighter: FighterRenderer
var _stage: Stage
var _floor_y: float = 206.0
var _btn_page: Button

func _ready() -> void:
	theme = HKTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_roster = FighterRegistry.all()
	_idx = maxi(_roster.find(Game.p1_data()), 0)
	_fighter = FighterRenderer.new()
	add_child(_fighter)
	_show_fighter()

	var row := HBoxContainer.new()
	row.position = Vector2(BackButton.RIGHT_EDGE, BackButton.POS.y)
	row.size = Vector2(426.0 - BackButton.RIGHT_EDGE - 12.0, BackButton.SIZE.y)
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var prev := _add_button(row, "< ANTERIOR", 100)
	prev.pressed.connect(func(): _step(-1))
	_btn_page = _add_button(row, "", 100)
	_btn_page.pressed.connect(_toggle_page)
	var next := _add_button(row, "SIGUIENTE >", 100)
	next.pressed.connect(func(): _step(1))
	var back := BackButton.add_to(self, _close)
	_refresh_buttons()
	back.grab_focus()

func _add_button(parent: Control, text: String, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, BackButton.SIZE.y)
	b.clip_text = true
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	b.pressed.connect(func(): Sfx.play(&"confirm"))
	parent.add_child(b)
	return b

func _data() -> FighterData:
	return _roster[_idx]

func _show_fighter() -> void:
	_load_stage(_data().id)
	_fighter.setup(_data())
	_fighter.pose_name = &"idle"
	# El personaje se escala para que todos ocupen un alto parecido.
	var s := clampf(SPRITE_MAX_H / maxf(_fighter.approx_height(), 1.0), 0.8, 1.7)
	_fighter.scale = Vector2(s, s)
	_fighter.position = Vector2(SPRITE_X, _floor_y)

## Pone de fondo el escenario del personaje (igual que CombatManager._load_stage).
func _load_stage(fighter_id: StringName) -> void:
	if _stage:
		_stage.queue_free()
	var packed := load(StageRegistry.scene_for(fighter_id)) as PackedScene
	if packed == null:
		packed = load(StageRegistry.COLOSSEUM)
	_stage = packed.instantiate() as Stage
	if _stage is ThemedStage:
		(_stage as ThemedStage).fighter_id = fighter_id
	# Un hijo se dibuja encima del padre; así el escenario queda detrás de los paneles.
	_stage.show_behind_parent = true
	add_child(_stage)
	move_child(_stage, 0)
	_floor_y = _stage.floor_y

func _step(dir: int) -> void:
	_idx = (_idx + dir + _roster.size()) % _roster.size()
	_show_fighter()
	Sfx.play(&"select")

func _toggle_page() -> void:
	_page = ((int(_page) + 1) % PAGE_NAMES.size()) as Page
	_refresh_buttons()

func _refresh_buttons() -> void:
	# El botón nombra la página a la que lleva.
	_btn_page.text = PAGE_NAMES[(int(_page) + 1) % PAGE_NAMES.size()]

func _close() -> void:
	Game.goto(Game.SCENE_MENU)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not Game.is_changing_scene():
		_close()
		get_viewport().set_input_as_handled()

## _input (y no _unhandled_input) para que las flechas no muevan el foco de los botones.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if event.is_action_pressed(&"ui_left"):
		_step(-1)
	elif event.is_action_pressed(&"ui_right"):
		_step(1)
	elif key != null and key.pressed and not key.echo and key.physical_keycode == KEY_TAB:
		_toggle_page()
		Sfx.play(&"select")
	else:
		return
	get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	queue_redraw()

# =========================================================================
#  Dibujo
# =========================================================================
func _draw() -> void:
	# Franjas oscuras arriba y abajo para que el título y los botones se lean sobre el escenario.
	draw_rect(Rect2(0, 0, 426, 22), SHADE)
	draw_rect(Rect2(0, 208, 426, 32), SHADE)
	HKTheme.draw_text(self, Vector2(0, 17), "PERSONAJES", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	_draw_plate()
	_draw_panel()
	match _page:
		Page.STORY: _draw_story()
		Page.POWERS: _draw_powers()
		Page.ULTIMATE: _draw_ultimate()
	var hint := "< > CAMBIAR   ·   TAB: PÁGINA   ·   %d/%d" % [_idx + 1, _roster.size()]
	HKTheme.draw_text(self, Vector2(0, 218), hint, 8, HKTheme.MUTED.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, 426, 2)

## Placa del personaje: nombre, país, época y escenario.
func _draw_plate() -> void:
	var d := _data()
	var rows: Array = []   # [texto, color]
	for line in _wrap(d.display_name.to_upper(), PLATE_W - 12.0):
		rows.append([line, HKTheme.PAPER])
	for line in _wrap(d.country.to_upper(), PLATE_W - 12.0):
		rows.append([line, HKTheme.GOLD])
	rows.append([d.era, HKTheme.MUTED.lightened(0.25)])
	var stage_lines := _wrap(StageRegistry.name_for(d.id), PLATE_W - 12.0)
	var r := Rect2(6, PANEL_Y, PLATE_W, 8.0 + (rows.size() + stage_lines.size()) * LINE_H + 5.0)
	draw_rect(r, SHADE)
	draw_rect(r, HKTheme.GOLD_DARK, false, 1.0)
	var y := PANEL_Y + 4.0
	for row in rows:
		y += LINE_H
		HKTheme.draw_text(self, Vector2(12, y), row[0], 8, row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	y += 3.0
	draw_rect(Rect2(10, y + 1.0, PLATE_W - 8.0, 1), HKTheme.GOLD_DARK.darkened(0.3))
	for line in stage_lines:
		y += LINE_H
		HKTheme.draw_text(self, Vector2(12, y), line, 8, BLUE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)

## Panel derecho con las dos pestañas y el número de personaje.
func _draw_panel() -> void:
	var r := Rect2(PANEL_X, PANEL_Y, PANEL_W, PANEL_BOTTOM - PANEL_Y)
	draw_rect(r, HKTheme.PANEL)
	draw_rect(r, HKTheme.GOLD_DARK, false, 1.0)
	var x := TEXT_X
	for i in PAGE_NAMES.size():
		var active := i == int(_page)
		var tab := PAGE_NAMES[i]
		HKTheme.draw_text(self, Vector2(x, PANEL_Y + 12), tab, 8, HKTheme.GOLD if active else HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
		if active:
			draw_rect(Rect2(x, PANEL_Y + 14, HKTheme.text_width(tab, 8), 2), HKTheme.GOLD)
		x += HKTheme.text_width(tab, 8) + 12.0
	draw_rect(Rect2(PANEL_X + 4, PANEL_Y + 17, PANEL_W - 8, 1), HKTheme.GOLD_DARK)

# --- Pestaña HISTORIA -------------------------------------------------------------
func _draw_story() -> void:
	var d := _data()
	var lore := RosterLore.get_lore(d.id)
	var y := PANEL_Y + 30.0
	# Estadísticas en dos columnas
	var bars := [
		["VIDA", d.max_health / 130.0, Color("48b048")],
		["FUERZA", d.strength / 1.4, Color("d04848")],
		["VELOC.", d.walk_speed / 100.0, Color("48a0d8")],
		["DEFENSA", d.resistance / 1.4, Color("d8b038")],
	]
	for i in bars.size():
		var bx := TEXT_X + (i % 2) * 128.0
		var by := y + (i / 2) * 11.0
		HKTheme.draw_text(self, Vector2(bx, by), bars[i][0], 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
		draw_rect(Rect2(bx + 58, by - 7, 62, 6), BAR_BG)
		draw_rect(Rect2(bx + 58, by - 7, roundf(62.0 * clampf(bars[i][1], 0.1, 1.0)), 6), bars[i][2])
	y += 22.0
	draw_rect(Rect2(PANEL_X + 4, y - 4, PANEL_W - 8, 1), HKTheme.GOLD_DARK.darkened(0.3))
	y = _section(TEXT_X, y + 8.0, "QUIÉN FUE", _text_or(lore[0], d.bio))
	_section(TEXT_X, y + 13.0, "QUÉ HIZO", _text_or(lore[1], ""))

func _text_or(text: String, fallback: String) -> String:
	return text if text != "" else fallback

# --- Pestaña PODERES --------------------------------------------------------------
func _draw_powers() -> void:
	var d := _data()
	var lore := RosterLore.get_lore(d.id)
	var y := PANEL_Y + 22.0
	y = _skill(y, "ESPECIAL 1", d.special_1, lore[2], HKTheme.GOLD)
	_skill(y + 4.0, "ESPECIAL 2", d.special_2, lore[3], HKTheme.GOLD)
	# Combos al pie del panel (pueden ocupar dos líneas).
	var combos := PackedStringArray()
	for c in d.get_combos():
		combos.append(c.display_name)
	var lines := _wrap("COMBOS: " + " · ".join(combos), TEXT_W)
	var cy := PANEL_BOTTOM - 6.0 - (lines.size() - 1) * LINE_H
	draw_rect(Rect2(PANEL_X + 4, cy - 10.0, PANEL_W - 8, 1), HKTheme.GOLD_DARK.darkened(0.3))
	for line in lines:
		HKTheme.draw_text(self, Vector2(TEXT_X, cy), line, 8, BLUE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
		cy += LINE_H

# --- Pestaña ULTIMATE -------------------------------------------------------------
func _draw_ultimate() -> void:
	var d := _data()
	var red := Color("ff7050")
	var y := _skill(PANEL_Y + 22.0, "ULTIMATE", d.ultimate, RosterLore.ult_text(d.ultimate, d.id), red)
	draw_rect(Rect2(PANEL_X + 4, y + 2.0, PANEL_W - 8, 1), HKTheme.GOLD_DARK.darkened(0.3))
	y = _section(TEXT_X, y + 16.0, "CÓMO SE LANZA",
		"Especial 1 + Especial 2 a la vez, en el suelo y con la energía al 100.")
	_section(TEXT_X, y + 13.0, "EFECTO", RosterLore.ULT_TEXT.get(d.ultimate.ult_kind, "Ataque definitivo.") if d.ultimate else "")

## Un poder: línea de etiqueta con daño y coste, nombre en color y descripción. Devuelve la y siguiente.
func _skill(y: float, slot: String, atk: AttackData, desc: String, color: Color) -> float:
	if atk == null:
		return y
	var muted := HKTheme.MUTED.lightened(0.2)
	HKTheme.draw_text(self, Vector2(TEXT_X, y + 8), slot, 8, muted, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	var stats := "DAÑO %d" % roundi(atk.damage)
	if atk.energy_cost > 0.0:
		stats += " · ENERGÍA %d" % roundi(atk.energy_cost)
	HKTheme.draw_text(self, Vector2(TEXT_X, y + 8), stats, 8, muted, HORIZONTAL_ALIGNMENT_RIGHT, TEXT_W, 0)
	y += 11.0
	HKTheme.draw_text(self, Vector2(TEXT_X, y + 8), atk.display_name.to_upper(), 8, color, HORIZONTAL_ALIGNMENT_LEFT, TEXT_W, 1)
	y += 11.0
	for line in _wrap(desc, TEXT_W):
		HKTheme.draw_text(self, Vector2(TEXT_X, y + 8), line, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
		y += LINE_H
	return y + 3.0

# --- Texto -----------------------------------------------------------------------------
## Título de sección azul y párrafo ajustado debajo. Devuelve la y de la última línea.
func _section(x: float, y: float, title: String, text: String) -> float:
	HKTheme.draw_text(self, Vector2(x, y), title, 8, BLUE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	y += 1.0
	for line in _wrap(text, TEXT_W):
		y += LINE_H
		HKTheme.draw_text(self, Vector2(x, y), line, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	return y

## Parte un texto en líneas que caben en `width` píxeles.
func _wrap(text: String, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var test: String = word if line.is_empty() else line + " " + word
		if HKTheme.text_width(test, 8) > width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = test
	if not line.is_empty():
		lines.append(line)
	return lines
