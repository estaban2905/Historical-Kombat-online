## Globo terráqueo del MODO HISTORIA. Se ve antes de cada combate, encima de la pantalla del rival.
##   Elegir  El mundo gira sobre su eje. Las ciudades de la época están ocupadas por los villanos (bandera roja);
##           las ya liberadas, en dorado. Con ← → (o el ratón) eliges a qué villano detener y con ENTER atacas.
##           El jefe de la época está bloqueado hasta vencer a todos los demás: así se pasa a la época siguiente.
##   Viaje   Tu nave sale de la última ciudad liberada (o cae del espacio en el primer combate), cruza el globo en
##           arco con estela, y el mundo gira siguiéndola.
##   Llegada Tiembla el planeta, se alza la bandera enemiga y la cámara se lanza dentro de la ciudad.
## Emite `picked(stage)` al confirmar (antes del viaje), `finished` al terminar y `cancelled` si se pulsa ESC.
## Mientras `waiting` es verdadero se queda en negro, debajo de la tarjeta del capítulo.
class_name StoryGlobeMap
extends Control

signal picked(stage: int)
signal finished
signal cancelled

enum Phase { SELECT, FLIGHT, ARRIVE, DIVE }

const CENTER := Vector2(213.0, 112.0)
const RADIUS := 80.0
const TEX_W := 960
const TEX_H := 480
## El rectángulo del globo es un poco mayor que la esfera para dejar sitio a la atmósfera.
const HALO := 1.22
const ARRIVE_TIME := 1.0
const DIVE_TIME := 0.65
const ROMAN: Array[String] = ["I", "II", "III", "IV", "V"]

const ENEMY := Color("d02a30")
const GOLD := Color("f0c040")
const NEXO_COLOR := Color("9a4dff")
const LOCKED := Color("7a6a88")
const SHADE := Color(0.05, 0.02, 0.07, 0.86)

const ANTARCTICA := [-180, -71, -150, -77, -120, -73, -90, -72, -65, -66, -60, -64, -55, -72, -30, -71, 0, -70, 30, -69,
	60, -67, 90, -66, 120, -66, 150, -69, 180, -71, 180, -90, -180, -90]

const SHADER := """
shader_type canvas_item;
uniform sampler2D earth : filter_linear;
uniform float lon0 = 0.0;
uniform float tilt = 0.0;
uniform float t = 0.0;
const float HALO = 1.22;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * HALO;
	float r2 = dot(p, p);
	if (r2 > 1.0) {
		float d = sqrt(r2);
		float glow = smoothstep(HALO, 1.0, d);
		COLOR = vec4(0.30, 0.62, 1.0, glow * glow * 0.75);
	} else {
		vec3 n = vec3(p.x, -p.y, sqrt(1.0 - r2));
		float ct = cos(tilt);
		float st = sin(tilt);
		float yw = n.y * ct + n.z * st;
		float zw = -n.y * st + n.z * ct;
		float lon = atan(n.x, zw) + lon0;
		float lat = asin(clamp(yw, -1.0, 1.0));
		vec2 uv = vec2(fract(lon / (2.0 * PI) + 0.5), 0.5 - lat / PI);
		vec3 col = texture(earth, uv).rgb;
		vec3 L = normalize(vec3(-0.55, 0.4, 0.75));
		float diff = clamp(dot(n, L), 0.0, 1.0);
		float ocean = step(col.r + 0.02, col.b);
		col *= 0.30 + 0.85 * diff;
		vec3 R = reflect(-L, n);
		col += ocean * pow(max(R.z, 0.0), 22.0) * 0.32 * vec3(0.7, 0.85, 1.0);
		vec2 cuv = vec2(lon * 3.0 + t * 0.05, lat * 5.0);
		float c = noise(cuv * 2.0) * noise(cuv * 5.0 + 7.0);
		col = mix(col, vec3(1.0), smoothstep(0.34, 0.70, c) * 0.17 * (0.35 + diff));
		float gl = abs(fract(lon / (PI / 6.0) + 0.5) - 0.5);
		float ga = abs(fract(lat / (PI / 6.0) + 0.5) - 0.5);
		float grid = (1.0 - smoothstep(0.0, 0.025, gl)) + (1.0 - smoothstep(0.0, 0.03, ga));
		col = mix(col, vec3(0.65, 0.85, 1.0), clamp(grid, 0.0, 1.0) * 0.10);
		float rim = pow(1.0 - n.z, 2.4);
		col += vec3(0.25, 0.5, 1.0) * rim * 0.85;
		COLOR = vec4(col, 1.0);
	}
}
"""

## Mientras sea verdadero se queda en negro y no avanza (esperando a que acabe la tarjeta del capítulo).
var waiting: bool = false

var _phase: Phase = Phase.SELECT
var _t: float = 0.0
var _pt: float = 0.0
var _done: bool = false
## Combates de la época actual: {stage, id, city, ll (longitud, latitud), boss, nexo, state: pending|beaten|locked}.
var _entries: Array[Dictionary] = []
## Ciudades de otras épocas: {ll, state: beaten|future}.
var _others: Array[Dictionary] = []
var _sel: int = 0
var _lon0: float = 0.0
var _tilt: float = 0.0
var _lon0_t: float = 0.0
var _tilt_t: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _has_origin: bool = false
var _flight_dur: float = 1.8
var _ship_u: float = 0.0
var _burst_done: bool = false
var _deny: float = 0.0
var _pivot: Vector2 = CENTER
var _parts: Array = []
var _stars: Array = []
var _rng := RandomNumberGenerator.new()
var _emit_acc: float = 0.0
var _headless: bool = false

var _world: Node2D
var _bg: Node2D
var _globe: ColorRect
var _dyn: Node2D
var _hud: Control
var _vp: SubViewport
var _mat: ShaderMaterial

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 5
	_headless = DisplayServer.get_name() == "headless"
	_build_entries()
	_make_layers()
	_make_stars()
	if not _headless:
		_build_earth()
	_focus_selected(true)

# =========================================================================
#  Datos
# =========================================================================
func _lonlat_of_stage(i: int) -> Vector2:
	while i > 0 and Game.story_is_creator(i):
		i -= 1   # el creador poseído pelea en la ciudad del jefe
	var id: StringName = Game.arcade_ladder[i]
	if id == Game.STORY_NEXO_ID:
		return WorldMapData.NEXO_LONLAT
	var c := WorldMapData.city_of(id)
	return Vector2(c[1], c[2])

func _city_name(i: int) -> String:
	var id: StringName = Game.arcade_ladder[i]
	return WorldMapData.NEXO_CITY if id == Game.STORY_NEXO_ID else str(WorldMapData.city_of(id)[0])

func _build_entries() -> void:
	var chapter := Game.story_current_chapter()
	var used: Array[Vector2] = []
	for i in Game.arcade_ladder.size():
		if Game.story_is_creator(i):
			continue
		var id: StringName = Game.arcade_ladder[i]
		var ll := _lonlat_of_stage(i)
		# Dos rivales en la misma ciudad (Roma, Moscú...) se separan un poco para que se vean los dos.
		var again := true
		while again:
			again = false
			for u in used:
				if absf(u.x - ll.x) < 3.0 and absf(u.y - ll.y) < 3.0:
					ll += Vector2(3.2, 2.4)
					again = true
		used.append(ll)
		var beaten := Game.story_beaten.has(i)
		if Game.story_chapter_of(id) == chapter:
			var state := &"beaten" if beaten else (&"pending" if Game.story_available(i) else &"locked")
			_entries.append({"stage": i, "id": id, "city": _city_name(i), "ll": ll, "state": state,
				"boss": Game.story_is_chapter_boss(i), "nexo": id == Game.STORY_NEXO_ID})
		else:
			_others.append({"ll": ll, "state": &"beaten" if beaten else &"future"})
	_sel = 0
	for k in _entries.size():
		if _entries[k].stage == Game.arcade_stage and _entries[k].state == &"pending":
			_sel = k
	if _entries[_sel].state != &"pending":
		for k in _entries.size():
			if _entries[k].state == &"pending":
				_sel = k
				break
	if Game.story_last_won >= 0:
		_origin = _lonlat_of_stage(Game.story_last_won)
		_has_origin = true

func _make_layers() -> void:
	_world = Node2D.new()
	add_child(_world)
	_bg = Node2D.new()
	_world.add_child(_bg)
	_bg.draw.connect(_draw_bg)
	_globe = ColorRect.new()
	_globe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var side := RADIUS * 2.0 * HALO
	_globe.size = Vector2(side, side)
	_globe.position = CENTER - _globe.size * 0.5
	if not _headless:
		var sh := Shader.new()
		sh.code = SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = sh
		_globe.material = _mat
	_world.add_child(_globe)
	_dyn = Node2D.new()
	_world.add_child(_dyn)
	_dyn.draw.connect(_draw_dyn)
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hud)
	_hud.draw.connect(_draw_hud)

func _make_stars() -> void:
	for i in 150:
		_stars.append([Vector2(_rng.randf_range(-300, 730), _rng.randf_range(-200, 440)), _rng.randf() * TAU, _rng.randf_range(0.6, 1.6)])

# =========================================================================
#  La Tierra (textura equirrectangular dibujada una vez en un SubViewport)
# =========================================================================
func _build_earth() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(TEX_W, TEX_H)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var n := Node2D.new()
	_vp.add_child(n)
	n.draw.connect(func(): _draw_earth(n))
	add_child(_vp)
	_mat.set_shader_parameter("earth", _vp.get_texture())

func _tex_pts(flat: Array) -> PackedVector2Array:
	var k := TEX_W / 360.0
	var pts := PackedVector2Array()
	var i := 0
	while i + 1 < flat.size():
		pts.append(Vector2((float(flat[i]) + 180.0) * k, (90.0 - float(flat[i + 1])) * k))
		i += 2
	return pts

func _fill(n: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	n.draw_colored_polygon(pts, color)

func _draw_earth(n: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# Mar: más claro en el ecuador.
	var bands := 48
	for i in bands:
		var u := (float(i) + 0.5) / bands
		var mid := 1.0 - absf(u - 0.5) * 2.0
		n.draw_rect(Rect2(0, TEX_H * float(i) / bands, TEX_W, TEX_H / float(bands) + 1.0),
			Color("07142a").lerp(Color("12406a"), mid * 0.85))
	var polys: Array[PackedVector2Array] = []
	for flat in WorldMapData.lands():
		polys.append(_tex_pts(flat))
	polys.append(_tex_pts(ANTARCTICA))
	for pts in polys:
		var closed := pts.duplicate()
		closed.append(pts[0])
		n.draw_polyline(closed, Color(0.30, 0.68, 0.92, 0.22), 7.0)
	for pts in polys:
		_fill(n, pts, Color("5b5238"))
	for pts in polys:
		var bb := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			bb = bb.expand(p)
		var count := mini(int(bb.get_area() / 14.0), 6000)
		for k in count:
			var p := Vector2(rng.randf_range(bb.position.x, bb.end.x), rng.randf_range(bb.position.y, bb.end.y))
			if Geometry2D.is_point_in_polygon(p, pts):
				var light := rng.randf() > 0.55
				n.draw_rect(Rect2(p.round(), Vector2(2, 2)), Color("6f6545") if light else Color("483f2b"))
	for flat in WorldMapData.seas():
		_fill(n, _tex_pts(flat), Color("0c2a48"))
	for pts in polys:
		var closed2 := pts.duplicate()
		closed2.append(pts[0])
		n.draw_polyline(closed2, Color("e0c26e", 0.85), 1.6)
	# Casquetes polares.
	var ice := Color(0.92, 0.96, 1.0)
	for i in 14:
		var a := 0.55 * (1.0 - float(i) / 14.0)
		n.draw_rect(Rect2(0, i * 2.0, TEX_W, 2), Color(ice, a))
		n.draw_rect(Rect2(0, TEX_H - (i + 1) * 2.0, TEX_W, 2), Color(ice, a))

# =========================================================================
#  Geometría del globo
# =========================================================================
static func _wvec(ll: Vector2) -> Vector3:
	var lon := deg_to_rad(ll.x)
	var lat := deg_to_rad(ll.y)
	return Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon))

## Lleva un punto de la esfera a la vista de la cámara: x a la derecha, y arriba, z hacia el espectador.
func _view_of(w: Vector3) -> Vector3:
	var c0 := cos(_lon0)
	var s0 := sin(_lon0)
	var x := w.x * c0 - w.z * s0
	var z := w.x * s0 + w.z * c0
	var ct := cos(_tilt)
	var st := sin(_tilt)
	return Vector3(x, w.y * ct - z * st, w.y * st + z * ct)

func _scr(v: Vector3, lift: float = 1.0) -> Vector2:
	return CENTER + Vector2(v.x, -v.y) * RADIUS * lift

func _focus_selected(snap: bool) -> void:
	var ll: Vector2 = _entries[_sel].ll
	_lon0_t = deg_to_rad(ll.x)
	_tilt_t = clampf(deg_to_rad(ll.y) * 0.9, -1.0, 1.0)
	if snap:
		_lon0 = _lon0_t
		_tilt = _tilt_t

# =========================================================================
#  Entrada
# =========================================================================
func _select(k: int) -> void:
	k = posmod(k, _entries.size())
	if k != _sel:
		_sel = k
		Sfx.play(&"select")
		_focus_selected(false)

func _confirm() -> void:
	var e: Dictionary = _entries[_sel]
	if e.state != &"pending":
		_deny = 0.5
		Sfx.play(&"denied")
		return
	Sfx.play(&"fight")
	Game.story_pick(e.stage)
	picked.emit(e.stage)
	_start_flight(e)

func _skip() -> void:
	if _phase != Phase.DIVE:
		_set_phase(Phase.DIVE)

func _input(event: InputEvent) -> void:
	if _done or waiting:
		return
	if _phase != Phase.SELECT:
		var key_skip := HKTheme.is_enter(event) or event.is_action_pressed(&"ui_cancel")
		var click := event as InputEventMouseButton
		if key_skip or (click != null and click.pressed):
			_skip()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_up"):
		_select(_sel - 1)
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_down"):
		_select(_sel + 1)
	elif HKTheme.is_enter(event) or event.is_action_pressed(&"ui_accept"):
		_confirm()
	elif event.is_action_pressed(&"ui_cancel"):
		cancelled.emit()
	else:
		var m := event as InputEventMouseButton
		if m == null or not m.pressed or m.button_index != MOUSE_BUTTON_LEFT:
			return
		_click(get_global_mouse_position())
		get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()

func _click(pos: Vector2) -> void:
	for k in _entries.size():
		if Rect2(4, 30 + k * 12, 118, 11).has_point(pos):
			if k == _sel:
				_confirm()
			else:
				_select(k)
			return
	for k in _entries.size():
		var v := _view_of(_wvec(_entries[k].ll))
		if v.z > 0.05 and _scr(v).distance_to(pos) < 8.0:
			if k == _sel:
				_confirm()
			else:
				_select(k)
			return

# =========================================================================
#  Fases
# =========================================================================
func _start_flight(e: Dictionary) -> void:
	var dest: Vector2 = e.ll
	if _has_origin:
		var a := _wvec(_origin)
		var b := _wvec(dest)
		var ang := a.angle_to(b)
		_flight_dur = clampf(1.2 + ang * 1.0, 1.5, 3.2)
	else:
		_flight_dur = 1.5
	_set_phase(Phase.FLIGHT)

func _set_phase(p: Phase) -> void:
	_phase = p
	_pt = 0.0
	if p == Phase.DIVE:
		var v := _view_of(_wvec(_entries[_sel].ll))
		_pivot = _scr(v)

func _process(delta: float) -> void:
	if _done or waiting:
		return
	_t += delta
	_pt += delta
	if _deny > 0.0:
		_deny = maxf(_deny - delta, 0.0)
	# El mundo gira hacia donde toca (por el camino corto).
	var k := 1.0 - exp(-delta * (6.0 if _phase == Phase.SELECT else 9.0))
	_lon0 = lerp_angle(_lon0, _lon0_t, k)
	_tilt = lerpf(_tilt, _tilt_t, k)
	match _phase:
		Phase.SELECT:
			# Un balanceo lento para que el globo esté siempre vivo.
			_lon0 += sin(_t * 0.7) * delta * 0.03
		Phase.FLIGHT:
			_ship_u = _ease_io(_pt / _flight_dur)
			var ll := _ship_lonlat(_ship_u)
			_lon0_t = deg_to_rad(ll.x)
			_tilt_t = clampf(deg_to_rad(ll.y) * 0.9, -1.0, 1.0)
			_emit_trail(delta)
			if _pt >= _flight_dur:
				_set_phase(Phase.ARRIVE)
				_focus_selected(false)
		Phase.ARRIVE:
			_focus_selected(false)
			if not _burst_done:
				_burst_done = true
				_arrival_burst()
			if _pt >= ARRIVE_TIME:
				_set_phase(Phase.DIVE)
		Phase.DIVE:
			var v := clampf(_pt / DIVE_TIME, 0.0, 1.0)
			var s := pow(7.0, _ease_in(v))
			_world.scale = Vector2(s, s)
			_world.position = _pivot * (1.0 - s)
			modulate.a = 1.0 - smoothstep(0.2, 1.0, v)
			if _pt >= DIVE_TIME:
				_done = true
				finished.emit()
				queue_free()
				return
	if _mat != null:
		_mat.set_shader_parameter("lon0", _lon0)
		_mat.set_shader_parameter("tilt", _tilt)
		_mat.set_shader_parameter("t", _t)
	_update_particles(delta)
	_bg.queue_redraw()
	_dyn.queue_redraw()
	_hud.queue_redraw()

## Posición (longitud, latitud) de la nave sobre el globo, y su altura en `_ship_lift`.
func _ship_lonlat(u: float) -> Vector2:
	var dest: Vector2 = _entries[_sel].ll
	if not _has_origin:
		return dest
	var w := _slerp(_wvec(_origin), _wvec(dest), u)
	return Vector2(rad_to_deg(atan2(w.x, w.z)), rad_to_deg(asin(clampf(w.y, -1.0, 1.0))))

func _ship_world(u: float) -> Vector3:
	var dest: Vector2 = _entries[_sel].ll
	if not _has_origin:
		return _wvec(dest)
	return _slerp(_wvec(_origin), _wvec(dest), u)

func _ship_lift(u: float) -> float:
	if not _has_origin:
		return 1.0 + 0.75 * (1.0 - _ease_out(u))   # cae del espacio
	return 1.0 + 0.16 * sin(PI * u)

static func _slerp(a: Vector3, b: Vector3, u: float) -> Vector3:
	var ang := a.angle_to(b)
	if ang < 0.0001:
		return a
	var s := sin(ang)
	return (a * sin((1.0 - u) * ang) + b * sin(u * ang)) / s

func _emit_trail(delta: float) -> void:
	var v := _view_of(_ship_world(_ship_u))
	if v.z < 0.0:
		return
	var p := _scr(v, _ship_lift(_ship_u))
	_emit_acc += delta * 80.0
	while _emit_acc >= 1.0:
		_emit_acc -= 1.0
		var col: Color = [GOLD, Color("fff0a0"), NEXO_COLOR.lightened(0.3)][_rng.randi() % 3]
		_parts.append([p, Vector2(_rng.randf_range(-9, 9), _rng.randf_range(-9, 9)), _rng.randf_range(0.4, 0.9), 0.9, col,
			1.0 if _rng.randf() < 0.7 else 2.0])

func _arrival_burst() -> void:
	var p := _scr(_view_of(_wvec(_entries[_sel].ll)))
	for i in 44:
		var col: Color = [ENEMY, Color("ff8a40"), Color.WHITE, GOLD][_rng.randi() % 4]
		_parts.append([p, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(10, 48), _rng.randf_range(0.5, 1.2), 1.2, col,
			1.0 if i % 3 else 2.0])

func _update_particles(delta: float) -> void:
	var i := _parts.size() - 1
	while i >= 0:
		var p: Array = _parts[i]
		p[2] = p[2] - delta
		if p[2] <= 0.0:
			_parts.remove_at(i)
		else:
			p[0] = p[0] + p[1] * delta
			p[1] = p[1] * (1.0 - 1.6 * delta)
		i -= 1

# =========================================================================
#  Dibujo
# =========================================================================
func _draw_bg() -> void:
	var n := _bg
	n.draw_rect(Rect2(-400, -300, 1300, 800), Color("04050f"))
	for k in 6:
		n.draw_circle(CENTER, RADIUS * (1.9 - k * 0.12), Color(0.10, 0.18, 0.45, 0.025 + k * 0.006))
	for s in _stars:
		var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 1.7 + s[1]))
		n.draw_rect(Rect2((s[0] as Vector2).round(), Vector2(s[2], s[2])), Color(0.85, 0.92, 1.0, a))

func _marker_colors(state: StringName) -> Color:
	match state:
		&"beaten":
			return GOLD
		&"locked":
			return LOCKED
		&"future":
			return ENEMY.darkened(0.45)
	return ENEMY

func _draw_dyn() -> void:
	var n := _dyn
	for o in _others:
		var v := _view_of(_wvec(o.ll))
		if v.z > 0.05:
			var c: Color = _marker_colors(o.state)
			n.draw_rect(Rect2((_scr(v) - Vector2(1, 1)).round(), Vector2(3, 3)), Color(c, smoothstep(0.05, 0.3, v.z)))
	# Primero las ciudades del fondo para que las del frente queden encima.
	var order: Array[int] = []
	for k in _entries.size():
		order.append(k)
	order.sort_custom(func(a, b): return _view_of(_wvec(_entries[a].ll)).z < _view_of(_wvec(_entries[b].ll)).z)
	for k in order:
		_draw_entry(n, k)
	for p in _parts:
		var col: Color = p[4]
		col.a *= clampf(p[2] / p[3], 0.0, 1.0)
		n.draw_rect(Rect2((p[0] as Vector2).round(), Vector2(p[5], p[5])), col)
	if _phase == Phase.FLIGHT:
		_draw_ship(n)
	if _phase == Phase.ARRIVE or (_phase == Phase.DIVE and _burst_done):
		_draw_shock(n)

func _draw_entry(n: CanvasItem, k: int) -> void:
	var e: Dictionary = _entries[k]
	var v := _view_of(_wvec(e.ll))
	if v.z <= 0.03:
		return
	var p := _scr(v)
	var m := 0.6 + 0.4 * v.z
	var fade := smoothstep(0.03, 0.3, v.z)
	var state: StringName = e.state
	var col := _marker_colors(state)
	if e.nexo and state != &"beaten":
		col = NEXO_COLOR
	var selected := k == _sel
	var pulse := 0.5 + 0.5 * sin(_t * 3.0 + k)
	# Zona ocupada: elipse sobre la superficie.
	n.draw_set_transform(p, 0.0, Vector2(1.0, 0.35 + 0.65 * v.z))
	var r := (6.5 if e.boss else 5.0) * m
	n.draw_circle(Vector2.ZERO, r, Color(col, (0.10 + 0.06 * pulse) * fade))
	n.draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(col, (0.55 + 0.25 * pulse) * fade), 1.0)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Bandera (el creador del Reloj poseído comparte la del jefe).
	var h := (9.0 if e.boss else 6.5) * m
	if _phase == Phase.ARRIVE and selected:
		h *= _ease_out_back(_pt / 0.5)
	elif _phase == Phase.FLIGHT and selected:
		h = 0.0
	if state == &"locked":
		h = 5.0 * m
	if h > 0.5:
		n.draw_line(p, p + Vector2(0, -h), Color(0.92, 0.88, 0.78, fade), 1.0)
		var w := 4 if e.boss else 3
		for q in w:
			var wave := sin(_t * 6.0 + k + q * 0.9) * 0.6 * (0.0 if state == &"locked" else 1.0)
			n.draw_rect(Rect2(p.x + 0.5 + q, p.y - h + wave, 1.0, maxf(h * 0.5, 1.0)), Color(col, fade))
	if e.nexo and state != &"beaten":
		var c := p + Vector2(0, -11.0 * m)
		n.draw_circle(c, 3.4 * m, Color("c9a0ff", fade))
		n.draw_circle(c, 2.2 * m, Color("1a1030", fade))
		n.draw_line(c, c + Vector2(cos(_t * 4.0), sin(_t * 4.0)) * 2.0, Color(1, 1, 1, fade), 1.0)
		n.draw_arc(c, 6.5 * m, _t * 2.0, _t * 2.0 + PI * 0.8, 10, Color(NEXO_COLOR.lightened(0.3), 0.85 * fade), 1.0)
	elif state == &"locked":
		# Candado sobre el jefe: se abre al vencer a los demás.
		var lp := p + Vector2(0, -h - 5.0)
		n.draw_arc(lp + Vector2(0, -1), 2.0, PI, TAU, 8, Color(col.lightened(0.3), fade), 1.0)
		n.draw_rect(Rect2(lp + Vector2(-2, -1), Vector2(5, 4)), Color(col.lightened(0.3), fade))
	elif e.boss and h > 2.0:
		var top := p + Vector2(0, -h - 3.0)
		n.draw_colored_polygon(PackedVector2Array([top + Vector2(0, -2), top + Vector2(2, 0), top + Vector2(0, 2), top + Vector2(-2, 0)]),
			Color("fff0a0", fade) if state == &"beaten" else Color("ffb0a0", fade))
	if selected and _phase == Phase.SELECT:
		var rr := 11.0 + 1.5 * sin(_t * 5.0)
		for q in 4:
			var a0 := _t * 1.6 + q * TAU / 4.0
			n.draw_arc(p, rr, a0, a0 + 0.55, 6, Color("fff0a0"), 1.0)
		var name_text: String = e.city
		var tw := HKTheme.text_width(name_text, 8)
		var pos := Vector2(clampf(p.x - tw * 0.5, 4.0, 422.0 - tw), clampf(p.y + 22.0, 30.0, 190.0))
		HKTheme.draw_text(n, pos, name_text, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)

func _draw_ship(n: CanvasItem) -> void:
	var u := _ship_u
	var v := _view_of(_ship_world(u))
	if v.z < 0.0:
		return
	var lift := _ship_lift(u)
	var p := _scr(v, lift)
	var v2 := _view_of(_ship_world(minf(u + 0.02, 1.0)))
	var q := _scr(v2, _ship_lift(minf(u + 0.02, 1.0)))
	var angle := (q - p).angle() if q.distance_to(p) > 0.05 else -PI * 0.5
	# Sombra de la nave sobre el suelo.
	n.draw_circle(_scr(v), 3.0, Color(0, 0, 0, 0.25))
	for k in range(4, 0, -1):
		n.draw_circle(p - Vector2.from_angle(angle) * (k * 3.0), 2.5, Color(GOLD, 0.06 * (5 - k)))
	n.draw_circle(p, 7.0, Color(GOLD, 0.13))
	n.draw_circle(p, 4.0, Color("fff0a0", 0.25))
	var xf := Transform2D(angle, p)
	var pts := PackedVector2Array()
	for h in [Vector2(5, 0), Vector2(-3, -3), Vector2(-1, 0), Vector2(-3, 3)]:
		pts.append(xf * h)
	n.draw_colored_polygon(pts, Color("fff0a0"))

func _draw_shock(n: CanvasItem) -> void:
	var p := _scr(_view_of(_wvec(_entries[_sel].ll)))
	var a := _pt if _phase == Phase.ARRIVE else ARRIVE_TIME + _pt
	for k in 3:
		var u := clampf((a - k * 0.12) / 0.9, 0.0, 1.0)
		if u <= 0.0 or u >= 1.0:
			continue
		var base := NEXO_COLOR if _entries[_sel].nexo else ENEMY
		n.draw_arc(p, 3.0 + _ease_out(u) * 36.0, 0.0, TAU, 40, Color(base.lerp(Color.WHITE, 1.0 - u), 0.9 * (1.0 - u)), 2.0 - u)

func _draw_hud() -> void:
	var h := _hud
	for i in 7:
		var a := 0.12 * (7 - i) / 7.0
		h.draw_rect(Rect2(i * 4, 0, 4, 240), Color(0, 0, 0, a))
		h.draw_rect(Rect2(426 - (i + 1) * 4, 0, 4, 240), Color(0, 0, 0, a))
	var e: Dictionary = _entries[_sel]
	var chapter := Game.story_current_chapter()
	h.draw_rect(Rect2(0, 0, 426, 22), SHADE)
	h.draw_rect(Rect2(0, 22, 426, 1), HKTheme.GOLD_DARK)
	var title := "FRENTE %s" % ROMAN[mini(chapter, ROMAN.size() - 1)] if chapter < Game.STORY_CHAPTERS.size() else "EL NEXO"
	HKTheme.draw_text(h, Vector2(8, 14), title + "  ·  " + Game.story_chapter_name(chapter), 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var done := 0
	for x in _entries:
		if x.state == &"beaten":
			done += 1
	HKTheme.draw_text(h, Vector2(0, 14), "VENCIDOS %d/%d" % [done, _entries.size()], 8, HKTheme.MUTED.lightened(0.25),
		HORIZONTAL_ALIGNMENT_RIGHT, 418, 1)
	# Lista de villanos de la época.
	if _phase == Phase.SELECT:
		for k in _entries.size():
			_draw_row(h, k)
	var bt := 1.0 if _phase == Phase.SELECT else clampf(_pt / 0.4, 0.0, 1.0) if _phase == Phase.FLIGHT else 1.0
	_draw_banner(h, e, (1.0 - _ease_out(clampf(_t / 0.5, 0.0, 1.0) * bt)) * 50.0)
	if _phase == Phase.SELECT:
		HKTheme.draw_text(h, Vector2(0, 237), "< >  ELEGIR   ENTER: ATACAR", 8, HKTheme.MUTED.lightened(0.15), HORIZONTAL_ALIGNMENT_RIGHT, 420, 1)
	else:
		HKTheme.draw_text(h, Vector2(0, 237), "ENTER: SALTAR", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 420, 1)
	if _phase == Phase.ARRIVE and _pt < 0.3:
		h.draw_rect(Rect2(0, 0, 426, 240), Color(1, 1, 1, 0.35 * (1.0 - _pt / 0.3)))
	if _phase == Phase.DIVE:
		var v := clampf(_pt / DIVE_TIME, 0.0, 1.0)
		h.draw_rect(Rect2(0, 0, 426, 240), Color(1, 0.94, 0.7, 0.5 * (1.0 - v) * (1.0 - v)))
	var fade_in := clampf(_t / 0.45, 0.0, 1.0)
	if fade_in < 1.0:
		h.draw_rect(Rect2(0, 0, 426, 240), Color(0.02, 0.01, 0.04, 1.0 - fade_in))

func _draw_row(h: CanvasItem, k: int) -> void:
	var e: Dictionary = _entries[k]
	var y := 30.0 + k * 12.0
	var selected := k == _sel
	if selected:
		h.draw_rect(Rect2(4, y, 118, 11), Color(0.35, 0.22, 0.05, 0.55))
		h.draw_rect(Rect2(4, y, 2, 11), HKTheme.GOLD)
	var col := _marker_colors(e.state)
	if e.nexo and e.state != &"beaten":
		col = NEXO_COLOR
	h.draw_rect(Rect2(10, y + 3, 5, 5), col)
	if e.state == &"beaten":
		h.draw_line(Vector2(11, y + 5), Vector2(12, y + 7), Color(0.1, 0.06, 0.02), 1.0)
		h.draw_line(Vector2(12, y + 7), Vector2(14, y + 3), Color(0.1, 0.06, 0.02), 1.0)
	var d := FighterRegistry.get_by_id(e.id)
	var tcol := HKTheme.PAPER if selected else (HKTheme.MUTED.lightened(0.3) if e.state != &"pending" else HKTheme.PAPER.darkened(0.15))
	var shake := Vector2(sin(_t * 60.0) * 2.0 * (_deny / 0.5), 0.0) if selected else Vector2.ZERO
	HKTheme.draw_text(h, Vector2(19, y + 9) + shake, d.short_name.to_upper(), 8, tcol, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

func _draw_banner(h: CanvasItem, e: Dictionary, slide: float) -> void:
	var d := FighterRegistry.get_by_id(e.id)
	var y0 := 196.0 + slide
	h.draw_rect(Rect2(0, y0, 426, 44), SHADE)
	h.draw_rect(Rect2(0, y0, 426, 1), HKTheme.GOLD_DARK)
	var name_text := d.display_name.to_upper()
	var size := 16 if HKTheme.text_width(name_text, 16) < 400.0 else 8
	HKTheme.draw_text(h, Vector2(8, y0 + (20 if size == 16 else 17)), name_text, size, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	var where: String = e.city if e.nexo else "%s  ·  %s  ·  %s" % [e.city, d.country.to_upper(), _year_text(d)]
	HKTheme.draw_text(h, Vector2(8, y0 + 33), where, 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	var tag := ""
	var tag_col := HKTheme.BLOOD.lightened(0.25)
	if e.state == &"locked":
		tag = "BLOQUEADO"
		tag_col = LOCKED.lightened(0.3)
	elif e.state == &"beaten":
		tag = "LIBERADA"
		tag_col = GOLD
	elif e.nexo:
		tag = "JEFE FINAL"
	elif e.boss:
		tag = "JEFE DE LA ÉPOCA"
	if tag != "":
		HKTheme.draw_text(h, Vector2(0, y0 + 14), tag, 8, tag_col, HORIZONTAL_ALIGNMENT_RIGHT, 418, 1)
	if e.state == &"locked":
		HKTheme.draw_text(h, Vector2(0, y0 + 26), "VENCE A LOS DEMÁS DE LA ÉPOCA", 8, tag_col, HORIZONTAL_ALIGNMENT_RIGHT, 418, 1)

func _year_text(d: FighterData) -> String:
	return "%d A.C." % -d.year if d.year < 0 else str(d.year)

# =========================================================================
#  Utilidades
# =========================================================================
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
	return 1.0 + 2.9 * pow(x - 1.0, 3.0) + 1.9 * pow(x - 1.0, 2.0)
