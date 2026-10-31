## Dibujo procedural (pixel art provisional) de los efectos de los poderes
## especiales: oso, dragón, muro, caballos, cohetes, etc.
##
## Todo se dibuja mirando a la DERECHA con el origen en el centro de la caja
## de impacto; draw() aplica el volteo según la dirección del efecto.
##   t     segundos desde que se creó el efecto
##   prog  0..1 progreso del retardo (1 = ya activo o sin retardo)
##   a     segundos desde que el efecto se activó
class_name PowerArt
extends RefCounted

const OL := Color("120a14")

static func draw(ci: CanvasItem, style: StringName, t: float, prog: float, a: float,
		dir: int, box: Vector2, col: Color) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1.0))
	match style:
		&"rocket": _rocket(ci, t)
		&"bear": _bear(ci, t)
		&"dragon": _dragon(ci, t, a)
		&"ring": _ring(ci, t, a, box, col, false)
		&"dance": _ring(ci, t, a, box, col, true)
		&"groundwave": _groundwave(ci, t, col)
		&"horses": _horses(ci, t)
		&"horse": _horse(ci, 0.0, 0.0, t, 0.0, Color("f0f0f0"), Color("c0a040"))
		&"jackal": _jackal(ci, prog, a)
		&"legion": _legion(ci, t)
		&"guard": _guard(ci, t)
		&"bell_wave": _bell_wave(ci, t)
		&"monkeys": _monkeys(ci, t)
		&"plane": _plane(ci, t)
		&"bomb": _bomb(ci, t)
		&"caravel": _caravel(ci, t, dir)
		&"sphere": _sphere(ci, t, col)
		&"boom": _boom(ci, t, col)
		&"sandstorm": _sandstorm(ci, t, box)
		&"wall": _wall(ci, prog, a, box)
		&"ice_burst": _ice_burst(ci, prog, a)
		&"gravity": _gravity(ci, t, prog)
		&"timefield": _timefield(ci, t, prog)
		&"lightburst": _lightburst(ci, prog, a)
		&"smoke": _smoke(ci, t, col)
		&"cannon": _cannon(ci)
		&"bigwave": _bigwave(ci, t)
		&"slash": _slash(ci, a)
		_: ci.draw_circle(Vector2.ZERO, 4.0, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# --- Utilidades -----------------------------------------------------------
static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

static func _rect(ci: CanvasItem, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), OL)
	ci.draw_rect(Rect2(x, y, w, h), c)

static func _poly(ci: CanvasItem, pts: Array, c: Color, outline: bool = true) -> void:
	var v := PackedVector2Array(pts)
	if outline:
		var center := Vector2.ZERO
		for p in v:
			center += p
		center /= v.size()
		var big := PackedVector2Array()
		for p in v:
			big.append(p + (p - center).normalized() * 1.5)
		ci.draw_colored_polygon(big, OL)
	ci.draw_colored_polygon(v, c)

static func _note(ci: CanvasItem, p: Vector2, c: Color) -> void:
	ci.draw_circle(p, 2.5, OL)
	ci.draw_circle(p, 1.8, c)
	ci.draw_rect(Rect2(p.x + 1.5, p.y - 8, 2, 8), OL)
	ci.draw_rect(Rect2(p.x + 2, p.y - 8, 1, 8), c)

# --- Entidades ------------------------------------------------------------
static func _rocket(ci: CanvasItem, t: float) -> void:
	_rect(ci, -7, -2, 12, 4, Color("c8ccd8"))
	ci.draw_rect(Rect2(5, -2, 3, 4), Color("e03030"))
	ci.draw_rect(Rect2(-8, -4, 3, 2), Color("e03030"))
	ci.draw_rect(Rect2(-8, 2, 3, 2), Color("e03030"))
	var fl := 4.0 + (3.0 if int(t * 30.0) % 2 == 0 else 0.0)
	ci.draw_rect(Rect2(-8 - fl, -1, fl, 3), Color("ffb030"))
	ci.draw_rect(Rect2(-8 - fl * 0.5, 0, fl * 0.5, 1), Color("fff0a0"))

static func _bear(ci: CanvasItem, t: float) -> void:
	var brown := Color("7a4a28")
	var run := sin(t * 18.0)
	for i in 4:
		var x := -13.0 + i * 8.0
		var sw := run * (3.0 if i % 2 == 0 else -3.0)
		_rect(ci, x + sw, 5, 5, 8, brown.darkened(0.2))
		ci.draw_rect(Rect2(x + sw + 3, 12, 2, 1), Color.WHITE)
	_rect(ci, -16, -10, 26, 16, brown)
	_rect(ci, 8, -14, 13, 12, brown)
	_rect(ci, 19, -9, 6, 5, Color("c89a60"))
	ci.draw_rect(Rect2(23, -9, 2, 2), OL)
	_rect(ci, 9, -17, 4, 4, brown)
	_rect(ci, 15, -17, 4, 4, brown)
	ci.draw_rect(Rect2(15, -11, 3, 3), Color.WHITE)
	ci.draw_rect(Rect2(16, -10, 2, 2), Color("c02020"))
	ci.draw_rect(Rect2(19, -4, 5, 2), Color("c03030"))
	ci.draw_rect(Rect2(20, -4, 1, 1), Color.WHITE)

static func _dragon(ci: CanvasItem, t: float, a: float) -> void:
	var red := Color("c82820")
	var gold := Color("e0b030")
	var n := 10
	for i in n:
		var k := float(i) / (n - 1)
		ci.draw_circle(Vector2(-30.0 + i * 6.4, sin(t * 8.0 + i * 0.7) * 5.0), 4.5 + k * 3.0, OL)
	for i in n:
		var k := float(i) / (n - 1)
		var p := Vector2(-30.0 + i * 6.4, sin(t * 8.0 + i * 0.7) * 5.0)
		ci.draw_circle(p, 3.5 + k * 3.0, red)
		ci.draw_circle(p + Vector2(0, 2.5), 1.8 + k, gold)
		if i % 3 == 0:
			_poly(ci, [p + Vector2(-2, -3), p + Vector2(0, -8), p + Vector2(2, -3)], gold, false)
	var hy := sin(t * 8.0 + 9 * 0.7) * 5.0
	_rect(ci, 28, hy - 5, 12, 9, red)
	_rect(ci, 38, hy - 2, 7, 5, red)
	_poly(ci, [Vector2(29, hy - 5), Vector2(25, hy - 13), Vector2(34, hy - 5)], gold)
	ci.draw_rect(Rect2(34, hy - 4, 3, 3), Color.WHITE)
	ci.draw_rect(Rect2(36, hy - 3, 1, 2), OL)
	ci.draw_line(Vector2(44, hy), Vector2(52, hy - 5 + sin(t * 10.0) * 2.0), gold, 1.0)
	ci.draw_line(Vector2(44, hy + 2), Vector2(52, hy + 6 + sin(t * 10.0) * 2.0), gold, 1.0)
	if a > 0.0:
		var fl := 16.0 + sin(t * 30.0) * 3.0
		_poly(ci, [Vector2(45, hy - 2), Vector2(45 + fl, hy - 9), Vector2(45 + fl * 0.8, hy),
			Vector2(45 + fl, hy + 9), Vector2(45, hy + 3)], Color("ff7020"), false)
		_poly(ci, [Vector2(45, hy - 1), Vector2(45 + fl * 0.6, hy - 4), Vector2(45 + fl * 0.5, hy + 4),
			Vector2(45, hy + 2)], Color("ffe060"), false)

static func _ring(ci: CanvasItem, t: float, a: float, box: Vector2, col: Color, notes: bool) -> void:
	var maxr := box.x * 0.5
	var r := minf(4.0 + a * 260.0, maxr)
	var fade := clampf(1.0 - a * 1.4, 0.2, 1.0)
	var c := Color(col.r, col.g, col.b, fade)
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, OL, 5.0)
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, c, 3.0)
	ci.draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 28, Color(1, 1, 1, 0.6 * fade), 1.0)
	if notes:
		for i in 4:
			var ang := i * TAU / 4.0 + t * 3.0
			_note(ci, Vector2(cos(ang) * r, sin(ang) * r * 0.7), c)

static func _groundwave(ci: CanvasItem, t: float, col: Color) -> void:
	for i in 3:
		var x := -i * 6.0
		ci.draw_arc(Vector2(x - 10, 6), 14.0, -1.3, 0.15, 8, OL, 5.0 - i)
		ci.draw_arc(Vector2(x - 10, 6), 14.0, -1.3, 0.15, 8, col if i == 0 else col.darkened(0.2 * i), 3.0 - i * 0.6)
	for i in 3:
		ci.draw_circle(Vector2(-16 - i * 6, 4 + (i % 2) * 2 + sin(t * 20 + i)), 2.0 + i, Color(0.7, 0.65, 0.55, 0.6 - i * 0.15))

static func _horse(ci: CanvasItem, ox: float, oy: float, t: float, ph: float, body: Color, mane: Color) -> void:
	var g := sin(t * 16.0 + ph)
	for i in 4:
		var lx := ox - 9.0 + i * 6.0
		var sw := g * (4.0 if i % 2 == 0 else -4.0)
		ci.draw_line(Vector2(lx, oy + 3), Vector2(lx + sw, oy + 14), OL, 4.0)
		ci.draw_line(Vector2(lx, oy + 3), Vector2(lx + sw, oy + 14), body.darkened(0.25), 2.0)
	_rect(ci, ox - 11, oy - 5, 22, 9, body)
	_rect(ci, ox + 8, oy - 13, 6, 11, body)
	_rect(ci, ox + 11, oy - 15, 9, 6, body)
	ci.draw_rect(Rect2(ox + 17, oy - 13, 3, 3), body.lightened(0.2))
	ci.draw_rect(Rect2(ox + 12, oy - 18, 2, 3), body)
	ci.draw_rect(Rect2(ox + 7, oy - 14, 3, 9), mane)
	ci.draw_rect(Rect2(ox - 16, oy - 4, 6, 3), mane)
	ci.draw_rect(Rect2(ox + 14, oy - 13, 1, 1), OL)

static func _horses(ci: CanvasItem, t: float) -> void:
	_horse(ci, -20, 2, t, 0.0, Color("6a4020"), Color("141010"))
	_horse(ci, 2, -2, t, 1.7, Color("8a5a30"), Color("2a1a10"))
	_horse(ci, 22, 2, t, 3.1, Color("a07040"), Color("3a2a1a"))

static func _jackal(ci: CanvasItem, prog: float, a: float) -> void:
	var oy := 16.0 + (1.0 - _ease(prog)) * 46.0
	var dark := Color("1e2840")
	var gold := Color("e0b030")
	_poly(ci, [Vector2(-14, oy - 20), Vector2(-9, oy - 48), Vector2(-2, oy - 20)], dark)
	_poly(ci, [Vector2(0, oy - 20), Vector2(6, oy - 46), Vector2(12, oy - 20)], dark)
	_poly(ci, [Vector2(-11, oy - 22), Vector2(-9, oy - 40), Vector2(-5, oy - 22)], gold, false)
	_poly(ci, [Vector2(3, oy - 22), Vector2(6, oy - 38), Vector2(9, oy - 22)], gold, false)
	_rect(ci, -16, oy - 22, 26, 28, dark)
	_rect(ci, 6, oy - 8, 24, 12, Color("2c3a5a"))
	ci.draw_rect(Rect2(28, oy - 8, 4, 4), OL)
	var open := absf(sin(a * 14.0)) * 7.0 if a > 0.0 else 0.0
	_rect(ci, 6, oy + 4 + open, 22, 6, Color("2c3a5a"))
	for i in 4:
		ci.draw_rect(Rect2(10 + i * 5, oy + 4, 2, 3 + open * 0.3), Color.WHITE)
	ci.draw_rect(Rect2(0, oy - 15, 8, 5), Color("ffe040"))
	ci.draw_rect(Rect2(4, oy - 14, 2, 3), Color("a01020"))
	_rect(ci, -18, oy + 6, 32, 6, gold)
	ci.draw_rect(Rect2(-2, oy + 7, 4, 4), Color("c02040"))

static func _soldier(ci: CanvasItem, ox: float, t: float, ph: float) -> void:
	var g := sin(t * 12.0 + ph)
	ci.draw_line(Vector2(ox - 2, 6), Vector2(ox - 2 + g * 3, 15), OL, 4.0)
	ci.draw_line(Vector2(ox + 2, 6), Vector2(ox + 2 - g * 3, 15), OL, 4.0)
	ci.draw_line(Vector2(ox - 2, 6), Vector2(ox - 2 + g * 3, 15), Color("d8b088"), 2.0)
	ci.draw_line(Vector2(ox + 2, 6), Vector2(ox + 2 - g * 3, 15), Color("d8b088"), 2.0)
	ci.draw_line(Vector2(ox - 7, 3), Vector2(ox + 15, -13), OL, 3.0)
	ci.draw_line(Vector2(ox - 7, 3), Vector2(ox + 15, -13), Color("c0c0c8"), 1.0)
	_rect(ci, ox - 5, -8, 10, 15, Color("a02020"))
	ci.draw_rect(Rect2(ox - 5, 2, 10, 2), Color("e0b030"))
	_rect(ci, ox - 3, -15, 6, 6, Color("e8c098"))
	_rect(ci, ox - 4, -18, 8, 5, Color("e0b030"))
	ci.draw_rect(Rect2(ox - 3, -22, 6, 4), Color("c02020"))
	_rect(ci, ox + 3, -9, 6, 14, Color("a02020"))
	ci.draw_rect(Rect2(ox + 5, -4, 2, 4), Color("e0b030"))

static func _legion(ci: CanvasItem, t: float) -> void:
	for i in 4:
		_soldier(ci, -21.0 + i * 14.0, t, i * 0.9)

static func _guard(ci: CanvasItem, t: float) -> void:
	ci.draw_rect(Rect2(-5, 6, 4, 9), OL)
	ci.draw_rect(Rect2(1, 6, 4, 9), OL)
	ci.draw_rect(Rect2(-4, 7, 2, 7), Color("2a2a38"))
	ci.draw_rect(Rect2(2, 7, 2, 7), Color("2a2a38"))
	ci.draw_line(Vector2(0, 0), Vector2(13, -9), OL, 3.0)
	ci.draw_line(Vector2(0, 0), Vector2(13, -9), Color("6a4a2a"), 1.0)
	_rect(ci, -5, -8, 10, 15, Color("c02020"))
	ci.draw_rect(Rect2(-5, 2, 10, 2), Color.WHITE)
	_rect(ci, -3, -14, 6, 6, Color("e8c098"))
	_rect(ci, -4, -27, 8, 13, Color("1a1a1e"))
	ci.draw_rect(Rect2(-4, -16, 8, 1), Color("e0b030"))

static func _bell_wave(ci: CanvasItem, t: float) -> void:
	for i in 3:
		var r := 9.0 + i * 7.0 + sin(t * 20.0 + i) * 1.5
		var c := Color("f0c840") if i % 2 == 0 else Color("fff0b0")
		c.a = 1.0 - i * 0.2
		ci.draw_arc(Vector2(-4, 0), r, -0.85, 0.85, 10, OL, 5.0)
		ci.draw_arc(Vector2(-4, 0), r, -0.85, 0.85, 10, c, 3.0)
	_poly(ci, [Vector2(-9, -7), Vector2(-3, -7), Vector2(-1, 5), Vector2(-11, 5)], Color("e0b030"))
	ci.draw_circle(Vector2(-6, 7), 2.0, Color("a07820"))

static func _monkeys(ci: CanvasItem, t: float) -> void:
	for i in 3:
		var ox := -14.0 + i * 14.0
		var y := 14.0 - absf(sin(t * 9.0 + i * 1.3)) * 14.0
		ci.draw_polyline(PackedVector2Array([Vector2(ox - 4, y - 2), Vector2(ox - 9, y - 6), Vector2(ox - 8, y - 12)]), OL, 3.0)
		ci.draw_polyline(PackedVector2Array([Vector2(ox - 4, y - 2), Vector2(ox - 9, y - 6), Vector2(ox - 8, y - 12)]), Color("7a4a28"), 1.0)
		ci.draw_line(Vector2(ox - 3, y - 8), Vector2(ox - 7, y - 16), Color("7a4a28"), 2.0)
		ci.draw_line(Vector2(ox + 3, y - 8), Vector2(ox + 8, y - 15), Color("7a4a28"), 2.0)
		_rect(ci, ox - 4, y - 8, 8, 9, Color("7a4a28"))
		ci.draw_rect(Rect2(ox - 2, y - 6, 4, 5), Color("d0a060"))
		_rect(ci, ox - 4, y - 15, 8, 7, Color("7a4a28"))
		ci.draw_rect(Rect2(ox - 2, y - 13, 5, 4), Color("e0b880"))
		ci.draw_rect(Rect2(ox, y - 13, 1, 1), OL)
		ci.draw_circle(Vector2(ox - 5, y - 13), 2.0, Color("c89060"))
		ci.draw_rect(Rect2(ox - 3, y + 1, 2, 3), Color("5a3a20"))
		ci.draw_rect(Rect2(ox + 1, y + 1, 2, 3), Color("5a3a20"))

static func _plane(ci: CanvasItem, t: float) -> void:
	var f := sin(t * 10.0)
	var wood := Color("8a5a2a")
	var cloth := Color("e8d8a8")
	_poly(ci, [Vector2(-4, -2), Vector2(12, -2), Vector2(8, -17 + f * 6), Vector2(-12, -14 + f * 6)], cloth)
	_poly(ci, [Vector2(-4, 2), Vector2(12, 2), Vector2(8, 15 - f * 6), Vector2(-12, 13 - f * 6)], cloth.darkened(0.15))
	_rect(ci, -16, -2, 32, 5, wood)
	_poly(ci, [Vector2(-16, -2), Vector2(-24, -8), Vector2(-24, 3)], cloth)
	ci.draw_circle(Vector2(2, -6), 3.0, OL)
	ci.draw_circle(Vector2(2, -6), 2.2, Color("e8c098"))
	ci.draw_rect(Rect2(0, -9, 5, 2), Color("a03030"))
	ci.draw_line(Vector2(16, 0), Vector2(20, 4), wood, 2.0)

static func _bomb(ci: CanvasItem, t: float) -> void:
	ci.draw_circle(Vector2.ZERO, 5.5, OL)
	ci.draw_circle(Vector2.ZERO, 4.5, Color("2a2a32"))
	ci.draw_circle(Vector2(-1.5, -1.5), 1.5, Color("8a8a9a"))
	ci.draw_line(Vector2(0, -5), Vector2(2, -9), Color("a08040"), 1.0)
	if int(t * 20.0) % 2 == 0:
		ci.draw_rect(Rect2(1, -11, 3, 3), Color("ffb030"))

static func _caravel(ci: CanvasItem, t: float, dir: int) -> void:
	var bob := sin(t * 6.0) * 1.5
	ci.draw_set_transform(Vector2(0, bob), 0.0, Vector2(dir, 1.0))
	var wood := Color("7a4a28")
	_poly(ci, [Vector2(-36, 2), Vector2(38, 2), Vector2(30, 17), Vector2(-26, 17)], wood)
	ci.draw_rect(Rect2(-36, 0, 74, 3), Color("a06a38"))
	ci.draw_rect(Rect2(-30, 8, 56, 1), Color("5a3418"))
	_rect(ci, -6, -26, 3, 28, Color("5a3418"))
	_rect(ci, 16, -18, 3, 20, Color("5a3418"))
	_poly(ci, [Vector2(-22, -24), Vector2(10, -24), Vector2(8, -6), Vector2(-20, -6)], Color("f0ece0"))
	ci.draw_rect(Rect2(-9, -22, 4, 14), Color("c02020"))
	ci.draw_rect(Rect2(-14, -17, 14, 4), Color("c02020"))
	_poly(ci, [Vector2(13, -16), Vector2(28, -16), Vector2(26, -4), Vector2(15, -4)], Color("f0ece0"))
	ci.draw_rect(Rect2(19, -15, 3, 9), Color("c02020"))
	ci.draw_rect(Rect2(-6, -31, 8, 5), Color("c02020"))
	for i in 5:
		ci.draw_circle(Vector2(-32 + i * 16 + sin(t * 8.0 + i) * 2.0, 18), 3.0, Color(0.5, 0.7, 1.0, 0.7))

static func _sphere(ci: CanvasItem, t: float, col: Color) -> void:
	var pulse := 1.0 + sin(t * 18.0) * 0.15
	for i in 8:
		var ang := i * TAU / 8.0 + t * 5.0
		var d := Vector2(cos(ang), sin(ang))
		ci.draw_line(d * 9.0 * pulse, d * 16.0 * pulse, col, 2.0)
	ci.draw_circle(Vector2.ZERO, 9.0 * pulse, OL)
	ci.draw_circle(Vector2.ZERO, 8.0 * pulse, col)
	ci.draw_circle(Vector2.ZERO, 4.0 * pulse, Color.WHITE)

static func _boom(ci: CanvasItem, t: float, col: Color) -> void:
	var k := clampf(t / 0.35, 0.0, 1.0)
	var r := 6.0 + k * 24.0
	ci.draw_circle(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.8 * (1.0 - k)))
	ci.draw_circle(Vector2.ZERO, r * 0.6, Color(1, 1, 0.8, 0.9 * (1.0 - k)))
	for i in 8:
		var d := Vector2(cos(i * TAU / 8.0), sin(i * TAU / 8.0))
		ci.draw_line(d * r, d * (r + 8.0), col, 2.0)

static func _sandstorm(ci: CanvasItem, t: float, box: Vector2) -> void:
	var shades := [Color("d8b878"), Color("c0a060"), Color("e8d098"), Color("a88848")]
	for i in 40:
		var ang := i * 2.399 + t * 6.0 * (1.0 + (i % 3) * 0.3)
		var rr := float((i * 37) % 100) / 100.0 * box.x * 0.5
		var p := Vector2(cos(ang) * rr, sin(ang * 0.8 + i) * box.y * 0.45)
		var s := 2.0 + float(i % 3)
		ci.draw_rect(Rect2(p.x, p.y, s, s), shades[i % 4])
	ci.draw_arc(Vector2.ZERO, box.x * 0.4, t * 4.0, t * 4.0 + 2.2, 12, Color(0.85, 0.7, 0.4, 0.7), 3.0)
	ci.draw_arc(Vector2.ZERO, box.x * 0.25, -t * 5.0, -t * 5.0 + 2.2, 10, Color(0.9, 0.8, 0.55, 0.7), 2.0)

static func _wall(ci: CanvasItem, prog: float, a: float, box: Vector2) -> void:
	var h := box.y * _ease(prog)
	var w := box.x
	var bottom := box.y * 0.5
	if h > 1.0:
		var r := Rect2(-w * 0.5, bottom - h, w, h)
		ci.draw_rect(r.grow(1), OL)
		ci.draw_rect(r, Color("b0a090"))
		var y := bottom - 7.0
		var row := 0
		while y > bottom - h:
			ci.draw_line(Vector2(-w * 0.5, y), Vector2(w * 0.5, y), Color("6a5a4a"), 1.0)
			var x := -w * 0.5 + (row % 2) * 6.0
			while x < w * 0.5:
				ci.draw_line(Vector2(x, y), Vector2(x, y + 7.0), Color("6a5a4a"), 1.0)
				x += 12.0
			y -= 7.0
			row += 1
		ci.draw_rect(Rect2(-w * 0.5, bottom - h, w, 2), Color("d8c8b0"))
		if prog >= 1.0:
			for i in 3:
				ci.draw_rect(Rect2(-w * 0.5 + i * (w / 2.5), bottom - h - 4, w / 5.0, 4), Color("b0a090"))
	if prog < 1.0 or a < 0.15:
		for i in 4:
			ci.draw_circle(Vector2(-w * 0.5 - 2 + i * (w / 3.0), bottom - 1), 3.0 + i % 2, Color(0.75, 0.7, 0.6, 0.5))

static func _ice_burst(ci: CanvasItem, prog: float, a: float) -> void:
	var grow := _ease(prog)
	for i in 5:
		var x := -18.0 + i * 9.0
		var h := (22.0 + (i % 3) * 9.0) * grow
		_poly(ci, [Vector2(x - 4, 26), Vector2(x + 4, 26), Vector2(x + (i % 2) * 2.0 - 1.0, 26.0 - h)], Color("bfe8ff"))
		_poly(ci, [Vector2(x - 1, 26), Vector2(x + 2, 26), Vector2(x, 26.0 - h * 0.8)], Color.WHITE, false)
	if a > 0.0:
		for i in 6:
			var p := Vector2(cos(i * 1.7) * a * 70.0, -absf(sin(i * 2.1)) * a * 70.0 + a * a * 120.0 + 14.0)
			ci.draw_rect(Rect2(p.x - 2, p.y - 2, 4, 4), OL)
			ci.draw_rect(Rect2(p.x - 1, p.y - 1, 3, 3), Color("a8a8b8") if i % 2 == 0 else Color("e0f4ff"))

static func _gravity(ci: CanvasItem, t: float, prog: float) -> void:
	var k := _ease(prog)
	for i in 3:
		var r := (10.0 + i * 8.0) * k
		var c := Color(0.7, 0.4, 1.0, 0.8 - i * 0.2)
		ci.draw_arc(Vector2.ZERO, r, t * 3.0 * (1 + i), t * 3.0 * (1 + i) + 4.2, 16, c, 2.0)
	for i in 4:
		var x := -15.0 + i * 10.0
		var y := 22.0 - fmod(t * 60.0 + i * 15.0, 50.0)
		_poly(ci, [Vector2(x - 3, y + 3), Vector2(x + 3, y + 3), Vector2(x, y - 3)], Color("b070ff"), false)

static func _timefield(ci: CanvasItem, t: float, prog: float) -> void:
	var r := 28.0 * _ease(prog)
	ci.draw_circle(Vector2.ZERO, r, Color(0.3, 0.6, 1.0, 0.25))
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, OL, 4.0)
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color("60d0ff"), 2.0)
	if r > 10.0:
		for i in 12:
			var d := Vector2(cos(i * TAU / 12.0), sin(i * TAU / 12.0))
			ci.draw_line(d * r * 0.85, d * r, Color.WHITE, 1.0)
		ci.draw_line(Vector2.ZERO, Vector2(cos(t * 9.0), sin(t * 9.0)) * r * 0.8, Color.WHITE, 1.0)
		ci.draw_line(Vector2.ZERO, Vector2(cos(t * 1.5), sin(t * 1.5)) * r * 0.5, Color("ffe060"), 2.0)

static func _lightburst(ci: CanvasItem, prog: float, a: float) -> void:
	var k := clampf(a / 0.3, 0.0, 1.0)
	var r := 8.0 + _ease(prog) * 8.0 + k * 28.0
	var fade := 1.0 - k * 0.7
	ci.draw_circle(Vector2.ZERO, r, Color(1.0, 0.9, 0.5, 0.45 * fade))
	ci.draw_circle(Vector2.ZERO, r * 0.55, Color(1, 1, 0.9, 0.9 * fade))
	for i in 12:
		var d := Vector2(cos(i * TAU / 12.0), sin(i * TAU / 12.0))
		ci.draw_line(d * r * 0.7, d * r * 1.5, Color(1.0, 0.85, 0.3, fade), 2.0)

static func _smoke(ci: CanvasItem, t: float, col: Color) -> void:
	for i in 7:
		var p := Vector2(cos(i * 1.9) * (t * 36.0 + 4.0), -sin(i * 2.7) * t * 28.0 - 10.0)
		var c := Color(col.r, col.g, col.b, clampf(1.0 - t * 1.8, 0.0, 0.9))
		ci.draw_circle(p, 5.0 + t * 12.0, c)

static func _cannon(ci: CanvasItem) -> void:
	_rect(ci, -10, 0, 18, 5, Color("6a4a2a"))
	_rect(ci, -6, -6, 24, 9, Color("3a3a44"))
	ci.draw_rect(Rect2(-2, -6, 2, 9), Color("8a8a9a"))
	ci.draw_rect(Rect2(8, -6, 2, 9), Color("8a8a9a"))
	_rect(ci, 16, -7, 4, 11, Color("2a2a32"))
	ci.draw_circle(Vector2(-2, 5), 7.0, OL)
	ci.draw_circle(Vector2(-2, 5), 6.0, Color("8a5a30"))
	ci.draw_circle(Vector2(-2, 5), 2.0, OL)
	ci.draw_line(Vector2(-8, 5), Vector2(4, 5), OL, 1.0)
	ci.draw_line(Vector2(-2, -1), Vector2(-2, 11), OL, 1.0)

static func _bigwave(ci: CanvasItem, t: float) -> void:
	for i in 4:
		var r := 8.0 + i * 8.0 + sin(t * 25.0 + i) * 1.5
		var c := Color("fff0a0") if i % 2 == 0 else Color.WHITE
		c.a = 1.0 - i * 0.2
		ci.draw_arc(Vector2(-10, 0), r, -0.85, 0.85, 10, OL, 6.0)
		ci.draw_arc(Vector2(-10, 0), r, -0.85, 0.85, 10, c, 4.0)
	ci.draw_rect(Rect2(-14, -4, 8, 8), Color("ffe060"))

static func _slash(ci: CanvasItem, a: float) -> void:
	var k := clampf(a / 0.15, 0.0, 1.0)
	var c := Color(1.0, 1.0, 1.0, 1.0 - k * 0.6)
	for i in 3:
		ci.draw_arc(Vector2(-6, 0), 14.0 + i * 7.0, -1.0 + i * 0.1, 1.0 - i * 0.1, 10, OL, 5.0)
		ci.draw_arc(Vector2(-6, 0), 14.0 + i * 7.0, -1.0 + i * 0.1, 1.0 - i * 0.1, 10, c if i != 1 else Color(0.8, 0.6, 1.0, c.a), 3.0)
