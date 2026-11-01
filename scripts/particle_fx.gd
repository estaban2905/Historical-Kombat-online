## Partículas de pixel art: polvo, chispas, estelas, piedras, sangre (o su
## versión suave) y destello de pantalla.
## Es solo decorado: nunca lee ni escribe estado de combate, así que no afecta
## al determinismo. Una sola instancia dibuja todo (máximo MAX_PARTICLES a la vez).
## La sangre depende de Game.gore (SUAVE / ROJA / NO).
class_name ParticleFX
extends Node2D

enum Shape { SQUARE, PUFF, STAR, DROP, LINE }
## Qué hace una partícula al llegar al suelo.
enum Floor { NONE, BOUNCE, DIE }

const MAX_PARTICLES := 30
const MAX_STAINS := 3
const STAIN_LIFE := 8.0
const DUST := Color("cdbb9a")
const SPARK_COLORS: Array[Color] = [Color("fff6c0"), Color("ffd040"), Color("ff9030")]
const BLOOD_COLORS: Array[Color] = [Color("b01020"), Color("7a0a14"), Color("d02030")]
const STONE_COLORS: Array[Color] = [Color("8a7a6a"), Color("5a4e48"), Color("a89888")]

## Altura del suelo (coordenada Y de los pies).
var floor_y: float = 200.0
## Si es true, crea una capa propia para el destello de pantalla (solo en combate).
var use_flash: bool = false

var _particles: Array[Dictionary] = []
var _stains: Array[Dictionary] = []
var _flash_rect: ColorRect
var _flash_alpha: float = 0.0

func _ready() -> void:
	if use_flash:
		var layer := CanvasLayer.new()
		layer.layer = 5
		_flash_rect = ColorRect.new()
		_flash_rect.color = Color(1, 1, 1, 0)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_flash_rect)
		add_child(layer)

## Borra partículas y manchas (cambio de ronda).
func clear() -> void:
	_particles.clear()
	_stains.clear()
	_flash_alpha = 0.0
	if _flash_rect:
		_flash_rect.color.a = 0.0
	queue_redraw()

# =========================================================================
#  Polvo
# =========================================================================
## Nubecita bajo los pies al caminar o correr. `back` = lado contrario al avance.
func dust_step(feet: Vector2, back: int, running: bool = false) -> void:
	var n := 2 if running else 1
	for i in n:
		_add(feet + Vector2(back * randf_range(2.0, 7.0), -1.0), Vector2(back * randf_range(8.0, 26.0), randf_range(-14.0, -6.0)),
			randf_range(0.28, 0.42), DUST, 2.0 if not running else 2.5, Shape.PUFF, 0.0, Floor.NONE, 1.6, 2.0)

## Nube redonda a los lados al aterrizar de un salto.
func dust_land(feet: Vector2) -> void:
	for side in [-1, 1]:
		for i in 2:
			_add(feet + Vector2(side * (3.0 + i * 3.0), -1.0), Vector2(side * randf_range(30.0, 62.0), randf_range(-12.0, -4.0)),
				randf_range(0.34, 0.5), DUST, 3.0, Shape.PUFF, 0.0, Floor.NONE, 1.8, 2.5)

## Onda de polvo pegada al suelo (luchador lanzado que cae, K.O.).
func dust_wave(feet: Vector2) -> void:
	for side in [-1, 1]:
		for i in 3:
			_add(feet + Vector2(side * (2.0 + i * 4.0), -1.0), Vector2(side * randf_range(45.0, 95.0), randf_range(-5.0, -1.0)),
				randf_range(0.4, 0.6), DUST, 3.5, Shape.PUFF, 0.0, Floor.NONE, 2.0, 2.5)

## Rastro de polvo al deslizarse por un empujón. `dir` = sentido del empujón.
func dust_slide(feet: Vector2, dir: int) -> void:
	_add(feet + Vector2(-dir * 3.0, -1.0), Vector2(-dir * randf_range(14.0, 34.0), randf_range(-16.0, -6.0)),
		randf_range(0.3, 0.45), DUST, 2.5, Shape.PUFF, 0.0, Floor.NONE, 1.6, 2.0)
	_add(feet + Vector2(-dir * 2.0, -2.0), Vector2(-dir * randf_range(20.0, 50.0), randf_range(-40.0, -20.0)),
		0.3, DUST.darkened(0.25), 1.0, Shape.SQUARE, 380.0, Floor.DIE)

## Polvo pegado al piso delante del luchador que barre.
func dust_sweep(feet: Vector2, facing: int) -> void:
	_add(feet + Vector2(facing * randf_range(10.0, 24.0), -1.0), Vector2(facing * randf_range(18.0, 44.0), randf_range(-4.0, -1.0)),
		randf_range(0.25, 0.4), DUST, 2.5, Shape.PUFF, 0.0, Floor.NONE, 1.5, 2.0)

# =========================================================================
#  Chispas, estelas, piedras y líneas
# =========================================================================
## Chispas que rebotan al bloquear. `dir` = hacia dónde salen (hacia el atacante).
func sparks(at: Vector2, dir: int) -> void:
	for i in 5:
		_add(at, Vector2(dir * randf_range(30.0, 110.0) + randf_range(-20.0, 20.0), randf_range(-130.0, -50.0)),
			randf_range(0.35, 0.55), SPARK_COLORS[i % SPARK_COLORS.size()], 2.0, Shape.SQUARE, 520.0, Floor.BOUNCE)

## Punto de estela mientras la hitbox está activa (patadas y especiales).
func trail(at: Vector2, color: Color = Color("fff6c0")) -> void:
	_add(at, Vector2.ZERO, 0.18, color, 3.0, Shape.SQUARE, 0.0, Floor.NONE, -0.8)

## Líneas de velocidad detrás de una embestida.
func speed_lines(feet: Vector2, dir: int) -> void:
	for i in 2:
		_add(feet + Vector2(-dir * randf_range(4.0, 14.0), randf_range(-40.0, -6.0)), Vector2(-dir * 40.0, 0.0),
			0.2, Color(1, 1, 1, 0.8), randf_range(8.0, 15.0), Shape.LINE)

## Fragmentos de piedra al golpear el suelo un poder.
func stones(at: Vector2) -> void:
	for i in 7:
		_add(at, Vector2(randf_range(-80.0, 80.0), randf_range(-170.0, -70.0)), randf_range(0.5, 0.8),
			STONE_COLORS[i % STONE_COLORS.size()], randf_range(2.0, 3.0), Shape.SQUARE, 620.0, Floor.BOUNCE)

# =========================================================================
#  Golpes fuertes: sangre (o versión suave) y destello
# =========================================================================
## `dir` = hacia dónde sale despedido el rival. `level` 1 = golpe fuerte, 2 = K.O. o lanzamiento.
func hit_burst(at: Vector2, dir: int, level: int) -> void:
	match Game.gore:
		Game.Gore.RED:
			for i in 4 + 5 * (level - 1):
				_add(at, Vector2(dir * randf_range(20.0, 100.0) + randf_range(-25.0, 25.0), randf_range(-120.0, -20.0)),
					randf_range(0.4, 0.7), BLOOD_COLORS[i % BLOOD_COLORS.size()], 1.0 + float(i % 2), Shape.DROP, 520.0, Floor.DIE)
		Game.Gore.SOFT:
			for i in 2 + 3 * (level - 1):
				_add(at, Vector2(dir * randf_range(15.0, 70.0) + randf_range(-25.0, 25.0), randf_range(-90.0, -25.0)),
					randf_range(0.35, 0.55), Color("ffe060") if i % 2 == 0 else Color("fff6c0"), 2.0, Shape.STAR, 0.0, Floor.NONE, -0.5, 3.0)
			for i in 2 + level:
				_add(at, Vector2(dir * randf_range(10.0, 50.0) + randf_range(-20.0, 20.0), randf_range(-100.0, -40.0)),
					randf_range(0.4, 0.6), Color("bfe6ff"), 1.0, Shape.DROP, 380.0, Floor.DIE)

## Mancha en el suelo tras un K.O. (solo con sangre roja).
func ko_stain(x: float) -> void:
	if Game.gore != Game.Gore.RED:
		return
	if _stains.size() >= MAX_STAINS:
		_stains.pop_front()
	_stains.append({"x": roundf(x), "age": 0.0})

## Destello de pantalla (golpe crítico, inicio de poder). 0..1.
func flash(amount: float) -> void:
	_flash_alpha = maxf(_flash_alpha, clampf(amount, 0.0, 1.0))

# =========================================================================
#  Motor
# =========================================================================
## `grow` > 0 agranda la partícula con el tiempo, < 0 la encoge. `drag` = frenado por segundo.
func _add(pos: Vector2, vel: Vector2, life: float, color: Color, size: float, shape: Shape,
		gravity: float = 0.0, on_floor: Floor = Floor.NONE, grow: float = 0.0, drag: float = 0.0) -> void:
	if _particles.size() >= MAX_PARTICLES:
		_particles.pop_front()
	_particles.append({"pos": pos, "vel": vel, "life": life, "age": 0.0, "col": color, "size": size,
		"shape": shape, "grav": gravity, "floor": on_floor, "grow": grow, "drag": drag})

func _process(delta: float) -> void:
	if _particles.is_empty() and _stains.is_empty() and _flash_alpha <= 0.0:
		return
	var i := _particles.size() - 1
	while i >= 0:
		var q := _particles[i]
		q.age += delta
		if q.age >= q.life:
			_particles.remove_at(i)
		else:
			var vel: Vector2 = q.vel
			vel.y += q.grav * delta
			if q.drag > 0.0:
				vel *= maxf(1.0 - q.drag * delta, 0.0)
			var pos: Vector2 = q.pos + vel * delta
			if q.floor != Floor.NONE and pos.y >= floor_y and vel.y > 0.0:
				if q.floor == Floor.DIE:
					_particles.remove_at(i)
					i -= 1
					continue
				pos.y = floor_y
				vel.y *= -0.45
				vel.x *= 0.7
			q.vel = vel
			q.pos = pos
		i -= 1
	var s := _stains.size() - 1
	while s >= 0:
		_stains[s].age += delta
		if _stains[s].age >= STAIN_LIFE:
			_stains.remove_at(s)
		s -= 1
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(_flash_alpha - delta * 5.0, 0.0)
		if _flash_rect:
			_flash_rect.color.a = _flash_alpha * 0.7
	queue_redraw()

func _draw() -> void:
	for st in _stains:
		var a := clampf((STAIN_LIFE - st.age) / 2.0, 0.0, 1.0)
		var c := Color("6a0a12", a)
		var x: float = st.x
		draw_rect(Rect2(x - 7, floor_y + 1, 14, 2), c)
		draw_rect(Rect2(x - 4, floor_y + 3, 8, 1), c)
		draw_rect(Rect2(x + 5, floor_y, 3, 1), c)
	for q in _particles:
		var k: float = q.age / q.life
		var c: Color = q.col
		var p: Vector2 = (q.pos as Vector2).round()
		var s: float = maxf(q.size * (1.0 + q.grow * k), 0.5)
		match q.shape:
			Shape.PUFF:
				c.a = (1.0 - k) * 0.7
				var r := roundf(s)
				draw_rect(Rect2(p.x - r, p.y - roundf(r * 0.5), r * 2.0, maxf(r, 1.0)), c)
				draw_rect(Rect2(p.x - roundf(r * 0.5), p.y - r, maxf(r, 1.0), r * 2.0), c.lightened(0.2))
			Shape.STAR:
				c.a = 1.0 - k
				var r := maxf(roundf(s), 1.0)
				draw_rect(Rect2(p.x - r, p.y, r * 2.0 + 1.0, 1), c)
				draw_rect(Rect2(p.x, p.y - r, 1, r * 2.0 + 1.0), c)
			Shape.DROP:
				c.a = 1.0 - k * 0.5
				draw_rect(Rect2(p.x, p.y, maxf(roundf(s), 1.0), maxf(roundf(s * 2.0), 2.0)), c)
			Shape.LINE:
				c.a *= 1.0 - k
				var d: Vector2 = (q.vel as Vector2).normalized()
				draw_line(p, (p - d * s).round(), c, 1.0)
			_:
				c.a = 1.0 - k * 0.6
				var r := roundf(s)
				draw_rect(Rect2(p.x - r * 0.5, p.y - r * 0.5, r, r), c)
