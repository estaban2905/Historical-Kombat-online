## Atmósfera común a los escenarios temáticos: viñeta suave en los bordes, bruma de profundidad en el
## horizonte, luz cálida desde arriba y motas de polvo que flotan.
##
## Es solo decorado: usa su propio reloj y no lee ni escribe estado de combate (no afecta al determinismo).
extends Node2D

const W := 426.0
const H := 240.0
const MOTES := 26

var _t: float = 0.0
var _accum: float = 0.0
var _horizon: float = 168.0

func setup(horizon: float) -> void:
	_horizon = horizon
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	_accum += delta
	if _accum >= 1.0 / 12.0:
		_accum = 0.0
		queue_redraw()

static func _h(i: int, s: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(s) * 78.233) * 43758.5453, 1.0)

func _draw() -> void:
	# Bruma de profundidad: aclara y desatura un poco justo sobre el horizonte.
	for k in 18:
		var a := 0.045 * (1.0 - float(k) / 18.0)
		draw_rect(Rect2(0, _horizon - 18.0 + float(k), W, 1), Color(1.0, 0.97, 0.9, a))
	# Luz cálida cayendo desde arriba.
	for k in 40:
		draw_rect(Rect2(0, float(k) * 2.0, W, 2), Color(1.0, 0.95, 0.8, 0.035 * (1.0 - float(k) / 40.0)))
	# Motas de polvo y luz que flotan despacio.
	for i in MOTES:
		var x := fposmod(_h(i, 1) * W + sin(_t * 0.5 + float(i)) * 6.0 + _t * (2.0 + _h(i, 4) * 3.0), W)
		var y := fposmod(_h(i, 2) * (H - 40.0) - _t * (3.0 + _h(i, 5) * 5.0), H - 40.0) + 8.0
		var tw := 0.5 + 0.5 * sin(_t * 1.6 + float(i) * 2.3)
		draw_rect(Rect2(floorf(x), floorf(y), 1, 1), Color(1.0, 0.96, 0.82, 0.12 + 0.2 * tw))
	# Viñeta: bordes y esquinas más oscuros que centran la mirada en el combate.
	for i in 14:
		var m := float(i) * 3.0
		var a := 0.011 * float(14 - i)
		draw_rect(Rect2(0, 0, W, m + 3.0), Color(0, 0, 0, a * 0.8))
		draw_rect(Rect2(0, H - m - 3.0, W, m + 3.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 0, m + 3.0, H), Color(0, 0, 0, a * 0.9))
		draw_rect(Rect2(W - m - 3.0, 0, m + 3.0, H), Color(0, 0, 0, a * 0.9))
