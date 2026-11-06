## Mapa del mundo del MODO HISTORIA. Se muestra antes de cada combate, encima de la pantalla del rival:
##   - La cámara baja desde el mapa entero hasta la ciudad donde acabas de vencer, que se libera (de rojo a dorado).
##   - Tu nave viaja por el aire, dejando estela, hasta la ciudad del siguiente rival (el año del reloj cambia en vuelo).
##   - Al llegar tiembla el suelo, se alza la bandera del enemigo y se anuncia quién te espera.
##   - La cámara se lanza dentro de la ciudad y el mapa se desvanece, dejando ver el combate.
## En el primer combate, en vez del viaje, un rayo de luz de la Torre del Reloj te deja en la primera ciudad.
## Si se repite el mismo combate (revancha), el mapa solo muestra la llegada.
## Enter, ESC o un clic lo saltan. Emite `finished` al terminar y se libera solo.
class_name StoryWorldMap
extends Control

signal finished

enum Mode { PORTAL, TRAVEL, ARRIVE }

const CENTER := Vector2(213.0, 120.0)
const ZOOM_TRAVEL := 2.3
const ZOOM_ARRIVE := 3.2
const FOCUS_TIME := 1.4
## Segundos que se ve el mundo entero antes de hacer zoom.
const OVERVIEW_HOLD := 0.55
const LIBERATE_TIME := 0.9
const ARRIVE_TIME := 1.0
const HOLD_TIME := 0.8
const DIVE_TIME := 0.6
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]

const ENEMY := Color("d02a30")
const GOLD := Color("f0c040")
const NEXO_COLOR := Color("9a4dff")
const SEA_DEEP := Color("060c1b")
const SEA_MID := Color("10304c")
const LAND := Color("5b5238")
const LAND_LIGHT := Color("6f6545")
const LAND_DARK := Color("483f2b")
const COAST := Color("e0c26e")
const SHADE := Color(0.05, 0.02, 0.07, 0.82)

## Último combate del que se mostró el mapa en esta sesión: si se repite, no hay viaje.
static var _last_stage: int = -1

var _mode: Mode = Mode.TRAVEL
var _t: float = 0.0
## Ciudades por las que pasa la campaña (los creadores poseídos comparten la del jefe de su época).
var _nodes: Array[Dictionary] = []
var _node_of_stage: Array[int] = []
## _legs[i]: tramo de la ciudad i-1 a la i -> {a, b, c (control de la curva), pts}.
var _legs: Array[Dictionary] = []
var _cur: int = 0
var _prev: int = -1
var _t_focus: float = 0.0
var _t_arrive: float = 0.0
var _t_hold: float = 0.0
var _t_dive: float = 0.0
var _t_end: float = 0.0
var _travel_dur: float = 0.0
var _focus: Vector2 = CENTER
var _zoom: float = 1.0
var _trav_pos: Vector2 = Vector2.ZERO
var _trav_angle: float = 0.0
var _dive_started: bool = false
var _dive_focus: Vector2 = CENTER
var _dive_zoom: float = 1.0
var _burst_done: bool = false
var _done: bool = false
var _emit_acc: float = 0.0
var _ember_acc: float = 0.0
var _year_from: int = 0
var _year_to: int = 0
## Partículas: [posición, velocidad, vida, vida máxima, color, tamaño].
var _parts: Array = []
## Nubes: [posición, ancho, alto, velocidad].
var _clouds: Array = []
var _shimmer: Array = []
var _rng := RandomNumberGenerator.new()

var _world: Node2D
var _sea: Node2D
var _land: Node2D
var _dyn: Node2D
var _hud: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 7
	_build_nodes()
	_pick_mode()
	_plan()
	_make_layers()
	_make_ambience()
	_update_camera()
	_trav_pos = _origin_pos() if _mode == Mode.TRAVEL else _nodes[_cur].pos
	_apply_camera()

# =========================================================================
#  Preparación
# =========================================================================
func _build_nodes() -> void:
	var ladder := Game.arcade_ladder
	for s in ladder.size():
		var id: StringName = ladder[s]
		var shared := s > 0 and Game.story_is_creator(s) and not _nodes.is_empty() \
			and Game.story_chapter_of(ladder[s - 1]) == Game.story_chapter_of(id)
		if shared:
			_nodes[_nodes.size() - 1]["last"] = s
			_node_of_stage.append(_nodes.size() - 1)
			continue
		var n := {"first": s, "last": s, "fighter": id, "boss": Game.story_is_chapter_boss(s), "nexo": id == Game.STORY_NEXO_ID}
		if id == Game.STORY_NEXO_ID:
			n["pos"] = WorldMapData.project(WorldMapData.NEXO_LONLAT.x, WorldMapData.NEXO_LONLAT.y)
			n["name"] = WorldMapData.NEXO_CITY
		else:
			var c := WorldMapData.city_of(id)
			n["pos"] = WorldMapData.project(c[1], c[2])
			n["name"] = c[0]
		_nodes.append(n)
		_node_of_stage.append(_nodes.size() - 1)
	_legs.append({})
	for i in range(1, _nodes.size()):
		var a: Vector2 = _nodes[i - 1].pos
		var b: Vector2 = _nodes[i].pos
		var c := (a + b) * 0.5 + Vector2(0.0, -minf(a.distance_to(b) * 0.3, 46.0))
		var pts := PackedVector2Array()
		for k in 41:
			pts.append(_bez(a, c, b, k / 40.0))
		_legs.append({"a": a, "b": b, "c": c, "pts": pts})
	_cur = _node_of_stage[clampi(Game.arcade_stage, 0, _node_of_stage.size() - 1)]
	_prev = _cur - 1

func _pick_mode() -> void:
	if Game.arcade_stage == 0 or _prev < 0:
		_mode = Mode.PORTAL
	elif Game.arcade_stage == _last_stage or _nodes[_cur].first != Game.arcade_stage:
		_mode = Mode.ARRIVE
	else:
		_mode = Mode.TRAVEL
	_last_stage = Game.arcade_stage
	_year_to = _year_of(_nodes[_cur].fighter)
	_year_from = _year_of(_nodes[_prev].fighter) if _prev >= 0 else _year_to

func _plan() -> void:
	match _mode:
		Mode.TRAVEL:
			var d: float = _nodes[_prev].pos.distance_to(_nodes[_cur].pos)
			_travel_dur = clampf(1.3 + d / 140.0, 1.7, 3.4)
			_t_focus = FOCUS_TIME
			_t_arrive = FOCUS_TIME + _travel_dur
		Mode.PORTAL:
			_t_focus = 1.8
			_t_arrive = 1.8
		_:
			_t_focus = 0.0
			_t_arrive = 0.0
	_t_hold = _t_arrive + ARRIVE_TIME
	_t_dive = _t_hold + HOLD_TIME
	_t_end = _t_dive + DIVE_TIME

func _make_layers() -> void:
	_world = Node2D.new()
	add_child(_world)
	_sea = Node2D.new()
	_world.add_child(_sea)
	_sea.draw.connect(_draw_sea)
	_land = Node2D.new()
	_world.add_child(_land)
	_land.draw.connect(_draw_land)
	_dyn = Node2D.new()
	_world.add_child(_dyn)
	_dyn.draw.connect(_draw_dyn)
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hud)
	_hud.draw.connect(_draw_hud)

func _make_ambience() -> void:
	for i in 8:
		_clouds.append([Vector2(_rng.randf_range(-120, 540), _rng.randf_range(44, 200)), _rng.randf_range(22, 52),
			_rng.randf_range(5, 9), _rng.randf_range(2.5, 6.0)])
	for i in 70:
		_shimmer.append([Vector2(_rng.randf_range(-100, 520), _rng.randf_range(10, 230)), _rng.randf() * TAU, _rng.randf_range(3, 7)])

# =========================================================================
#  Entrada
# =========================================================================
## Espera (tapando lo que hay debajo, en negro) hasta que la pantalla de la historia llame a start().
var waiting: bool = false

func start() -> void:
	waiting = false

func _input(event: InputEvent) -> void:
	if _done or waiting:
		return
	var skip := HKTheme.is_enter(event) or event.is_action_pressed(&"ui_cancel")
	var m := event as InputEventMouseButton
	if m != null and m.pressed:
		skip = true
	if skip:
		if _t < _t_dive:
			_t = _t_dive
		get_viewport().set_input_as_handled()

# =========================================================================
#  Animación
# =========================================================================
func _process(delta: float) -> void:
	if _done or waiting:
		return
	_t += delta
	_update_traveler()
	_update_camera()
	_apply_camera()
	_update_particles(delta)
	_sea.queue_redraw()
	_dyn.queue_redraw()
	_hud.queue_redraw()
	if _t >= _t_end:
		_done = true
		finished.emit()
		queue_free()

func _origin_pos() -> Vector2:
	return _nodes[_prev].pos if _prev >= 0 else _nodes[_cur].pos

func _update_traveler() -> void:
	var dest: Vector2 = _nodes[_cur].pos
	if _mode != Mode.TRAVEL:
		_trav_pos = dest
		return
	if _t < _t_focus:
		_trav_pos = _origin_pos()
		return
	var leg: Dictionary = _legs[_cur]
	var u := _ease_io(clampf((_t - _t_focus) / _travel_dur, 0.0, 1.0))
	_trav_pos = _bez(leg.a, leg.c, leg.b, u)
	var ahead := _bez(leg.a, leg.c, leg.b, minf(u + 0.02, 1.0))
	if ahead.distance_to(_trav_pos) > 0.001:
		_trav_angle = (ahead - _trav_pos).angle()

func _update_camera() -> void:
	var dest: Vector2 = _nodes[_cur].pos
	var f := CENTER
	var z := 1.0
	if _t >= _t_dive:
		if not _dive_started:
			_dive_started = true
			_dive_focus = _focus
			_dive_zoom = _zoom
		var v := clampf((_t - _t_dive) / DIVE_TIME, 0.0, 1.0)
		var e := _ease_in(v)
		_focus = _dive_focus.lerp(dest, _ease_io(v))
		_zoom = _dive_zoom * pow(4.0, e)
		modulate.a = 1.0 - smoothstep(0.15, 1.0, v)
		return
	if _t < _t_arrive:
		if _mode == Mode.PORTAL:
			var u := _ease_io((_t - OVERVIEW_HOLD) / (_t_focus - OVERVIEW_HOLD))
			f = CENTER.lerp(dest, u)
			z = lerpf(1.0, ZOOM_ARRIVE, u)
		elif _t < _t_focus:
			var u := _ease_io((_t - OVERVIEW_HOLD) / (_t_focus - OVERVIEW_HOLD))
			f = CENTER.lerp(_origin_pos(), u)
			z = lerpf(1.0, ZOOM_TRAVEL, u)
		else:
			var p := clampf((_t - _t_focus) / _travel_dur, 0.0, 1.0)
			var dip := clampf(_nodes[_prev].pos.distance_to(dest) / 220.0, 0.0, 1.0) * 0.9
			f = _trav_pos
			z = ZOOM_TRAVEL - dip * sin(PI * p)
	else:
		var a := clampf((_t - _t_arrive) / ARRIVE_TIME, 0.0, 1.0)
		var z0 := ZOOM_TRAVEL if _mode == Mode.TRAVEL else (ZOOM_ARRIVE if _mode == Mode.PORTAL else 1.7)
		f = dest if _mode != Mode.ARRIVE else CENTER.lerp(dest, _ease_io(a))
		z = lerpf(z0, ZOOM_ARRIVE, _ease_out(a))
		z += 0.25 * clampf((_t - _t_hold) / HOLD_TIME, 0.0, 1.0)
	_focus = f
	_zoom = z

func _apply_camera() -> void:
	var shake := Vector2.ZERO
	var since := _t - _t_arrive
	if since >= 0.0 and since < 0.45 and not _dive_started:
		var s := (1.0 - since / 0.45) * 2.4
		shake = Vector2(_rng.randf_range(-s, s), _rng.randf_range(-s, s))
	_world.scale = Vector2(_zoom, _zoom)
	_world.position = CENTER - _focus * _zoom + shake

func _update_particles(delta: float) -> void:
	# Estela de la nave durante el vuelo.
	if _mode == Mode.TRAVEL and _t >= _t_focus and _t < _t_arrive:
		_emit_acc += delta * 70.0
		while _emit_acc >= 1.0:
			_emit_acc -= 1.0
			var dir := Vector2.from_angle(_trav_angle)
			var col: Color = [GOLD, Color("fff0a0"), NEXO_COLOR.lightened(0.3)][_rng.randi() % 3]
			_parts.append([_trav_pos - dir * 3.0, -dir * _rng.randf_range(4, 16) + Vector2(_rng.randf_range(-7, 7), _rng.randf_range(-7, 7)),
				_rng.randf_range(0.5, 1.0), 1.0, col, 1.0 if _rng.randf() < 0.7 else 2.0])
	# Explosión al llegar.
	if not _burst_done and _t >= _t_arrive:
		_burst_done = true
		var dest: Vector2 = _nodes[_cur].pos
		for i in 40:
			var ang := _rng.randf() * TAU
			var sp := _rng.randf_range(10, 46)
			var col2: Color = [ENEMY, Color("ff8a40"), Color.WHITE, GOLD][_rng.randi() % 4]
			_parts.append([dest, Vector2.from_angle(ang) * sp, _rng.randf_range(0.5, 1.2), 1.0, col2, 1.0 if i % 3 else 2.0])
	# Brasas que suben de las ciudades que aún están en manos del enemigo.
	_ember_acc += delta * 9.0
	while _ember_acc >= 1.0:
		_ember_acc -= 1.0
		var idx := _cur + (_rng.randi() % maxi(_nodes.size() - _cur, 1))
		var n: Dictionary = _nodes[idx]
		var life := _rng.randf_range(1.0, 1.9)
		_parts.append([n.pos + Vector2(_rng.randf_range(-5, 5), _rng.randf_range(-2, 2)), Vector2(_rng.randf_range(-2, 2), -_rng.randf_range(4, 9)),
			life, life, (NEXO_COLOR.lightened(0.3) if n.nexo else Color("ff6a3a")), 1.0])
	var i := _parts.size() - 1
	while i >= 0:
		var p: Array = _parts[i]
		p[2] = p[2] - delta
		if p[2] <= 0.0:
			_parts.remove_at(i)
		else:
			p[0] = p[0] + p[1] * delta
			p[1] = p[1] * (1.0 - 1.5 * delta)
		i -= 1
	if _parts.size() > 420:
		_parts = _parts.slice(_parts.size() - 420)

# =========================================================================
#  Dibujo: mar y tierra
# =========================================================================
func _draw_sea() -> void:
	var n := _sea
	var y0 := -420.0
	var y1 := 660.0
	var strips := 36
	for i in strips:
		var u := float(i) / (strips - 1)
		var mid := 1.0 - absf(u - 0.5) * 2.0
		var col := SEA_DEEP.lerp(SEA_MID, mid * 0.9)
		n.draw_rect(Rect2(-720, y0 + (y1 - y0) * i / strips, 1900, (y1 - y0) / strips + 1.0), col)
	# Cuadrícula de meridianos y paralelos.
	var grid := Color(0.45, 0.7, 0.9, 0.07)
	for lon in range(-180, 181, 30):
		var x := (lon + 180.0) * WorldMapData.K
		n.draw_line(Vector2(x, -420), Vector2(x, 660), grid, 1.0)
	for lat in range(-60, 91, 30):
		var y := WorldMapData.Y_TOP + (WorldMapData.LAT_TOP - lat) * WorldMapData.K
		n.draw_line(Vector2(-720, y), Vector2(1180, y), grid, 1.0)
	# Reflejos del agua.
	for s in _shimmer:
		var a := 0.5 + 0.5 * sin(_t * 1.6 + s[1])
		var p: Vector2 = s[0]
		n.draw_line(p, p + Vector2(s[2], 0), Color(0.6, 0.85, 1.0, 0.05 + 0.13 * a), 1.0)

func _draw_land() -> void:
	var n := _land
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var polys: Array[PackedVector2Array] = []
	for flat in WorldMapData.lands():
		polys.append(WorldMapData.to_points(flat))
	# Brillo del litoral y sombra.
	for pts in polys:
		var closed := pts.duplicate()
		closed.append(pts[0])
		n.draw_polyline(closed, Color(0.25, 0.6, 0.85, 0.16), 5.0)
		n.draw_polyline(closed, Color(0.35, 0.75, 0.95, 0.20), 3.0)
	for pts in polys:
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + Vector2(1.5, 2.0))
		_fill(n, shadow, Color(0.0, 0.0, 0.0, 0.45))
	for pts in polys:
		_fill(n, pts, LAND)
	# Textura de puntos dentro de cada masa de tierra.
	for pts in polys:
		var bb := _bounds(pts)
		var count := int(bb.get_area() / 9.0)
		for k in mini(count, 3500):
			var p := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
			if Geometry2D.is_point_in_polygon(p, pts):
				var shade := rng.randf()
				var col := LAND_LIGHT if shade > 0.55 else LAND_DARK
				n.draw_rect(Rect2(p.round(), Vector2(1, 1)), Color(col, 0.55))
	# Mares interiores.
	for flat in WorldMapData.seas():
		var s := WorldMapData.to_points(flat)
		_fill(n, s, SEA_MID.darkened(0.25))
		var closed2 := s.duplicate()
		closed2.append(s[0])
		n.draw_polyline(closed2, Color(COAST, 0.5), 1.0)
	# Línea de costa.
	for pts in polys:
		var closed3 := pts.duplicate()
		closed3.append(pts[0])
		n.draw_polyline(closed3, Color(COAST, 0.8), 1.0)

func _fill(n: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		push_warning("StoryWorldMap: polígono no válido")
		return
	n.draw_colored_polygon(pts, color)

func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r

# =========================================================================
#  Dibujo: capa dinámica (territorios, rutas, nave, partículas)
# =========================================================================
func _draw_dyn() -> void:
	var n := _dyn
	for c in _clouds:
		var cx := fposmod(c[0].x + _t * c[3] + 120.0, 660.0) - 120.0
		var cy: float = c[0].y
		n.draw_rect(Rect2(cx, cy, c[1], c[2]), Color(1, 1, 1, 0.045))
		n.draw_rect(Rect2(cx + c[1] * 0.2, cy - c[2] * 0.5, c[1] * 0.5, c[2]), Color(1, 1, 1, 0.045))
	for i in _nodes.size():
		_draw_territory(n, i)
	_draw_routes(n)
	for i in _nodes.size():
		_draw_node(n, i)
	_draw_particles(n)
	_draw_traveler(n)
	_draw_shock(n)

## 0 = ciudad en manos del enemigo, 1 = liberada.
func _liberation(i: int) -> float:
	if i < _cur:
		if i == _prev and _mode == Mode.TRAVEL:
			return _ease_io(_t / LIBERATE_TIME)
		return 1.0
	return 0.0

func _node_color(i: int, lib: float) -> Color:
	var base := NEXO_COLOR if _nodes[i].nexo else ENEMY
	return base.lerp(GOLD, lib)

func _draw_territory(n: CanvasItem, i: int) -> void:
	var node: Dictionary = _nodes[i]
	var pos: Vector2 = node.pos
	var lib := _liberation(i)
	var r := 7.0 + (3.0 if node.boss or node.nexo else 0.0)
	var col := _node_color(i, lib)
	var pulse := 0.5 + 0.5 * sin(_t * 2.4 + i * 1.3)
	var fill_a := 0.10 + 0.07 * pulse * (1.0 - lib)
	n.draw_circle(pos, r, Color(col, fill_a))
	n.draw_arc(pos, r, 0.0, TAU, 32, Color(col, 0.35 + 0.25 * pulse * (1.0 - lib)), 1.0)
	if lib < 0.99:
		# El ejército patrulla la ciudad.
		for k in 3:
			var ang := _t * 1.3 + k * TAU / 3.0 + i
			n.draw_rect(Rect2((pos + Vector2(cos(ang), sin(ang) * 0.7) * r).round(), Vector2(1, 1)), Color(col, 0.9 * (1.0 - lib)))
	if i == _prev and _mode == Mode.TRAVEL and _t < LIBERATE_TIME + 0.4:
		var u := clampf(_t / (LIBERATE_TIME + 0.4), 0.0, 1.0)
		n.draw_arc(pos, lerpf(r, r + 26.0, _ease_out(u)), 0.0, TAU, 40, Color(GOLD, 0.9 * (1.0 - u)), 1.5)
	if i == _cur and _t >= _t_arrive:
		# Anillo de alarma en la ciudad del rival.
		var a := fposmod((_t - _t_arrive) * 1.4, 1.0)
		n.draw_arc(pos, r + 2.0 + a * 9.0, 0.0, TAU, 32, Color(col, 0.7 * (1.0 - a)), 1.0)

func _draw_node(n: CanvasItem, i: int) -> void:
	var node: Dictionary = _nodes[i]
	var pos: Vector2 = node.pos
	var lib := _liberation(i)
	var col := _node_color(i, lib)
	if node.nexo:
		_draw_tower(n, pos)
		return
	var h := 9.0 if node.boss else 6.0
	if i == _cur and _t >= _t_arrive:
		# La bandera enemiga se alza con un pequeño rebote.
		var a := clampf((_t - _t_arrive - 0.1) / 0.5, 0.0, 1.0)
		h *= _ease_out_back(a)
	elif i == _cur:
		h = 0.0 if _mode != Mode.PORTAL else 0.0
	_flag(n, pos, h, 4.0 if node.boss else 3.0, col, i * 0.7)
	n.draw_rect(Rect2((pos - Vector2(1, 0)).round(), Vector2(3, 1)), Color(0.12, 0.08, 0.1))
	if node.boss and h > 2.0:
		var top := pos + Vector2(0, -h - 2.0)
		n.draw_colored_polygon(PackedVector2Array([top + Vector2(0, -2), top + Vector2(2, 0), top + Vector2(0, 2), top + Vector2(-2, 0)]),
			Color("fff0a0") if lib > 0.5 else Color("ffb0a0"))

func _flag(n: CanvasItem, base: Vector2, h: float, w: float, col: Color, phase: float) -> void:
	if h <= 0.4:
		return
	n.draw_line(base, base + Vector2(0, -h), Color(0.92, 0.88, 0.78), 1.0)
	for k in int(w):
		var wave := sin(_t * 6.0 + phase + k * 0.9) * 0.6
		n.draw_rect(Rect2(base.x + 0.5 + k, base.y - h + wave, 1.0, maxf(h * 0.5, 1.0)), col)

func _draw_tower(n: CanvasItem, pos: Vector2) -> void:
	var c := pos + Vector2(0, -11)
	var swirl := _t * 2.0
	n.draw_circle(pos, 9.0 + 1.5 * sin(_t * 3.0), Color(NEXO_COLOR, 0.16))
	n.draw_rect(Rect2(pos.x - 1.5, pos.y - 9, 3, 9), Color("2a1a44"))
	n.draw_rect(Rect2(pos.x - 2.5, pos.y - 1, 5, 1), Color("1a1030"))
	n.draw_circle(c, 3.4, Color("c9a0ff"))
	n.draw_circle(c, 2.4, Color("1a1030"))
	n.draw_line(c, c + Vector2(cos(_t * 4.0), sin(_t * 4.0)) * 2.0, Color.WHITE, 1.0)
	n.draw_line(c, c + Vector2(cos(_t * 0.7), sin(_t * 0.7)) * 1.4, Color("e0c0ff"), 1.0)
	n.draw_arc(c, 6.5, swirl, swirl + PI * 0.8, 12, Color(NEXO_COLOR.lightened(0.3), 0.85), 1.0)
	n.draw_arc(c, 8.5, -swirl * 0.8, -swirl * 0.8 + PI * 0.6, 12, Color(NEXO_COLOR, 0.6), 1.0)

func _draw_routes(n: CanvasItem) -> void:
	var march := int(_t * 7.0)
	for i in range(1, _nodes.size()):
		var pts: PackedVector2Array = _legs[i].pts
		if i < _cur or (i == _cur and (_mode != Mode.TRAVEL or _t >= _t_arrive)):
			n.draw_polyline(pts, Color(GOLD, 0.16), 3.0)
			n.draw_polyline(pts, Color(GOLD, 0.85), 1.0)
		elif i == _cur:
			var frac := _ease_io(clampf((_t - _t_focus) / _travel_dur, 0.0, 1.0)) if _t >= _t_focus else 0.0
			var upto := int(frac * (pts.size() - 1)) + 1
			if upto >= 2:
				var part := pts.slice(0, upto)
				n.draw_polyline(part, Color(GOLD, 0.16), 3.0)
				n.draw_polyline(part, Color("fff0a0"), 1.0)
			_dashed(n, pts, upto - 1, march, Color(1, 1, 1, 0.22))
		else:
			_dashed(n, pts, 0, march, Color(ENEMY, 0.30))

func _dashed(n: CanvasItem, pts: PackedVector2Array, from: int, march: int, col: Color) -> void:
	for j in range(maxi(from, 0), pts.size() - 1):
		if (j + march) % 4 < 2:
			n.draw_line(pts[j], pts[j + 1], col, 1.0)

func _draw_particles(n: CanvasItem) -> void:
	for p in _parts:
		var life: float = clampf(p[2] / p[3], 0.0, 1.0)
		var col: Color = p[4]
		col.a *= life
		n.draw_rect(Rect2((p[0] as Vector2).round(), Vector2(p[5], p[5])), col)

func _draw_traveler(n: CanvasItem) -> void:
	var dest: Vector2 = _nodes[_cur].pos
	var landed := _t >= _t_arrive
	if _mode == Mode.PORTAL:
		_draw_beam(n, dest)
		if _t < _t_arrive + 0.25:
			return
	if _mode == Mode.TRAVEL and _t < _t_focus:
		var leg: Dictionary = _legs[_cur]
		_draw_ship(n, _trav_pos, (leg.c - leg.a).angle(), 0.0)
		return
	if landed:
		# Marcador de tu posición: una flecha que flota sobre la ciudad.
		var bob := sin(_t * 5.0) * 1.2
		var top := dest + Vector2(0, -15.0 - bob - (0.0 if not _nodes[_cur].boss else 3.0))
		n.draw_colored_polygon(PackedVector2Array([top, top + Vector2(-3, -4), top + Vector2(3, -4)]), Color("fff0a0"))
		n.draw_rect(Rect2(top + Vector2(-1, -8), Vector2(2, 4)), Color("fff0a0"))
		return
	_draw_ship(n, _trav_pos, _trav_angle, 1.0)

func _draw_ship(n: CanvasItem, pos: Vector2, angle: float, echo: float) -> void:
	var xf := Transform2D(angle, pos)
	# Ecos: copias que se quedan atrás y se desvanecen (sensación de velocidad).
	if echo > 0.0:
		for k in range(4, 0, -1):
			var back := pos - Vector2.from_angle(angle) * (k * 3.0)
			n.draw_circle(back, 2.5, Color(GOLD, 0.06 * (5 - k)))
	n.draw_circle(pos, 6.5, Color(GOLD, 0.12))
	n.draw_circle(pos, 4.0, Color("fff0a0", 0.22))
	var hull := PackedVector2Array([Vector2(5, 0), Vector2(-3, -3), Vector2(-1, 0), Vector2(-3, 3)])
	var pts := PackedVector2Array()
	for p in hull:
		pts.append(xf * p)
	n.draw_colored_polygon(pts, Color("fff0a0"))
	var core := xf * Vector2(0.5, 0)
	n.draw_rect(Rect2(core - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.4, 0.15, 0.1))

func _draw_beam(n: CanvasItem, dest: Vector2) -> void:
	var a := _t - _t_arrive
	var k: float
	if _t < _t_arrive:
		k = _ease_in(clampf(_t / _t_arrive, 0.0, 1.0)) * 0.9
	else:
		k = maxf(1.0 - a / 0.9, 0.0)
	if k <= 0.0:
		return
	var w := 2.0 + 7.0 * k
	for s in 5:
		var ww := w * (1.0 - s * 0.17)
		n.draw_rect(Rect2(dest.x - ww * 0.5, dest.y - 180.0, ww, 180.0), Color(NEXO_COLOR.lerp(Color.WHITE, s * 0.2), 0.10 + 0.07 * s) * Color(1, 1, 1, k))
	for s in 6:
		var yy := dest.y - fposmod(_t * 90.0 + s * 31.0, 150.0)
		n.draw_rect(Rect2(dest.x + sin(yy * 0.5 + s) * w * 0.4, yy, 1, 3), Color(1, 1, 1, 0.7 * k))

func _draw_shock(n: CanvasItem) -> void:
	var a := _t - _t_arrive
	if a < 0.0 or a > 1.2:
		return
	var dest: Vector2 = _nodes[_cur].pos
	for k in 3:
		var u := clampf((a - k * 0.12) / 0.9, 0.0, 1.0)
		if u <= 0.0 or u >= 1.0:
			continue
		var col := ENEMY.lerp(Color.WHITE, 1.0 - u) if not _nodes[_cur].nexo else NEXO_COLOR.lerp(Color.WHITE, 1.0 - u)
		n.draw_arc(dest, 3.0 + _ease_out(u) * 34.0, 0.0, TAU, 40, Color(col, 0.9 * (1.0 - u)), 2.0 - u)

# =========================================================================
#  Dibujo: capa fija (interfaz)
# =========================================================================
func _draw_hud() -> void:
	var h := _hud
	# Viñeta.
	for i in 7:
		var a := 0.11 * (7 - i) / 7.0
		h.draw_rect(Rect2(i * 4, 0, 4, 240), Color(0, 0, 0, a))
		h.draw_rect(Rect2(426 - (i + 1) * 4, 0, 4, 240), Color(0, 0, 0, a))
	var fade_in := clampf(_t / 0.4, 0.0, 1.0)
	# Barra superior: frente, año del reloj y número de combate.
	h.draw_rect(Rect2(0, 0, 426, 22), SHADE)
	h.draw_rect(Rect2(0, 22, 426, 1), HKTheme.GOLD_DARK)
	var chapter := Game.story_chapter_of(_nodes[_cur].fighter)
	var title := "FRENTE %s" % ROMAN[mini(chapter, ROMAN.size() - 1)] if chapter < Game.STORY_CHAPTERS.size() else "EL NEXO"
	HKTheme.draw_text(h, Vector2(8, 14), title, 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var combat := "COMBATE %d/%d" % [Game.arcade_stage + 1, Game.arcade_ladder.size()]
	HKTheme.draw_text(h, Vector2(0, 14), combat, 8, HKTheme.MUTED.lightened(0.25), HORIZONTAL_ALIGNMENT_RIGHT, 418, 1)
	_draw_year(h)
	# Etiqueta de la ciudad cuando la cámara está cerca.
	if _zoom > 1.8 and not _dive_started:
		_label(h, _cur)
		if _mode == Mode.TRAVEL and _t < _t_focus + 0.9:
			_label(h, _prev)
	# Banner del rival, abajo.
	var bt := clampf((_t - _t_arrive - 0.15) / 0.55, 0.0, 1.0)
	if bt > 0.0 and not _dive_started:
		_draw_banner(h, (1.0 - _ease_out(bt)) * 54.0)
	if _t < _t_dive and int(_t * 2.0) % 2 == 0:
		HKTheme.draw_text(h, Vector2(0, 237), "ENTER: SALTAR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 420, 1)
	# Destellos: al llegar y al lanzarse dentro de la ciudad.
	var since := _t - _t_arrive
	if since >= 0.0 and since < 0.3:
		h.draw_rect(Rect2(0, 0, 426, 240), Color(1, 1, 1, 0.35 * (1.0 - since / 0.3)))
	if _dive_started:
		var v := clampf((_t - _t_dive) / DIVE_TIME, 0.0, 1.0)
		h.draw_rect(Rect2(0, 0, 426, 240), Color(1, 0.94, 0.7, 0.5 * (1.0 - v) * (1.0 - v)))
	# Aparición del mapa.
	if fade_in < 1.0:
		h.draw_rect(Rect2(0, 0, 426, 240), Color(0.02, 0.01, 0.04, 1.0 - fade_in))

func _label(h: CanvasItem, i: int) -> void:
	var node: Dictionary = _nodes[i]
	var s: Vector2 = node.pos * _zoom + _world.position
	var text: String = node.name
	var w := HKTheme.text_width(text, 8)
	var lib := _liberation(i)
	var col := HKTheme.GOLD if lib > 0.5 else HKTheme.PAPER
	var pos := Vector2(clampf(s.x - w * 0.5, 6.0, 420.0 - w), clampf(s.y + 8.0 + 3.0 * _zoom, 34.0, 198.0))
	HKTheme.draw_text(h, pos, text, 8, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)

func _draw_year(h: CanvasItem) -> void:
	var text: String
	var col := Color("fff0a0")
	if _nodes[_cur].nexo and (_mode != Mode.TRAVEL or _t >= _t_focus):
		text = "????"
		if _t < _t_arrive and int(_t * 14.0) % 3 != 0:
			text = "%d" % _rng.randi_range(1000, 9999)
		col = NEXO_COLOR.lightened(0.5)
	else:
		var u := 0.0
		if _mode == Mode.TRAVEL:
			u = _ease_io(clampf((_t - _t_focus) / _travel_dur, 0.0, 1.0))
		else:
			u = 1.0
		var year := int(round(lerpf(float(_year_from), float(_year_to), u)))
		text = "%d A.C." % -year if year < 0 else str(year)
	var tw := HKTheme.text_width(text, 16)
	HKTheme.draw_text(h, Vector2(213 - tw * 0.5, 17), text, 16, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)

func _draw_banner(h: CanvasItem, slide: float) -> void:
	var node: Dictionary = _nodes[_cur]
	var d := FighterRegistry.get_by_id(node.fighter)
	var y0 := 196.0 + slide
	h.draw_rect(Rect2(0, y0, 426, 44), SHADE)
	h.draw_rect(Rect2(0, y0, 426, 1), HKTheme.GOLD_DARK)
	var name_text := d.display_name.to_upper()
	var size := 16 if HKTheme.text_width(name_text, 16) < 400.0 else 8
	HKTheme.draw_text(h, Vector2(8, y0 + (20 if size == 16 else 17)), name_text, size, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var where: String = node.name if node.nexo else "%s  ·  %s" % [node.name, d.country.to_upper()]
	HKTheme.draw_text(h, Vector2(8, y0 + 33), where, 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var tag := ""
	if node.nexo:
		tag = "JEFE FINAL"
	elif node.boss:
		tag = "JEFE DE LA ÉPOCA"
	if tag != "":
		HKTheme.draw_text(h, Vector2(0, y0 + 14), tag, 8, HKTheme.BLOOD.lightened(0.25), HORIZONTAL_ALIGNMENT_RIGHT, 418, 1)

# =========================================================================
#  Utilidades
# =========================================================================
func _year_of(id: StringName) -> int:
	return FighterRegistry.get_by_id(id).year

static func _bez(a: Vector2, c: Vector2, b: Vector2, u: float) -> Vector2:
	return a.lerp(c, u).lerp(c.lerp(b, u), u)

static func _ease_io(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

static func _ease_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

static func _ease_in(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x

static func _ease_out_back(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	var c1 := 1.9
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)
