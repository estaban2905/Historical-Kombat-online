## Fondo animado para menús: cielo de atardecer, sol gigante, silueta de
## arcos del coliseo y brasas que suben. Opcionalmente dibuja el título.
extends Control

@export var show_title: bool = true
@export var title_y: float = 40.0

var _t: float = 0.0
var _embers: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1815
	for i in 40:
		_embers.append({"x": rng.randf() * 426.0, "y": rng.randf() * 240.0,
			"s": rng.randf_range(8.0, 22.0), "p": rng.randf() * TAU})

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var bands := [Color("12081c"), Color("1c0b26"), Color("2a0f2e"), Color("3d1430"),
		Color("561a2e"), Color("74222c"), Color("922e28"), Color("ae4024")]
	for i in bands.size():
		draw_rect(Rect2(0, i * 20, 426, 20), bands[i])
	draw_rect(Rect2(0, 160, 426, 80), Color("1a0a14"))
	# Sol rojo gigante
	draw_circle(Vector2(213, 150), 70, Color("c8462a"))
	draw_circle(Vector2(213, 150), 62, Color("e0602e"))
	for i in 5:
		draw_rect(Rect2(140, 112 + i * 9, 146, 2 + i), bands[3 + mini(i, 4)])
	# Silueta del coliseo
	var base := 168.0
	draw_rect(Rect2(0, base - 54, 426, 54), Color("1e0c16"))
	for row in 3:
		var y := base - 52 + row * 17
		for x in range(-4 + row * 6, 426, 24):
			draw_rect(Rect2(x, y + 3, 12, 12), Color("3a1620") if row != 1 else Color("4a1a24"))
			draw_rect(Rect2(x + 2, y + 1, 8, 2), Color("3a1620"))
	draw_rect(Rect2(0, base, 426, 72), Color("120610"))
	draw_rect(Rect2(0, base, 426, 1), Color("5a2028"))
	# Brasas
	for e in _embers:
		var y: float = fmod(e.y - _t * e.s + 240.0 * 4.0, 240.0)
		var x: float = e.x + sin(_t * 2.0 + e.p) * 3.0
		var c := Color("ffb040") if int(e.p * 10) % 2 == 0 else Color("ff6030")
		draw_rect(Rect2(roundf(x), roundf(y), 1, 1), c)
	if show_title:
		_draw_title()

func _draw_title() -> void:
	var y := title_y
	var shake := 0.0
	HKTheme.draw_text(self, Vector2(2, y + 2), "HISTORICAL", 24, Color("5a0a10"), HORIZONTAL_ALIGNMENT_CENTER, 426, 0)
	HKTheme.draw_text(self, Vector2(0, y), "HISTORICAL", 24, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 426, 4)
	HKTheme.draw_text(self, Vector2(3, y + 37 + shake), "KOMBAT", 32, Color("5a0a10"), HORIZONTAL_ALIGNMENT_CENTER, 426, 0)
	var glow := 0.5 + 0.5 * sin(_t * 3.0)
	HKTheme.draw_text(self, Vector2(0, y + 34), "KOMBAT", 32, HKTheme.GOLD.lerp(Color("fff0a0"), glow * 0.4), HORIZONTAL_ALIGNMENT_CENTER, 426, 4)
	draw_rect(Rect2(110, y + 42, 206, 1), HKTheme.GOLD_DARK)
	HKTheme.draw_text(self, Vector2(0, y + 54), "EL TORNEO DE LOS SIGLOS", 8, HKTheme.BLOOD.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
