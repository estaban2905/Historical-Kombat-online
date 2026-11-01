## Selección de luchador para Versus local, Arcade y Duelo online.
## Rejilla de 42 casillas: las de los personajes disponibles y el resto
## bloqueadas ("?") como adelanto del roster completo.
##   J1: A/D/W/S mover · U confirmar · J cancelar
##   J2: Flechas mover · Num1 (o Supr) confirmar · Num4 (o Insert) cancelar
##   ESC: volver al menú
extends Control

const COLS := 7
const ROWS := 6
const CELL := Vector2(24, 18)
const GRID_ORIGIN := Vector2(129, 34)
const P1_COLOR := Color("e83a3a")
const P2_COLOR := Color("3a8af0")

var roster: Array[FighterData] = []
var cursor: Array[int] = [0, 0, 1]      # índice de casilla por jugador (1 y 2)
var confirmed: Array[bool] = [false, false, false]
var _previews: Array = [null, null, null]
var _t: float = 0.0
var _starting: bool = false
## Arcade (1 jugador vs CPU) y online: solo elige J1; el rival lo sortea Game o lo
## pone el servidor. Se llama _cpu porque oculta el panel de J2.
var _cpu: bool = false
var _inputs: Array = [null, InputManager.new(1), InputManager.new(2)]
## Capa superior para dibujar los cursores por encima de los retratos.
var _overlay: Control

func _ready() -> void:
	theme = HKTheme.theme()
	_cpu = Game.is_vs_cpu() or Game.is_online()
	confirmed[2] = _cpu
	roster = FighterRegistry.all()
	cursor[1] = FighterRegistry.index_of(Game.p1_fighter_id)
	cursor[2] = FighterRegistry.index_of(Game.p2_fighter_id)
	if roster.size() > 1 and cursor[1] == cursor[2]:
		cursor[2] = (cursor[1] + 1) % roster.size()
	_build_cells()
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.draw.connect(_draw_cursors)
	for p in [1, 2]:
		var r := FighterRenderer.new()
		add_child(r)
		r.position = Vector2(64 if p == 1 else 362, 172)
		r.scale.x = 1 if p == 1 else -1
		_previews[p] = r
		_refresh_preview(p)
		if _cpu and p == 2:
			r.visible = false

func _build_cells() -> void:
	for i in roster.size():
		var cell := Control.new()
		cell.clip_contents = true
		cell.position = _cell_pos(i) + Vector2(1, 1)
		cell.size = CELL - Vector2(2, 2)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(cell)
		var bust := FighterRenderer.new()
		bust.draw_shadow = false
		bust.setup(roster[i])
		# Pies fuera de la casilla: solo se ve cabeza y hombros.
		bust.position = Vector2(CELL.x * 0.5 - 2, bust.approx_height() + 1)
		cell.add_child(bust)

func _cell_pos(i: int) -> Vector2:
	return GRID_ORIGIN + Vector2(i % COLS, i / COLS) * CELL

func _refresh_preview(p: int) -> void:
	var r: FighterRenderer = _previews[p]
	if cursor[p] < roster.size():
		r.visible = true
		r.setup(roster[cursor[p]])
		r.pose_name = &"victory" if confirmed[p] else &"idle"
	else:
		r.visible = false

func _process(delta: float) -> void:
	_t += delta
	if not _starting:
		for p in ([1] if _cpu else [1, 2]):
			_handle_player(p)
	queue_redraw()
	_overlay.queue_redraw()

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
			_refresh_preview(p)
		if inp.just_pressed(&"punch_light"):
			if cursor[p] < roster.size():
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
		Game.goto(Game.SCENE_MENU)
		get_viewport().set_input_as_handled()

func _check_start() -> void:
	if confirmed[1] and confirmed[2] and not _starting:
		_starting = true
		if Game.is_online():
			Game.p1_fighter_id = roster[cursor[1]].id
		elif _cpu:
			Game.start_arcade(roster[cursor[1]].id)
		else:
			Game.p1_fighter_id = roster[cursor[1]].id
			Game.p2_fighter_id = roster[cursor[2]].id
		Sfx.play(&"fight")
		await get_tree().create_timer(1.0).timeout
		if is_inside_tree():
			Game.goto(Game.SCENE_LOBBY if Game.is_online() else Game.SCENE_FIGHT)

func _draw() -> void:
	HKTheme.draw_text(self, Vector2(0, 20), "ELIGE TU LUCHADOR", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
	# Rejilla (fondo continuo para que no se vea el cielo entre casillas)
	draw_rect(Rect2(GRID_ORIGIN - Vector2(2, 2), CELL * Vector2(COLS, ROWS) + Vector2(3, 3)), HKTheme.INK)
	for i in COLS * ROWS:
		var pos := _cell_pos(i)
		var r := Rect2(pos, CELL - Vector2(1, 1))
		draw_rect(r, HKTheme.INK)
		if i < roster.size():
			draw_rect(r.grow(-1), Color("4a2a38"))
		else:
			draw_rect(r.grow(-1), Color("1c1220"))
			HKTheme.draw_text(self, pos + Vector2(0, 14), "?", 8, Color("4a3a48"), HORIZONTAL_ALIGNMENT_CENTER, CELL.x - 1, 0)
	# Fichas de cada jugador
	for p in [1, 2]:
		var x0 := 4.0 if p == 1 else 300.0
		var w := 122.0
		var col: Color = P1_COLOR if p == 1 else P2_COLOR
		if Game.is_online() and p == 2:
			HKTheme.draw_text(self, Vector2(x0, 44), "RIVAL", 8, col, HORIZONTAL_ALIGNMENT_CENTER, w)
			HKTheme.draw_text(self, Vector2(x0, 100), "OTRA PERSONA", 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, w)
			HKTheme.draw_text(self, Vector2(x0, 112), "POR INTERNET", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)
			continue
		if _cpu and p == 2:
			HKTheme.draw_text(self, Vector2(x0, 44), "CPU", 8, col, HORIZONTAL_ALIGNMENT_CENTER, w)
			HKTheme.draw_text(self, Vector2(x0, 100), "%d RIVALES" % Game.ARCADE_RIVALS, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, w)
			HKTheme.draw_text(self, Vector2(x0, 112), "AL AZAR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)
			HKTheme.draw_text(self, Vector2(x0, 130), Game.difficulty_name(), 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
			continue
		HKTheme.draw_text(self, Vector2(x0, 44), "JUGADOR %d" % p, 8, col, HORIZONTAL_ALIGNMENT_CENTER, w)
		var idx: int = cursor[p]
		if idx < roster.size():
			var d := roster[idx]
			HKTheme.draw_text(self, Vector2(x0, 188), d.short_name, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, w)
			HKTheme.draw_text(self, Vector2(x0, 199), d.country.to_upper(), 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w, 1)
			HKTheme.draw_text(self, Vector2(x0, 209), d.era, 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w, 1)
		else:
			HKTheme.draw_text(self, Vector2(x0, 120), "BLOQUEADO", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)
		if confirmed[p]:
			HKTheme.draw_text(self, Vector2(x0, 58), "¡LISTO!", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
	# Frase de presentación del luchador bajo el cursor de J1 / J2
	var quote_y := 156.0
	for p in ([1] if _cpu else [1, 2]):
		if cursor[p] < roster.size():
			var q := "\"%s\"" % roster[cursor[p]].intro_quote
			_draw_wrapped(Vector2(129, quote_y), q, 168, HKTheme.PAPER if p == 1 else Color("b8d0f0"))
			quote_y += 32
	if _starting:
		HKTheme.draw_text(self, Vector2(0, 120), "VS", 32, HKTheme.BLOOD, HORIZONTAL_ALIGNMENT_CENTER, 426, 4)
	var hint := "J1: WASD+U   ESC: VOLVER" if _cpu else "J1: WASD+U   J2: FLECHAS+NUM1   ESC: VOLVER"
	if Game.mode == Game.Mode.TRAINING:
		hint = "J1: WASD+U  MUÑECO: FLECHAS+NUM1  ESC: VOLVER"
	HKTheme.draw_text(self, Vector2(0, 234), hint, 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 426, 1)

## Texto de 8 px partido en líneas de un ancho máximo.
func _draw_wrapped(pos: Vector2, text: String, width: float, color: Color) -> void:
	var words := text.split(" ")
	var line := ""
	var y := pos.y
	for w in words:
		var test := w if line.is_empty() else line + " " + w
		if HKTheme.text_width(test, 8) > width and not line.is_empty():
			HKTheme.draw_text(self, Vector2(pos.x, y), line, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
			y += 10
			line = w
		else:
			line = test
	if not line.is_empty():
		HKTheme.draw_text(self, Vector2(pos.x, y), line, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

func _draw_cursors() -> void:
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
