## Duelo de fondo del menú principal: cada pocos segundos dos luchadores al azar
## entran de un salto, se miran en guardia, lanzan algún golpe al aire y uno celebra.
## Luego un destello y entra otra pareja. Es solo decorado (usa su propio azar).
class_name MenuDuel
extends Node2D

## Segundos que dura cada pareja en pantalla.
const CYCLE := 6.5
const ENTER := 0.55
const EXIT := 0.35
const FLOOR_Y := 226.0
const HOME_X: Array[float] = [58.0, 368.0]
## Alto objetivo en píxeles (todos se ven de un tamaño parecido).
const TARGET_H := 92.0
const ATTACK_TIME := 0.42

var _roster: Array[FighterData] = []
var _rng := RandomNumberGenerator.new()
var _fighters: Array[FighterRenderer] = []
var _t: float = 0.0
var _flash: float = 0.0
## Momento (dentro del ciclo) del próximo golpe de cada uno y del que está en curso.
var _next_attack: Array[float] = [0.0, 0.0]
var _attack_t: Array[float] = [-1.0, -1.0]
var _winner: int = 0

func _ready() -> void:
	_rng.randomize()
	_roster = FighterRegistry.all()
	for i in 2:
		var r := FighterRenderer.new()
		add_child(r)
		_fighters.append(r)
	_new_pair()

func _new_pair() -> void:
	if _roster.size() < 2:
		return
	var a := _rng.randi_range(0, _roster.size() - 1)
	var b := _rng.randi_range(0, _roster.size() - 2)
	if b >= a:
		b += 1
	var ids := [a, b]
	for i in 2:
		var r := _fighters[i]
		r.setup(_roster[ids[i]])
		var s := clampf(TARGET_H / maxf(r.approx_height(), 1.0), 1.0, 1.6)
		# El de la derecha mira a la izquierda.
		r.scale = Vector2(s if i == 0 else -s, s)
		_next_attack[i] = _rng.randf_range(1.2, 3.8)
		_attack_t[i] = -1.0
	_winner = _rng.randi_range(0, 1)
	_t = 0.0
	_flash = 1.0

## Nombre corto del luchador i (para el rótulo "X VS Y").
func fighter_name(i: int) -> String:
	return _fighters[i].data.short_name if i < _fighters.size() and _fighters[i].data else ""

func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 3.0, 0.0)
	if _t >= CYCLE:
		_new_pair()
	for i in 2:
		_animate(i, delta)
	queue_redraw()

func _animate(i: int, delta: float) -> void:
	var r := _fighters[i]
	if r.data == null:
		return
	var side := -1.0 if i == 0 else 1.0
	var home := HOME_X[i]
	r.airborne = false
	r.phase = &""
	if _t < ENTER:
		# Entra de un salto desde fuera de la pantalla.
		var k := _t / ENTER
		r.position = Vector2(lerpf(home + side * 110.0, home, k), FLOOR_Y - sin(k * PI) * 46.0)
		r.airborne = true
		r.pose_name = &"jump"
		r.height_above_floor = sin(k * PI) * 46.0
		return
	r.height_above_floor = 0.0
	if _t > CYCLE - EXIT:
		# Sale de un salto hacia atrás.
		var k := (_t - (CYCLE - EXIT)) / EXIT
		r.position = Vector2(lerpf(home, home + side * 120.0, k), FLOOR_Y - sin(k * PI) * 30.0)
		r.airborne = true
		r.pose_name = &"jump"
		return
	r.position = Vector2(home, FLOOR_Y)
	if _t > CYCLE - EXIT - 1.3:
		r.pose_name = &"victory" if i == _winner else &"idle"
		return
	# Golpes al aire de vez en cuando, con su propia animación (puño, patada, arma...).
	if _attack_t[i] < 0.0 and _t >= _next_attack[i]:
		_attack_t[i] = 0.0
		var slots: Array[StringName] = [&"punch_light", &"punch_heavy", &"kick_light", &"kick_heavy"]
		var atk := r.data.get_attack(slots[_rng.randi_range(0, slots.size() - 1)])
		r.pose_name = atk.anim if atk else &"jab"
		_next_attack[i] = _t + _rng.randf_range(1.0, 2.2)
	if _attack_t[i] >= 0.0:
		_attack_t[i] += delta
		var k := _attack_t[i] / ATTACK_TIME
		if k < 0.45:
			r.phase = &"startup"
			r.phase_t = k / 0.45
		elif k < 0.6:
			r.phase = &"active"
			r.phase_t = 0.0
		elif k < 1.0:
			r.phase = &"recovery"
			r.phase_t = (k - 0.6) / 0.4
		else:
			_attack_t[i] = -1.0
			r.pose_name = &"idle"
		return
	r.pose_name = &"idle"

func _draw() -> void:
	if _roster.size() < 2:
		return
	# Rótulo de cada luchador sobre su cabeza, y destello al cambiar de pareja.
	var a := clampf((_t - ENTER) / 0.3, 0.0, 1.0) * clampf((CYCLE - EXIT - _t) / 0.3, 0.0, 1.0)
	for i in 2:
		var r := _fighters[i]
		if r.data == null or a <= 0.0:
			continue
		var top := FLOOR_Y - r.approx_height() * absf(r.scale.y) - 4.0
		var col := HKTheme.GOLD if i == _winner and _t > CYCLE - EXIT - 1.3 else HKTheme.PAPER
		col.a = a
		# El contorno no admite transparencia: solo se pone cuando el rótulo ya se ve entero.
		HKTheme.draw_text(self, Vector2(HOME_X[i] - 60.0, top), r.data.short_name, 8, col, HORIZONTAL_ALIGNMENT_CENTER, 120.0,
			2 if a >= 1.0 else 0)
	if _flash > 0.0:
		draw_rect(Rect2(-10, -10, 446, 260), Color(1, 0.95, 0.8, _flash * 0.35))
