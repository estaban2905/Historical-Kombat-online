## Primitivas de dibujo (pixel art procedural) para los escenarios temáticos.
## Cada método op_xxx es una "operación" que las definiciones de escenario
## (stage_defs_*.gd) piden por nombre: ["mount", 176, 40, "5a3a6a", 7].
## Los sprites (soldados, criaturas) se dibujan con _at() + _r(): el origen
## está en los pies, +x hacia delante y y negativa hacia arriba.
class_name StageOps
extends Node2D

const W := 426
const H := 240

const CLOTH := ["c03030", "3a60b0", "d0a040", "508848", "8a4aa0", "e07030", "ddd2b8", "2a8a8a"]
const HAIRS := ["3a2418", "1a1a1a", "8a6a3a", "c8a050"]
const SKINS := ["f0c8a0", "d8a070", "b07848", "8a5a38"]

## Estilos de soldado: uni=torso, legs, boots, belt, trim, skin, helm (forma),
## hc (color del casco), plume, weap (arma), shield.
const STYLES := {
	"legion": {"uni": "b03030", "legs": "c8a070", "boots": "5a3a22", "helm": "legion", "hc": "c0c0c8", "plume": "b02828", "weap": "pilum", "shield": "b02828"},
	"hoplite": {"uni": "c8c0a0", "legs": "d8a878", "boots": "5a3a22", "helm": "corinth", "hc": "c89838", "plume": "c02828", "weap": "pike", "shield": "c89838"},
	"musket": {"uni": "2a4a9a", "legs": "e8e8e0", "boots": "1a1a1a", "trim": "e8e8e0", "helm": "shako", "hc": "1a1a1a", "plume": "c02828", "weap": "rifle"},
	"union": {"uni": "2a3a7a", "legs": "5a7ab0", "trim": "d8c040", "helm": "cap", "hc": "2a3a7a", "weap": "rifle"},
	"confed": {"uni": "8a8a90", "legs": "7a6a50", "helm": "cap", "hc": "7a7a68", "weap": "rifle"},
	"royal": {"uni": "c02020", "legs": "1a1a2a", "boots": "0a0a0a", "trim": "e8e0c0", "helm": "busby", "hc": "1a1a1a", "plume": "e8e8e8", "weap": "rifle"},
	"swiss": {"uni": "c8a020", "legs": "b02020", "trim": "2a3a8a", "helm": "beret", "hc": "1a1a1a", "weap": "halberd"},
	"kpa": {"uni": "7a7a48", "legs": "7a7a48", "trim": "d8c040", "helm": "cap", "hc": "7a7a48", "weap": "rifle"},
	"rusguard": {"uni": "3a5a3a", "legs": "2a2a2a", "trim": "d8c040", "helm": "ushanka", "hc": "8a8a8a", "weap": "rifle"},
	"soviet": {"uni": "6a5a38", "legs": "5a4a30", "helm": "ushanka", "hc": "5a4a30", "weap": "rifle"},
	"wehr": {"uni": "5a5a48", "legs": "4a4a40", "helm": "steel", "hc": "5a5a58", "weap": "rifle"},
	"fascist": {"uni": "1a1a1a", "legs": "1a1a1a", "trim": "d8d8d8", "helm": "fez", "hc": "1a1a1a", "weap": "rifle"},
	"chinese": {"uni": "b02828", "legs": "7a1818", "trim": "d8b040", "helm": "conical", "hc": "d8b040", "plume": "b02828", "weap": "spear"},
	"suit": {"uni": "1a1a24", "legs": "1a1a24", "boots": "0a0a0a", "trim": "e8e8e8", "helm": "hair", "hc": "2a2018", "skin": "f0c8a0", "weap": "none"},
	"marine": {"uni": "1a2a6a", "legs": "c8c8d8", "trim": "e8e8e8", "helm": "cap", "hc": "e8e8e8", "weap": "rifle"},
	"chavista": {"uni": "c02828", "legs": "2a3a6a", "helm": "cap", "hc": "c02828", "weap": "none"},
	"militia": {"uni": "5a6a38", "legs": "4a5a30", "helm": "beret", "hc": "b02020", "weap": "rifle"},
	"guerrilla": {"uni": "5a6a38", "legs": "4a5a30", "trim": "b02020", "helm": "cap", "hc": "4a5a30", "weap": "rifle"},
	"iraqi": {"uni": "7a6a40", "legs": "6a5a38", "helm": "beret", "hc": "1a1a1a", "weap": "rifle"},
	"mujahid": {"uni": "8a7a58", "legs": "7a6a48", "helm": "turban", "hc": "e8e0d0", "skin": "c89868", "weap": "rifle"},
	"mongol": {"uni": "3a5a8a", "legs": "5a3a22", "trim": "c8a030", "helm": "mong", "hc": "5a3a22", "skin": "d8a878", "weap": "sword"},
	"egypt": {"uni": "e8e0c0", "legs": "e8e0c0", "helm": "nemes", "hc": "2a5aa0", "plume": "d8b030", "skin": "c89868", "weap": "spear", "shield": "c89838"},
	"robe": {"uni": "e8e0d0", "legs": "e8e0d0", "boots": "8a6a4a", "helm": "hair", "hc": "5a3a22", "skin": "d8a878", "weap": "staff"},
	"monk": {"uni": "e07a1a", "legs": "e07a1a", "boots": "8a6a4a", "helm": "bald", "skin": "c89868", "weap": "none"},
	"cossack": {"uni": "6a2020", "legs": "1a1a2a", "trim": "d8c040", "helm": "papakha", "hc": "2a2a2a", "weap": "sword"},
	"sicario": {"uni": "e8e8e0", "legs": "3a4a6a", "helm": "vueltiao", "hc": "e0d8b0", "weap": "rifle"},
	"sailor": {"uni": "e0d8c0", "legs": "5a4a3a", "trim": "3a5a9a", "helm": "capknit", "hc": "b02020", "weap": "none"},
	"conquistador": {"uni": "8a8a90", "legs": "4a2a22", "trim": "b02020", "helm": "morion", "hc": "a0a0a8", "weap": "halberd"},
	"scientist": {"uni": "e8e8f0", "legs": "3a3a4a", "helm": "hair", "hc": "d8d8d8", "weap": "none"},
	"florentine": {"uni": "8a3a2a", "legs": "3a3a4a", "trim": "d8b040", "helm": "beret", "hc": "2a2a5a", "weap": "none"},
}

static var _cc := {}

var _t: float = 0.0
var _ex: float = 0.0
var _ox: float = 0.0
var _oy: float = 0.0
var _sc: float = 1.0
var _fl: float = 1.0

# --------------------------------------------------------------------------
#  Utilidades
# --------------------------------------------------------------------------
func _c(v) -> Color:
	if v is Color:
		return v
	var k := String(v)
	if not _cc.has(k):
		_cc[k] = Color(k)
	return _cc[k]

## Número pseudoaleatorio estable en [0,1).
func _h(i: int, s: int) -> float:
	return fposmod(sin(float(i) * 12.9898 + float(s) * 78.233) * 43758.5453, 1.0)

func _rect(x: float, y: float, w: float, h: float, col) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), maxf(1.0, floorf(w)), maxf(1.0, floorf(h))), _c(col))

func _at(x: float, y: float, sc: float = 1.0, face: float = 1.0) -> void:
	_ox = x
	_oy = y
	_sc = sc
	_fl = 1.0 if face >= 0.0 else -1.0

## Rectángulo de sprite: respeta origen, escala y espejo.
func _r(x: float, y: float, w: float, h: float, col) -> void:
	var px := _ox + (x if _fl > 0.0 else -x - w) * _sc
	var py := _oy + y * _sc
	draw_rect(Rect2(floorf(px), floorf(py), maxf(1.0, roundf(w * _sc)), maxf(1.0, roundf(h * _sc))), _c(col))

func _ring(x: float, y: float, r: float, col, w: float = 1.0) -> void:
	draw_arc(Vector2(_ox + x * _sc * _fl, _oy + y * _sc), r * _sc, 0.0, TAU, 14, _c(col), w)

func _sub(dx: float, dy: float, mult: float) -> Array:
	var s := [_ox, _oy, _sc, _fl]
	_ox += dx * _sc * _fl
	_oy += dy * _sc
	_sc *= mult
	return s

func _restore(s: Array) -> void:
	_ox = s[0]
	_oy = s[1]
	_sc = s[2]
	_fl = s[3]

func _style(name) -> Dictionary:
	return STYLES.get(name, STYLES["legion"])

func _crowd_style(i: int, seed: int) -> Dictionary:
	return {
		"uni": CLOTH[int(_h(i, seed + 3) * CLOTH.size())], "legs": "3a3a4a",
		"helm": "hair", "hc": HAIRS[int(_h(i, seed + 4) * HAIRS.size())],
		"skin": SKINS[int(_h(i, seed + 6) * SKINS.size())], "weap": "none",
	}

# --------------------------------------------------------------------------
#  Fondo y paisaje (estático)
# --------------------------------------------------------------------------
func op_sky(cols: Array, h: int = 176) -> void:
	var bh := ceili(float(h) / cols.size())
	for i in cols.size():
		draw_rect(Rect2(0, i * bh, W, bh), _c(cols[i]))

func op_rect(x, y, w, h, col) -> void:
	_rect(x, y, w, h, col)

func op_rects(list: Array) -> void:
	for r in list:
		_rect(r[0], r[1], r[2], r[3], r[4])

func op_circle(x, y, r, col) -> void:
	draw_circle(Vector2(x, y), r, _c(col))

func op_ring(x, y, r, col, w := 1.0) -> void:
	draw_arc(Vector2(x, y), r, 0.0, TAU, 20, _c(col), w)

func op_line(x1, y1, x2, y2, col, w := 1.0) -> void:
	draw_line(Vector2(x1, y1), Vector2(x2, y2), _c(col), w)

func op_poly(pts: Array, col) -> void:
	var v := PackedVector2Array()
	for i in range(0, pts.size() - 1, 2):
		v.append(Vector2(pts[i], pts[i + 1]))
	draw_colored_polygon(v, _c(col))

func op_stars(n: int, seed: int, ymax: int, col, twinkle := true) -> void:
	var c := _c(col)
	for i in n:
		if twinkle and sin(_t * 2.0 + i * 1.7) > 0.85:
			continue
		var s := 1 + int(_h(i, seed + 9) > 0.93)
		draw_rect(Rect2(floorf(_h(i, seed) * W), floorf(_h(i, seed + 7) * ymax), s, s), c)

func op_disc(x, y, r, c1, c2 := "") -> void:
	draw_circle(Vector2(x, y), r, _c(c1))
	if c2 != "":
		draw_circle(Vector2(x, y), maxf(r - 3.0, 1.0), _c(c2))

func op_glow(x, y, r, col, pulse := 0.15) -> void:
	var c := _c(col)
	var k := 1.0 + sin(_t * 2.0) * pulse
	for i in 4:
		c.a = 0.10 + i * 0.05
		draw_circle(Vector2(x, y), r * k * (1.0 - i * 0.22), c)

func op_clouds(n: int, seed: int, ymin: int, ymax: int, col, shade, speed := 2.0) -> void:
	for i in n:
		var w := 22.0 + _h(i, seed + 2) * 26.0
		var x := fposmod(_h(i, seed) * (W + 80.0) + _t * speed * (0.6 + _h(i, seed + 4)), W + 80.0) - 50.0
		var y := floorf(ymin + _h(i, seed + 1) * (ymax - ymin))
		draw_rect(Rect2(floorf(x), y, w, 3), _c(col))
		draw_rect(Rect2(floorf(x) + 4, y - 2, w - 10, 2), _c(col))
		draw_rect(Rect2(floorf(x) + 6, y + 3, w - 6, 1), _c(shade))

## Silueta de montañas/colinas. rough>1 = más picudas.
func op_mount(base: int, amp: float, col, seed: float = 1.0, snow := "", rough: float = 1.0) -> void:
	var c := _c(col)
	for x in range(0, W, 2):
		var n := 0.45 + 0.28 * sin(x * 0.018 * rough + seed) + 0.18 * sin(x * 0.047 * rough + seed * 2.3) + 0.08 * sin(x * 0.11 * rough + seed * 4.1)
		var h := int(amp * n)
		draw_rect(Rect2(x, base - h, 2, h + 2), c)
		if snow != "" and h > amp * 0.62:
			draw_rect(Rect2(x, base - h, 2, int((h - amp * 0.62) * 0.55) + 1), _c(snow))

## Hilera de edificios. ruin = parte superior rota; win = color de ventanas.
func op_skyline(base: int, col, seed: int, wmin: int, wmax: int, hmin: int, hmax: int, win := "", ruin := false, roof := false) -> void:
	var c := _c(col)
	var x := -6
	var i := 0
	while x < W:
		var w := wmin + int(_h(i, seed) * (wmax - wmin))
		var h := hmin + int(_h(i, seed + 1) * (hmax - hmin))
		if ruin:
			for cx in range(0, w, 3):
				var cut := int(_h(i * 31 + cx, seed + 2) * 14.0)
				draw_rect(Rect2(x + cx, base - h + cut, 3, h - cut + 2), c)
		else:
			draw_rect(Rect2(x, base - h, w, h + 2), c)
			draw_rect(Rect2(x, base - h, w, 1), c.lightened(0.15))
			if roof:
				for r in 4:
					draw_rect(Rect2(x + r, base - h - 4 + r, w - r * 2, 1), c.darkened(0.1))
		if win != "":
			var wc := _c(win)
			for wy in range(base - h + 4, base - 3, 5):
				for wx in range(x + 2, x + w - 2, 4):
					if _h(wx * 7 + wy, seed + 3) > 0.45:
						draw_rect(Rect2(wx, wy, 2, 2), wc)
		x += w + int(_h(i, seed + 5) * 3.0)
		i += 1

func op_grid(x, y, cols: int, rows: int, sx, sy, w, h, col) -> void:
	var c := _c(col)
	for j in rows:
		for i in cols:
			draw_rect(Rect2(x + i * sx, y + j * sy, w, h), c)

func op_col(x, top, bottom, width, marble := "ddd0b4", dark := "b8a888", light := "fff4dc") -> void:
	var h: float = bottom - top
	draw_rect(Rect2(x - width / 2 - 3, bottom - 5, width + 6, 5), _c(dark))
	draw_rect(Rect2(x - width / 2 - 4, top, width + 8, 4), _c(marble))
	draw_rect(Rect2(x - width / 2 - 4, top - 2, width + 8, 2), _c(light))
	draw_rect(Rect2(x - width / 2, top + 4, width, h - 9), _c(marble))
	for fx in range(int(x - width / 2) + 1, int(x + width / 2) - 1, 3):
		draw_rect(Rect2(fx, top + 4, 1, h - 9), _c(dark))
	draw_rect(Rect2(x + width / 2 - 2, top + 4, 2, h - 9), _c(dark))
	draw_rect(Rect2(x - width / 2, top + 4, 1, h - 9), _c(light))

func op_arch(x, base, w, h, col) -> void:
	var c := _c(col)
	draw_rect(Rect2(x, base - h + w / 2.0, w, h - w / 2.0), c)
	draw_circle(Vector2(x + w / 2.0, base - h + w / 2.0), w / 2.0, c)

func op_dome(x, base, r, c1, c2, tip := "") -> void:
	var h := int(r * 1.7)
	for k in h:
		var u := k / float(h)
		var half: float
		if u < 0.3:
			half = r * (0.45 + 0.55 * sqrt(maxf(1.0 - pow((0.3 - u) / 0.3, 2.0), 0.0)))
		else:
			half = r * (1.0 - pow((u - 0.3) / 0.7, 0.9))
		var hi := int(half)
		var y: float = base - k
		draw_rect(Rect2(x - hi, y, hi * 2 + 1, 1), _c(c1))
		for kx in range(-hi, hi + 1, 4):
			if (kx + k) % 4 == 0 or (kx + k) % 4 == 1:
				draw_rect(Rect2(x + kx, y, 1, 1), _c(c2))
	if tip != "":
		draw_rect(Rect2(x, base - h - 6, 1, 7), _c(tip))
		draw_rect(Rect2(x - 2, base - h - 4, 5, 1), _c(tip))

func op_hemi(x, base, r, c1, c2, lantern := "") -> void:
	for k in r:
		var half := int(sqrt(maxf(float(r * r - k * k), 0.0)))
		draw_rect(Rect2(x - half, base - k, half * 2 + 1, 1), _c(c1))
		draw_rect(Rect2(x + half * 0.45, base - k, maxf(half * 0.55, 1.0), 1), _c(c2))
	for rib in [-0.6, -0.3, 0.0, 0.3, 0.6]:
		draw_rect(Rect2(x + rib * r, base - r * 0.8, 1, r * 0.8), _c(c2))
	if lantern != "":
		draw_rect(Rect2(x - 3, base - r - 8, 6, 8), _c(lantern))
		draw_rect(Rect2(x - 1, base - r - 14, 2, 6), _c(lantern))

func op_tent(x, base, w, h, c1, c2 := "") -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(x - w / 2.0, base), Vector2(x, base - h), Vector2(x, base)]), _c(c1))
	draw_colored_polygon(PackedVector2Array([Vector2(x, base - h), Vector2(x + w / 2.0, base), Vector2(x, base)]), _c(c2 if c2 != "" else c1))

func op_yurt(x, base, w, c1, c2) -> void:
	var h := int(w * 0.42)
	draw_rect(Rect2(x - w / 2.0, base - h, w, h), _c(c1))
	draw_rect(Rect2(x - w / 2.0, base - h, w, 2), _c(c2))
	draw_colored_polygon(PackedVector2Array([Vector2(x - w / 2.0 - 2, base - h), Vector2(x, base - h - w * 0.28), Vector2(x + w / 2.0 + 2, base - h)]), _c(c1).darkened(0.08))
	draw_rect(Rect2(x - 3, base - h * 0.75, 6, h * 0.75), _c(c2).darkened(0.35))
	draw_rect(Rect2(x, base - h - w * 0.28 - 3, 1, 4), _c(c2))

func op_pyramid(x, base, w, c1, c2) -> void:
	var h: float = w * 0.52
	draw_colored_polygon(PackedVector2Array([Vector2(x - w / 2.0, base), Vector2(x, base - h), Vector2(x, base)]), _c(c1))
	draw_colored_polygon(PackedVector2Array([Vector2(x, base - h), Vector2(x + w / 2.0, base), Vector2(x, base)]), _c(c2))
	for i in range(1, int(h / 5.0)):
		var yy: float = base - i * 5.0
		var half: float = w / 2.0 * (1.0 - (i * 5.0) / h)
		draw_rect(Rect2(x - half, yy, half * 2, 1), _c(c2).darkened(0.12))

func op_palm(x, base, h, trunk := "7a5a38", leaf := "3a8a3a") -> void:
	var off := 0.0
	for i in int(h / 3.0):
		off = roundf(sin(i * 0.4) * 2.0)
		draw_rect(Rect2(x + off, base - (i + 1) * 3, 3, 3), _c(trunk).darkened(0.12 * (i % 2)))
	var top := Vector2(x + off + 1, base - h)
	var sway := sin(_t * 1.6 + x) * 0.6
	for k in 8:
		var a := -PI * 0.97 + k * (PI * 0.94 / 7.0)
		for j in range(1, 5):
			var px := top.x + cos(a) * j * 4.0
			var py := top.y + sin(a) * j * 3.0 + j * j * 0.7 + sway * j
			draw_rect(Rect2(floorf(px), floorf(py), 3, 2), _c(leaf) if k % 2 == 0 else _c(leaf).darkened(0.18))
	draw_rect(Rect2(top.x - 1, top.y + 1, 3, 3), _c(trunk).darkened(0.3))

func op_pine(x, base, h, col, snow := "") -> void:
	var tiers := 4
	var th: float = h / float(tiers)
	for k in tiers:
		var y: float = base - h + k * th * 0.85
		var w := 7.0 + k * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - w / 2, y + th * 1.2), Vector2(x, y), Vector2(x + w / 2, y + th * 1.2)]), _c(col))
		if snow != "":
			draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.22, y + th * 0.45), Vector2(x, y), Vector2(x + w * 0.22, y + th * 0.45)]), _c(snow))
	draw_rect(Rect2(x - 1, base - 3, 3, 3), _c("4a2e1a"))

func op_tree(x, base, h, leaf, trunk := "5a3a22") -> void:
	var c := _c(leaf)
	draw_rect(Rect2(x - 1, base - h * 0.55, 3, h * 0.55), _c(trunk))
	draw_circle(Vector2(x, base - h * 0.62), h * 0.34, c.darkened(0.18))
	draw_circle(Vector2(x - h * 0.2, base - h * 0.5), h * 0.24, c.darkened(0.1))
	draw_circle(Vector2(x + h * 0.2, base - h * 0.52), h * 0.24, c)
	draw_circle(Vector2(x - 2, base - h * 0.72), h * 0.2, c.lightened(0.12))

func op_wall(y, h, c1, c2, merlon := true) -> void:
	draw_rect(Rect2(0, y, W, h), _c(c1))
	draw_rect(Rect2(0, y, W, 2), _c(c1).lightened(0.15))
	if merlon:
		for x in range(0, W, 12):
			draw_rect(Rect2(x, y - 5, 7, 5), _c(c1))
			draw_rect(Rect2(x, y - 5, 7, 1), _c(c1).lightened(0.15))
	for row in range(1, int(h / 5.0)):
		draw_rect(Rect2(0, y + row * 5, W, 1), _c(c2))
		for x in range((row % 2) * 6, W, 12):
			draw_rect(Rect2(x, y + (row - 1) * 5, 1, 5), _c(c2))

func op_tower(x, base, w, h, c1, c2, roof := "") -> void:
	draw_rect(Rect2(x - w / 2.0, base - h, w, h), _c(c1))
	draw_rect(Rect2(x + w / 2.0 - 3, base - h, 3, h), _c(c2))
	for mx in range(int(x - w / 2.0), int(x + w / 2.0), 6):
		draw_rect(Rect2(mx, base - h - 4, 4, 4), _c(c1))
	draw_rect(Rect2(x - 3, base - 9, 6, 9), _c(c2).darkened(0.4))
	draw_rect(Rect2(x - 1, base - h * 0.6, 3, 5), _c(c2).darkened(0.4))
	if roof != "":
		op_tent(x, base - h - 4, w + 6, w * 0.7, roof, str(_c(roof).darkened(0.2).to_html()))

func op_flag(x, base, pole_h, w, h, c1, c2 := "", c3 := "") -> void:
	var top: float = base - pole_h
	var mode := String(c3)
	draw_rect(Rect2(x, top, 1, pole_h), _c("5a4a3a"))
	draw_rect(Rect2(x - 1, top - 2, 3, 2), _c("e6b43c"))
	for i in int(w):
		var off := roundf(sin(_t * 5.0 - i * 0.45) * minf(float(i), 5.0) * 0.4)
		var cx: float = x + 1 + i
		var cy: float = top + off
		draw_rect(Rect2(cx, cy, 1, h), _c(c1))
		if mode == "uk":
			draw_rect(Rect2(cx, cy + h * 0.33, 1, h * 0.34), _c("e8e8f0"))
			if i >= w * 0.4 and i <= w * 0.6:
				draw_rect(Rect2(cx, cy, 1, h), _c("e8e8f0"))
			draw_rect(Rect2(cx, cy + h * 0.43, 1, h * 0.14), _c("c01830"))
			if i >= w * 0.45 and i <= w * 0.55:
				draw_rect(Rect2(cx, cy, 1, h), _c("c01830"))
		elif mode.begins_with("tri:"):
			draw_rect(Rect2(cx, cy + h / 3.0, 1, h / 3.0), _c(c2))
			draw_rect(Rect2(cx, cy + h * 2.0 / 3.0, 1, h / 3.0), _c(mode.substr(4)))
		elif mode.begins_with("vtri:"):
			if i >= w / 3.0:
				draw_rect(Rect2(cx, cy, 1, h), _c(c2))
			if i >= w * 2.0 / 3.0:
				draw_rect(Rect2(cx, cy, 1, h), _c(mode.substr(5)))
		else:
			if c2 != "":
				draw_rect(Rect2(cx, cy + h / 3.0, 1, h / 3.0), _c(c2))
			if mode != "" and i < w * 0.4:
				draw_rect(Rect2(cx, cy, 1, h * 0.55), _c(mode))

## Estandarte colgante rectangular con emblema circular.
func op_banner(x, y, w, h, c1, c2, emblem := "") -> void:
	draw_rect(Rect2(x, y, w, h), _c(c1))
	draw_rect(Rect2(x, y, w, 2), _c(c2))
	draw_rect(Rect2(x, y + h - 2, w, 2), _c(c2))
	for i in int(w / 3.0):
		draw_rect(Rect2(x + i * 3, y + h, 2, 3), _c(c2))
	if emblem != "":
		draw_circle(Vector2(x + w / 2.0, y + h / 2.0), minf(w, h) * 0.28, _c("f0f0e8"))
		draw_circle(Vector2(x + w / 2.0, y + h / 2.0), minf(w, h) * 0.18, _c(emblem))

## Varios estandartes en fila (n, separados step px).
func op_banners(x0, n: int, step, y, w, h, c1, c2, emblem := "") -> void:
	for i in n:
		op_banner(x0 + i * step, y, w, h, c1, c2, emblem)

func op_text(x, y, text: String, size: int, col, align := 0, width := -1.0) -> void:
	HKTheme.draw_text(self, Vector2(x, y), text, size, _c(col), align, width, 0)

func op_ground(y: int, kind: String, c1, c2, c3 := "", seed: int = 1) -> void:
	var a := _c(c1)
	var b := _c(c2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	draw_rect(Rect2(0, y, W, H - y), a)
	draw_rect(Rect2(0, y, W, 2), _c(c3) if c3 != "" else b.darkened(0.3))
	match kind:
		"slabs":
			var row_y := y + 2
			var row_h := 5
			var row := 0
			while row_y < H:
				var slab_w := 22 + row * 6
				var x := -((row % 2) * slab_w / 2)
				while x < W:
					var shade := rng.randf_range(-0.07, 0.07)
					var col := a.lightened(shade) if shade > 0 else a.darkened(-shade)
					draw_rect(Rect2(x + 1, row_y + 1, slab_w - 1, row_h - 1), col)
					draw_rect(Rect2(x + 1, row_y + 1, slab_w - 1, 1), col.lightened(0.12))
					if rng.randf() < 0.18:
						draw_rect(Rect2(x + rng.randi_range(4, maxi(slab_w - 6, 5)), row_y + 2, 2, 1), b)
					x += slab_w
				row_y += row_h
				row_h += 2
				row += 1
		"planks":
			var row_y := y + 2
			var rh := 5
			while row_y < H:
				draw_rect(Rect2(0, row_y, W, rh - 1), a.lerp(b, rng.randf() * 0.35))
				draw_rect(Rect2(0, row_y + rh - 1, W, 1), b.darkened(0.3))
				var x := rng.randi_range(0, 40)
				while x < W:
					draw_rect(Rect2(x, row_y, 1, rh - 1), b.darkened(0.3))
					x += rng.randi_range(50, 110)
				row_y += rh
				rh += 1
		"checker":
			var row_y := y + 2
			var rh := 5
			var row := 0
			while row_y < H:
				var tw := 18 + row * 5
				var x := -tw
				var k := row % 2
				while x < W:
					draw_rect(Rect2(x, row_y, tw, rh), a if k == 0 else b)
					k = 1 - k
					x += tw
				row_y += rh
				rh += 2
				row += 1
		_:
			var row_y := y + 2
			var rh := 6
			var k := 0
			while row_y < H:
				if k % 2 == 1:
					draw_rect(Rect2(0, row_y, W, rh), a.darkened(0.05))
				row_y += rh
				rh += 2
				k += 1
			var alt := _c(c3) if c3 != "" else a.lightened(0.15)
			for i in 120:
				draw_rect(Rect2(rng.randi_range(0, W), rng.randi_range(y + 4, H), rng.randi_range(1, 4), 1), b if rng.randf() < 0.6 else alt)

## Agua con olas animadas.
func op_waves(y: int, h: int, c1, c2, c3) -> void:
	draw_rect(Rect2(0, y, W, h), _c(c1))
	var rows := int(h / 4.0)
	for r in rows:
		if r % 2 == 1:
			draw_rect(Rect2(0, y + r * 4, W, 2), _c(c2))
		for k in 9:
			var x := fposmod(k * 53.0 + r * 17.0 + _t * (6.0 + r * 2.0), W + 20.0) - 10.0
			draw_rect(Rect2(floorf(x), y + r * 4 + 1, 6 + (r % 3) * 3, 1), _c(c3))

# --------------------------------------------------------------------------
#  Cuerpos de sprite: soldados y criaturas (origen en los pies)
# --------------------------------------------------------------------------
func _soldier(s: Dictionary, ph: float, step: bool, cheer: bool) -> void:
	var skin = s.get("skin", "e0b080")
	var uni = s.get("uni", "666666")
	var legs = s.get("legs", uni)
	var boots = s.get("boots", "2a2018")
	var sw := 0
	if step:
		sw = 1 if sin(ph) > 0.0 else -1
	var l_up := 1 if sw > 0 else 0
	var r_up := 1 if sw < 0 else 0
	_r(-3, -7, 2, 6 - l_up, legs)
	_r(-3, -1 - l_up, 2, 1, boots)
	_r(1, -7, 2, 6 - r_up, legs)
	_r(1, -1 - r_up, 2, 1, boots)
	_r(-3, -15, 6, 8, uni)
	_r(-3, -9, 6, 1, s.get("belt", "2a1a10"))
	if s.has("trim"):
		_r(-1, -15, 1, 6, s.trim)
		_r(1, -14, 1, 5, s.trim)
	_r(-4, -14, 1, 6, uni)
	if cheer:
		_r(-4, -20, 1, 6, skin)
		_r(3, -20, 1, 6, skin)
	else:
		_r(3, -14, 1, 4, uni)
		_r(3, -11, 2, 2, skin)
	_r(-2, -20, 4, 5, skin)
	_r(1, -18, 1, 1, "20140c")
	if s.has("shield"):
		_r(-8, -16, 6, 10, s.shield)
		_r(-6, -12, 2, 2, "e0c040")
	var hc = s.get("hc", "444444")
	var pl = s.get("plume", "b02828")
	match s.get("helm", "none"):
		"legion":
			_r(-3, -22, 6, 3, hc)
			_r(-3, -25, 6, 2, pl)
		"corinth":
			_r(-3, -22, 6, 4, hc)
			_r(0, -20, 1, 3, hc)
			_r(-1, -28, 2, 6, pl)
		"shako":
			_r(-3, -22, 6, 1, hc)
			_r(-2, -27, 4, 5, hc)
			_r(-2, -24, 4, 1, "d8c040")
			_r(0, -30, 1, 3, pl)
		"steel":
			_r(-3, -22, 6, 3, hc)
			_r(-3, -19, 1, 2, hc)
		"busby":
			_r(-3, -28, 6, 9, hc)
			_r(2, -30, 1, 3, pl)
		"cap":
			_r(-3, -22, 6, 2, hc)
			_r(2, -20, 3, 1, hc)
			_r(0, -22, 1, 1, "d02020")
		"ushanka":
			_r(-3, -23, 6, 4, hc)
			_r(-4, -20, 1, 3, hc)
			_r(3, -20, 1, 3, hc)
		"beret":
			_r(-3, -22, 6, 2, hc)
			_r(-4, -21, 2, 2, hc)
		"mong":
			_r(-3, -22, 6, 2, hc)
			_r(-2, -24, 4, 2, hc)
			_r(-1, -26, 2, 2, hc)
			_r(3, -21, 1, 3, hc)
		"turban":
			_r(-3, -23, 6, 4, hc)
			_r(-3, -21, 6, 1, "b8b0a0")
		"conical":
			_r(-4, -21, 8, 1, hc)
			_r(-3, -23, 6, 2, hc)
			_r(-2, -25, 4, 2, hc)
			_r(-1, -27, 2, 2, hc)
			_r(0, -29, 1, 2, pl)
		"nemes":
			_r(-3, -22, 6, 3, hc)
			_r(-4, -19, 2, 6, hc)
			_r(2, -19, 2, 6, hc)
			_r(-3, -21, 6, 1, pl)
		"fez":
			_r(-2, -25, 4, 4, hc)
			_r(2, -24, 1, 3, "d8c040")
		"papakha":
			_r(-3, -26, 6, 6, hc)
			_r(-3, -26, 6, 1, "5a5a5a")
		"vueltiao":
			_r(-5, -21, 10, 1, hc)
			_r(-3, -24, 6, 3, hc)
			_r(-3, -22, 6, 1, "1a1a1a")
		"capknit":
			_r(-3, -22, 6, 3, hc)
			_r(-1, -24, 2, 2, hc)
		"morion":
			_r(-4, -21, 8, 1, hc)
			_r(-3, -23, 6, 2, hc)
			_r(-1, -26, 2, 3, hc)
		"hair":
			_r(-2, -21, 4, 2, hc)
			_r(-3, -20, 1, 3, hc)
	match s.get("weap", "none"):
		"rifle":
			_r(4, -25, 1, 17, "4a3a2a")
			_r(4, -28, 1, 3, "c8c8d0")
		"pilum", "spear":
			_r(5, -32, 1, 26, "6a4a2a")
			_r(5, -35, 1, 3, "d0d0d8")
		"pike":
			_r(5, -46, 1, 40, "7a5a30")
			_r(5, -49, 1, 3, "d0d0d8")
		"sword":
			_r(5, -24, 1, 12, "d8d8e0")
			_r(4, -13, 3, 1, "d8b040")
		"halberd":
			_r(5, -34, 1, 28, "6a4a2a")
			_r(6, -33, 3, 4, "c8c8d0")
			_r(5, -36, 1, 3, "c8c8d0")
		"staff":
			_r(5, -30, 1, 28, "6a4a2a")

func _k_horse(coat, mane, ph: float, rider) -> void:
	var dk := _c(coat).darkened(0.25)
	var b1 := 2 if sin(ph) > 0.0 else 0
	var b2 := 2 if sin(ph) <= 0.0 else 0
	var f1 := 2 if sin(ph + 1.5) > 0.0 else 0
	var f2 := 2 if sin(ph + 1.5) <= 0.0 else 0
	_r(-10, -10, 2, 10 - b1, dk)
	_r(-7, -10, 2, 10 - b2, coat)
	_r(5, -10, 2, 10 - f1, dk)
	_r(8, -10, 2, 10 - f2, coat)
	_r(-11, -18, 22, 9, coat)
	_r(-11, -11, 22, 2, dk)
	_r(8, -26, 5, 10, coat)
	_r(11, -27, 7, 4, coat)
	_r(16, -25, 3, 3, dk)
	_r(11, -29, 2, 2, coat)
	_r(14, -26, 1, 1, "101010")
	_r(7, -27, 2, 11, mane)
	_r(-14, -18, 3, 3, mane)
	_r(-15, -15, 2, 9, mane)
	if rider is String and rider != "":
		var s := _sub(0, -17, 0.75)
		_soldier(_style(rider), ph, false, false)
		_restore(s)

func _k_camel(coat, shade, ph: float) -> void:
	var l1 := 2 if sin(ph) > 0.0 else 0
	var l2 := 2 if sin(ph) <= 0.0 else 0
	_r(-9, -12, 2, 12 - l1, shade)
	_r(-5, -12, 2, 12 - l2, coat)
	_r(4, -12, 2, 12 - l2, shade)
	_r(7, -12, 2, 12 - l1, coat)
	_r(-11, -20, 22, 8, coat)
	_r(-8, -25, 6, 5, coat)
	_r(1, -25, 6, 5, coat)
	_r(-8, -21, 14, 2, "b02828")
	_r(9, -30, 3, 12, coat)
	_r(10, -33, 3, 5, coat)
	_r(11, -34, 7, 3, coat)
	_r(16, -32, 3, 2, shade)
	_r(12, -33, 1, 1, "101010")
	_r(-13, -19, 2, 6, shade)

func _k_elephant(skin, rider, ph: float) -> void:
	var dk := _c(skin).darkened(0.22)
	var l1 := 1 if sin(ph * 0.5) > 0.0 else 0
	_r(-14, -14, 6, 14 - l1, dk)
	_r(-6, -14, 6, 14 - (1 - l1), skin)
	_r(4, -14, 6, 14 - (1 - l1), dk)
	_r(11, -14, 6, 14 - l1, skin)
	_r(-18, -34, 36, 22, skin)
	_r(-18, -16, 36, 4, dk)
	_r(14, -40, 14, 18, skin)
	_r(10, -38, 6, 13, dk)
	_r(22, -35, 1, 1, "101010")
	_r(24, -25, 6, 2, "f4f0e0")
	for i in 6:
		var sway := roundf(sin(_t * 2.0 + i * 0.5) * 1.5 * i / 5.0)
		_r(25 + sway, -28 + i * 4, 4, 4, skin)
	_r(-20, -30, 2, 12, dk)
	_r(-8, -40, 16, 6, "8a3a20")
	_r(-10, -42, 20, 2, "d8b040")
	_r(-8, -34, 16, 2, "d8b040")
	if rider is String and rider != "":
		var s := _sub(0, -41, 0.7)
		_soldier(_style(rider), ph, false, false)
		_restore(s)

func _k_hippo(skin, ph: float) -> void:
	var dk := _c(skin).darkened(0.25)
	_r(-12, -4, 4, 4, dk)
	_r(-4, -4, 4, 4, dk)
	_r(5, -4, 4, 4, dk)
	_r(-14, -13, 28, 10, skin)
	_r(-14, -6, 28, 2, dk)
	_r(12, -14, 12, 10, skin)
	_r(14, -17, 2, 3, skin)
	_r(19, -17, 2, 3, skin)
	_r(22, -12, 1, 1, dk)
	_r(17, -13, 1, 1, "101010")
	if sin(_t * 1.5 + ph * 0.1) > 0.85:
		_r(14, -7, 10, 3, "d89898")
		_r(15, -8, 2, 1, "f4f0e0")

func _k_tortoise(shell, skin, ph: float) -> void:
	for i in 7:
		_r(-11 + i, -4 - i, 22 - i * 2, 1, shell)
		if i % 2 == 0:
			_r(-6 + i, -4 - i, 1, 1, _c(shell).darkened(0.3))
			_r(2 - i / 2, -4 - i, 1, 1, _c(shell).darkened(0.3))
	_r(-11, -4, 22, 1, _c(shell).darkened(0.25))
	var ext := roundf(sin(_t * 0.8 + ph * 0.1))
	_r(10, -6, 4 + ext, 3, skin)
	_r(13 + ext, -8, 4, 4, skin)
	_r(15 + ext, -7, 1, 1, "101010")
	var lift := 1 if sin(ph * 0.4) > 0.0 else 0
	_r(-8, -3, 4, 3 - lift, skin)
	_r(4, -3, 4, 3 - (1 - lift), skin)
	_r(-13, -3, 3, 1, skin)

func _k_iguana(col, ph: float) -> void:
	var dk := _c(col).darkened(0.3)
	_r(-8, -5, 14, 3, col)
	_r(6, -6, 5, 3, col)
	_r(9, -5, 1, 1, "d02020")
	for i in 6:
		_r(-6 + i * 2, -6, 1, 1, dk)
	var wag := roundf(sin(_t * 2.0 + ph * 0.1) * 1.0)
	_r(-14, -4, 7, 2, col)
	_r(-19, -3 + wag, 5, 1, col)
	_r(-5, -2, 2, 2, dk)
	_r(3, -2, 2, 2, dk)

func _k_wolf(coat, ph: float) -> void:
	var dk := _c(coat).darkened(0.28)
	var l := 1 if sin(ph) > 0.0 else 0
	_r(-8, -5, 2, 5 - l, dk)
	_r(-4, -5, 2, 5 - (1 - l), coat)
	_r(4, -5, 2, 5 - (1 - l), dk)
	_r(7, -5, 2, 5 - l, coat)
	_r(-8, -11, 16, 6, coat)
	_r(7, -15, 6, 5, coat)
	_r(12, -13, 3, 2, dk)
	_r(8, -17, 2, 2, coat)
	_r(11, -14, 1, 1, "f0d020")
	_r(-12, -10, 4, 3, coat)

func _k_bear(coat, ph: float) -> void:
	var dk := _c(coat).darkened(0.28)
	var l := 1 if sin(ph) > 0.0 else 0
	_r(-13, -8, 6, 8 - l, dk)
	_r(-5, -8, 5, 8 - (1 - l), coat)
	_r(3, -8, 5, 8 - (1 - l), dk)
	_r(9, -8, 5, 8 - l, coat)
	_r(-14, -20, 26, 14, coat)
	_r(-6, -23, 10, 3, coat)
	_r(10, -22, 10, 9, coat)
	_r(18, -17, 4, 4, "3a2a1a")
	_r(11, -24, 3, 3, coat)
	_r(15, -20, 1, 1, "101010")
	_r(21, -17, 1, 1, "101010")

func _k_sheep(wool, ph: float) -> void:
	var l := 1 if sin(ph) > 0.0 else 0
	_r(-4, -2, 1, 2 - l, "3a3030")
	_r(3, -2, 1, 2 - (1 - l), "3a3030")
	_r(-6, -9, 12, 7, wool)
	_r(-7, -8, 1, 4, wool)
	_r(-5, -10, 8, 1, wool)
	_r(6, -9, 4, 4, "3a3030")

func _k_corgi(ph: float) -> void:
	var l := 1 if sin(ph * 1.5) > 0.0 else 0
	_r(-4, -2, 1, 2 - l, "c07838")
	_r(3, -2, 1, 2 - (1 - l), "c07838")
	_r(-5, -5, 10, 4, "d89048")
	_r(-4, -2, 8, 1, "f4f0e0")
	_r(4, -8, 5, 4, "d89048")
	_r(4, -10, 2, 2, "d89048")
	_r(7, -10, 2, 2, "d89048")
	_r(8, -6, 2, 2, "f4f0e0")
	_r(-6, -6, 1, 2, "d89048")

func _k_sphinx(stone) -> void:
	var dk := _c(stone).darkened(0.2)
	_r(-18, -12, 34, 12, stone)
	_r(-18, -2, 34, 2, dk)
	_r(8, -3, 16, 3, stone)
	_r(6, -20, 10, 10, stone)
	_r(8, -32, 10, 12, stone)
	_r(6, -32, 3, 16, "2a5aa0")
	_r(17, -32, 2, 14, "2a5aa0")
	_r(8, -34, 10, 2, "d8b030")
	_r(14, -26, 1, 1, "101010")
	_r(16, -22, 2, 2, dk)
	_r(-20, -6, 3, 6, dk)

func _k_tank(col, ph: float) -> void:
	var dk := _c(col).darkened(0.3)
	var bump := 1 if sin(ph) > 0.8 else 0
	_r(-18, -6 - bump, 36, 6, "2a2a24")
	for i in 5:
		_r(-15 + i * 7, -5 - bump, 4, 4, "4a4a40")
	_r(-16, -12 - bump, 32, 6, col)
	_r(-6, -19 - bump, 14, 7, col)
	_r(-6, -19 - bump, 14, 1, dk)
	_r(8, -17 - bump, 20, 2, dk)
	_r(-2, -16 - bump, 3, 3, "d02020")

func _k_missile(ph: float) -> void:
	_r(-22, -8, 44, 4, "3a4a3a")
	_r(14, -18, 10, 10, "4a5a4a")
	_r(18, -16, 4, 4, "8ab0c0")
	for x in [-18, -8, 2, 16]:
		_r(x, -5, 5, 5, "101010")
	_r(-20, -17, 32, 5, "d8d8d0")
	_r(12, -17, 4, 5, "c02020")
	_r(-20, -19, 4, 2, "a8a8a0")
	_r(-20, -12, 4, 2, "a8a8a0")

func _k_ship(hull, sail, ph: float) -> void:
	var sway := sin(_t * 1.4 + ph * 0.05) * 1.5
	_oy += sway * _sc
	_r(-20, -6, 40, 6, hull)
	_r(-20, -6, 40, 1, _c(hull).lightened(0.25))
	_r(18, -10, 4, 4, hull)
	_r(-20, -12, 9, 6, hull)
	_r(-2, -40, 2, 34, "4a3220")
	_r(10, -30, 2, 24, "4a3220")
	_r(-12, -37, 20, 17, sail)
	_r(-4, -34, 4, 11, "c02020")
	_r(-8, -30, 12, 3, "c02020")
	_r(6, -28, 12, 12, sail)
	_r(10, -26, 4, 8, "c02020")
	_r(-1, -43, 6, 3, "c02020")
	for i in 4:
		_r(-16 + i * 9, -4, 3, 3, "20140c")

func _k_plane(ph: float) -> void:
	_r(-12, -5, 24, 4, "f0f0e8")
	_r(-12, -4, 24, 1, "c02020")
	_r(-6, -9, 12, 2, "e0e0d8")
	_r(-14, -11, 3, 7, "f0f0e8")
	_r(12, -6, 3, 4, "8a8a90")
	_r(-1, -6, 4, 2, "8ab0c0")
	var pr := 6 if int(_t * 24.0) % 2 == 0 else 3
	_r(15, -4 - pr / 2.0, 1, pr, "3a3a3a")

func _k_cannon() -> void:
	_r(-6, -9, 18, 4, "3a3a3a")
	_r(11, -10, 3, 6, "2a2a2a")
	_r(-8, -6, 12, 3, "6a4a2a")
	_ring(-2, -4, 4, "5a3a22", 2.0)
	_ring(-2, -4, 1, "d8c040")

func _k_bird(col, ph: float) -> void:
	if sin(ph) > 0.0:
		_r(-5, -3, 3, 1, col)
		_r(-2, -2, 4, 1, col)
		_r(2, -3, 3, 1, col)
	else:
		_r(-5, -1, 3, 1, col)
		_r(-2, -2, 4, 1, col)
		_r(2, -1, 3, 1, col)
	_r(-1, -3, 2, 2, col)

func _k_dove(ph: float) -> void:
	_k_bird("f4f4f0", ph)

## Despacha un sprite por nombre. a/b = colores, rider = estilo de jinete/estilo.
func _kind(kind: String, a, b, ph: float, rider) -> void:
	match kind:
		"horse": _k_horse(a, b, ph, rider)
		"camel": _k_camel(a, b, ph)
		"elephant": _k_elephant(a, rider, ph)
		"hippo": _k_hippo(a, ph)
		"tortoise": _k_tortoise(a, b, ph)
		"iguana": _k_iguana(a, ph)
		"wolf": _k_wolf(a, ph)
		"bear": _k_bear(a, ph)
		"sheep": _k_sheep(a, ph)
		"corgi": _k_corgi(ph)
		"sphinx": _k_sphinx(a)
		"tank": _k_tank(a, ph)
		"missile": _k_missile(ph)
		"ship": _k_ship(a, b, ph)
		"plane": _k_plane(ph)
		"cannon": _k_cannon()
		"bird": _k_bird(a, ph)
		"soldier": _soldier(_style(a), ph, true, false)

func op_sprite(kind: String, x, y, sc := 1.0, face := 1, a := "", b := "", rider := "") -> void:
	_at(x, y, sc, face)
	_kind(kind, a, b, _t * 7.0, rider)

## Va y viene entre x0 y x1.
func op_patrol(kind: String, y, x0, x1, period := 8.0, sc := 1.0, phase := 0.0, a := "", b := "", rider := "") -> void:
	var u := fposmod(_t / period + phase, 1.0)
	var tri := 1.0 - absf(2.0 * u - 1.0)
	_at(lerpf(x0, x1, tri), y, sc, 1.0 if u < 0.5 else -1.0)
	_kind(kind, a, b, _t * 7.0 + phase * 10.0, rider)

## Cruza la pantalla sin parar (speed<0 = hacia la izquierda).
func op_travel(kind: String, y, speed, sc := 1.0, count := 1, seed := 1, a := "", b := "", rider := "") -> void:
	var dir := 1.0 if speed >= 0.0 else -1.0
	for i in count:
		var x := fposmod(_h(i, seed) * (W + 120.0) + _t * speed, W + 120.0) - 60.0
		_at(x, y + (i % 2) * 3.0, sc, dir)
		_kind(kind, a, b, _t * 9.0 + i * 2.0, rider)

func op_soldier(x, y, style, sc := 1.0, face := 1) -> void:
	_at(x, y, sc, face)
	_soldier(_style(style), _t * 6.0, false, _ex > 0.35 and sin(_t * 5.0) > 0.2)

## Filas de soldados/público. march = marchan al mismo paso.
func op_formation(x0, x1, y, spacing, style, seed := 1, sc := 1.0, rows := 1, dy := 4.0, march := false, face := 0, weap := "") -> void:
	var base: Dictionary = _style(style)
	if weap != "":
		base = base.duplicate()
		base["weap"] = weap
	var n := int((x1 - x0) / spacing) + 1
	for r in rows:
		for k in n:
			var idx := r * 100 + k
			var xx: float = x0 + k * spacing + (r % 2) * spacing * 0.5 + (_h(idx, seed) - 0.5) * 2.0
			var yy: float = y + r * dy
			var ph := _h(idx, seed + 5) * TAU
			var f := float(face)
			if face == 0:
				f = 1.0 if xx < W * 0.5 else -1.0
			var s: Dictionary = _crowd_style(idx, seed) if style == "crowd" else base
			var wave := sin(_t * (3.0 + _h(idx, seed + 9) * 3.0) + ph)
			var bob := 0.0
			if wave > 0.7 - _ex * 0.9:
				bob = -1.0 - floorf(_ex * 2.0)
			var cheer := _ex > 0.35 and wave > 0.2
			if march:
				ph = _t * 6.0
				bob = -1.0 if sin(_t * 6.0) > 0.6 else 0.0
				cheer = false
			_at(xx, yy + bob, sc, f)
			_soldier(s, ph, march, cheer)

func op_birds(n: int, seed: int, ymin, ymax, speed := 14.0, col := "202020", sc := 1.0) -> void:
	for i in n:
		var dir := 1.0 if i % 2 == 0 else -1.0
		var x := fposmod(_h(i, seed) * (W + 40.0) + _t * speed * dir * (0.7 + _h(i, seed + 1) * 0.6), W + 40.0) - 20.0
		var y: float = ymin + _h(i, seed + 2) * (ymax - ymin) + sin(_t * 1.5 + i) * 3.0
		_at(x, y, sc, dir)
		_k_bird(col, _t * 10.0 + i * 2.0)

func op_dragon(y, amp, speed, c1, c2) -> void:
	var hx := fposmod(_t * speed, W + 200.0) - 40.0
	var segs := 18
	for i in segs:
		var sx := hx - i * 6.0
		if sx < -10.0 or sx > W + 10.0:
			continue
		var sy: float = y + sin(_t * 2.2 - i * 0.45) * amp
		var col := _c(c1).lerp(_c(c2), i / float(segs))
		var sz := 7.0 - i * 0.18
		draw_rect(Rect2(floorf(sx), floorf(sy), sz, sz), col)
		if i % 3 == 1:
			draw_rect(Rect2(floorf(sx) + 2, floorf(sy) - 2, 2, 2), _c("f0d040"))
	var hy: float = y + sin(_t * 2.2) * amp
	draw_rect(Rect2(floorf(hx) + 4, floorf(hy) - 2, 10, 8), _c(c1))
	draw_rect(Rect2(floorf(hx) + 12, floorf(hy) + 1, 5, 4), _c(c1).lightened(0.1))
	draw_rect(Rect2(floorf(hx) + 6, floorf(hy) - 5, 2, 4), _c("f0d040"))
	draw_rect(Rect2(floorf(hx) + 9, floorf(hy) - 4, 2, 3), _c("f0d040"))
	draw_rect(Rect2(floorf(hx) + 9, floorf(hy), 2, 2), _c("fff8d0"))
	draw_rect(Rect2(floorf(hx) + 16, floorf(hy) + 4, 8, 1), _c("f0d040"))

# --------------------------------------------------------------------------
#  Efectos animados
# --------------------------------------------------------------------------
func op_snow(n: int, col := "ffffff", speed := 22.0, drift := 6.0) -> void:
	var c := _c(col)
	for i in n:
		var x := fposmod(_h(i, 3) * W + sin(_t * 0.8 + i) * drift, W)
		var y := fposmod(_h(i, 8) * H + _t * speed * (0.6 + _h(i, 4) * 0.8), H)
		draw_rect(Rect2(floorf(x), floorf(y), 1 + int(i % 5 == 0), 1 + int(i % 5 == 0)), c)

func op_rain(n: int, col := "a8b8d0", speed := 220.0) -> void:
	var c := _c(col)
	for i in n:
		var x := fposmod(_h(i, 5) * (W + 40.0) - _t * speed * 0.2, W + 40.0) - 20.0
		var y := fposmod(_h(i, 6) * H + _t * speed, H)
		draw_line(Vector2(x, y), Vector2(x - 2, y + 5), c, 1.0)

func op_embers(n: int, col := "ffb040", speed := 14.0) -> void:
	var c := _c(col)
	for i in n:
		var x := fposmod(_h(i, 11) * W + sin(_t + i) * 8.0, W)
		var y := H - fposmod(_h(i, 12) * H + _t * speed * (0.6 + _h(i, 13)), H)
		c.a = 0.4 + 0.6 * _h(i, 14)
		draw_rect(Rect2(floorf(x), floorf(y), 1, 1), c)

func op_smoke(x, y, n := 5, col := "5a5048", rise := 50.0, spread := 1.0) -> void:
	for i in n:
		var u := fposmod(_t * 0.25 + i / float(n), 1.0)
		var c := _c(col)
		c.a = (1.0 - u) * 0.6
		draw_circle(Vector2(x + sin(_t + i * 2.0) * 3.0 + u * 10.0 * spread, y - u * rise), 3.0 + u * 7.0, c)

func op_fire(x, y, w := 12, ex_boost := 4.0) -> void:
	var n := int(w / 2.0)
	for i in n:
		var f := sin(_t * 9.0 + i * 1.7 + x)
		var hgt := 6.0 + f * 2.0 + _ex * ex_boost - absf(i - n / 2.0 + 0.5) * 1.2
		var xx: float = x - w / 2.0 + i * 2
		draw_rect(Rect2(xx, y - hgt, 2, hgt), _c("e04020"))
		draw_rect(Rect2(xx, y - hgt * 0.6, 2, hgt * 0.6), _c("f8a030"))
		draw_rect(Rect2(xx, y - hgt * 0.25, 2, hgt * 0.25), _c("fff0a0"))

func op_lightning(x, y, tx, ty, n := 3, col := "a8d8ff", seed := 1, spread := 60.0) -> void:
	var frame := int(_t * 12.0)
	for k in n:
		if fposmod(_t * 2.3 + k * 0.37, 1.0) > 0.55:
			continue
		var pts := PackedVector2Array([Vector2(x, y)])
		var ex: float = tx + (_h(frame + k, seed + 20) - 0.5) * spread * 2.0
		for j in range(1, 7):
			var u := j / 6.0
			pts.append(Vector2(lerpf(x, ex, u) + (_h(frame * 7 + k * 3 + j, seed) - 0.5) * 14.0, lerpf(y, ty, u)))
		var c := _c(col)
		c.a = 0.35
		draw_polyline(pts, c, 4.0)
		draw_polyline(pts, _c("ffffff"), 1.0)

func op_beams(n: int, col := "c8d8ff40", x0 := 30, x1 := 396, base := 176) -> void:
	for k in n:
		var bx: float = lerpf(x0, x1, (k + 0.5) / float(n))
		var lean := sin(_t * 0.6 + k * 1.3) * 0.08
		var c := _c(col)
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 7, base), Vector2(bx + 7, base),
			Vector2(bx + 3 + lean * base, 0), Vector2(bx - 3 + lean * base, 0)]), c)

func op_fireworks(n: int, seed: int, cols: Array) -> void:
	for k in n:
		var u := fposmod(_t / 2.4 + _h(k, seed), 1.0)
		if u > 0.7:
			continue
		var cx := 40.0 + _h(k, seed + 3) * 340.0
		var cy := 20.0 + _h(k, seed + 5) * 60.0
		var rad := u / 0.7 * 24.0
		var c := _c(cols[k % cols.size()])
		c.a = 1.0 - u / 0.7
		for s in 14:
			var a := s * TAU / 14.0
			draw_rect(Rect2(floorf(cx + cos(a) * rad), floorf(cy + sin(a) * rad + u * u * 12.0), 2, 2), c)

func op_cannonfire(x, y, face := 1, period := 5.0, seed := 0.0) -> void:
	var u := fposmod(_t / period + seed * 0.37, 1.0)
	var mx: float = x + face * 14.0
	if u < 0.06:
		draw_circle(Vector2(mx, y - 8), 6.0, _c("fff0a0"))
		draw_circle(Vector2(mx, y - 8), 3.0, _c("ffffff"))
	elif u < 0.5:
		var k := (u - 0.06) / 0.44
		var c := _c("9a9288")
		c.a = (1.0 - k) * 0.7
		draw_circle(Vector2(mx + face * k * 24.0, y - 8 - k * 14.0), 4.0 + k * 9.0, c)

func op_orbit(cx, cy, rx, ry, period, r, col, phase := 0.0) -> void:
	var a: float = _t / period * TAU + phase
	draw_circle(Vector2(cx + cos(a) * rx, cy + sin(a) * ry), r, _c(col))

func op_planet(x, y, r, c1, c2, ring := "") -> void:
	if ring != "":
		draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.28))
		draw_arc(Vector2.ZERO, r * 1.7, PI, TAU, 24, _c(ring), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(x, y), r, _c(c1))
	draw_circle(Vector2(x + r * 0.25, y + r * 0.2), r * 0.72, _c(c2))
	if ring != "":
		draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.28))
		draw_arc(Vector2.ZERO, r * 1.7, 0.0, PI, 24, _c(ring), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func op_galaxy(x, y, r, col, seed := 1) -> void:
	var c := _c(col)
	for i in 110:
		var a := i * 0.22 + _t * 0.05
		var rr: float = i / 110.0 * r
		c.a = 0.9 - i / 160.0
		draw_rect(Rect2(floorf(x + cos(a) * rr), floorf(y + sin(a) * rr * 0.45), 1, 1), c)
		draw_rect(Rect2(floorf(x + cos(a + PI) * rr), floorf(y + sin(a + PI) * rr * 0.45), 1, 1), c)

func op_clock(x, y, r) -> void:
	draw_circle(Vector2(x, y), r, _c("e8e0c8"))
	draw_arc(Vector2(x, y), r, 0.0, TAU, 16, _c("5a3a22"), 1.0)
	var a := _t * 1.5
	draw_line(Vector2(x, y), Vector2(x + cos(a) * r * 0.8, y + sin(a) * r * 0.8), _c("201810"), 1.0)
	draw_line(Vector2(x, y), Vector2(x + cos(a / 12.0) * r * 0.5, y + sin(a / 12.0) * r * 0.5), _c("201810"), 1.0)

func op_gear(x, y, r, col, speed := 1.0) -> void:
	for k in 8:
		var a := _t * speed + k * TAU / 8.0
		draw_rect(Rect2(floorf(x + cos(a) * (r + 1)) - 1, floorf(y + sin(a) * (r + 1)) - 1, 3, 3), _c(col))
	draw_arc(Vector2(x, y), r, 0.0, TAU, 14, _c(col), 3.0)
	draw_rect(Rect2(x - 1, y - 1, 3, 3), _c("201810"))

func op_bubbles(x, y, n := 6, col := "80ffa0", rise := 24.0) -> void:
	var c := _c(col)
	for i in n:
		var u := fposmod(_t * 0.6 + i / float(n), 1.0)
		c.a = 1.0 - u
		draw_rect(Rect2(floorf(x + sin(_t * 3.0 + i * 2.0) * 2.0 + (i % 3) - 1), floorf(y - u * rise), 1 + i % 2, 1 + i % 2), c)

func op_flicker(x, y, r, col) -> void:
	var c := _c(col)
	c.a = 0.18 + 0.12 * sin(_t * 17.0 + x) * sin(_t * 5.0)
	draw_circle(Vector2(x, y), r, c)
