## Mini-intro del MODO HISTORIA (~15 s), al empezar la partida y tras elegir luchador:
## una grieta del Nexo se abre, el luchador del jugador cae de ella, las sombras de los jefes
## desfilan al fondo y el Nexo hace la pregunta del torneo, con voz y subtítulos.
## Todo se dibuja por código; la voz sale de tools/gen_story_voice.py (mismo texto que NEXO_INTRO)
## y la música es un tramo de la intro (assets/music/intro.ogg, donde el Nexo habla).
## `finished` se emite al terminar o al saltarla (skip()).
class_name StoryPrologue
extends Control

signal finished

const W := 426.0
const H := 240.0
const FLOOR_Y := 196.0
const T_CRACK := 0.3
const T_DROP := 1.2
const T_LAND := 2.0
const T_SHADOWS := 5.6
const T_END := 15.0
const FADE_OUT := 0.6
## Tramo de intro.ogg donde habla el Nexo (T_JUDGE en intro_screen.gd).
const MUSIC_FROM := 66.0
const VOID := Color("07040c")
const NEXO_GOLD := Color("ffd24a")
const VIOLET := Color("9a4dff")
## Voz del Nexo: inicio (s), duración (s) y subtítulo.
const NEXO_INTRO: Array = [
	[2.2, 3.05, "EL TIEMPO TE ELIGIÓ."],
	[5.6, 3.74, "SOLO UNO RECLAMARÁ MI PODER."],
	[9.6, 5.07, "¿QUIÉN MERECE CONTROLAR EL DESTINO\nDE TODA LA HISTORIA?"],
]

var _t: float = 0.0
var _done: bool = false
var _fighter: FighterRenderer
var _shadows: Array[FighterRenderer] = []
var _voices: Array[AudioStreamPlayer] = []
var _started: Array[bool] = []
var _music: AudioStreamPlayer

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Los luchadores son hijos de este nodo: se dibujan encima del fondo.
	_fighter = _make_renderer(Game.p1_data())
	_fighter.visible = false
	# Los jefes de capítulo, en sombra, como anticipo de lo que viene.
	for i in Game.arcade_ladder.size():
		if Game.story_is_chapter_boss(i):
			var r := _make_renderer(FighterRegistry.get_by_id(Game.arcade_ladder[i]))
			r.visible = false
			_shadows.append(r)
	for i in NEXO_INTRO.size():
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sounds/story/nexo_%d.wav" % (i + 1)) as AudioStream
		p.volume_db = 2.0
		add_child(p)
		_voices.append(p)
		_started.append(false)
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/music/intro.ogg") as AudioStream
	_music.volume_db = -12.0
	add_child(_music)
	_music.play(MUSIC_FROM)

func _make_renderer(d: FighterData) -> FighterRenderer:
	var r := FighterRenderer.new()
	add_child(r)
	r.setup(d)
	return r

## Salta la mini-intro (la tarjeta del capítulo la gestiona quien la llama).
func skip() -> void:
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	for v in _voices:
		v.stop()
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
	_t += delta
	if _t >= T_END:
		_finish()
		return
	var talking := false
	for i in _voices.size():
		if not _started[i] and _t >= NEXO_INTRO[i][0]:
			_started[i] = true
			_voices[i].play()
		talking = talking or _voices[i].playing
	_music.volume_db = move_toward(_music.volume_db, -18.0 if talking else -10.0, 20.0 * delta)
	if _t > T_END - FADE_OUT:
		_music.volume_db = lerpf(_music.volume_db, -60.0, 0.15)
	_place()
	queue_redraw()

func _place() -> void:
	var out := 1.0 - _ph(T_END - FADE_OUT, T_END)
	# El luchador cae de la grieta y se asienta con la pose de victoria.
	var d := _ph(T_DROP, T_LAND)
	_fighter.visible = _t >= T_DROP
	var s := clampf(110.0 / maxf(_fighter.approx_height(), 1.0), 0.8, 1.6)
	_fighter.scale = Vector2(s, s)
	_fighter.position = Vector2(104.0, lerpf(-90.0, FLOOR_Y, d * d))
	_fighter.pose_name = &"victory" if _t > T_LAND + 0.3 else &"idle"
	_fighter.modulate.a = _ph(T_DROP, T_DROP + 0.3) * out
	for i in _shadows.size():
		var r := _shadows[i]
		var a := _ph(T_SHADOWS + i * 0.55, T_SHADOWS + i * 0.55 + 0.6) * out
		r.visible = a > 0.01
		var sc := 58.0 / maxf(r.approx_height(), 1.0)
		var x := 200.0 + (W - 220.0) * (i + 0.5) / maxf(_shadows.size(), 1.0)
		r.scale = Vector2(sc * (-1.0 if i % 2 == 0 else 1.0), sc)
		r.position = Vector2(x, 160.0 + sin(_t * 1.5 + i) * 1.5)
		r.pose_name = &"idle"
		r.modulate = Color(0.12, 0.04, 0.2, a * 0.95)

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), VOID)
	_draw_backdrop()
	_draw_crack()
	_draw_text()
	var out := _ph(T_END - FADE_OUT, T_END)
	if out > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.02, 0.05, out))

func _draw_backdrop() -> void:
	var a := _ph(0.0, 1.0)
	for i in 5:
		draw_circle(Vector2(W * 0.5, 100.0), (40.0 + i * 36.0) * a, Color(VIOLET, 0.05))
	for i in 40:
		var p := Vector2(_h(i) * W, fposmod(_h(i + 5.0) * H - _t * (6.0 + _h(i + 2.0) * 14.0), H))
		draw_rect(Rect2(p, Vector2(1, 1)), Color(NEXO_GOLD, 0.4 * a))
	# Suelo de cristal negro con vetas.
	draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), Color(0.03, 0.015, 0.06))
	draw_rect(Rect2(0, FLOOR_Y, W, 2), Color(NEXO_GOLD, 0.5 * a))
	for i in 9:
		draw_line(Vector2(W * 0.5 + (i - 4) * 14.0, FLOOR_Y + 2), Vector2(W * 0.5 + (i - 4) * 70.0, H), Color(VIOLET, 0.25 * a), 1.0)

func _draw_crack() -> void:
	var g := _ease(_ph(T_CRACK, T_DROP)) * (1.0 - _ease(_ph(T_LAND, T_LAND + 1.2)))
	if g <= 0.0:
		return
	var pts := PackedVector2Array()
	for i in 15:
		var k := float(i) / 14.0
		pts.append(Vector2(104.0 + (_h(4.0 + i * 1.7) - 0.5) * 30.0 * (0.4 + k), FLOOR_Y * k * g))
	var wob := 0.7 + 0.3 * sin(_t * 9.0)
	draw_polyline(pts, Color(VIOLET, 0.25 * wob), 18.0)
	draw_polyline(pts, Color(VIOLET, 0.6), 8.0)
	draw_polyline(pts, NEXO_GOLD, 4.0)
	draw_polyline(pts, Color("02000a"), 2.0)

## Destello, onda de aterrizaje, placa del luchador y subtítulos (se dibujan bajo los luchadores).
func _draw_text() -> void:
	var d := Game.p1_data()
	if _t >= T_DROP and _t < T_DROP + 0.4:
		draw_rect(Rect2(0, 0, W, H), Color(1, 1, 0.9, 0.5 * (1.0 - (_t - T_DROP) / 0.4)))
	if _t >= T_LAND and _t < T_LAND + 0.6:
		var r := (_t - T_LAND) * 220.0
		draw_arc(Vector2(104.0, FLOOR_Y), r, PI, TAU, 40, Color(NEXO_GOLD, 1.0 - (_t - T_LAND) / 0.6), 3.0)
	var a := _ph(T_LAND, T_LAND + 0.6) * (1.0 - _ph(T_END - FADE_OUT, T_END))
	if a > 0.0:
		var x := 232.0
		draw_rect(Rect2(x - 8, 36, 190, 50), Color(0.03, 0.01, 0.06, 0.78 * a))
		draw_rect(Rect2(x - 8, 36, 3, 50), Color(NEXO_GOLD, a))
		HKTheme.draw_text(self, Vector2(x, 58), d.short_name.to_upper(), 16, Color(HKTheme.PAPER, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		HKTheme.draw_text(self, Vector2(x, 72), d.era, 8, Color(HKTheme.MUTED.lightened(0.25), a), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
		HKTheme.draw_text(self, Vector2(x, 83), d.country.to_upper(), 8, Color(HKTheme.GOLD, a), HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	if _t < 2.0:
		HKTheme.draw_text(self, Vector2(0, 20), "EL NEXO TE OBSERVA", 8, Color(VIOLET.lightened(0.4), _ph(0.3, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, W, 1)
	if _t < 3.0:
		HKTheme.draw_text(self, Vector2(0, 232), "CUALQUIER TECLA: SALTAR", 8, Color(HKTheme.MUTED, 1.0 - _ph(2.0, 3.0)), HORIZONTAL_ALIGNMENT_RIGHT, W - 6, 1)
	# Subtítulo del Nexo.
	for s in NEXO_INTRO:
		var end: float = s[0] + s[1] + 0.3
		if _t >= s[0] and _t < end:
			var lines: PackedStringArray = (s[2] as String).split("\n")
			var al := minf(clampf((_t - s[0]) / 0.15, 0.0, 1.0), clampf((end - _t) / 0.15, 0.0, 1.0))
			var h := 8.0 + lines.size() * 11.0
			var y0 := 237.0 - h
			draw_rect(Rect2(0, y0, W, h + 3.0), Color(0.02, 0.0, 0.04, 0.62 * al))
			for i in lines.size():
				HKTheme.draw_text(self, Vector2(0, y0 + 12.0 + i * 11.0), lines[i], 8, Color(HKTheme.PAPER, al), HORIZONTAL_ALIGNMENT_CENTER, W, 2)
			return
