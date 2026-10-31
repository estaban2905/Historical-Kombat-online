## Capas dibujadas del escenario EL COLISEO ROMANO (pixel art procedural).
##   BACK  : cielo al atardecer, sol, ático con arcos y gradas (estático)
##   CROWD : público animado (salta más cuando hay golpes fuertes)
##   FRONT : muro del pódium, palco imperial, estandartes, columnas, suelo
##   FIRE  : llamas animadas de los braseros
## Las capas estáticas se dibujan una sola vez (Godot guarda los comandos).
extends Node2D

enum Layer { BACK, CROWD, FRONT, FIRE }

@export var layer: Layer = Layer.BACK

const W := 426
const H := 240
const STONE := Color("c9a06a")
const STONE_LIGHT := Color("e2bf86")
const STONE_DARK := Color("8c6440")
const STONE_DEEP := Color("4a3022")
const SHADOW := Color("2a1a18")
const MARBLE := Color("e8dcc4")
const IMPERIAL := Color("6a2a7a")
const RED := Color("a82828")
const GOLD := Color("e6b43c")

var _t: float = 0.0
var _accum: float = 0.0
var _stage: Stage
var _crowd: Array = []

func _ready() -> void:
	_stage = get_parent() as Stage
	if layer == Layer.CROWD:
		_build_crowd()

func _process(delta: float) -> void:
	if layer == Layer.CROWD or layer == Layer.FIRE:
		_t += delta
		_accum += delta
		# 12 fps de animación: suficiente para pixel art y barato en web.
		if _accum >= 1.0 / 12.0:
			_accum = 0.0
			queue_redraw()

func _draw() -> void:
	match layer:
		Layer.BACK: _draw_back()
		Layer.CROWD: _draw_crowd()
		Layer.FRONT: _draw_front()
		Layer.FIRE: _draw_fire()

# --------------------------------------------------------------------------
func _draw_back() -> void:
	# Cielo en bandas (degradado retro sin suavizado)
	var sky := [Color("2b1740"), Color("3f1d4f"), Color("5e2556"), Color("86305a"),
		Color("b04a52"), Color("d6694a"), Color("ee9450"), Color("f7bd6a")]
	for i in sky.size():
		draw_rect(Rect2(0, i * 7, W, 7), sky[i])
	# Sol poniente
	draw_circle(Vector2(330, 52), 18, Color("ffd27a"))
	draw_circle(Vector2(330, 52), 14, Color("ffe6a0"))
	for i in 3:
		draw_rect(Rect2(310, 44 + i * 6, 40, 1), sky[5 + mini(i, 2)])
	# Nubes pixeladas
	for c in [[40, 14, 34], [120, 24, 22], [210, 10, 40], [380, 20, 26]]:
		draw_rect(Rect2(c[0], c[1], c[2], 3), Color("f3a2a0"))
		draw_rect(Rect2(c[0] + 4, c[1] - 2, c[2] - 10, 2), Color("f8c4b0"))
		draw_rect(Rect2(c[0] + 6, c[1] + 3, c[2] - 6, 1), Color("b85a70"))

	# Ático exterior (fila superior de arcos, recortados contra el cielo)
	var attic_top := 34
	draw_rect(Rect2(0, attic_top, W, 22), STONE)
	draw_rect(Rect2(0, attic_top, W, 2), STONE_LIGHT)
	draw_rect(Rect2(0, attic_top + 20, W, 2), STONE_DARK)
	for x in range(6, W, 22):
		draw_rect(Rect2(x, attic_top + 6, 10, 14), STONE_DEEP)
		draw_rect(Rect2(x + 1, attic_top + 4, 8, 2), STONE_DEEP)
		draw_rect(Rect2(x - 2, attic_top + 4, 2, 16), STONE_LIGHT)
		draw_rect(Rect2(x + 14, attic_top + 4, 2, 16), STONE_DARK)
	# Mástiles del velarium con banderines
	for x in range(20, W, 64):
		draw_rect(Rect2(x, attic_top - 16, 2, 16), Color("5a3a22"))
		draw_rect(Rect2(x + 2, attic_top - 16, 9, 5), RED)
		draw_rect(Rect2(x + 2, attic_top - 12, 6, 1), Color("801818"))

	# Gradas (cavea): escalones de piedra donde se sienta el público
	var top := 56
	var bottom := 150
	draw_rect(Rect2(0, top, W, bottom - top), Color("7a5636"))
	for y in range(top, bottom, 7):
		draw_rect(Rect2(0, y + 5, W, 2), Color("5c3e28"))
	# Pasillos (praecinctiones) que separan los sectores
	for y in [86, 118]:
		draw_rect(Rect2(0, y, W, 4), STONE)
		draw_rect(Rect2(0, y, W, 1), STONE_LIGHT)
		draw_rect(Rect2(0, y + 4, W, 1), SHADOW)
	# Escaleras (vomitoria) que cortan las gradas
	for x in range(48, W, 96):
		draw_rect(Rect2(x, top, 8, bottom - top), Color("9a7048"))
		for y in range(top, bottom, 3):
			draw_rect(Rect2(x, y, 8, 1), Color("6a4a30"))

# --------------------------------------------------------------------------
func _build_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1453
	var skins := [Color("f0c8a0"), Color("d8a070"), Color("b07848"), Color("8a5a38"), Color("f4d8b8")]
	var cloth := [Color("eeeae0"), Color("c03030"), Color("3a60b0"), Color("d0a040"),
		Color("508848"), Color("8a4aa0"), Color("e07030"), Color("ddd2b8")]
	var sectors := [[58, 84], [92, 116], [124, 148]]
	for s in sectors:
		var y: int = s[0] + 2
		while y < s[1] - 2:
			var x := rng.randi_range(0, 3)
			while x < W:
				var skip := false
				for sx in range(48, W, 96):
					if x >= sx - 3 and x <= sx + 9:
						skip = true
				if not skip and rng.randf() > 0.08:
					_crowd.append({
						"x": x, "y": y,
						"skin": skins[rng.randi() % skins.size()],
						"cloth": cloth[rng.randi() % cloth.size()],
						"phase": rng.randf() * TAU,
						"speed": rng.randf_range(3.0, 7.0),
						"hair": rng.randf() < 0.5,
					})
				x += rng.randi_range(5, 7)
			y += 7

func _draw_crowd() -> void:
	var ex := _stage.excitement if _stage else 0.0
	for p in _crowd:
		var wave := sin(_t * p.speed + p.phase)
		var bob := 0
		if wave > 0.7 - ex * 0.9:
			bob = -1 - int(ex * 2.0)
		var x: int = p.x
		var y: int = p.y + bob
		draw_rect(Rect2(x, y + 3, 4, 3), p.cloth)
		draw_rect(Rect2(x + 1, y, 3, 3), p.skin)
		if p.hair:
			draw_rect(Rect2(x + 1, y, 3, 1), Color("3a2418"))
		# Con emoción alta levantan los brazos
		if ex > 0.35 and wave > 0.2:
			draw_rect(Rect2(x - 1, y - 2, 1, 3), p.skin)
			draw_rect(Rect2(x + 4, y - 2, 1, 3), p.skin)

# --------------------------------------------------------------------------
func _draw_front() -> void:
	# Muro del pódium (mármol con friso rojo)
	var py := 150
	draw_rect(Rect2(0, py, W, 26), MARBLE)
	draw_rect(Rect2(0, py, W, 2), Color("fff4dc"))
	draw_rect(Rect2(0, py + 8, W, 5), RED)
	for x in range(0, W, 8):
		draw_rect(Rect2(x + 2, py + 9, 3, 3), GOLD)
	draw_rect(Rect2(0, py + 24, W, 2), Color("a89878"))
	for x in range(0, W, 30):
		draw_rect(Rect2(x, py + 14, 1, 10), Color("c8b898"))

	# Palco imperial en el centro con toldo púrpura
	var cx := W / 2
	draw_rect(Rect2(cx - 34, py - 22, 68, 22), MARBLE)
	draw_rect(Rect2(cx - 30, py - 18, 60, 14), Color("3a2030"))
	draw_rect(Rect2(cx - 36, py - 28, 72, 7), IMPERIAL)
	for i in 9:
		draw_rect(Rect2(cx - 36 + i * 8, py - 21, 6, 3), IMPERIAL)
	draw_rect(Rect2(cx - 36, py - 29, 72, 1), GOLD)
	# Silueta del emperador en el palco
	draw_rect(Rect2(cx - 3, py - 15, 6, 8), Color("e8e0d0"))
	draw_rect(Rect2(cx - 2, py - 18, 4, 3), Color("d8a878"))
	draw_rect(Rect2(cx - 3, py - 19, 6, 1), Color("5a9a40"))
	# Estandartes "SPQR" colgando del pódium
	for bx in [cx - 70, cx + 58]:
		draw_rect(Rect2(bx, py + 1, 12, 20), RED)
		draw_rect(Rect2(bx, py + 1, 12, 1), GOLD)
		draw_rect(Rect2(bx + 2, py + 21, 8, 2), RED)
		draw_rect(Rect2(bx + 4, py + 23, 4, 2), RED)
		# Corona de laurel
		draw_arc(Vector2(bx + 6, py + 10), 4, 0.6, PI - 0.6, 6, GOLD, 1.0)
		draw_rect(Rect2(bx + 5, py + 6, 2, 2), GOLD)

	# Columnas romanas (dos grandes a los lados, varias pequeñas sobre el pódium)
	for c in [[10, 18, 60], [398, 18, 60]]:
		_column(c[0], c[2], 176, c[1])
	for x in [96, 156, 270, 330]:
		_column(x, 98, 150, 8)

	# Braseros
	for x in [70, 356]:
		draw_rect(Rect2(x - 6, py - 6, 12, 4), Color("5a4a40"))
		draw_rect(Rect2(x - 4, py - 2, 8, 2), Color("3a2e28"))
		draw_rect(Rect2(x - 1, py, 2, 2), Color("3a2e28"))

	# Suelo de piedra de la arena con perspectiva sencilla
	var fy := 176
	draw_rect(Rect2(0, fy, W, H - fy), Color("9c8a72"))
	draw_rect(Rect2(0, fy, W, 3), Color("5a4a3a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 476
	var row_y := fy + 3
	var row_h := 5
	var row := 0
	while row_y < H:
		var slab_w := 22 + row * 6
		var offset := (row % 2) * slab_w / 2
		var x := -offset
		while x < W:
			var shade := rng.randf_range(-0.07, 0.07)
			var col := Color("b4a084").lightened(shade) if shade > 0 else Color("b4a084").darkened(-shade)
			draw_rect(Rect2(x + 1, row_y + 1, slab_w - 1, row_h - 1), col)
			draw_rect(Rect2(x + 1, row_y + 1, slab_w - 1, 1), col.lightened(0.12))
			if rng.randf() < 0.18:
				var cx2 := x + rng.randi_range(4, maxi(slab_w - 6, 5))
				draw_rect(Rect2(cx2, row_y + 2, 1, 2), Color("6a5a48"))
				draw_rect(Rect2(cx2 + 1, row_y + 3, 2, 1), Color("6a5a48"))
			x += slab_w
		row_y += row_h
		row_h += 2
		row += 1
	# Arena sobre la piedra (manchas)
	for i in 40:
		draw_rect(Rect2(rng.randi_range(0, W), rng.randi_range(fy + 6, H), rng.randi_range(2, 6), 1), Color("cdb68e"))

func _column(x: float, top: float, bottom: float, width: float) -> void:
	var h := bottom - top
	# Basa y capitel
	draw_rect(Rect2(x - width / 2 - 3, bottom - 5, width + 6, 5), STONE_DARK)
	draw_rect(Rect2(x - width / 2 - 2, bottom - 7, width + 4, 2), MARBLE)
	draw_rect(Rect2(x - width / 2 - 4, top, width + 8, 4), MARBLE)
	draw_rect(Rect2(x - width / 2 - 2, top + 4, width + 4, 2), Color("c8b898"))
	draw_rect(Rect2(x - width / 2 - 4, top - 2, width + 8, 2), Color("fff4dc"))
	# Fuste estriado
	draw_rect(Rect2(x - width / 2, top + 6, width, h - 13), Color("ddd0b4"))
	var step := maxf(width / 4.0, 2.0)
	var fx := x - width / 2 + 1
	while fx < x + width / 2 - 1:
		draw_rect(Rect2(fx, top + 6, 1, h - 13), Color("b8a888"))
		fx += step
	draw_rect(Rect2(x + width / 2 - 2, top + 6, 2, h - 13), Color("a89878"))
	draw_rect(Rect2(x - width / 2, top + 6, 1, h - 13), Color("fff4dc"))

# --------------------------------------------------------------------------
func _draw_fire() -> void:
	var ex := _stage.excitement if _stage else 0.0
	for bx in [70, 356]:
		var base := Vector2(bx, 144)
		for i in 6:
			var f := sin(_t * 9.0 + i * 1.7 + bx)
			var hgt := 6.0 + f * 2.0 + ex * 4.0 - absf(i - 2.5) * 1.2
			var xx := base.x - 5 + i * 2
			draw_rect(Rect2(xx, base.y - hgt, 2, hgt), Color("e04020"))
			draw_rect(Rect2(xx, base.y - hgt * 0.6, 2, hgt * 0.6), Color("f8a030"))
			draw_rect(Rect2(xx, base.y - hgt * 0.25, 2, hgt * 0.25), Color("fff0a0"))
		if int(_t * 12.0 + bx) % 3 == 0:
			draw_rect(Rect2(base.x + sin(_t * 3.0) * 4.0, base.y - 14 - fmod(_t * 20.0, 8.0), 1, 1), Color("ffd060"))
