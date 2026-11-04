## Proyectil o efecto de un ataque especial (cañonazo, onda del megáfono,
## oso, dragón, muro...). El CombatManager compara su get_rect() con las
## hurtboxes y con otros proyectiles (choque = ambos se anulan). No usa el motor
## de física; DebugOverlay dibuja la caja en depuración.
##
## Sin configurar es el proyectil clásico: se mueve en horizontal y se destruye
## al impactar. PowerEffects lo configura (configure) para los poderes:
## retardo, objetos que atraviesan, golpes repetidos, caída con gravedad,
## entidades inofensivas de decorado, etc. Cómo se dibuja: ver power_art.gd.
class_name Projectile
extends Node2D

## Pide sacudir la cámara cuando la entidad se arma tras su retardo (lo conecta quien la crea).
signal shake_requested(amount: float)
signal sound_requested(sound: StringName)

const TICKS_PER_SECOND := 60.0

var owner_fighter: Fighter
var attack: AttackData
var direction: int = 1
var speed: float = 200.0
## Velocidad vertical (px/s, negativa = hacia arriba) y su aceleración.
var vy: float = 0.0
var accel_y: float = 0.0
## Todos los tiempos de la entidad van en frames (ticks de combate a 60 Hz), igual que los golpes.
## Frames que le quedan de vida (cuenta también el retardo).
var life_frames: int = 120
var alive: bool = true

## Estilo gráfico de PowerArt. Vacío = estilo clásico (attack.projectile_style).
var art: StringName = &""
var art_color: Color = Color.WHITE
var box: Vector2 = Vector2(12, 12)
## Si true no se destruye al impactar (atraviesa); cada objetivo recibe como
## máximo `max_hits` golpes, separados por `rehit_frames`.
var pierce: bool = false
var rehit_frames: int = 0
var max_hits: int = 1
## Entidad de decorado: no golpea, no choca (cañones, guardias, humo...).
var harmless: bool = false
## Puede chocar contra otros proyectiles y anularse.
var clashable: bool = true
## true: el empuje va hacia fuera del centro (ondas expansivas).
var radial: bool = false
## Frames hasta que el efecto "se activa" (antes no golpea ni se mueve).
var delay_frames: int = 0
## Si true se dibuja ya durante el retardo (muro que sube, mono que salta...).
var show_before_arm: bool = false
var shake_on_arm: float = 0.0
var sound_on_arm: StringName = &""
## > 0: se destruye al llegar a esta altura (bombas). Con `boom` explota.
var floor_y: float = -1.0
var boom: bool = false
## El golpe arrastra al objetivo hacia el lanzador.
var pull: bool = false
## Combo con nombre que completa este especial (su bono lo cobra el primer golpe que entre).
var combo: ComboData
var combo_instance: int = -1
## Visual que acompaña al lanzador mientras tiene el escudo activo.
var follow: bool = false

## Frames transcurridos desde que se creó.
var age: int = 0
## Segundos desde que se creó. Solo para dibujar y animar: la lógica usa `age`.
var _t: float:
	get: return age / TICKS_PER_SECOND
var _armed: bool = true
var _trail: Array[Vector2] = []
## objetivo -> [golpes, frames hasta poder repetir]
var _hit_log: Dictionary = {}

func setup(p_owner: Fighter, p_attack: AttackData, spawn_position: Vector2) -> void:
	owner_fighter = p_owner
	attack = p_attack
	combo = p_owner.attack_combo
	combo_instance = p_owner.attack_instance
	direction = p_owner.facing
	speed = p_attack.projectile_speed
	life_frames = maxi(roundi(p_attack.projectile_lifetime * TICKS_PER_SECOND), 1)
	position = spawn_position
	box = p_attack.hitbox_size

## Aplica las opciones de un poder (claves de PowerEffects._spawn).
func configure(d: Dictionary) -> void:
	art = d.get("art", &"")
	art_color = d.get("color", art_color)
	direction = int(d.get("dir", direction))
	box = d.get("box", box)
	speed = d.get("speed", 0.0)
	vy = d.get("vy", 0.0)
	accel_y = d.get("accel_y", 0.0)
	delay_frames = int(d.get("delay", 0))
	life_frames = int(d.get("life", 90)) + delay_frames
	pierce = d.get("pierce", false)
	rehit_frames = d.get("rehit", 0)
	max_hits = d.get("max_hits", 1)
	radial = d.get("radial", false)
	show_before_arm = d.get("show", false)
	shake_on_arm = d.get("shake", 0.0)
	sound_on_arm = d.get("sound", &"")
	floor_y = d.get("floor_y", -1.0)
	boom = d.get("boom", false)
	pull = d.get("pull", false)
	clashable = d.get("clash", art == &"")
	_armed = delay_frames <= 0
	visible = _armed or show_before_arm

## Entidad solo visual (humo, cañón, guardia, explosión...).
static func make_visual(p_owner: Fighter, pos: Vector2, d: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.owner_fighter = p_owner
	p.direction = p_owner.facing
	p.position = pos
	p.harmless = true
	p.clashable = false
	p.art = d.get("art", &"")
	p.art_color = d.get("color", Color.WHITE)
	p.box = d.get("box", Vector2(20, 20))
	p.speed = d.get("speed", 0.0)
	p.vy = d.get("vy", 0.0)
	p.delay_frames = int(d.get("delay", 0))
	p.life_frames = int(d.get("life", 30)) + p.delay_frames
	p._armed = p.delay_frames <= 0
	p.visible = p._armed or d.get("show", false)
	p.show_before_arm = d.get("show", false)
	p.follow = d.get("follow", false)
	return p

func is_armed() -> bool:
	return _armed

## Caja de impacto en coordenadas globales, centrada en el proyectil.
func get_rect() -> Rect2:
	return Rect2(global_position - box * 0.5, box)

func tick(delta: float) -> void:
	if not alive:
		return
	# Tiempo lento: la entidad de un luchador ralentizado avanza solo uno de cada dos frames,
	# igual que él (ver Fighter.tick).
	if owner_fighter != null and owner_fighter.slow_frames > 0 and owner_fighter.frame_counter % 2 == 0:
		return
	age += 1
	life_frames -= 1
	if follow:
		if owner_fighter == null or owner_fighter.shield_frames <= 0 or life_frames <= 0:
			destroy()
			return
		position = owner_fighter.position + Vector2(0, -36)
		queue_redraw()
		return
	for target in _hit_log:
		_hit_log[target][1] = maxi(_hit_log[target][1] - 1, 0)
	if not _armed:
		if age >= delay_frames:
			_arm()
		if life_frames <= 0:
			destroy()
		queue_redraw()
		return
	_trail.push_front(position)
	if _trail.size() > 6:
		_trail.pop_back()
	vy += accel_y * delta
	position += Vector2(direction * speed, vy) * delta
	if life_frames <= 0 or position.x < -80.0 or position.x > 506.0 or position.y > 280.0:
		destroy()
	elif floor_y > 0.0 and position.y >= floor_y:
		if boom:
			_spawn_boom()
		destroy()
	queue_redraw()

func _arm() -> void:
	_armed = true
	visible = true
	if shake_on_arm > 0.0:
		shake_requested.emit(shake_on_arm)
	if sound_on_arm != &"":
		sound_requested.emit(sound_on_arm)

func can_hit(target: Fighter) -> bool:
	var entry = _hit_log.get(target)
	if entry == null:
		return true
	return rehit_frames > 0 and entry[0] < max_hits and entry[1] <= 0

func register_hit(target: Fighter) -> void:
	var entry: Array = _hit_log.get(target, [0, 0])
	entry[0] += 1
	entry[1] = rehit_frames
	_hit_log[target] = entry
	if boom:
		_spawn_boom()
	if not pierce:
		destroy()

## Hacia dónde sale despedido el objetivo.
func hit_direction(target: Fighter) -> int:
	if radial:
		return 1 if target.position.x >= position.x else -1
	return -direction if pull else direction

func _spawn_boom() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var b := Projectile.make_visual(owner_fighter, position, {"art": &"boom", "box": Vector2(40, 40),
		"life": 21, "color": art_color if art_color != Color.WHITE else Color("ffd060")})
	parent.add_child(b)
	sound_requested.emit(&"cannon")

func destroy() -> void:
	if not alive:
		return
	alive = false
	queue_free()

func _draw() -> void:
	if art != &"":
		PowerArt.draw(self, art, _t, clampf(float(age) / maxf(delay_frames, 1), 0.0, 1.0) if not _armed else 1.0,
			maxf(_t - delay_frames / TICKS_PER_SECOND, 0.0), direction, box, art_color)
		return
	match attack.projectile_style if attack else &"ball":
		&"soundwave":
			# Ondas de sonido del megáfono: tres arcos que vibran.
			for i in 3:
				var r := 4.0 + i * 4.0 + sin(_t * 30.0 + i) * 1.0
				var col := Color("fff0a0") if i % 2 == 0 else Color("ffffff")
				col.a = 1.0 - i * 0.25
				var center_angle := 0.0 if direction > 0 else PI
				draw_arc(Vector2(-direction * 8.0, 0), r, center_angle - 0.9, center_angle + 0.9, 6, col, 2.0)
			draw_rect(Rect2(-2, -1, 3, 3), Color("ffe060"))
		&"orb":
			# Esfera de energía con estela y núcleo claro.
			var col := attack.projectile_color
			for i in _trail.size():
				var p := _trail[i] - position
				draw_circle(p, 4.0 - i * 0.5, Color(col.r, col.g, col.b, 0.5 - i * 0.07))
			draw_circle(Vector2.ZERO, 6.0, Color("120a14"))
			draw_circle(Vector2.ZERO, 5.0, col)
			draw_circle(Vector2(-1, -1), 2.5, col.lightened(0.6))
		&"bolt":
			# Rayo en zigzag que vibra.
			var col := attack.projectile_color
			var pts := PackedVector2Array()
			for i in 6:
				var jitter := -4.0 if (i + int(_t * 30.0)) % 2 == 0 else 4.0
				pts.append(Vector2(-direction * (14.0 - i * 5.0), jitter))
			draw_polyline(pts, Color("120a14"), 4.0)
			draw_polyline(pts, col, 2.0)
			draw_circle(Vector2(direction * 3.0, 0), 3.0, col.lightened(0.5))
		&"spin":
			# Objeto que gira (billetes, libros, frascos...).
			var col := attack.projectile_color
			draw_set_transform(Vector2.ZERO, _t * 14.0 * direction)
			draw_rect(Rect2(-5, -3, 10, 6), Color("120a14"))
			draw_rect(Rect2(-4, -2, 8, 4), col)
			draw_rect(Rect2(-2, -1, 4, 2), col.lightened(0.4))
			draw_set_transform(Vector2.ZERO, 0.0)
		_:
			# Bala de cañón con estela de humo.
			for i in _trail.size():
				var p := _trail[i] - position
				var a := 0.5 - i * 0.08
				draw_circle(p + Vector2(-direction * 2.0 * i, 0), 3.0 + i * 0.6, Color(0.8, 0.78, 0.72, a))
			draw_circle(Vector2.ZERO, 5.0, Color("120a14"))
			draw_circle(Vector2.ZERO, 4.0, Color("2a2a32"))
			draw_rect(Rect2(-2, -3, 2, 2), Color("8a8a9a"))
			if int(_t * 20.0) % 2 == 0:
				draw_rect(Rect2(-direction * 6.0 - 1, -1, 2, 2), Color("ffb030"))
