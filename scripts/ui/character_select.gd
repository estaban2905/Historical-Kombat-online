## Selección de luchador para el modo Historia, el Duelo online y el entrenamiento (y el modo de dos
## jugadores en el mismo equipo que usan las pruebas).
## Selector de épocas: una pestaña por período histórico y, debajo, solo los luchadores de esa época en casillas grandes.
## En el modo Historia, los luchadores que aún no se han ganado también salen bloqueados (ver Unlocks);
## en el duelo online con ranking están los 50 abiertos.
##   J1: A/D/W/S mover · U confirmar · J cancelar · I/K cambiar de época (o W en la fila de arriba)
##   J2: Flechas mover · Num1 (o Supr) confirmar · Num4 (o Insert) cancelar · Num2/Num5 cambiar de época
##   Ratón: pasar por una casilla la señala, clic izquierdo elige (o elige época en las pestañas)
##   A/D al llegar al borde de una época pasan a la siguiente, así se recorre todo el plantel seguido.
##   ESC: volver al menú
class_name CharacterSelect
extends Control

const COLS := 5
const ROWS := 3
const CELL := Vector2(39, 30)
const GRID_ORIGIN := Vector2(115, 43)
## Aumento del busto dentro de cada casilla (cabeza y hombros).
const BUST_SCALE := 1.45
## Épocas: [nombre, año mínimo, año máximo] según el año de nacimiento de cada luchador.
const ERAS: Array = [
	["ANTIGÜEDAD", -100000, 499],
	["MEDIEVAL", 500, 1600],
	["MODERNA", 1601, 1869],
	["SIGLO XX", 1870, 1939],
	["ACTUAL", 1940, 100000],
]
const TAB_Y := 25.0
const TAB_H := 13.0
const P1_COLOR := Color("e83a3a")
const P2_COLOR := Color("3a8af0")
const SHADE := Color(0.05, 0.02, 0.07, 0.78)
## Placas de información de cada jugador (a los lados de la rejilla).
const PLATE_W := 104.0
const PLATE_Y := 43.0
const PREVIEW_X := [62.0, 364.0]
## Alto en pantalla del luchador de la vista previa.
const PREVIEW_H := 104.0
## Montar un escenario es caro: se cambia solo cuando el cursor lleva un rato quieto.
const STAGE_DELAY := 0.3

var roster: Array[FighterData] = []
var cursor: Array[int] = [0, 0, 1]      # índice de casilla por jugador (1 y 2)
var confirmed: Array[bool] = [false, false, false]
var _previews: Array = [null, null, null]
var _t: float = 0.0
var _starting: bool = false
## Modo Historia (1 jugador vs CPU) y online: solo elige J1; el rival lo pone la línea del
## tiempo de Game o el servidor. Se llama _cpu porque oculta el panel de J2.
var _cpu: bool = false
var _inputs: Array = [null, InputManager.new(1), InputManager.new(2)]
## Capa superior para dibujar los cursores por encima de los retratos.
var _overlay: Control
## Escenario de fondo: el del último luchador que se miró.
var _stage: Stage
var _stage_id: StringName = &""
var _floor_y: float = 206.0
var _stage_cache: Dictionary = {}       # id del luchador -> escenario ya construido
var _preload_queue: Array[StringName] = []
var _stage_pending: StringName = &""
var _stage_wait: float = 0.0
## Estado dibujado la última vez: solo se redibuja si cambia (y el cursor al parpadear).
var _drawn_key: Array = []
var _drawn_blink: int = -1
var _wrap_cache: Dictionary = {}
## Épocas: índices del plantel de cada una (ordenados por año), época mostrada, jugador que mira la rejilla y
## quién tiene el foco en las pestañas (en vez de en las casillas).
var _era_lists: Array = []
var _view_era: int = -1
var _focus_p: int = 1
var _tabs: Array[bool] = [false, false, false]
var _cells: Dictionary = {}             # índice del plantel -> casilla con el busto
## Historia: las partidas guardadas por id de luchador. Se leen del equipo al abrir y, con sesión, se
## completan con las de la cuenta; hasta entonces no se sabe si el luchador elegido ya tiene una.
var _saves: Dictionary = {}
var _saves_ready: bool = false
signal saves_loaded
## Mientras se espera a las partidas o se muestra el aviso, la selección no atiende los mandos.
var _asking: bool = false
var _dialog: Control
var _dialog_first: Button
var _back: BackButton

func _ready() -> void:
	theme = HKTheme.theme()
	_cpu = Game.is_vs_cpu() or Game.is_online()
	confirmed[2] = _cpu
	roster = FighterRegistry.all().duplicate()
	cursor[1] = FighterRegistry.index_of(Game.p1_fighter_id)
	cursor[2] = FighterRegistry.index_of(Game.p2_fighter_id)
	cursor[1] = _first_unlocked(cursor[1])
	cursor[2] = _first_unlocked(cursor[2])
	if roster.size() > 1 and cursor[1] == cursor[2]:
		cursor[2] = _first_unlocked((cursor[1] + 1) % roster.size())
		if cursor[2] == cursor[1]:
			cursor[2] = (cursor[1] + 1) % roster.size()
	_build_eras()
	_view_era = _era_of(cursor[1])
	_load_stage(roster[cursor[1]].id if cursor[1] < roster.size() else roster[0].id)
	for i in roster.size():
		if not _is_locked(i):
			_preload_queue.append(roster[i].id)
	_build_cells()
	_layout_cells()
	_back =BackButton.add_to(self, _on_back)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.draw.connect(_draw_cursors)
	for p in [1, 2]:
		var r := FighterRenderer.new()
		add_child(r)
		_previews[p] = r
		_refresh_preview(p)
		if _cpu and p == 2:
			r.visible = false
	# La capa de cursores y del VS va la última para quedar encima de todo.
	move_child(_overlay, -1)
	if _is_story():
		_load_saves()

## Modo Historia (contra la CPU, no el duelo online).
func _is_story() -> bool:
	return _cpu and not Game.is_online()

func _load_saves() -> void:
	_saves = Backend.stories_local()
	if Backend.is_logged_in():
		_saves = await Backend.load_stories()
	if not is_inside_tree():
		return
	_saves_ready = true
	_drawn_key = []   # que se redibuje con las marcas de partida guardada
	saves_loaded.emit()

## ¿Esta casilla es un luchador que todavía no se puede usar? Solo en el modo Historia.
func _is_locked(i: int) -> bool:
	if i >= roster.size() or Game.mode != Game.Mode.ARCADE:
		return false
	return not Unlocks.fighter_unlocked(roster[i].id)

## La primera casilla desde `from` (dando la vuelta) con un luchador utilizable.
func _first_unlocked(from: int) -> int:
	for k in roster.size():
		var i := (from + k) % roster.size()
		if not _is_locked(i):
			return i
	return from

## Reparte el plantel por épocas (por año de nacimiento) y lo ordena dentro de cada una.
func _build_eras() -> void:
	_era_lists = []
	for e in ERAS:
		_era_lists.append([])
	for i in roster.size():
		var y := roster[i].year
		for k in ERAS.size():
			if y >= int(ERAS[k][1]) and y <= int(ERAS[k][2]):
				(_era_lists[k] as Array).append(i)
				break
	for l in _era_lists:
		(l as Array).sort_custom(func(a: int, b: int) -> bool:
			return roster[a].year < roster[b].year or (roster[a].year == roster[b].year and a < b))

func _era_of(idx: int) -> int:
	for k in _era_lists.size():
		if (_era_lists[k] as Array).has(idx):
			return k
	return 0

func _slot_of(idx: int) -> int:
	return (_era_lists[_era_of(idx)] as Array).find(idx)

## Siguiente (dir 1) o anterior (dir -1) luchador; al salir de una época pasa a la vecina que tenga gente.
func _step(c: int, dir: int) -> int:
	var e := _era_of(c)
	var s := _slot_of(c) + dir
	var list: Array = _era_lists[e]
	if s >= 0 and s < list.size():
		return list[s]
	for _k in _era_lists.size():
		e = (e + dir + _era_lists.size()) % _era_lists.size()
		list = _era_lists[e]
		if not list.is_empty():
			return list[0] if dir > 0 else list[list.size() - 1]
	return c

## Salta a la época vecina conservando la posición dentro de la rejilla en lo posible.
func _hop_era(c: int, dir: int) -> int:
	var slot := _slot_of(c)
	var e := _era_of(c)
	for _k in _era_lists.size():
		e = (e + dir + _era_lists.size()) % _era_lists.size()
		var list: Array = _era_lists[e]
		if not list.is_empty():
			return list[mini(slot, list.size() - 1)]
	return c

func _build_cells() -> void:
	for i in roster.size():
		if _is_locked(i):
			continue
		var cell := Control.new()
		cell.clip_contents = true
		cell.size = CELL - Vector2(2, 2)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		var bust := FighterRenderer.new()
		bust.draw_shadow = false
		# Retrato fijo: se dibuja una vez en setup(); sin _process no se redibuja cada frame.
		bust.set_process(false)
		bust.setup(roster[i])
		bust.scale = Vector2(BUST_SCALE, BUST_SCALE)
		# Pies fuera de la casilla: solo se ve cabeza y hombros, grandes.
		bust.position = Vector2(cell.size.x * 0.5 - 2.0 * BUST_SCALE, bust.approx_height() * BUST_SCALE + 1.0)
		cell.add_child(bust)
		_cells[i] = cell

## Muestra solo las casillas de la época actual, en su sitio.
func _layout_cells() -> void:
	for i in _cells:
		var cell: Control = _cells[i]
		cell.visible = _era_of(i) == _view_era
		if cell.visible:
			cell.position = _cell_pos(i) + Vector2(1, 1)

## Posición de la casilla de un luchador en la rejilla de su época.
func _cell_pos(i: int) -> Vector2:
	var slot := _slot_of(i)
	return GRID_ORIGIN + Vector2(slot % COLS, slot / COLS) * CELL

func _refresh_preview(p: int) -> void:
	var r: FighterRenderer = _previews[p]
	if cursor[p] < roster.size() and not _is_locked(cursor[p]):
		r.visible = true
		r.setup(roster[cursor[p]])
		r.pose_name = &"victory" if confirmed[p] else &"idle"
		# Todos se escalan a un alto parecido y quedan de pie sobre el suelo del escenario.
		var sc := clampf(PREVIEW_H / maxf(r.approx_height(), 1.0), 0.8, 1.5)
		r.scale = Vector2(sc if p == 1 else -sc, sc)
		r.position = Vector2(PREVIEW_X[p - 1], _floor_y)
	else:
		r.visible = false

## Pone de fondo el escenario del luchador (el mismo que tendrá en combate).
func _load_stage(fighter_id: StringName) -> void:
	if _stage and _stage_id == fighter_id:
		return
	_stage_id = fighter_id
	if _stage:
		_set_stage_active(_stage, false)
	_stage = _stage_for(fighter_id)
	_set_stage_active(_stage, true)
	_floor_y = _stage.floor_y
	for p in [1, 2]:
		if _previews[p]:
			(_previews[p] as FighterRenderer).position.y = _floor_y

## El escenario de ese luchador: del caché si ya se construyó; si no, se construye y se guarda
## (oculto y sin procesar) para no rearmarlo la próxima vez.
func _stage_for(fighter_id: StringName) -> Stage:
	if _stage_cache.has(fighter_id):
		return _stage_cache[fighter_id]
	var packed := load(StageRegistry.scene_for(fighter_id)) as PackedScene
	if packed == null:
		packed = load(StageRegistry.COLOSSEUM)
	var st := packed.instantiate() as Stage
	if st is ThemedStage:
		(st as ThemedStage).fighter_id = fighter_id
	# Un hijo se dibuja encima del padre; así el escenario queda detrás de la rejilla y los textos.
	st.show_behind_parent = true
	_set_stage_active(st, false)
	add_child(st)
	move_child(st, 0)
	_stage_cache[fighter_id] = st
	return st

func _set_stage_active(st: Stage, on: bool) -> void:
	st.visible = on
	st.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED

## Construye de a un escenario por frame mientras el jugador no mueve el cursor.
func _preload_next_stage() -> void:
	while not _preload_queue.is_empty():
		var id: StringName = _preload_queue.pop_front()
		if not _stage_cache.has(id):
			_stage_for(id)
			return

func _process(delta: float) -> void:
	_t += delta
	if _stage_pending == &"" and not _starting:
		_preload_next_stage()
	if not _starting and not _asking:
		for p in ([1] if _cpu else [1, 2]):
			_handle_player(p)
	if _stage_pending != &"":
		_stage_wait -= delta
		if _stage_wait <= 0.0:
			_load_stage(_stage_pending)
			_stage_pending = &""
	var want := _era_of(cursor[_focus_p])
	if want != _view_era:
		_view_era = want
		_layout_cells()
	var key := [cursor[1], cursor[2], confirmed[1], confirmed[2], _starting, _view_era, _tabs[1], _tabs[2]]
	var blink := int(_t * 6.0) % 2
	if key != _drawn_key:
		_drawn_key = key
		queue_redraw()
		_overlay.queue_redraw()
	elif blink != _drawn_blink:
		_overlay.queue_redraw()
	_drawn_blink = blink

func _handle_player(p: int) -> void:
	var inp: InputManager = _inputs[p]
	if not confirmed[p]:
		var c: int = cursor[p]
		var list: Array = _era_lists[_era_of(c)]
		var slot := _slot_of(c)
		var moved := false
		if inp.just_pressed(&"left"):
			c = _hop_era(c, -1) if _tabs[p] else _step(c, -1); moved = true
		elif inp.just_pressed(&"right"):
			c = _hop_era(c, 1) if _tabs[p] else _step(c, 1); moved = true
		elif inp.just_pressed(&"punch_heavy"):
			c = _hop_era(c, 1); moved = true
		elif inp.just_pressed(&"kick_heavy"):
			c = _hop_era(c, -1); moved = true
		elif inp.just_pressed(&"jump"):
			if _tabs[p]:
				pass
			elif slot < COLS:
				_set_tabs(p, true)
			else:
				c = list[slot - COLS]; moved = true
		elif inp.just_pressed(&"crouch"):
			if _tabs[p]:
				_set_tabs(p, false)
			elif slot / COLS < (list.size() - 1) / COLS:
				c = list[mini(slot + COLS, list.size() - 1)]; moved = true
		if moved:
			_move_cursor(p, c)
		if inp.just_pressed(&"punch_light"):
			if _tabs[p]:
				_set_tabs(p, false)
			else:
				_confirm(p)
	elif inp.just_pressed(&"kick_light"):
		confirmed[p] = false
		Sfx.play(&"select")
		_refresh_preview(p)

func _set_tabs(p: int, on: bool) -> void:
	_tabs[p] = on
	_focus_p = p
	Sfx.play(&"select")

func _move_cursor(p: int, c: int) -> void:
	cursor[p] = c
	_focus_p = p
	Sfx.play(&"select")
	if c < roster.size() and not _is_locked(c):
		_stage_pending = roster[c].id
		# Ya construido: el cambio es barato y va al instante; si no, se espera a que el cursor pare.
		_stage_wait = 0.0 if _stage_cache.has(_stage_pending) else STAGE_DELAY
	_refresh_preview(p)

func _confirm(p: int) -> void:
	if cursor[p] < roster.size() and not _is_locked(cursor[p]):
		confirmed[p] = true
		Sfx.play(&"confirm")
		_refresh_preview(p)
		_check_start()
	else:
		Sfx.play(&"denied")

## La casilla bajo `pos` de la época mostrada (índice del plantel; -1 si está fuera de la rejilla o vacía).
func _cell_at(pos: Vector2) -> int:
	var rel := pos - GRID_ORIGIN
	if rel.x < 0.0 or rel.y < 0.0:
		return -1
	var col := int(rel.x / CELL.x)
	var row := int(rel.y / CELL.y)
	if col >= COLS or row >= ROWS or _view_era < 0:
		return -1
	var slot := row * COLS + col
	var list: Array = _era_lists[_view_era]
	return list[slot] if slot < list.size() else -1

## Pestaña de época bajo `pos` (-1 si no hay).
func _tab_at(pos: Vector2) -> int:
	if pos.y < TAB_Y or pos.y > TAB_Y + TAB_H or pos.x < 6.0 or pos.x > 420.0:
		return -1
	return clampi(int((pos.x - 6.0) / (414.0 / ERAS.size())), 0, ERAS.size() - 1)

## Ratón: pasar por una casilla mueve el cursor de J1 y un clic izquierdo lo elige; las pestañas cambian de época.
func _gui_input(event: InputEvent) -> void:
	if _starting or _asking or _dialog != null or confirmed[1]:
		return
	var click := event as InputEventMouseButton
	if not event is InputEventMouseMotion and (click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT):
		return
	var at := (event as InputEventMouse).position
	var tab := _tab_at(at)
	if tab >= 0:
		if click != null and tab != _era_of(cursor[1]) and not (_era_lists[tab] as Array).is_empty():
			var list: Array = _era_lists[tab]
			_tabs[1] = false
			_move_cursor(1, list[mini(_slot_of(cursor[1]), list.size() - 1)])
		return
	var c := _cell_at(at)
	if c < 0:
		return
	_tabs[1] = false
	if c != cursor[1]:
		_move_cursor(1, c)
	if click != null:
		_confirm(1)

func _on_back() -> void:
	if _starting:
		return
	Game.drop_challenge()
	Game.goto(Game.SCENE_MENU)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _starting:
		if _dialog:
			_cancel_dialog()
		else:
			Game.drop_challenge()
			Game.goto(Game.SCENE_MENU)
		get_viewport().set_input_as_handled()

func _check_start() -> void:
	if not (confirmed[1] and confirmed[2]) or _starting or _asking:
		return
	if _is_story():
		_asking = true
		if not _saves_ready:
			await saves_loaded
		var save: Dictionary = _saves.get(str(roster[cursor[1]].id), {})
		if not save.is_empty():
			# Esta partida se perdería al empezar de nuevo con el mismo luchador: se pregunta primero.
			_open_dialog(roster[cursor[1]], save)
			return
	_begin()

## Arranca el modo con lo elegido. Con `resume` (Historia) retoma esa partida en vez de empezar otra.
func _begin(resume: Dictionary = {}) -> void:
	_asking = false
	_starting = true
	if Game.is_online():
		Game.p1_fighter_id = roster[cursor[1]].id
	elif _cpu:
		# Si la partida guardada ya no vale (otra versión del juego), se empieza una nueva.
		if resume.is_empty() or not Game.story_resume(resume):
			Game.start_story(roster[cursor[1]].id)
			Game.story_autosave()
	else:
		Game.p1_fighter_id = roster[cursor[1]].id
		Game.p2_fighter_id = roster[cursor[2]].id
	Sfx.play(&"fight")
	await get_tree().create_timer(1.0).timeout
	if is_inside_tree():
		Game.goto(Game.SCENE_LOBBY if Game.is_online() else (Game.SCENE_STORY if _cpu else Game.SCENE_FIGHT),
			Game.SCENE_SELECT)

## Aviso de que el luchador elegido ya tiene una partida: continuarla, empezar de nuevo (la pierde) o volver.
func _open_dialog(d: FighterData, save: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.theme = HKTheme.theme()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)
	var diff := int(save["difficulty"])
	var lines := [
		["PARTIDA GUARDADA", 16, HKTheme.GOLD],
		[d.short_name.to_upper(), 8, HKTheme.PAPER],
		["COMBATE %d/%d · %s" % [int(save["stage"]) + 1, FighterRegistry.all().size(),
			Game.DIFFICULTY_NAMES[diff] if diff >= 0 and diff < Game.DIFFICULTY_NAMES.size() else "?"], 8, HKTheme.PAPER],
		["EMPEZAR DE NUEVO LA BORRA", 8, HKTheme.MUTED.lightened(0.25)],
	]
	for l in lines:
		var label := Label.new()
		label.text = HKTheme.fold(l[0])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", l[1])
		label.add_theme_color_override("font_color", l[2])
		box.add_child(label)
	_dialog_first = _dialog_button(box, "CONTINUAR PARTIDA", func(): _close_dialog(); _begin(save))
	_dialog_button(box, "EMPEZAR DE NUEVO", func(): _close_dialog(); _begin())
	_dialog_button(box, "CANCELAR", _cancel_dialog)
	_dialog = dim
	_back.disabled = true   # con el aviso abierto, el clic derecho no debe sacarte de la pantalla
	add_child(dim)
	_dialog_first.grab_focus()

func _dialog_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 16)
	b.pressed.connect(func():
		Sfx.play(&"confirm")
		cb.call())
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	parent.add_child(b)
	return b

func _close_dialog() -> void:
	if _dialog:
		_dialog.queue_free()
		_dialog = null
		_back.disabled = false

## Vuelve a la selección sin tocar la partida: el luchador queda sin confirmar para elegir otro.
func _cancel_dialog() -> void:
	_close_dialog()
	_asking = false
	confirmed[1] = false
	Sfx.play(&"select")
	_refresh_preview(1)

func _draw() -> void:
	# Franjas oscuras arriba y abajo para que el título y la ayuda se lean sobre cualquier escenario.
	draw_rect(Rect2(0, 0, 426, 22), SHADE)
	draw_rect(Rect2(0, 220, 426, 20), SHADE)
	HKTheme.draw_text(self, Vector2(0, 15), "ELIGE TU LUCHADOR", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
	if _any_locked():
		HKTheme.draw_text(self, Vector2(0, 15), "%d/%d" % [Unlocks.fighters_unlocked(), FighterRegistry.all().size()], 8,
			HKTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 420, 1)
	_draw_tabs()
	# Rejilla de la época mostrada (fondo continuo para que no se vea el escenario entre casillas)
	var list: Array = _era_lists[_view_era] if _view_era >= 0 else []
	var grid := Rect2(GRID_ORIGIN - Vector2(2, 2), CELL * Vector2(COLS, ROWS) + Vector2(3, 3))
	draw_rect(grid, HKTheme.INK)
	for slot in COLS * ROWS:
		var pos := GRID_ORIGIN + Vector2(slot % COLS, slot / COLS) * CELL
		var r := Rect2(pos, CELL - Vector2(1, 1))
		draw_rect(r, HKTheme.INK)
		if slot < list.size() and not _is_locked(list[slot]):
			draw_rect(r.grow(-1), Color("4a2a38"))
		elif slot < list.size():
			# Luchador por ganar: casilla oscura con "?".
			draw_rect(r.grow(-1), Color("26162c"))
			HKTheme.draw_text(self, pos + Vector2(0, 19), "?", 16, Color("8a6a7a"), HORIZONTAL_ALIGNMENT_CENTER, CELL.x - 1, 0)
		else:
			draw_rect(r.grow(-1), Color("1c1220"))
	# Placas de información de cada jugador y frases de presentación
	for p in [1, 2]:
		_draw_plate(p)
	_draw_quotes(grid.end.y + 6.0)
	var hint := "WASD+U · ÉPOCA: I/K" if _cpu else "WASD+U · FLECHAS+NUM1 · ÉPOCA: I/K, NUM2/5"
	if Game.mode == Game.Mode.TRAINING:
		hint = "WASD+U · MUÑECO: FLECHAS+NUM1 · ÉPOCA: I/K"
	HKTheme.draw_text(self, Vector2(70, 233), hint, 8, HKTheme.MUTED.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, 356, 1)

## Barra de épocas: la mostrada va resaltada y cada jugador marca la suya con una franja de su color.
func _draw_tabs() -> void:
	var w := 414.0 / ERAS.size()
	for e in ERAS.size():
		var r := Rect2(6.0 + e * w, TAB_Y, w - 2.0, TAB_H)
		var on := e == _view_era
		draw_rect(r, SHADE if not on else Color("4a2a38"))
		draw_rect(r, HKTheme.GOLD if on else HKTheme.GOLD_DARK.darkened(0.3), false, 1.0)
		HKTheme.draw_text(self, Vector2(r.position.x, r.position.y + 10.0), ERAS[e][0], 8,
			HKTheme.GOLD if on else HKTheme.MUTED.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 1)
		# Franja de color bajo la pestaña de la época de cada jugador (J1 a la izquierda, J2 a la derecha).
		for p in ([1] if _cpu else [1, 2]):
			if _era_of(cursor[p]) == e:
				var half := r.size.x * (1.0 if _cpu else 0.5)
				draw_rect(Rect2(r.position.x + (0.0 if p == 1 else r.size.x - half), r.end.y - 2.0, half, 2.0), P1_COLOR if p == 1 else P2_COLOR)

## Placa compacta de un jugador: etiqueta (y "LISTO") arriba y, debajo, nombre, país y época.
func _draw_plate(p: int) -> void:
	var x0 := 6.0 if p == 1 else 426.0 - 6.0 - PLATE_W
	var col: Color = P1_COLOR if p == 1 else P2_COLOR
	var tag := "J%d" % p
	var lines: Array = []   # [texto, color]
	if Game.is_online() and p == 2:
		tag = "RIVAL"
		lines = [["POR INTERNET", HKTheme.PAPER]]
	elif _cpu and p == 2:
		tag = "CPU"
		lines = [["MODO HISTORIA", HKTheme.PAPER], [Game.difficulty_name(), HKTheme.GOLD]]
	else:
		var idx: int = cursor[p]
		if idx < roster.size() and _is_locked(idx):
			lines = [["BLOQUEADO", HKTheme.MUTED], ["VENCELO EN", HKTheme.PAPER], ["EL MODO", HKTheme.PAPER], ["HISTORIA", HKTheme.PAPER]]
		elif idx < roster.size():
			var d := roster[idx]
			lines.append([d.short_name, HKTheme.PAPER])
			for l in _wrap(d.country.to_upper(), PLATE_W - 8.0):
				lines.append([l, HKTheme.GOLD])
			for l in _wrap(d.era, PLATE_W - 8.0):
				lines.append([l, HKTheme.MUTED.lightened(0.25)])
			# Nombre de su pasiva (si tiene); el detalle está en PERSONAJES.
			for l in _wrap(Passives.display_name(d.passive), PLATE_W - 8.0):
				lines.append([l, Color("60d060")])
			if _is_story() and _saves.has(str(d.id)):
				lines.append(["GUARDADA · COMBATE %d" % (int(_saves[str(d.id)]["stage"]) + 1), Color("60d060")])
		else:
			lines.append(["BLOQUEADO", HKTheme.MUTED])
	var box := Rect2(x0, PLATE_Y, PLATE_W, 6.0 + (lines.size() + 1) * 10.0)
	draw_rect(box, SHADE)
	draw_rect(box, col.darkened(0.2), false, 1.0)
	var y := PLATE_Y + 11.0
	HKTheme.draw_text(self, Vector2(x0 + 4, y), tag, 8, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	if confirmed[p] and not (_cpu and p == 2):
		HKTheme.draw_text(self, Vector2(x0, y), "¡LISTO!", 8, Color("60d060"), HORIZONTAL_ALIGNMENT_RIGHT, PLATE_W - 4.0, 1)
	for l in lines:
		y += 10.0
		HKTheme.draw_text(self, Vector2(x0, y), l[0], 8, l[1], HORIZONTAL_ALIGNMENT_CENTER, PLATE_W, 1)

## Frases de presentación de los luchadores bajo la rejilla, en una sola caja.
func _draw_quotes(top: float) -> void:
	var entries: Array = []
	for p in ([1] if _cpu else [1, 2]):
		if cursor[p] < roster.size() and not _is_locked(cursor[p]):
			var me := roster[cursor[p]]
			var intro := me.intro_quote
			# Si el otro jugador eligió a un rival con el que hay historia, dice una frase para ese duelo.
			var foe_idx: int = cursor[3 - p]
			if not _cpu and not Game.is_online() and foe_idx < roster.size() and not _is_locked(foe_idx):
				intro = RosterLines.intro(me.id, roster[foe_idx].id, intro)
			var quote := "\"%s\"" % intro
			entries.append([_clip_lines(_wrap(quote, 160.0), 3), HKTheme.PAPER if p == 1 else Color("b8d0f0")])
	if entries.is_empty():
		return
	var rows := 0
	for e in entries:
		rows += (e[0] as PackedStringArray).size()
	var box := Rect2(GRID_ORIGIN.x - 2, top, CELL.x * COLS + 3, 8.0 + rows * 10.0 + (entries.size() - 1) * 4.0)
	draw_rect(box, SHADE)
	draw_rect(box, HKTheme.GOLD_DARK.darkened(0.3), false, 1.0)
	var y := top + 10.0
	for e in entries:
		for line in e[0]:
			HKTheme.draw_text(self, Vector2(GRID_ORIGIN.x + 4, y), line, 8, e[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
			y += 10.0
		y += 4.0

## Como mucho `max_lines` líneas: si sobran, la última acaba en "..." (una frase larga no debe tapar la ayuda de abajo).
func _clip_lines(lines: PackedStringArray, max_lines: int) -> PackedStringArray:
	if lines.size() <= max_lines:
		return lines
	var out := lines.slice(0, max_lines)
	out[max_lines - 1] = out[max_lines - 1].left(maxi(out[max_lines - 1].length() - 3, 1)) + "..."
	return out

## Texto de 8 px partido en líneas de un ancho máximo.
func _wrap(text: String, width: float) -> PackedStringArray:
	var cache_key := "%s|%d" % [text, int(width)]
	if not _wrap_cache.has(cache_key):
		_wrap_cache[cache_key] = _wrap_lines(text, width)
	return _wrap_cache[cache_key]

func _wrap_lines(text: String, width: float) -> PackedStringArray:
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

func _any_locked() -> bool:
	for i in roster.size():
		if _is_locked(i):
			return true
	return false

func _draw_cursors() -> void:
	# El VS va en esta capa para quedar por encima de la rejilla y de los retratos.
	if _starting:
		HKTheme.draw_text(_overlay, Vector2(0, 100), "VS", 32, HKTheme.BLOOD, HORIZONTAL_ALIGNMENT_CENTER, 426, 4)
	for p in ([1] if _cpu else [1, 2]):
		var col: Color = P1_COLOR if p == 1 else P2_COLOR
		var blink := confirmed[p] or int(_t * 6.0) % 2 == 0
		if _tabs[p]:
			# Foco en las pestañas: parpadea el borde de la época de este jugador.
			var tw := 414.0 / ERAS.size()
			if blink:
				_overlay.draw_rect(Rect2(6.0 + _era_of(cursor[p]) * tw - 1.0, TAB_Y - 1.0, tw, TAB_H + 2.0), col, false, 2.0)
			continue
		if _era_of(cursor[p]) != _view_era:
			continue
		var pos := _cell_pos(cursor[p])
		var r := Rect2(pos - Vector2(1, 1), CELL + Vector2(1, 1))
		if not _cpu and cursor[1] == cursor[2]:
			# Casilla compartida: cada uno pinta media.
			var half := Rect2(r.position, Vector2(r.size.x * 0.5, r.size.y)) if p == 1 \
				else Rect2(r.position + Vector2(r.size.x * 0.5, 0), Vector2(r.size.x * 0.5, r.size.y))
			if blink:
				_overlay.draw_rect(half, col, false, 2.0)
		elif blink:
			_overlay.draw_rect(r, col, false, 2.0)
		HKTheme.draw_text(_overlay, pos + Vector2(1 if p == 1 else CELL.x - 15, CELL.y - 1), "%dP" % p, 8, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
