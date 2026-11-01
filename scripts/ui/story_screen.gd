## Pantalla del MODO HISTORIA que se ve antes de cada combate.
##   Arriba   la línea del tiempo: un punto por rival, de hoy (izquierda) al origen (derecha),
##            agrupados en capítulos (I, II, III...). Dorado = vencido, parpadeo = combate actual,
##            rombo = jefe del capítulo, "?" = el secreto del final.
##   Centro   tu luchador y el rival sobre el escenario del rival, con su nombre y época.
##   Al empezar un capítulo nuevo se muestra primero su tarjeta de título.
## COMBATIR (o ENTER) empieza el combate; ESC vuelve al menú.
extends Control

const SHADE := Color(0.05, 0.02, 0.07, 0.78)
const BAR_X0 := 26.0
const BAR_X1 := 400.0
const BAR_Y := 48.0
const SPRITE_H := 96.0
const PLAYER_X := 80.0
const RIVAL_X := 346.0
## Segundos que dura la tarjeta de capítulo (los últimos 0.5 se desvanece).
const CARD_TIME := 2.4
const CARD_FADE := 0.5
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "?"]
const DONE := Color("f0c040")
const FUTURE := Color("5a4a58")

var _stage: Stage
var _t: float = 0.0
var _card: bool = false
var _btn: Button
## Capa superior para la tarjeta de capítulo (debe tapar también a los luchadores).
var _overlay: Control

func _ready() -> void:
	theme = HKTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rival := Game.p2_data()
	_load_stage(rival.id)
	_add_fighter(Game.p1_data(), PLAYER_X, 1)
	_add_fighter(rival, RIVAL_X, -1)
	_btn = Button.new()
	_btn.text = "¡COMBATIR!"
	_btn.custom_minimum_size = Vector2(110, 16)
	_btn.position = Vector2(158, 220)
	_btn.pressed.connect(func():
		Sfx.play(&"fight")
		Game.goto(Game.SCENE_FIGHT))
	_btn.focus_entered.connect(func(): Sfx.play(&"select"))
	add_child(_btn)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.draw.connect(_draw_card)
	_card = Game.story_chapter_start(Game.arcade_stage)
	_btn.visible = not _card
	if not _card:
		_btn.grab_focus()

func _load_stage(fighter_id: StringName) -> void:
	var packed := load(StageRegistry.scene_for(fighter_id)) as PackedScene
	if packed == null:
		packed = load(StageRegistry.COLOSSEUM)
	_stage = packed.instantiate() as Stage
	if _stage is ThemedStage:
		(_stage as ThemedStage).fighter_id = fighter_id
	# Un hijo se dibuja encima del padre; así el escenario queda detrás de los paneles.
	_stage.show_behind_parent = true
	add_child(_stage)

func _add_fighter(d: FighterData, x: float, facing: int) -> void:
	var r := FighterRenderer.new()
	add_child(r)
	r.setup(d)
	r.pose_name = &"idle"
	var s := clampf(SPRITE_H / maxf(r.approx_height(), 1.0), 0.8, 1.5)
	r.scale = Vector2(s * facing, s)
	r.position = Vector2(x, _stage.floor_y)

func _unhandled_input(event: InputEvent) -> void:
	if Game.is_changing_scene():
		return
	if _card and event.is_pressed() and not event.is_echo() and not event is InputEventMouseMotion:
		_t = maxf(_t, CARD_TIME - CARD_FADE)   # saltar la tarjeta
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		Game.goto(Game.SCENE_MENU)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_t += delta
	if _card and _t >= CARD_TIME:
		_card = false
		_btn.visible = true
		_btn.grab_focus()
	queue_redraw()
	_overlay.queue_redraw()

# =========================================================================
#  Dibujo
# =========================================================================
func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 62), SHADE)
	draw_rect(Rect2(0, 210, 426, 30), SHADE)
	_draw_timeline()
	_draw_plate()
	HKTheme.draw_text(self, Vector2(0, 218), "ESC: MENÚ", 8, HKTheme.MUTED.lightened(0.2), HORIZONTAL_ALIGNMENT_RIGHT, 420, 1)

## Línea del tiempo con todos los rivales.
func _draw_timeline() -> void:
	var ladder := Game.arcade_ladder
	var hidden := not Game.story_secret and Game.p1_fighter_id != Game.STORY_SECRET_ID
	var total := ladder.size() + (1 if hidden else 0)
	var step := (BAR_X1 - BAR_X0) / maxf(total - 1.0, 1.0)
	var cur := Game.arcade_stage
	var cur_chapter := Game.story_chapter_of(ladder[cur])
	HKTheme.draw_text(self, Vector2(0, 11), "MODO HISTORIA", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
	# Barra: gris la que falta, dorada la recorrida.
	draw_rect(Rect2(BAR_X0, BAR_Y - 1, BAR_X1 - BAR_X0, 2), FUTURE.darkened(0.3))
	draw_rect(Rect2(BAR_X0, BAR_Y - 1, step * cur, 2), DONE)
	# Capítulos: número romano centrado sobre sus puntos.
	var first := 0
	while first < total:
		var chapter := Game.story_chapter_of(ladder[first]) if first < ladder.size() else ROMAN.size() - 1
		var last := first
		while last + 1 < total and (Game.story_chapter_of(ladder[last + 1]) if last + 1 < ladder.size() else ROMAN.size() - 1) == chapter:
			last += 1
		var label := ROMAN[mini(chapter, ROMAN.size() - 1)]
		var cx := BAR_X0 + step * (first + last) * 0.5
		var col := HKTheme.GOLD if chapter == cur_chapter else HKTheme.MUTED
		HKTheme.draw_text(self, Vector2(cx - HKTheme.text_width(label, 8) * 0.5, BAR_Y - 9), label, 8, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		if first > 0:
			draw_rect(Rect2(BAR_X0 + step * (first - 0.5), BAR_Y - 5, 1, 10), FUTURE)
		first = last + 1
	# Puntos
	for i in total:
		var x := BAR_X0 + step * i
		if i >= ladder.size():
			HKTheme.draw_text(self, Vector2(x - 3, BAR_Y + 4), "?", 8, HKTheme.MUTED.lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
			continue
		var boss := Game.story_is_chapter_boss(i)
		var r := 3.0 if boss else 2.0
		if i < cur:
			_dot(x, r, DONE, boss)
		elif i == cur:
			var blink := 0.5 + 0.5 * sin(_t * 8.0)
			_dot(x, r + 2.0, Color("fff0a0").lerp(Color.WHITE, blink), boss)
		else:
			_dot(x, r, FUTURE, boss)
	# Flecha y año del combate actual
	var ax := BAR_X0 + step * cur
	draw_colored_polygon(PackedVector2Array([Vector2(ax, BAR_Y + 7), Vector2(ax - 3, BAR_Y + 11), Vector2(ax + 3, BAR_Y + 11)]), Color("fff0a0"))
	var year := _year_text(Game.p2_data())
	var w := HKTheme.text_width(year, 8)
	HKTheme.draw_text(self, Vector2(clampf(ax - w * 0.5, 4.0, 422.0 - w), BAR_Y + 21), year, 8, Color("fff0a0"), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

## Punto de la línea del tiempo: cuadrado, o rombo si es el jefe del capítulo.
func _dot(x: float, r: float, color: Color, diamond: bool) -> void:
	if diamond:
		draw_colored_polygon(PackedVector2Array([Vector2(x, BAR_Y - r - 1), Vector2(x + r + 1, BAR_Y),
			Vector2(x, BAR_Y + r + 1), Vector2(x - r - 1, BAR_Y)]), color)
	else:
		draw_rect(Rect2(x - r, BAR_Y - r, r * 2.0, r * 2.0), color)

func _year_text(d: FighterData) -> String:
	return "%d A.C." % -d.year if d.year < 0 else str(d.year)

## Placa central con el capítulo, el número de combate y los datos del rival.
func _draw_plate() -> void:
	var d := Game.p2_data()
	var stage := Game.arcade_stage
	var boss := Game.story_is_chapter_boss(stage)
	var secret := Game.is_story_secret_fight()
	var r := Rect2(150, 72, 126, 126)
	draw_rect(r, SHADE)
	draw_rect(r, HKTheme.GOLD_DARK, false, 1.0)
	var cx := 213.0
	_centered(cx, 84, "COMBATE %d/%d" % [stage + 1, Game.arcade_ladder.size()], HKTheme.MUTED.lightened(0.25))
	var tag := ""
	if secret:
		tag = "JEFE SECRETO"
	elif boss:
		tag = "JEFE DEL CAPÍTULO"
	if tag != "":
		_centered(cx, 96, tag, Color("ff7050") if secret else HKTheme.GOLD)
	HKTheme.draw_text(self, Vector2(cx - 54, 116), "VS", 16, HKTheme.BLOOD, HORIZONTAL_ALIGNMENT_CENTER, 108, 3)
	var y := 138.0
	for line in _wrap(d.display_name.to_upper(), 114.0):
		_centered(cx, y, line, HKTheme.PAPER)
		y += 10.0
	_centered(cx, y + 2.0, d.country.to_upper(), HKTheme.GOLD)
	_centered(cx, y + 12.0, d.era, HKTheme.MUTED.lightened(0.25))

## Tarjeta de título del capítulo, a pantalla completa, que se desvanece.
func _draw_card() -> void:
	var a := clampf((CARD_TIME - _t) / CARD_FADE, 0.0, 1.0)
	if a <= 0.0:
		return
	var chapter := Game.story_chapter_of(Game.arcade_ladder[Game.arcade_stage])
	_overlay.draw_rect(Rect2(0, 0, 426, 240), Color(0.03, 0.02, 0.05, a))
	var fade := Color(1, 1, 1, a)
	var title := "CAPÍTULO %s" % ROMAN[mini(chapter, ROMAN.size() - 1)] if chapter < Game.STORY_CHAPTERS.size() else "FINAL SECRETO"
	HKTheme.draw_text(_overlay, Vector2(0, 104), title, 16, HKTheme.GOLD * fade, HORIZONTAL_ALIGNMENT_CENTER, 426, 3 if a > 0.5 else 0)
	HKTheme.draw_text(_overlay, Vector2(0, 126), Game.story_chapter_name(chapter), 8, HKTheme.PAPER * fade, HORIZONTAL_ALIGNMENT_CENTER, 426, 2 if a > 0.5 else 0)
	var first := Game.arcade_stage
	var last := first
	while last + 1 < Game.arcade_ladder.size() and Game.story_chapter_of(Game.arcade_ladder[last + 1]) == chapter:
		last += 1
	var span := "%s  ›  %s" % [_year_text(FighterRegistry.get_by_id(Game.arcade_ladder[first])),
		_year_text(FighterRegistry.get_by_id(Game.arcade_ladder[last]))]
	HKTheme.draw_text(_overlay, Vector2(0, 142), span, 8, HKTheme.MUTED.lightened(0.2) * fade, HORIZONTAL_ALIGNMENT_CENTER, 426, 0)
	HKTheme.draw_text(_overlay, Vector2(0, 158), "%d COMBATES · %d REVANCHAS" % [last - first + 1, Game.arcade_continues],
		8, HKTheme.MUTED * fade, HORIZONTAL_ALIGNMENT_CENTER, 426, 0)

func _centered(cx: float, y: float, text: String, color: Color) -> void:
	HKTheme.draw_text(self, Vector2(cx - HKTheme.text_width(text, 8) * 0.5, y), text, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

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
