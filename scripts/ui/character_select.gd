## Selección de luchador para Versus local, Arcade y Duelo online.
## Rejilla de 54 casillas: las de los personajes y el resto bloqueadas ("?") como adelanto del roster.
## En el modo Historia y el versus local, los luchadores que aún no se han ganado también salen bloqueados
## (ver Unlocks); en el duelo online con ranking están los 50 abiertos.
##   J1: A/D/W/S mover · U confirmar · J cancelar
##   J2: Flechas mover · Num1 (o Supr) confirmar · Num4 (o Insert) cancelar
##   ESC: volver al menú
class_name CharacterSelect
extends Control

const COLS := 9
const ROWS := 6
const CELL := Vector2(22, 18)
const GRID_ORIGIN := Vector2(114, 34)
const P1_COLOR := Color("e83a3a")
const P2_COLOR := Color("3a8af0")
const SHADE := Color(0.05, 0.02, 0.07, 0.78)
## Placas de información de cada jugador (a los lados de la rejilla).
const PLATE_W := 104.0
const PLATE_Y := 27.0
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
var _stage_pending: StringName = &""
var _stage_wait: float = 0.0
## Estado dibujado la última vez: solo se redibuja si cambia (y el cursor al parpadear).
var _drawn_key: Array = []
var _drawn_blink: int = -1
var _wrap_cache: Dictionary = {}

func _ready() -> void:
	theme = HKTheme.theme()
	_cpu = Game.is_vs_cpu() or Game.is_online()
	confirmed[2] = _cpu
	roster = FighterRegistry.all().duplicate()
	# El Nexo se juega solo en el versus local y una vez visto el final oculto (con sus estadísticas normales:
	# el refuerzo de jefe es solo del modo Historia). Ni el online ni la Historia lo ofrecen.
	if nexo_playable():
		roster.append(FighterRegistry.get_by_id(FighterRegistry.NEXO_ID))
	cursor[1] = FighterRegistry.index_of(Game.p1_fighter_id)
	cursor[2] = FighterRegistry.index_of(Game.p2_fighter_id)
	cursor[1] = _first_unlocked(cursor[1])
	cursor[2] = _first_unlocked(cursor[2])
	if roster.size() > 1 and cursor[1] == cursor[2]:
		cursor[2] = _first_unlocked((cursor[1] + 1) % roster.size())
		if cursor[2] == cursor[1]:
			cursor[2] = (cursor[1] + 1) % roster.size()
	_load_stage(roster[cursor[1]].id if cursor[1] < roster.size() else roster[0].id)
	_build_cells()
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

## ¿Se ofrece el Nexo como luchador? Solo en el versus local y con el final oculto visto.
static func nexo_playable() -> bool:
	return Game.mode == Game.Mode.VERSUS and Unlocks.has("ending", str(Unlocks.HIDDEN_ENDING))

## ¿Esta casilla es un luchador que todavía no se puede usar? Solo en el modo Historia y el versus local.
func _is_locked(i: int) -> bool:
	if i >= roster.size() or not (Game.mode == Game.Mode.ARCADE or Game.mode == Game.Mode.VERSUS):
		return false
	# El Nexo solo está en la lista si ya se desbloqueó.
	if roster[i].id == FighterRegistry.NEXO_ID:
		return false
	return not Unlocks.fighter_unlocked(roster[i].id)

## La primera casilla desde `from` (dando la vuelta) con un luchador utilizable.
func _first_unlocked(from: int) -> int:
	for k in roster.size():
		var i := (from + k) % roster.size()
		if not _is_locked(i):
			return i
	return from

func _build_cells() -> void:
	for i in roster.size():
		if _is_locked(i):
			continue
		var cell := Control.new()
		cell.clip_contents = true
		cell.position = _cell_pos(i) + Vector2(1, 1)
		cell.size = CELL - Vector2(2, 2)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		var bust := FighterRenderer.new()
		bust.draw_shadow = false
		# Retrato fijo: se dibuja una vez en setup(); sin _process no se redibuja cada frame.
		bust.set_process(false)
		bust.setup(roster[i])
		# Pies fuera de la casilla: solo se ve cabeza y hombros.
		bust.position = Vector2(CELL.x * 0.5 - 2, bust.approx_height() + 1)
		cell.add_child(bust)

func _cell_pos(i: int) -> Vector2:
	return GRID_ORIGIN + Vector2(i % COLS, i / COLS) * CELL

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
		_stage.queue_free()
	var packed := load(StageRegistry.scene_for(fighter_id)) as PackedScene
	if packed == null:
		packed = load(StageRegistry.COLOSSEUM)
	_stage = packed.instantiate() as Stage
	if _stage is ThemedStage:
		(_stage as ThemedStage).fighter_id = fighter_id
	# Un hijo se dibuja encima del padre; así el escenario queda detrás de la rejilla y los textos.
	_stage.show_behind_parent = true
	add_child(_stage)
	move_child(_stage, 0)
	_floor_y = _stage.floor_y
	for p in [1, 2]:
		if _previews[p]:
			(_previews[p] as FighterRenderer).position.y = _floor_y

func _process(delta: float) -> void:
	_t += delta
	if not _starting:
		for p in ([1] if _cpu else [1, 2]):
			_handle_player(p)
	if _stage_pending != &"":
		_stage_wait -= delta
		if _stage_wait <= 0.0:
			_load_stage(_stage_pending)
			_stage_pending = &""
	var key := [cursor[1], cursor[2], confirmed[1], confirmed[2], _starting]
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
		var moved := false
		var c: int = cursor[p]
		if inp.just_pressed(&"left"):
			c = (c - 1 + COLS * ROWS) % (COLS * ROWS); moved = true
		elif inp.just_pressed(&"right"):
			c = (c + 1) % (COLS * ROWS); moved = true
		elif inp.just_pressed(&"jump"):
			c = (c - COLS + COLS * ROWS) % (COLS * ROWS); moved = true
		elif inp.just_pressed(&"crouch"):
			c = (c + COLS) % (COLS * ROWS); moved = true
		if moved:
			cursor[p] = c
			Sfx.play(&"select")
			if c < roster.size() and not _is_locked(c):
				_stage_pending = roster[c].id
				_stage_wait = STAGE_DELAY
			_refresh_preview(p)
		if inp.just_pressed(&"punch_light"):
			if cursor[p] < roster.size() and not _is_locked(cursor[p]):
				confirmed[p] = true
				Sfx.play(&"confirm")
				_refresh_preview(p)
				_check_start()
			else:
				Sfx.play(&"denied")
	elif inp.just_pressed(&"kick_light"):
		confirmed[p] = false
		Sfx.play(&"select")
		_refresh_preview(p)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _starting:
		Game.drop_challenge()
		Game.goto(Game.SCENE_MENU)
		get_viewport().set_input_as_handled()

func _check_start() -> void:
	if confirmed[1] and confirmed[2] and not _starting:
		_starting = true
		if Game.is_online():
			Game.p1_fighter_id = roster[cursor[1]].id
		elif _cpu:
			Game.start_story(roster[cursor[1]].id)
			Game.story_autosave()
		else:
			Game.p1_fighter_id = roster[cursor[1]].id
			Game.p2_fighter_id = roster[cursor[2]].id
		Sfx.play(&"fight")
		await get_tree().create_timer(1.0).timeout
		if is_inside_tree():
			Game.goto(Game.SCENE_LOBBY if Game.is_online() else (Game.SCENE_STORY if _cpu else Game.SCENE_FIGHT))

func _draw() -> void:
	# Franjas oscuras arriba y abajo para que el título y la ayuda se lean sobre cualquier escenario.
	draw_rect(Rect2(0, 0, 426, 22), SHADE)
	draw_rect(Rect2(0, 220, 426, 20), SHADE)
	HKTheme.draw_text(self, Vector2(0, 15), "ELIGE TU LUCHADOR", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
	if _any_locked():
		HKTheme.draw_text(self, Vector2(0, 15), "%d/%d" % [Unlocks.fighters_unlocked(), FighterRegistry.all().size()], 8,
			HKTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 420, 1)
	# Rejilla (fondo continuo para que no se vea el escenario entre casillas)
	var grid := Rect2(GRID_ORIGIN - Vector2(2, 2), CELL * Vector2(COLS, ROWS) + Vector2(3, 3))
	draw_rect(grid, HKTheme.INK)
	for i in COLS * ROWS:
		var pos := _cell_pos(i)
		var r := Rect2(pos, CELL - Vector2(1, 1))
		draw_rect(r, HKTheme.INK)
		if i < roster.size() and not _is_locked(i):
			draw_rect(r.grow(-1), Color("4a2a38"))
		elif i < roster.size():
			# Luchador por ganar: casilla oscura con el "?" más claro que las vacías.
			draw_rect(r.grow(-1), Color("26162c"))
			HKTheme.draw_text(self, pos + Vector2(0, 14), "?", 8, Color("8a6a7a"), HORIZONTAL_ALIGNMENT_CENTER, CELL.x - 1, 0)
		else:
			draw_rect(r.grow(-1), Color("1c1220"))
			HKTheme.draw_text(self, pos + Vector2(0, 14), "?", 8, Color("4a3a48"), HORIZONTAL_ALIGNMENT_CENTER, CELL.x - 1, 0)
	# Placas de información de cada jugador y frases de presentación
	for p in [1, 2]:
		_draw_plate(p)
	_draw_quotes(grid.end.y + 6.0)
	var hint := "J1: WASD+U   ESC: VOLVER" if _cpu else "J1: WASD+U   J2: FLECHAS+NUM1   ESC: VOLVER"
	if Game.mode == Game.Mode.TRAINING:
		hint = "J1: WASD+U  MUÑECO: FLECHAS+NUM1  ESC: VOLVER"
	HKTheme.draw_text(self, Vector2(0, 233), hint, 8, HKTheme.MUTED.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, 426, 1)

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
			var quote := "\"%s\"" % roster[cursor[p]].intro_quote
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
		var pos := _cell_pos(cursor[p])
		var col: Color = P1_COLOR if p == 1 else P2_COLOR
		var blink := confirmed[p] or int(_t * 6.0) % 2 == 0
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
