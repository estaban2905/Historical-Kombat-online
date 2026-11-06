## Pantalla del MODO HISTORIA que se ve antes de cada combate.
##   Arriba   la cabecera: el frente, el año del rival y los fragmentos del Reloj (el progreso por las ciudades
##            lo muestra el mapa del mundo, que se ve antes de cada combate).
##   Centro   tu luchador y el rival sobre la ciudad invadida por su ejército (la Torre del Reloj, el Nexo), con su nombre y época.
##   Al empezar un capítulo nuevo se muestra primero su tarjeta de título.
## COMBATIR (o ENTER) empieza el combate; ESC o VOLVER regresa a la selección de luchador (o al menú).
extends Control

const SHADE := Color(0.05, 0.02, 0.07, 0.78)
const BAR_X0 := 26.0
const SPRITE_H := 96.0
const PLAYER_X := 80.0
const RIVAL_X := 346.0
## Segundos que dura la tarjeta de capítulo (los últimos 0.5 se desvanece).
const CARD_TIME := 2.4
const CARD_FADE := 0.5
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V", "?"]
const FUTURE := Color("5a4a58")

var _stage: Stage
var _t: float = 0.0
var _card: bool = false
var _btn: Button
var _back: BackButton
## Capa superior para la tarjeta de capítulo (debe tapar también a los luchadores).
var _overlay: Control
## Animación en curso (mini-intro del Nexo y/o arranque de la época); mientras existe, la tarjeta
## y el botón esperan. Solo Enter las salta todas.
var _intro: Node
var _skip_intros: bool = false
## Globo terráqueo en curso (donde se elige a quién detener y el viaje hasta su ciudad); mientras existe, el resto espera.
var _map: StoryGlobeMap
var _rival_fig: FighterRenderer
var _auto_fight: bool = false
## El creador poseído pelea en la misma batalla que el jefe: no hay nada que elegir ni viaje.
var _skip_globe: bool = false

func _ready() -> void:
	theme = HKTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_stage(Game.stage_owner(1))
	_add_fighter(Game.p1_data(), PLAYER_X, 1)
	_rival_fig = _add_fighter(Game.p2_data(), RIVAL_X, -1)
	_btn = Button.new()
	_btn.text = "¡COMBATIR!"
	_btn.custom_minimum_size = Vector2(110, 16)
	_btn.position = Vector2(158, 220)
	_btn.pressed.connect(func():
		Sfx.play(&"fight")
		Game.goto(Game.SCENE_FIGHT))
	_btn.focus_entered.connect(func(): Sfx.play(&"select"))
	add_child(_btn)
	_back = BackButton.add_to(self, _go_back)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.draw.connect(_draw_card)
	_card = Game.story_chapter_fresh()
	_auto_fight = Game.story_possessed_entry
	Game.story_possessed_entry = false
	_skip_globe = _auto_fight or Game.story_is_creator(Game.arcade_stage)
	_btn.visible = false
	_back.visible = false
	if not _skip_globe:
		_make_map()
	if not _card:
		_after_card()
	if _card:
		# En el primer combate, la mini-intro del Nexo; después, la animación de la época.
		# Al acabar (o saltarlas) sigue la tarjeta del capítulo.
		if Game.arcade_stage == 0:
			_play_intro(StoryPrologue.new(), true)
		else:
			_play_era_intro()

## Tras la tarjeta del capítulo: el globo, donde se elige a quién detener y se viaja a su ciudad. El creador poseído
## pelea en la misma batalla: sin globo.
func _after_card() -> void:
	if not _skip_globe:
		_play_map()
		return
	_after_map()

## El globo se coloca desde el principio, tapando el escenario de la pelea, y espera (en negro) debajo de la
## tarjeta del capítulo y de las animaciones: así nunca se ve el combate antes del viaje.
func _make_map() -> void:
	var map := StoryGlobeMap.new()
	map.waiting = true
	_map = map
	map.picked.connect(_on_picked)
	map.cancelled.connect(_go_back)
	map.finished.connect(func():
		_map = null
		_after_map())
	add_child(map)
	move_child(map, _overlay.get_index())

func _play_map() -> void:
	_btn.visible = false
	_back.visible = false
	_map.waiting = false

## El jugador eligió a quién detener: el escenario y el rival de debajo del globo pasan a ser los suyos.
func _on_picked(_stage_index: int) -> void:
	if _stage:
		_stage.queue_free()
	if _rival_fig:
		_rival_fig.queue_free()
	_load_stage(Game.stage_owner(1))
	_rival_fig = _add_fighter(Game.p2_data(), RIVAL_X, -1)
	# Lo nuevo se añade al final: el globo y la tarjeta tienen que seguir por encima.
	if _map:
		move_child(_map, -1)
	move_child(_overlay, -1)

## Tras el mapa: la escena de diálogo del rival, si tiene, y después el botón de combatir.
func _after_map() -> void:
	var scene := StoryScenes.lines(Game.p2_fighter_id, Game.p1_fighter_id)
	if scene.is_empty():
		_show_fight_button()
		return
	var d := StoryDialogue.new()
	d.lines = scene
	d.scene_id = StoryScenes.scene_id(Game.p2_fighter_id, Game.p1_fighter_id)
	d.finished.connect(_show_fight_button)
	add_child(d)

func _show_fight_button() -> void:
	if _auto_fight:
		# Creador poseído: la pelea sigue enseguida, sin botón.
		_auto_fight = false
		await get_tree().create_timer(0.8).timeout
		if is_inside_tree() and not Game.is_changing_scene():
			Sfx.play(&"fight")
			Game.goto(Game.SCENE_FIGHT)
		return
	_btn.visible = true
	_back.visible = true
	_btn.grab_focus()

func _play_intro(intro: Node, then_era: bool) -> void:
	_intro = intro
	add_child(intro)
	intro.finished.connect(func():
		_intro = null
		if then_era and not _skip_intros:
			_play_era_intro())

func _play_era_intro() -> void:
	var era := StoryEraIntro.new()
	era.chapter = Game.story_chapter_of(Game.arcade_ladder[Game.arcade_stage])
	_play_intro(era, false)

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

func _add_fighter(d: FighterData, x: float, facing: int) -> FighterRenderer:
	var r := FighterRenderer.new()
	add_child(r)
	r.setup(d)
	r.pose_name = &"idle"
	var s := clampf(SPRITE_H / maxf(r.approx_height(), 1.0), 0.8, 1.5)
	r.scale = Vector2(s * facing, s)
	r.position = Vector2(x, _stage.floor_y)
	return r

## A la selección de luchador si se llegó desde ahí; si no (CONTINUAR), al menú.
func _go_back() -> void:
	Game.goto(Game.back_target())

func _unhandled_input(event: InputEvent) -> void:
	if Game.is_changing_scene():
		return
	if _card and HKTheme.is_enter(event):
		_t = maxf(_t, CARD_TIME - CARD_FADE)   # saltar la tarjeta y las animaciones, si las hay
		_skip_intros = true
		if _intro:
			_intro.skip()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel") and not _card:
		_go_back()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _intro:
		return
	_t += delta
	if _card and _t >= CARD_TIME:
		_card = false
		_after_card()
	queue_redraw()
	_overlay.queue_redraw()

# =========================================================================
#  Dibujo
# =========================================================================
func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 36), SHADE)
	draw_rect(Rect2(0, 210, 426, 30), SHADE)
	_draw_header()
	_draw_plate()
	HKTheme.draw_text(self, Vector2(0, 218), "ESC: MENÚ", 8, HKTheme.MUTED.lightened(0.2), HORIZONTAL_ALIGNMENT_RIGHT, 420, 1)

## Cabecera: el frente en el que estás, el año del rival y los fragmentos del Reloj recuperados.
## El progreso por las ciudades ya lo cuenta el mapa del mundo, que se ve antes de cada combate.
func _draw_header() -> void:
	var chapter := Game.story_chapter_of(Game.arcade_ladder[Game.arcade_stage])
	HKTheme.draw_text(self, Vector2(0, 11), "MODO HISTORIA", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
	_draw_fragments()
	var front := "FRENTE %s" % ROMAN[mini(chapter, ROMAN.size() - 1)] if chapter < Game.STORY_CHAPTERS.size() else "EL NEXO"
	var label := "%s  ·  %s" % [front, Game.story_chapter_name(chapter)]
	_centered(213.0, 28.0, label, HKTheme.MUTED.lightened(0.25))
	var year := _year_text(Game.p2_data())
	HKTheme.draw_text(self, Vector2(0, 11), year, 8, Color("fff0a0"), HORIZONTAL_ALIGNMENT_RIGHT, 400, 1)

## Los cinco fragmentos del Reloj, arriba a la izquierda: de color los que ya se recuperaron.
func _draw_fragments() -> void:
	HKTheme.draw_text(self, Vector2(BAR_X0, 11), "RELOJ", 8, HKTheme.MUTED.lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	for c in Game.STORY_CHAPTERS.size():
		var x := BAR_X0 + 46.0 + c * 11.0
		var col: Color = StoryEnding.SHARD_COLORS[c]
		if Game.story_fragment_earned(c):
			draw_colored_polygon(PackedVector2Array([Vector2(x + 4, 4), Vector2(x + 8, 8), Vector2(x + 4, 12), Vector2(x, 8)]), col)
		else:
			draw_polyline(PackedVector2Array([Vector2(x + 4, 4), Vector2(x + 8, 8), Vector2(x + 4, 12), Vector2(x, 8), Vector2(x + 4, 4)]),
				FUTURE, 1.0)

func _year_text(d: FighterData) -> String:
	if d.id == Game.STORY_NEXO_ID:
		return "????"
	return "%d A.C." % -d.year if d.year < 0 else str(d.year)

## Placa central con el capítulo, el número de combate y los datos del rival.
func _draw_plate() -> void:
	var d := Game.p2_data()
	var stage := Game.arcade_stage
	var boss := Game.story_is_chapter_boss(stage)
	var r := Rect2(150, 72, 126, 112)
	draw_rect(r, SHADE)
	draw_rect(r, HKTheme.GOLD_DARK, false, 1.0)
	var cx := 213.0
	_centered(cx, 84, "COMBATE %d/%d" % [Game.story_fight_number(), Game.arcade_ladder.size()], HKTheme.MUTED.lightened(0.25))
	var tag := ""
	if Game.is_story_nexo_fight():
		tag = "JEFE FINAL"
	elif boss:
		tag = "JEFE DE LA ÉPOCA"
	elif Game.story_is_creator(stage):
		tag = "CREADOR POSEÍDO"
	if tag != "":
		_centered(cx, 96, tag, HKTheme.GOLD)
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
	var title := "FRENTE %s" % ROMAN[mini(chapter, ROMAN.size() - 1)] if chapter < Game.STORY_CHAPTERS.size() else "EL NEXO"
	HKTheme.draw_text(_overlay, Vector2(0, 104), title, 16, HKTheme.GOLD * fade, HORIZONTAL_ALIGNMENT_CENTER, 426, 3 if a > 0.5 else 0)
	HKTheme.draw_text(_overlay, Vector2(0, 126), Game.story_chapter_name(chapter), 8, HKTheme.PAPER * fade, HORIZONTAL_ALIGNMENT_CENTER, 426, 2 if a > 0.5 else 0)
	var first := Game.arcade_stage
	var last := first
	while last + 1 < Game.arcade_ladder.size() and Game.story_chapter_of(Game.arcade_ladder[last + 1]) == chapter:
		last += 1
	var span := "%s  ›  %s" % [_year_text(FighterRegistry.get_by_id(Game.arcade_ladder[first])),
		_year_text(FighterRegistry.get_by_id(Game.arcade_ladder[last]))]
	var final := chapter >= Game.STORY_CHAPTERS.size()
	if final:
		span = "FUERA DEL TIEMPO"
	HKTheme.draw_text(_overlay, Vector2(0, 142), span, 8, HKTheme.MUTED.lightened(0.2) * fade, HORIZONTAL_ALIGNMENT_CENTER, 426, 0)
	var nexo: Array = Game.STORY_NEXO_LINES[mini(chapter, Game.STORY_NEXO_LINES.size() - 1)]
	for i in nexo.size():
		HKTheme.draw_text(_overlay, Vector2(0, 176 + i * 11), nexo[i], 8, Color("9a4dff").lightened(0.4) * fade, HORIZONTAL_ALIGNMENT_CENTER, 426, 0)
	var react := Game.story_nexo_reaction()
	for i in react.size():
		HKTheme.draw_text(_overlay, Vector2(0, 208 + i * 11), react[i], 8, HKTheme.GOLD.darkened(0.1) * fade, HORIZONTAL_ALIGNMENT_CENTER, 426, 0)
	var count := "EL COMBATE FINAL · REVANCHAS ILIMITADAS" if final \
		else "%d COMBATES · REVANCHAS ILIMITADAS" % [last - first + 1]
	HKTheme.draw_text(_overlay, Vector2(0, 158), count, 8, HKTheme.MUTED * fade, HORIZONTAL_ALIGNMENT_CENTER, 426, 0)

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
