## Efecto visual de impacto (chispa de golpe, destello de bloqueo, K.O.).
## Se dibuja con primitivas y se autodestruye al terminar.
class_name HitEffect
extends Node2D

enum Type { HIT, BLOCK, KO, CLASH }

var type: Type = Type.HIT
var size: float = 1.0
var duration: float = 0.25
var _t: float = 0.0
var _rays: Array[float] = []

static func spawn(parent: Node, at: Vector2, p_type: Type, p_size: float = 1.0) -> HitEffect:
	var fx := HitEffect.new()
	fx.type = p_type
	fx.size = p_size
	fx.position = at.round()
	fx.z_index = 20
	if p_type == Type.KO:
		fx.duration = 0.5
	parent.add_child(fx)
	return fx

func _ready() -> void:
	var count := 8 if type != Type.BLOCK else 5
	for i in count:
		_rays.append(randf() * TAU)

func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := _t / duration
	var main := Color("fff6c0")
	var accent := Color("ff7020")
	if type == Type.BLOCK:
		main = Color("d0f0ff")
		accent = Color("4080ff")
	elif type == Type.KO:
		accent = Color("ff2040")
	elif type == Type.CLASH:
		accent = Color("ffd040")
	var s := size * (1.0 if type != Type.KO else 1.8)
	# Estrella central que se encoge
	var core := (1.0 - k) * 7.0 * s
	if core > 1.0:
		draw_rect(Rect2(-core, -1, core * 2, 3), main)
		draw_rect(Rect2(-1, -core, 3, core * 2), main)
		draw_rect(Rect2(-core * 0.5, -core * 0.5, core, core), accent)
	# Rayos que se expanden
	for a in _rays:
		var dir := Vector2(cos(a), sin(a))
		var inner := (4.0 + k * 14.0) * s
		var outer := inner + (1.0 - k) * 8.0 * s
		draw_line((dir * inner).round(), (dir * outer).round(), accent if int(a * 10) % 2 == 0 else main, 2.0)
	if type == Type.BLOCK:
		# Escudo: arco brillante
		draw_arc(Vector2.ZERO, (6.0 + k * 6.0) * s, -1.2, 1.2, 8, main, 2.0)
		draw_arc(Vector2.ZERO, (6.0 + k * 6.0) * s, PI - 1.2, PI + 1.2, 8, main, 2.0)
