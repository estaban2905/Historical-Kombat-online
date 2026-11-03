## Rejilla con todos los luchadores y una casilla "?" delante. Según Game.picker_purpose sirve para:
##   "avatar"   elegir el retrato de la cuenta ("?" lo quita); se guarda en el servidor y vuelve al perfil.
##   "ranking"  filtrar el ranking por luchador ("?" = todos); vuelve al ranking.
## Flechas para moverse, ENTER para elegir, ESC para volver sin cambiar nada.
extends Control

const COLS := 9
const CELL := Vector2(22, 18)
const ORIGIN := Vector2(114, 40)

var _ids: Array[String] = [""]   # la casilla 0 es "sin avatar"
var _cursor: int = 0
var _saving: bool = false
var _error_until: float = 0.0
var _overlay: Control
var _preview: AvatarFrame

func _ready() -> void:
	theme = HKTheme.theme()
	if not _for_ranking() and not Backend.is_logged_in():
		Game.goto.call_deferred(Game.SCENE_MENU)
		return
	for d in FighterRegistry.all():
		_ids.append(str(d.id))
	_cursor = maxi(_ids.find(Game.ranking_fighter if _for_ranking() else Backend.avatar()), 0)
	for i in _ids.size():
		var cell := AvatarFrame.new(CELL)
		cell.position = _cell_pos(i)
		cell.set_fighter(_ids[i])
		add_child(cell)
	_preview = AvatarFrame.new(Vector2(48, 48))
	_preview.position = Vector2(46, 56)
	add_child(_preview)
	_preview.set_fighter(_ids[_cursor])
	# La capa del cursor va la última para quedar encima de las casillas.
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_cursor)
	add_child(_overlay)

func _for_ranking() -> bool:
	return Game.picker_purpose == "ranking"

## A dónde se vuelve: al ranking o al perfil.
func _back_scene() -> String:
	return Game.SCENE_RANKING if _for_ranking() else Game.SCENE_PROFILE

func _cell_pos(i: int) -> Vector2:
	return ORIGIN + Vector2(i % COLS, i / COLS) * CELL

func _unhandled_input(event: InputEvent) -> void:
	if _saving:
		return
	if event.is_action_pressed(&"ui_cancel"):
		Game.goto(_back_scene())
		get_viewport().set_input_as_handled()
		return
	var step := Vector2i.ZERO
	if event.is_action_pressed(&"ui_left"): step.x = -1
	elif event.is_action_pressed(&"ui_right"): step.x = 1
	elif event.is_action_pressed(&"ui_up"): step.y = -1
	elif event.is_action_pressed(&"ui_down"): step.y = 1
	if step != Vector2i.ZERO:
		var n := _ids.size()
		_cursor = posmod(_cursor + step.x + step.y * COLS, n)
		_preview.set_fighter(_ids[_cursor])
		Sfx.play(&"select")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		_save()

func _save() -> void:
	if _for_ranking():
		Game.ranking_fighter = _ids[_cursor]
		Sfx.play(&"confirm")
		Game.goto(Game.SCENE_RANKING)
		return
	_saving = true
	if await Backend.set_avatar(_ids[_cursor]):
		Sfx.play(&"confirm")
		Game.goto(Game.SCENE_PROFILE)
		return
	Sfx.play(&"denied")
	_error_until = Time.get_ticks_msec() / 1000.0 + 2.5
	_saving = false

func _process(_delta: float) -> void:
	queue_redraw()
	if _overlay:
		_overlay.queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 240), HKTheme.INK)
	HKTheme.draw_text(self, Vector2(0, 24), "FILTRAR POR LUCHADOR" if _for_ranking() else "TU AVATAR", 16, HKTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	var id := _ids[_cursor]
	var label := "TODOS LOS LUCHADORES" if _for_ranking() else "SIN AVATAR"
	var detail := ""
	if id != "":
		var d := FighterRegistry.get_by_id(StringName(id))
		label = d.display_name.to_upper()
		detail = ("%s · %s" % [d.country, d.era]).to_upper() if d.country != "" else d.era.to_upper()
	HKTheme.draw_text(self, Vector2(0, 176), label, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	HKTheme.draw_text(self, Vector2(0, 190), detail, 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	if _saving:
		HKTheme.draw_text(self, Vector2(0, 208), "GUARDANDO...", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	elif Time.get_ticks_msec() / 1000.0 < _error_until:
		HKTheme.draw_text(self, Vector2(0, 208), "NO SE PUDO GUARDAR", 8, HKTheme.BLOOD, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
	else:
		HKTheme.draw_text(self, Vector2(0, 218), "ENTER: ELEGIR   ESC: VOLVER", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)

func _draw_cursor() -> void:
	var blink := int(Time.get_ticks_msec() / 160.0) % 2 == 0
	if blink:
		_overlay.draw_rect(Rect2(_cell_pos(_cursor) - Vector2(1, 1), CELL + Vector2(1, 1)), HKTheme.GOLD, false, 2.0)
