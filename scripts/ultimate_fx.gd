## Efectos de pantalla de un ultimate: el ambiente se nubla y oscurece (o se
## sobreexpone con luz), el suelo se agrieta con fisuras brillantes, caen rayos,
## escombros, brasas y chispas, y las ondas de choque recorren el suelo.
##
## Es solo decorado: no lee ni escribe estado de combate (usa su propio reloj y su
## propio azar), así que no afecta al determinismo. Se crea al empezar la cinemática
## del ultimate (para que el cielo ya se oscurezca durante el zoom) y PowerEffects le
## va programando grietas, rayos y sacudidas con `at()` cuando el ultimate se lanza.
##
## Se dibuja en dos capas: una DEBAJO de los luchadores (oscurecimiento, haces de luz,
## grietas y ondas, para que ellos sigan viéndose) y otra ENCIMA (partículas, destellos
## de rayos, cortes y viñeta).
class_name UltimateFX
extends Node2D

const W := 426.0
const H := 240.0
const MAX_PARTS := 220
## Partículas por segundo según el tipo de ultimate.
const RATES := {&"storm": 150.0, &"barrage": 60.0, &"meteor": 70.0, &"quake": 55.0, &"charge": 40.0,
	&"light": 45.0, &"wave": 40.0, &"summon": 40.0, &"slash": 60.0, &"trap": 45.0, &"snipe": 30.0}

var kind: StringName = &""
var color: Color = Color.WHITE
var tint: Color = Color(0.1, 0.05, 0.1)
var floor_y: float = 200.0
var duration: float = 5.6
var age: float = 0.0

var _cm: CombatManager
var _under: Node2D
var _cracks: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _cuts: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _parts: Array[Dictionary] = []
var _flash: float = 0.0
var _acc: float = 0.0
var _rng := RandomNumberGenerator.new()

func setup(cm: CombatManager, atk: AttackData) -> void:
	_cm = cm
	kind = atk.ult_kind
	color = atk.ult_color
	tint = atk.ult_tint
	floor_y = cm.stage.floor_y
	_rng.seed = hash(String(atk.id) + String(atk.display_name))
	z_index = 19

func _ready() -> void:
	_under = Node2D.new()
	_under.z_index = 4
	_under.z_as_relative = false
	add_child(_under)
	_under.draw.connect(_draw_under)

## Programa un evento dentro de `delay` frames de combate (ticks). Se dispara cuando el combate
## llega a ese tick, así va a la par de los golpes aunque haya congelados o esperas.
## Tipos: crack {x, len} · shake {amount} · stones {x} · dust {x} · flash {amount} ·
## bolt {} (destello de rayo) · ring {x} (onda en el suelo) · cut {} (corte en pantalla) ·
## debris {x} (lluvia de escombros).
func at(delay: int, type: StringName, args: Dictionary = {}) -> void:
	var e := args.duplicate()
	e["tick"] = _cm.tick_count + delay
	e["type"] = type
	_events.append(e)

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	_spawn_ambient(delta)
	_update_parts(delta)
	_flash = maxf(_flash - delta * 3.5, 0.0)
	_under.queue_redraw()
	queue_redraw()

## Los eventos siguen el reloj del combate (ticks), no el de pantalla.
func _physics_process(_delta: float) -> void:
	_run_events()

func _run_events() -> void:
	var i := _events.size() - 1
	while i >= 0:
		var e := _events[i]
		if _cm.tick_count >= int(e["tick"]):
			_events.remove_at(i)
			_fire(e)
		i -= 1

func _fire(e: Dictionary) -> void:
	var x: float = e.get("x", 213.0)
	match e["type"]:
		&"crack":
			_add_crack(x, float(e.get("len", 100.0)))
			_cm.shake(float(e.get("shake", 2.0)))
			_cm.fx.stones(Vector2(x, floor_y))
		&"shake":
			_cm.shake(float(e.get("amount", 3.0)))
		&"stones":
			_cm.fx.stones(Vector2(x, floor_y))
		&"dust":
			_cm.fx.dust_wave(Vector2(x, floor_y))
		&"flash":
			_cm.fx.flash(float(e.get("amount", 0.4)))
		&"bolt":
			_flash = 1.0
			_cm.shake(3.5)
			Sfx.play(&"hit_heavy")
		&"ring":
			_rings.append({"x": x, "t0": age})
			_cm.shake(3.0)
		&"cut":
			var a := Vector2(_rng.randf_range(-20.0, W * 0.5), _rng.randf_range(10.0, H * 0.5))
			_cuts.append({"a": a, "b": Vector2(W - a.x + 20.0, H - a.y), "t0": age})
			_flash = maxf(_flash, 0.5)
			_cm.shake(2.0)
		&"debris":
			for k in 14:
				_add_part(Vector2(x + _rng.randf_range(-40.0, 40.0), floor_y - 4.0),
					Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-190.0, -70.0)),
					_rng.randf_range(0.5, 1.0), Color("8a7a6a").lerp(color, 0.2), 2.0, 0, 520.0)

# --- Grietas -------------------------------------------------------------------
## Fisura en el suelo que se abre a los dos lados de `x` y echa ramas hacia abajo.
func _add_crack(x: float, length: float) -> void:
	var lines: Array[PackedVector2Array] = []
	for dir in [-1, 1]:
		var pts := PackedVector2Array([Vector2(x, floor_y + 3.0)])
		var cx := x
		var steps := int(length / 8.0)
		for s in steps:
			cx += dir * _rng.randf_range(5.0, 10.0)
			pts.append(Vector2(cx, clampf(floor_y + 3.0 + _rng.randf_range(-4.0, 7.0), floor_y - 1.0, floor_y + 22.0)))
		lines.append(pts)
		# Ramas hacia abajo.
		for b in 2:
			var at_i := _rng.randi_range(1, maxi(pts.size() - 1, 1))
			var bp := PackedVector2Array([pts[at_i]])
			var by: float = pts[at_i].y
			var bx: float = pts[at_i].x
			for s in 3:
				bx += dir * _rng.randf_range(2.0, 6.0)
				by += _rng.randf_range(4.0, 8.0)
				bp.append(Vector2(bx, minf(by, H - 2.0)))
			lines.append(bp)
	_cracks.append({"lines": lines, "t0": age})

# --- Partículas ------------------------------------------------------------------
func _add_part(p: Vector2, v: Vector2, life: float, c: Color, size: float, shape: int, g: float = 0.0) -> void:
	if _parts.size() >= MAX_PARTS:
		return
	_parts.append({"p": p, "v": v, "life": life, "max": life, "c": c, "s": size, "shape": shape, "g": g})

func _spawn_ambient(delta: float) -> void:
	if age < 0.45 or age > duration - 0.8:
		return
	_acc += float(RATES.get(kind, 40.0)) * delta
	while _acc >= 1.0:
		_acc -= 1.0
		var rx := _rng.randf_range(-10.0, W + 10.0)
		match kind:
			&"storm":
				_add_part(Vector2(rx, -6.0), Vector2(-50.0, _rng.randf_range(460.0, 560.0)), 0.55,
					Color(0.75, 0.85, 1.0, 0.7), 1.0, 1)
			&"barrage", &"meteor":
				_add_part(Vector2(rx, floor_y + _rng.randf_range(0.0, 34.0)), Vector2(_rng.randf_range(-18.0, 18.0), _rng.randf_range(-100.0, -40.0)),
					_rng.randf_range(0.9, 1.5), Color("ffb040") if _rng.randf() < 0.6 else Color("ff5030"), 1.5, 0)
			&"quake":
				_add_part(Vector2(rx, -4.0), Vector2(0.0, _rng.randf_range(40.0, 120.0)), 1.4,
					Color("7a6a5a"), 2.0, 0, 260.0)
			&"light":
				_add_part(Vector2(rx, floor_y + _rng.randf_range(0.0, 34.0)), Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-70.0, -30.0)),
					_rng.randf_range(1.2, 2.0), Color("fff0b0"), 2.0, 2)
			&"slash":
				_add_part(Vector2(rx, _rng.randf_range(20.0, floor_y)), Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-90.0, 90.0)),
					0.5, color if _rng.randf() < 0.5 else Color.WHITE, 1.5, 1)
			&"wave":
				_add_part(Vector2(rx, floor_y + _rng.randf_range(0.0, 30.0)), Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-80.0, -30.0)),
					0.9, color, 1.5, 2)
			_:
				_add_part(Vector2(rx, floor_y + _rng.randf_range(-4.0, 10.0)), Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-30.0, -8.0)),
					0.9, Color("cdbb9a"), 2.5, 2)

func _update_parts(delta: float) -> void:
	var i := _parts.size() - 1
	while i >= 0:
		var q := _parts[i]
		q["life"] = float(q["life"]) - delta
		if float(q["life"]) <= 0.0:
			_parts.remove_at(i)
		else:
			q["v"] = Vector2(q["v"]) + Vector2(0.0, float(q["g"]) * delta)
			q["p"] = Vector2(q["p"]) + Vector2(q["v"]) * delta
		i -= 1

# --- Dibujo ------------------------------------------------------------------------
## Intensidad del ambiente: sube al empezar y baja al final.
func _env() -> float:
	return minf(age / 0.5, 1.0) * clampf((duration - age) / 0.9, 0.0, 1.0)

## Capa de ABAJO: oscurecimiento, haces de luz, grietas y ondas.
func _draw_under() -> void:
	var a := _env()
	var n := _under
	if kind == &"light":
		n.draw_rect(Rect2(-40, -40, W + 80, H + 80), Color(1.0, 0.95, 0.75, 0.42 * a))
		for i in 5:
			var bx := 213.0 + (i - 2) * 70.0 + sin(age * 1.5 + i) * 6.0
			n.draw_rect(Rect2(bx - 9.0, 0.0, 18.0, floor_y), Color(1.0, 0.97, 0.8, 0.2 * a))
			n.draw_rect(Rect2(bx - 3.0, 0.0, 6.0, floor_y), Color(1.0, 1.0, 0.95, 0.22 * a))
	else:
		n.draw_rect(Rect2(-40, -40, W + 80, H + 80), Color(tint.r, tint.g, tint.b, 0.68 * a))
	for c in _cracks:
		_draw_crack(n, c, a)
	for r in _rings:
		var t := age - float(r["t0"])
		if t > 1.0:
			continue
		var rad := t * 260.0
		var ra := (1.0 - t) * 0.8 * a
		var pts := PackedVector2Array()
		for k in 25:
			var ang := TAU * k / 24.0
			pts.append(Vector2(float(r["x"]) + cos(ang) * rad, floor_y + 6.0 + sin(ang) * rad * 0.12))
		n.draw_polyline(pts, Color(0, 0, 0, ra * 0.8), 5.0)
		n.draw_polyline(pts, Color(color.r, color.g, color.b, ra), 2.0)

func _draw_crack(n: Node2D, c: Dictionary, a: float) -> void:
	var t := age - float(c["t0"])
	var grow := clampf(t / 0.35, 0.0, 1.0)
	# La fisura se mantiene y se apaga con el ambiente.
	var life := clampf(a * 2.0, 0.0, 1.0)
	for pts: PackedVector2Array in c["lines"]:
		var count := mini(maxi(int(float(pts.size()) * grow), 2), pts.size())
		var part: PackedVector2Array = pts.slice(0, count)
		if part.size() < 2:
			continue
		n.draw_polyline(part, Color(color.r, color.g, color.b, 0.35 * life), 8.0)
		n.draw_polyline(part, Color(0.03, 0.01, 0.02, 0.95 * life), 4.0)
		n.draw_polyline(part, Color(color.r, color.g, color.b, 0.9 * life), 1.0)

## Capa de ARRIBA: partículas, destellos, cortes y viñeta.
func _draw() -> void:
	var a := _env()
	for q in _parts:
		var al: float = clampf(float(q["life"]) / float(q["max"]) * 2.0, 0.0, 1.0)
		var c: Color = q["c"]
		c.a *= al
		var p: Vector2 = q["p"]
		match int(q["shape"]):
			1:
				draw_line(p, p - Vector2(q["v"]) * 0.025, c, float(q["s"]))
			2:
				draw_circle(p, float(q["s"]), c)
			_:
				draw_rect(Rect2(p.round(), Vector2(q["s"], q["s"])), c)
	for cut in _cuts:
		var t := age - float(cut["t0"])
		if t > 0.3:
			continue
		var k := 1.0 - t / 0.3
		draw_line(cut["a"], cut["b"], Color(0, 0, 0, 0.6 * k), 7.0)
		draw_line(cut["a"], cut["b"], Color(1, 1, 1, k), 3.0)
		draw_line(cut["a"], cut["b"], Color(color.r, color.g, color.b, k), 1.0)
	if _flash > 0.0:
		draw_rect(Rect2(-40, -40, W + 80, H + 80), Color(1, 1, 1, _flash * 0.45))
	# Viñeta: bordes oscuros que se cierran sobre la escena.
	if kind != &"light":
		for i in 6:
			var m := float(i) * 7.0
			draw_rect(Rect2(-40, -40, W + 80, 40 + m), Color(0, 0, 0, 0.07 * a))
			draw_rect(Rect2(-40, H - m, W + 80, 40 + m), Color(0, 0, 0, 0.07 * a))
			draw_rect(Rect2(-40, -40, 40 + m, H + 80), Color(0, 0, 0, 0.05 * a))
			draw_rect(Rect2(W - m, -40, 40 + m, H + 80), Color(0, 0, 0, 0.05 * a))
