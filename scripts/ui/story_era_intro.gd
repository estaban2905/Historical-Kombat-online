## Animación de arranque de cada época del MODO HISTORIA (~8 s), con la voz del Nexo:
##   0 El mundo actual      ciudad de neón, gritos y señal que se corta
##   1 El siglo XX          película vieja, relojes al revés y sirenas
##   2 Revoluciones         engranajes, chispas y bobinas de Tesla
##   3 Imperios             un mapa antiguo, una ruta y un barco
##   4 La antigüedad        sol enorme, columnas y dunas
##   5 El Nexo              la grieta se abre y aparece la esfera
## Todo se dibuja por código. La voz sale de tools/gen_story_voice.py (mismo texto que ERAS) y la
## música es un tramo de la intro (assets/music/intro.ogg). `finished` se emite al acabar o al
## saltarla (skip()). `chapter` se asigna antes de añadirla al árbol.
class_name StoryEraIntro
extends Control

signal finished

const W := 426.0
const H := 240.0
const VOICE_AT := 1.0
const TAIL := 1.0
const FADE_IN := 0.5
const FADE_OUT := 0.6
const MUSIC_FROM := 66.0
const VOID := Color("07040c")
const NEXO_GOLD := Color("ffd24a")
const CYAN := Color("35e6ff")
const VIOLET := Color("9a4dff")

## Por época: título, subtítulos (mismo texto que la voz) y duración de la voz (s).
const ERAS: Array = [
	{"title": "FRAGMENTO I · EL MUNDO ACTUAL", "len": 8.41,
		"subs": ["CADA ÉPOCA ES AHORA UN FRAGMENTO ROTO.", "ESTE LO GOBIERNAN LOS QUE GRITAN MÁS FUERTE."]},
	{"title": "FRAGMENTO II · EL SIGLO XX", "len": 5.60,
		"subs": ["UN SIGLO DE GUERRAS.", "EL TIEMPO AÚN SANGRA."]},
	{"title": "FRAGMENTO III · REVOLUCIONES, IMPERIOS Y DESCUBRIMIENTOS", "len": 9.56,
		"subs": ["IDEAS, REINOS Y FLOTAS: PODER DE SOBRA", "Y POCA MEMORIA. AQUÍ SE FORJÓ EL MUNDO MODERNO."]},
	{"title": "FRAGMENTO IV · IMPERIOS Y DESCUBRIMIENTOS", "len": 7.85,
		"subs": ["REINOS, FLOTAS Y CORONAS.", "DEMASIADO PODER, POCA MEMORIA."]},
	{"title": "FRAGMENTO IV · LA ANTIGÜEDAD Y LA EDAD MEDIA", "len": 7.82,
		"subs": ["LA CUNA DE LA HISTORIA.", "AQUÍ NACIÓ EL PODER, Y AQUÍ DECIDES CÓMO TERMINA."]},
	{"title": "EL JUICIO DEL NEXO", "len": 6.10,
		"subs": ["HAS LLEGADO HASTA MÍ.", "DEMUESTRA QUE MERECES EL TIEMPO."]},
]

var chapter: int = 0
## Qué animación (índice de ERAS) usa cada época del modo Historia: las épocas 3 y 4 reutilizan la de las revoluciones
## y la de la antigüedad, y el Nexo la suya.
const ERA_ART: Array[int] = [0, 1, 2, 4, 5]
## >= 0 congela el reloj en ese instante y no reproduce audio (capturas de pantalla).
var preview_time: float = -1.0

var _t: float = 0.0
var _done: bool = false
var _voice: AudioStreamPlayer
var _voice_started: bool = false
var _music: AudioStreamPlayer
var _idx: int = 0
var _end: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_idx = ERA_ART[clampi(chapter, 0, ERA_ART.size() - 1)]
	_end = VOICE_AT + float(ERAS[_idx]["len"]) + TAIL
	if preview_time >= 0.0:
		_t = preview_time
		return
	_voice = AudioStreamPlayer.new()
	_voice.stream = load("res://assets/sounds/story/era_%d.wav" % (_idx + 1)) as AudioStream
	_voice.volume_db = 2.0
	add_child(_voice)
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/music/intro.ogg") as AudioStream
	_music.volume_db = -14.0
	add_child(_music)
	_music.play(MUSIC_FROM)

## Salta la animación (la tarjeta de la época la gestiona quien la llama).
func skip() -> void:
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	if _voice:
		_voice.stop()
	if _music:
		_music.stop()
	finished.emit()
	queue_free()

static func _h(i: float) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)

static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _ph(a: float, b: float) -> float:
	return clampf((_t - a) / (b - a), 0.0, 1.0)

func _process(delta: float) -> void:
	if preview_time < 0.0:
		_t += delta
		if _t >= _end:
			_finish()
			return
		if not _voice_started and _t >= VOICE_AT:
			_voice_started = true
			_voice.play()
		var talking := _voice.playing
		_music.volume_db = move_toward(_music.volume_db, -20.0 if talking else -12.0, 20.0 * delta)
		if _t > _end - FADE_OUT:
			_music.volume_db = lerpf(_music.volume_db, -60.0, 0.15)
	queue_redraw()

# =========================================================================
#  Dibujo
# =========================================================================
func _draw() -> void:
	match _idx:
		0: _draw_modern()
		1: _draw_century()
		2: _draw_industry()
		3: _draw_discovery()
		4: _draw_ancient()
		_: _draw_nexo()
	_draw_title()
	_draw_subtitles()
	# Fundido desde y hacia negro.
	var a := (1.0 - _ph(0.0, FADE_IN)) + _ph(_end - FADE_OUT, _end)
	if a > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.02, 0.05, clampf(a, 0.0, 1.0)))
	if _t < 3.0:
		HKTheme.draw_text(self, Vector2(0, 9), "ENTER: SALTAR", 8,
			Color(HKTheme.MUTED, 1.0 - _ph(2.0, 3.0)), HORIZONTAL_ALIGNMENT_RIGHT, W - 6, 1)

func _draw_title() -> void:
	var a := _ph(0.4, 1.2) * (1.0 - _ph(_end - 1.6, _end - FADE_OUT))
	if a <= 0.0:
		return
	var title: String = ERAS[_idx]["title"]
	var w := HKTheme.text_width(title, 8) + 24.0
	draw_rect(Rect2(W * 0.5 - w * 0.5, 12, w, 18), Color(0.03, 0.01, 0.06, 0.72 * a))
	draw_rect(Rect2(W * 0.5 - w * 0.5, 29, w, 1), Color(HKTheme.GOLD_DARK, a))
	HKTheme.draw_text(self, Vector2(0, 25), title, 8, Color(HKTheme.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, W, 1)

## Los subtítulos se reparten por el largo de cada frase durante la voz.
func _draw_subtitles() -> void:
	var subs: Array = ERAS[_idx]["subs"]
	var total := 0.0
	for s in subs:
		total += float((s as String).length() + 6)
	var t0 := VOICE_AT
	for s in subs:
		var d: float = float(ERAS[_idx]["len"]) * float((s as String).length() + 6) / total
		if _t >= t0 and _t < t0 + d:
			var a := minf(clampf((_t - t0) / 0.15, 0.0, 1.0), clampf((t0 + d - _t) / 0.15, 0.0, 1.0))
			draw_rect(Rect2(0, 207, W, 22), Color(0.02, 0.0, 0.04, 0.66 * a))
			HKTheme.draw_text(self, Vector2(0, 222), s, 8, Color(HKTheme.PAPER, a), HORIZONTAL_ALIGNMENT_CENTER, W, 2)
			return
		t0 += d

func _quad(c: Vector2, w: float, h: float, rot: float, col: Color) -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	var pts := PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	for i in 4:
		pts[i] = c + pts[i].rotated(rot)
	draw_colored_polygon(pts, col)

func _gear(c: Vector2, r: float, teeth: int, rot: float, col: Color, hole: Color) -> void:
	draw_circle(c, r, col)
	for k in teeth:
		var a := rot + TAU * k / teeth
		_quad(c + Vector2.from_angle(a) * (r + r * 0.1), r * 0.28, r * 0.24, a, col)
	draw_circle(c, r * 0.62, hole)
	for k in 4:
		var a := rot + TAU * k / 4.0
		draw_line(c, c + Vector2.from_angle(a) * r * 0.62, col, maxf(1.0, r * 0.1))
	draw_circle(c, r * 0.2, col.lightened(0.2))

func _bolt(a: Vector2, b: Vector2, seed_v: float, col: Color, w: float, jag: float = 6.0) -> void:
	var pts := PackedVector2Array()
	var nrm := (b - a).orthogonal().normalized()
	for i in 9:
		var off := 0.0 if (i == 0 or i == 8) else (_h(seed_v + i * 3.1) - 0.5) * 2.0 * jag
		pts.append(a.lerp(b, i / 8.0) + nrm * off)
	draw_polyline(pts, Color(col, 0.3), w + 2.0)
	draw_polyline(pts, col, w)

func _bands(colors: Array, y0: float, y1: float) -> void:
	var h := (y1 - y0) / colors.size()
	for i in colors.size():
		draw_rect(Rect2(0, y0 + i * h, W, h + 1.0), Color(colors[i]))

func _vignette(strength: float) -> void:
	# Bordes oscuros en degradado suave: muchas franjas finas y casi transparentes.
	var steps := 14
	var step_w := 2.0
	for i in steps:
		var a := strength * 0.035 * (1.0 - float(i) / steps)
		var d := step_w * (steps - i)
		draw_rect(Rect2(0, 0, W, d), Color(0, 0, 0, a))
		draw_rect(Rect2(0, H - d, W, d), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 0, d, H), Color(0, 0, 0, a))
		draw_rect(Rect2(W - d, 0, d, H), Color(0, 0, 0, a))

# --- I · El mundo actual: ciudad de neón, gritos y señal que se corta ------
const SHOUTS: Array[String] = ["¡EN VIVO!", "¡VIRAL!", "¡EXCLUSIVA!", "¡TENDENCIA!", "¡YO!", "¡NO!"]
const NEON: Array[Color] = [Color("ff3a9a"), Color("35e6ff"), Color("ffd24a"), Color("9a4dff")]

func _draw_modern() -> void:
	var zoom := 1.0 + 0.07 * _ph(0.0, _end)   # la cámara avanza despacio hacia la ciudad
	draw_set_transform(Vector2(W * 0.5, 150.0) * (1.0 - zoom), 0.0, Vector2(zoom, zoom))
	_bands(["0a0618", "100a28", "1a0f38", "2a1450", "3e1a64", "5a2470"], 0, 190)
	# Un reloj gigante y agrietado en el cielo: el tiempo se rompe sobre la ciudad.
	var ck := Vector2(318, 70)
	draw_arc(ck, 52.0, 0, TAU, 56, Color(CYAN, 0.22), 3.0)
	for k in 12:
		var a := TAU * k / 12.0
		draw_line(ck + Vector2.from_angle(a) * 44.0, ck + Vector2.from_angle(a) * 50.0, Color(CYAN, 0.25), 2.0)
	draw_line(ck, ck + Vector2.from_angle(_t * 0.9 - 1.0) * 30.0, Color(CYAN, 0.3), 2.0)
	draw_line(ck, ck + Vector2.from_angle(_t * 5.0) * 42.0, Color(NEON[0], 0.3), 1.0)
	draw_polyline(PackedVector2Array([ck + Vector2(-10, -52), ck + Vector2(4, -22), ck + Vector2(-6, 0), ck + Vector2(12, 30), ck + Vector2(2, 52)]),
		Color(NEXO_GOLD, 0.45), 2.0)
	# Focos que barren el cielo.
	for k in 2:
		var bx := 90.0 + k * 250.0
		var tip := bx + sin(_t * 0.9 + k * 2.0) * 90.0
		draw_colored_polygon(PackedVector2Array([Vector2(bx - 3, 190), Vector2(bx + 3, 190), Vector2(tip + 22.0, 20), Vector2(tip - 22.0, 20)]),
			Color(1, 1, 1, 0.045))
	# Drones con luces que cruzan.
	for k in 4:
		var dx := fposmod(_t * (14.0 + k * 6.0) + k * 97.0, W + 40.0) - 20.0
		var dy := 34.0 + k * 17.0 + sin(_t * 2.0 + k) * 3.0
		draw_rect(Rect2(dx, dy, 5, 2), Color("1a1224"))
		draw_rect(Rect2(dx - 1, dy - 1, 1, 1), Color("ff3030") if int(_t * 3.0 + k) % 2 == 0 else Color("ffffff"))
	# Tres capas de edificios con parallax: cuanto más cerca, más rápido pasan.
	_city_layer(0, _t * 3.0, Color("0d0618"), 0.3, 150.0)
	_city_layer(1, _t * 7.0, Color("140a26"), 0.5, 120.0)
	_city_layer(2, _t * 13.0, Color("1c0e34"), 0.7, 96.0)
	# Rótulos de neón con gritos de la ciudad.
	for k in 4:
		var x := 36.0 + k * 100.0
		var y := 108.0 + (k % 2) * 30.0
		var col := NEON[k]
		var on := _h(floorf(_t * 5.0) + k * 7.0) > 0.2
		var word := SHOUTS[(k + int(_t * 0.7)) % SHOUTS.size()]
		var w := HKTheme.text_width(word, 8) + 10.0
		draw_rect(Rect2(x - 3, y - 11, w, 15), Color(0.04, 0.02, 0.08, 0.8))
		draw_rect(Rect2(x - 3, y - 11, w, 15), Color(col, 0.8 if on else 0.2), false, 1.0)
		if on:
			HKTheme.draw_text(self, Vector2(x + 2, y), word, 8, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	# Ondas de grito que salen de las azoteas y se expanden.
	for k in 3:
		var origin := Vector2(70.0 + k * 140.0, 112.0 - (k % 2) * 14.0)
		for r in 3:
			var p := fposmod(_t * 0.55 + r * 0.33 + k * 0.21, 1.0)
			draw_arc(origin, 6.0 + p * 52.0, -0.9, 0.9, 14, Color(NEON[k % 4], 0.65 * (1.0 - p)), 2.0)
	# Calle mojada: reflejos de neón y lluvia.
	draw_rect(Rect2(0, 190, W, 50), Color("08040f"))
	for k in 14:
		var rx := _h(k * 5.0) * W
		draw_rect(Rect2(rx, 193.0 + _h(k) * 30.0, 14.0 + _h(k + 2.0) * 30.0, 1), Color(NEON[k % 4], 0.35))
	draw_rect(Rect2(0, 190, W, 1), Color(CYAN, 0.6))
	for i in 70:
		var px := fposmod(_h(i) * W - _t * 60.0, W)
		var py := fposmod(_h(i + 3.0) * H + _t * 260.0 * (0.6 + _h(i + 1.0) * 0.6), H)
		draw_line(Vector2(px, py), Vector2(px - 2.0, py + 7.0), Color(0.7, 0.85, 1.0, 0.22), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Glitch: la señal se corta, con las franjas desplazadas en cian y magenta.
	var q := floorf(_t * 9.0)
	for k in 4:
		if _h(q + k * 3.0) > 0.55:
			var gy := _h(q + k) * H
			var gh := 2.0 + _h(q) * 8.0
			draw_rect(Rect2(0, gy, W, gh), Color(CYAN, 0.2))
			draw_rect(Rect2(4.0 + _h(q + 2.0) * 8.0, gy + 1.0, W, gh), Color(NEON[0], 0.2))
	if _h(floorf(_t * 3.0)) > 0.9:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.07))

## Una capa de la ciudad que se desplaza en bucle; `top` es la altura máxima de sus edificios.
func _city_layer(layer: int, offset: float, col: Color, lit: float, top: float) -> void:
	var count := 22
	var total := 0.0
	for i in count:
		total += 20.0 + _h(layer * 31.0 + i) * 24.0 + 2.0
	var shift := fposmod(offset, total)
	var twinkle := floorf(_t * (0.8 + layer * 0.5))
	for copy in 2:
		var x := -shift + copy * total - 10.0
		for i in count:
			var bw := 20.0 + _h(layer * 31.0 + i) * 24.0
			var bh := 36.0 + _h(layer * 17.0 + i * 1.7) * top
			if x + bw > 0.0 and x < W:
				draw_rect(Rect2(x, 190.0 - bh, bw, bh), col)
				draw_rect(Rect2(x, 190.0 - bh, bw, 1), Color(CYAN, 0.12 + 0.08 * layer))
				for wy in int(bh / 8.0):
					for wx in int(bw / 6.0):
						if _h(layer * 97.0 + i * 13.0 + wy * 5.0 + wx * 3.0 + twinkle) < lit * 0.55:
							draw_rect(Rect2(x + 2 + wx * 6, 190.0 - bh + 3 + wy * 8, 3, 4), NEXO_GOLD if (wx + wy) % 3 else CYAN)
			x += bw + 2.0

# --- II · El siglo XX: película vieja, relojes al revés y sirenas ----------
func _draw_century() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("2a2018"))
	for i in 6:
		draw_circle(Vector2(W * 0.5, 110.0), 190.0 - i * 28.0, Color(0.5, 0.4, 0.25, 0.05))
	# Reloj que gira al revés.
	var c := Vector2(W * 0.5, 112.0)
	var R := 66.0
	draw_circle(c, R + 6.0, Color("5a4630"))
	draw_circle(c, R, Color("1a140e"))
	draw_arc(c, R, 0, TAU, 64, Color("c8b080"), 2.0)
	for k in 12:
		var a := TAU * k / 12.0 - PI * 0.5
		draw_line(c + Vector2.from_angle(a) * (R - 8), c + Vector2.from_angle(a) * (R - 2), Color("c8b080"), 2.0)
	draw_line(c, c + Vector2.from_angle(-_t * 0.6 - PI * 0.5) * R * 0.5, Color("e8d8b0"), 3.0)
	draw_line(c, c + Vector2.from_angle(-_t * 2.2 - PI * 0.5) * R * 0.78, Color("e8d8b0"), 2.0)
	draw_line(c, c + Vector2.from_angle(-_t * 9.0 - PI * 0.5) * R * 0.85, Color("c02020"), 1.0)
	draw_circle(c, 3.0, Color("c02020"))
	# Siluetas de soldados y banderas rotas al fondo.
	for k in 7:
		var x := 30.0 + k * 58.0
		draw_rect(Rect2(x, 160, 5, 30), Color("0e0a06"))
		draw_rect(Rect2(x + 5, 158, 14, 9), Color(0.55, 0.1, 0.1, 0.75))
	draw_rect(Rect2(0, 190, W, 50), Color("0e0a06"))
	# Sirena: un haz rojo que barre la pantalla.
	var sweep := sin(_t * 3.0) * 0.5 + 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(W * sweep, 0), Vector2(W * sweep - 60.0, H), Vector2(-60, H)]),
		Color(0.9, 0.1, 0.1, 0.09 + 0.05 * sin(_t * 12.0)))
	# Película: grano, rayas y perforaciones.
	var f := floorf(_t * 24.0)
	for i in 70:
		draw_rect(Rect2(_h(f + i) * W, _h(f * 3.0 + i * 1.3) * H, 1, 1), Color(1, 1, 0.9, 0.28))
	for i in 3:
		if _h(f + i * 5.0) > 0.45:
			draw_rect(Rect2(_h(f * 2.0 + i) * W, 0, 1, H), Color(1, 1, 0.9, 0.22))
	for k in 12:
		var y := fposmod(k * 22.0 + _t * 40.0, H + 22.0) - 22.0
		draw_rect(Rect2(3, y, 7, 12), Color("07050a"))
		draw_rect(Rect2(W - 10, y, 7, 12), Color("07050a"))
	draw_rect(Rect2(0, 0, W, H), Color(1, 0.95, 0.8, 0.04 * _h(f)))
	_vignette(1.0)

# --- III · Revoluciones y progreso: engranajes, chispas y bobinas ---------
func _draw_industry() -> void:
	_bands(["14100c", "1c140e", "261a10", "321f12", "3e2814"], 0, 200)
	# Chimeneas con humo que sube.
	for k in 4:
		var x := 52.0 + k * 100.0
		draw_rect(Rect2(x, 100, 16, 100), Color("0e0a07"))
		draw_rect(Rect2(x - 2, 98, 20, 5), Color("1c140e"))
		for s in 8:
			var p := fposmod(_t * 0.18 + s * 0.125 + k * 0.3, 1.0)
			draw_circle(Vector2(x + 8.0 + sin(p * 6.0 + k) * 8.0 * p, 98.0 - p * 90.0), 5.0 + p * 14.0, Color(0.35, 0.3, 0.26, 0.28 * (1.0 - p)))
	# Engranajes de varios tamaños que giran engranados.
	var hole := Color("1c140e")
	_gear(Vector2(70, 170), 44.0, 14, _t * 0.5, Color("7a5a2a"), hole)
	_gear(Vector2(150, 150), 28.0, 10, -_t * 0.8 + 0.2, Color("a07a38"), hole)
	_gear(Vector2(290, 176), 52.0, 16, -_t * 0.42, Color("6a4a22"), hole)
	_gear(Vector2(366, 128), 30.0, 11, _t * 0.7, Color("a07a38"), hole)
	_gear(Vector2(213, 190), 24.0, 9, _t * 0.9, Color("8a6a30"), hole)
	# Bobina de Tesla a la derecha, con arcos hacia el suelo.
	var tc := Vector2(400, 190)
	draw_rect(Rect2(tc.x - 4, 120, 8, 70), Color("3a2a18"))
	draw_circle(Vector2(tc.x, 114), 10.0, Color("b8862a"))
	var q := floorf(_t * 14.0)
	for i in 3:
		if _h(q + i * 5.0) > 0.35:
			_bolt(Vector2(tc.x, 114), Vector2(tc.x - 60.0 - _h(q + i) * 160.0, 190.0), q + i, CYAN, 1.0, 9.0)
	# Chispas anaranjadas.
	for i in 40:
		var p := fposmod(_t * (0.6 + _h(i) * 0.6) + _h(i + 4.0), 1.0)
		var sx := 20.0 + _h(i + 1.0) * (W - 40.0)
		draw_rect(Rect2(sx + sin(p * 9.0 + i) * 10.0, 200.0 - p * 150.0, 1.5, 1.5), Color(1.0, 0.6, 0.2, 1.0 - p))
	draw_rect(Rect2(0, 200, W, 40), Color("0e0a07"))
	_vignette(0.8)

# --- IV · Imperios y descubrimientos: un mapa antiguo y un barco ----------
func _draw_discovery() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("d8c090"))
	for i in 7:
		draw_circle(Vector2(W * 0.5, 120.0), 260.0 - i * 24.0, Color(0.45, 0.3, 0.12, 0.06))
	# Cuadrícula tenue y continentes.
	for x in range(20, int(W), 40):
		draw_line(Vector2(x, 0), Vector2(x, H), Color(0.4, 0.28, 0.14, 0.18), 1.0)
	for y in range(20, int(H), 40):
		draw_line(Vector2(0, y), Vector2(W, y), Color(0.4, 0.28, 0.14, 0.18), 1.0)
	var land := Color("b89a5a")
	var edge := Color("6a4a24")
	var masses := [
		[Vector2(30, 70), Vector2(90, 50), Vector2(130, 80), Vector2(120, 130), Vector2(70, 150), Vector2(40, 120)],
		[Vector2(320, 60), Vector2(390, 48), Vector2(410, 100), Vector2(380, 150), Vector2(330, 130)],
		[Vector2(170, 170), Vector2(240, 160), Vector2(270, 195), Vector2(210, 205)],
	]
	for m in masses:
		var pts := PackedVector2Array(m)
		draw_colored_polygon(pts, land)
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, edge, 2.0)
	# La ruta se va dibujando, punteada, hasta el barco.
	var a := Vector2(130, 110)
	var b := Vector2(322, 96)
	var p := _ease(_t / 6.0)
	var n := int(46 * p)
	var head := a
	for i in n:
		var k := float(i) / 45.0
		var pt := a.lerp(b, k) + Vector2(0, -sin(k * PI) * 34.0)
		draw_circle(pt, 1.4, Color("8a1c1c"))
		head = pt
	# Barco: casco y dos velas que cabecean.
	var bob := sin(_t * 3.0) * 2.0
	var sp := head + Vector2(0, bob)
	draw_colored_polygon(PackedVector2Array([sp + Vector2(-12, 0), sp + Vector2(12, 0), sp + Vector2(8, 7), sp + Vector2(-8, 7)]), Color("4a2a14"))
	draw_line(sp + Vector2(0, 0), sp + Vector2(0, -22), Color("3a2210"), 1.5)
	draw_colored_polygon(PackedVector2Array([sp + Vector2(1, -21), sp + Vector2(12, -8), sp + Vector2(1, -8)]), Color("f4ecd8"))
	draw_colored_polygon(PackedVector2Array([sp + Vector2(-1, -19), sp + Vector2(-10, -8), sp + Vector2(-1, -8)]), Color("e8dcc0"))
	# Rosa de los vientos.
	var rc := Vector2(364, 188)
	draw_arc(rc, 24.0, 0, TAU, 40, edge, 1.5)
	for k in 8:
		var ang := _t * 0.15 + TAU * k / 8.0
		var r2 := 22.0 if k % 2 == 0 else 13.0
		draw_line(rc, rc + Vector2.from_angle(ang) * r2, Color("8a1c1c") if k % 2 == 0 else edge, 2.0 if k % 2 == 0 else 1.0)
	# Monstruos marinos: olas dibujadas a mano.
	for k in 5:
		var wx := 160.0 + k * 22.0
		var wy := 120.0 + (k % 2) * 6.0
		draw_arc(Vector2(wx, wy), 5.0, PI, TAU, 10, Color("4a6a8a", 0.6), 1.5)
	_vignette(1.2)

# --- V · La antigüedad: sol enorme, columnas y dunas ----------------------
func _draw_ancient() -> void:
	_bands(["f6c860", "f2b448", "ec9a38", "d87a2e", "a8522c"], 0, 176)
	var sc := Vector2(W * 0.5, 104.0)
	var pulse := 1.0 + 0.03 * sin(_t * 2.0)
	for i in 5:
		draw_circle(sc, (70.0 + i * 22.0) * pulse, Color(1.0, 0.92, 0.6, 0.07))
	for k in 24:
		var ang := _t * 0.1 + TAU * k / 24.0
		draw_line(sc + Vector2.from_angle(ang) * 52.0, sc + Vector2.from_angle(ang) * (120.0 + 20.0 * sin(_t * 2.0 + k)), Color(1.0, 0.95, 0.7, 0.16), 3.0)
	draw_circle(sc, 50.0 * pulse, Color("ffe488"))
	draw_circle(sc, 40.0 * pulse, Color("fff4c0"))
	# Dunas lejanas y cercanas.
	for layer in 2:
		var pts := PackedVector2Array([Vector2(0, H), Vector2(0, 170.0 + layer * 14.0)])
		for x in range(0, int(W) + 20, 20):
			pts.append(Vector2(x, 168.0 + layer * 14.0 + sin(x * 0.02 + layer * 2.0) * 10.0))
		pts.append(Vector2(W, H))
		draw_colored_polygon(pts, Color("c8884a") if layer == 0 else Color("a86a38"))
	# Columnas rotas en silueta.
	var col := Color("3a1e1a")
	var xs := [38.0, 96.0, 160.0, 262.0, 326.0, 388.0]
	for i in xs.size():
		var h := 70.0 + _h(i * 3.0) * 40.0
		var x: float = xs[i]
		draw_rect(Rect2(x - 7, 176 - h, 14, h), col)
		draw_rect(Rect2(x - 10, 176 - h - 4, 20, 5), col)
		draw_rect(Rect2(x - 10, 172, 20, 6), col)
		if i % 2 == 1:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 10, 176 - h - 4), Vector2(x + 10, 176 - h - 4), Vector2(x + 2, 176 - h - 12)]), Color("f2b448"))
	# Polvo que arrastra el viento.
	for i in 30:
		var p := fposmod(_t * (0.2 + _h(i) * 0.25) + _h(i + 2.0), 1.0)
		draw_rect(Rect2(p * (W + 40.0) - 20.0, 130.0 + _h(i + 6.0) * 70.0, 6.0 + _h(i) * 10.0, 1), Color(1, 0.9, 0.7, 0.35 * (1.0 - p)))
	_vignette(0.7)

# --- VI · El Nexo: la grieta se abre y aparece la esfera -------------------
func _draw_nexo() -> void:
	draw_rect(Rect2(0, 0, W, H), VOID)
	var bands := ["05020a", "0a0415", "12081f", "1c0c2c", "2a1238", "3a1a40"]
	for i in bands.size():
		draw_rect(Rect2(0, i * 32, W, 33), Color(bands[i]))
	for i in 50:
		draw_rect(Rect2(_h(i) * W, _h(i + 9.0) * 150.0, 1, 1), Color(1, 1, 1, 0.3 + 0.4 * _h(i + 2.0)))
	# Grieta vertical que crece de arriba abajo.
	var grow := _ease(_ph(0.4, 2.4))
	var cx := W * 0.5
	var pts := PackedVector2Array()
	for i in 15:
		var k := float(i) / 14.0
		pts.append(Vector2(cx + (_h(4.0 + i * 1.7) - 0.5) * 26.0 * (0.4 + k), 200.0 * k * grow))
	var wob := 0.7 + 0.3 * sin(_t * 9.0)
	if pts.size() > 1:
		draw_polyline(pts, Color(VIOLET, 0.25 * wob), 18.0)
		draw_polyline(pts, Color(VIOLET, 0.6), 8.0)
		draw_polyline(pts, NEXO_GOLD, 4.0)
		draw_polyline(pts, Color("02000a"), 2.0)
	# La esfera del Nexo crece, pulsa y emite arcos orbitales.
	var sg := _ease(_ph(2.2, 4.4))
	var sphere_c := Vector2(cx, 92.0 + sin(_t * 1.1) * 2.0)
	var r := 26.0 * sg
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	if sg > 0.0:
		for i in 5:
			draw_circle(sphere_c, r * (2.4 - i * 0.35), Color(NEXO_GOLD, 0.05 + 0.02 * i))
		draw_circle(sphere_c, r + 3.0, Color(VIOLET, 0.7))
		draw_circle(sphere_c, r, NEXO_GOLD)
		draw_circle(sphere_c, r * 0.72, Color("fff0a0"))
		draw_circle(sphere_c, r * 0.38, Color.WHITE)
		for k in 3:
			var a0 := _t * (1.2 + k * 0.5) + k * 2.1
			draw_arc(sphere_c, r * (1.25 + k * 0.18), a0, a0 + 2.2, 24, [CYAN, VIOLET, CYAN][k] as Color, 2.0)
		draw_arc(sphere_c, r * 1.6 + pulse * 3.0, 0, TAU, 48, Color(CYAN, 0.35), 1.0)
	# Chispas que suben desde el suelo.
	for i in 40:
		var p := fposmod(_t * (0.12 + _h(i) * 0.2) + _h(i + 3.0), 1.0)
		draw_rect(Rect2(20.0 + _h(i + 1.0) * (W - 40.0), 196.0 - p * 190.0, 1.5, 1.5), Color(NEXO_GOLD, 0.7 * (1.0 - p)))
	draw_rect(Rect2(0, 196, W, 44), Color(0.03, 0.015, 0.06))
	draw_rect(Rect2(0, 196, W, 2), Color(NEXO_GOLD, 0.6))
	if _t > 2.2 and _t < 2.6:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 0.9, 0.5 * (1.0 - (_t - 2.2) / 0.4)))
