## INTRO del juego (~2 minutos): cuenta cómo se rompió el tiempo y nació el torneo.
##   I    EL RELOJ DEL ORIGEN      cuatro científicos y su máquina
##   II   LA FRACTURA DEL NEXO     el interruptor, el silencio, la explosión
##   III  LA COLISIÓN DE LAS ERAS  cinco mundos fundidos y un campo de ruinas
##   IV   EL JUICIO DEL NEXO       la esfera, el coliseo y el público espectral
##   V    LOS LUCHADORES           presentación de los 15 y el círculo final
##   VI   IMPACTO Y LOGOTIPO       choque, corte a negro, HISTORY COMBAT, PRESS START
## Todo se dibuja por código sobre el reloj de la música (assets/music/intro.ogg) y la narración
## (assets/sounds/intro/voice_N.wav). Cualquier tecla salta la intro y va al inicio de sesión.
## Los instantes T_* deben coincidir con tools/gen_intro_music.py; las voces se regeneran con
## tools/gen_intro_voice.py (mismo texto que SUBS).
extends Control

const W := 426.0
const H := 240.0

const T_LEVER := 15.5
const T_BLAST := 17.2
const T_COLLIDE := 33.0
const T_RUINS := 60.5
const T_JUDGE := 66.0
const T_ARENA := 76.0
const T_SELECT := 90.0
const T_CIRCLE := 106.5
const T_BUILD := 111.6
const T_CLASH := 115.0
const T_LOGO := 116.0
const T_END := 124.0
const SELECT_STEP := 1.1

const VOID := Color("07040c")
const NEXO_GOLD := Color("ffd24a")
const CYAN := Color("35e6ff")
const VIOLET := Color("9a4dff")
const BRASS := Color("b8862a")
const BRASS_D := Color("5e4216")

## Narración: inicio (s), duración (s) y subtítulos (se reparten según el largo de cada uno).
const VOICE_T: Array[float] = [1.5, 19.5, 34.0, 68.0, 104.0, 116.6]
const VOICE_LEN: Array[float] = [10.89, 11.75, 11.14, 12.88, 6.80, 3.69]
const SUBS: Array = [
	["CUATRO MENTES DE ÉPOCAS DISTINTAS\nCONSTRUYERON UNA MÁQUINA", "PARA VER TODO EL TIEMPO A LA VEZ.", "LA LLAMARON EL RELOJ DEL ORIGEN."],
	["FUNCIONÓ... DEMASIADO BIEN.", "ROMPIÓ EL TIEMPO, Y DE LA GRIETA NACIÓ EL NEXO,\nEL PODER QUE SOSTIENE TODAS LAS ÉPOCAS."],
	["LOS MUNDOS CHOCARON.", "REYES, GUERREROS Y PROFETAS FUERON\nARRANCADOS DE SU ÉPOCA", "Y ARROJADOS A UN MISMO CAMPO DE RUINAS."],
	["ENTONCES EL NEXO HABLÓ:", "SOLO UNO DE USTEDES PODRÁ RECLAMAR MI PODER.", "EL ÚLTIMO EN PIE DECIDIRÁ SI EL TIEMPO\nSE REPARA... O SE ESCRIBE DE NUEVO."],
	["ALIADOS NO HAY.\nÉPOCAS NO HAY. REGLAS NO HAY."],
	[],
]

## Tarjetas de capítulo: [segundo, texto].
const CARDS: Array = [
	[0.4, "I · EL RELOJ DEL ORIGEN"],
	[18.0, "II · LA FRACTURA DEL NEXO"],
	[33.4, "III · LA COLISIÓN DE LAS ERAS"],
	[66.6, "IV · EL JUICIO DEL NEXO"],
	[90.3, "V · LOS LUCHADORES"],
]

## Los cuatro científicos: [id, nombre, x, segundo en que aparecen].
const SCIENTISTS: Array = [
	[&"nikola_tesla", "TESLA", 96.0, 1.8],
	[&"albert_einstein", "EINSTEIN", 176.0, 4.0],
	[&"marie_curie", "CURIE", 256.0, 6.2],
	[&"leonardo_da_vinci", "DA VINCI", 336.0, 8.4],
]

## Cinco mundos fundidos: escenario del luchador, rótulo y tinte.
const WORLDS: Array = [
	[33.0, &"cleopatra", "EGIPTO CIBERNÉTICO", Color(0.1, 0.9, 1.0, 0.14)],
	[38.5, &"julio_cesar", "METRÓPOLIS ROMANA", Color(1.0, 0.5, 0.2, 0.12)],
	[44.0, &"gengis_kan", "ESTEPA URBANA", Color(0.5, 0.7, 1.0, 0.12)],
	[49.5, &"pachacutec", "LOS ANDES FRACTURADOS", Color(1.0, 0.8, 0.2, 0.12)],
	[55.0, &"lautaro", "TIERRAS AUSTRALES", Color(0.6, 0.4, 1.0, 0.14)],
]

## Campo de ruinas: quién cae y dónde.
const RUINS: Array = [
	[&"juana_de_arco", 78.0], [&"alejandro_magno", 146.0], [&"boudica", 213.0],
	[&"napoleon", 280.0], [&"arturo_prat", 348.0],
]

## Presentación: [id, rasgo, color, aura (0 rayos, 1 llamas, 2 órbita, 3 destellos)].
const CAST: Array = [
	[&"cleopatra", "DAGA DE ESMERALDA", Color("b070ff"), 1],
	[&"julio_cesar", "GLADIUS IMPERIAL", Color("ffd24a"), 3],
	[&"alejandro_magno", "ESCUDO SOLAR", Color("ffc030"), 3],
	[&"gengis_kan", "SABLE DE LA HORDA", Color("ff7a3a"), 1],
	[&"pachacutec", "MAZA DE PIEDRA Y ORO", Color("ffd24a"), 2],
	[&"lautaro", "LANZA Y VIENTO", Color("35e6ff"), 2],
	[&"janequeo", "PICA DE PLATA", Color("c8e0ff"), 3],
	[&"boudica", "ESCUDO CELTA", Color("4aa0ff"), 2],
	[&"juana_de_arco", "FUEGO BLANCO", Color("fff4d8"), 1],
	[&"napoleon", "SABLE DE CABALLERÍA", Color("6aa8ff"), 3],
	[&"arturo_prat", "SABLE DE ABORDAJE", Color("35e6ff"), 3],
	[&"nikola_tesla", "ELECTRICIDAD VOLTAICA", Color("35e6ff"), 0],
	[&"albert_einstein", "GRAVEDAD", Color("9a4dff"), 2],
	[&"marie_curie", "ENERGÍA RADIACTIVA", Color("60ff70"), 2],
	[&"leonardo_da_vinci", "COMPÁS DE LUZ", Color("ffd24a"), 3],
]

var _t: float = 0.0
var _fighters: Dictionary = {}
var _world: Node2D
var _fx: Control
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _voice_started: Array[bool] = []
var _subs: Array = []          # [desde, hasta, texto]
var _stage: Stage
var _stage_key: int = -1
var _shake: Vector2 = Vector2.ZERO
var _done: bool = false
var _clash_frozen: bool = false

func _ready() -> void:
	theme = HKTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_world = Node2D.new()
	add_child(_world)
	for e in CAST:
		var r := FighterRenderer.new()
		_world.add_child(r)
		r.setup(FighterRegistry.get_by_id(e[0]))
		r.visible = false
		_fighters[e[0]] = r
	_fx = Control.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/music/intro.ogg") as AudioStream
	_music.volume_db = -5.0
	add_child(_music)
	for i in VOICE_T.size():
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sounds/intro/voice_%d.wav" % (i + 1)) as AudioStream
		p.volume_db = 2.0
		add_child(p)
		_voices.append(p)
		_voice_started.append(false)
	_build_subs()
	_music.play()

func _build_subs() -> void:
	for i in SUBS.size():
		var chunks: Array = SUBS[i]
		var total := 0.0
		for c in chunks:
			total += float((c as String).length() + 6)
		var t := VOICE_T[i]
		for c in chunks:
			var d := VOICE_LEN[i] * float((c as String).length() + 6) / total
			_subs.append([t, t + d, c])
			t += d

func _unhandled_input(event: InputEvent) -> void:
	if _done or _t < 0.5:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		_finish()
		get_viewport().set_input_as_handled()

func _finish() -> void:
	if _done:
		return
	_done = true
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -60.0, 0.2)
	for v in _voices:
		tw.parallel().tween_property(v, "volume_db", -60.0, 0.2)
	Game.goto(Game.SCENE_LOGIN)

func _process(delta: float) -> void:
	_t += delta
	if _music.playing and delta < 0.1:
		var at := _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		if absf(at - _t) > 0.25:
			_t = at
	var talking := false
	for i in _voices.size():
		if not _voice_started[i] and _t >= VOICE_T[i]:
			_voice_started[i] = true
			_voices[i].play()
		talking = talking or _voices[i].playing
	_music.volume_db = move_toward(_music.volume_db, -10.0 if talking else -5.0, 30.0 * delta)
	_update_shake()
	_update_stage()
	_place_fighters()
	if _t > T_END + 8.0:
		_finish()
	queue_redraw()
	_fx.queue_redraw()

# =========================================================================
#  Utilidades
# =========================================================================
static func _h(i: float) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)

static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## Progreso 0..1 del reloj entre dos instantes.
func _ph(a: float, b: float) -> float:
	return clampf((_t - a) / (b - a), 0.0, 1.0)

func _txt(ci: CanvasItem, y: float, text: String, size: int, col: Color, x: float = 0.0, w: float = W, outline: int = 2) -> void:
	HKTheme.draw_text(ci, Vector2(x, y), text, size, col, HORIZONTAL_ALIGNMENT_CENTER, w, outline)

func _quad(ci: CanvasItem, c: Vector2, w: float, h: float, rot: float, col: Color) -> void:
	var hw := w * 0.5
	var hh := h * 0.5
	var pts := PackedVector2Array([Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)])
	for i in 4:
		pts[i] = c + pts[i].rotated(rot)
	ci.draw_colored_polygon(pts, col)

func _gear(ci: CanvasItem, c: Vector2, r: float, teeth: int, rot: float, col: Color, hole: Color) -> void:
	ci.draw_circle(c, r, col)
	for k in teeth:
		var a := rot + TAU * k / teeth
		_quad(ci, c + Vector2.from_angle(a) * (r + r * 0.1), r * 0.28, r * 0.24, a, col)
	ci.draw_circle(c, r * 0.62, hole)
	for k in 4:
		var a := rot + TAU * k / 4.0
		ci.draw_line(c, c + Vector2.from_angle(a) * r * 0.62, col, maxf(1.0, r * 0.1))
	ci.draw_circle(c, r * 0.2, col.lightened(0.2))

func _bolt(ci: CanvasItem, a: Vector2, b: Vector2, seed_v: float, col: Color, w: float, jag: float = 6.0) -> void:
	var pts := PackedVector2Array()
	var nrm := (b - a).orthogonal().normalized()
	for i in 9:
		var off := 0.0 if (i == 0 or i == 8) else (_h(seed_v + i * 3.1) - 0.5) * 2.0 * jag
		pts.append(a.lerp(b, i / 8.0) + nrm * off)
	ci.draw_polyline(pts, Color(col, 0.3), w + 2.0)
	ci.draw_polyline(pts, col, w)

func _crack_points(top: float, bottom: float, seed_v: float, jag: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var k := float(i) / n
		pts.append(Vector2(W * 0.5 + (_h(seed_v + i * 1.7) - 0.5) * jag * (0.4 + k), lerpf(top, bottom, k)))
	return pts

# =========================================================================
#  Escenarios y luchadores
# =========================================================================
func _world_index() -> int:
	var idx := -1
	for i in WORLDS.size():
		if _t >= WORLDS[i][0]:
			idx = i
	return idx if (_t >= T_COLLIDE and _t < T_RUINS) else -1

func _update_stage() -> void:
	var key := _world_index()
	if key == _stage_key:
		if _stage:
			var k := 1.0 + 0.07 * _ph(WORLDS[key][0], WORLDS[key][0] + 5.5)
			_stage.scale = Vector2(k, k)
			_stage.position = Vector2(W * 0.5, H * 0.5) * (1.0 - k) + _shake
		return
	_stage_key = key
	if _stage:
		_stage.queue_free()
		_stage = null
	if key < 0:
		return
	var id: StringName = WORLDS[key][1]
	var packed := load(StageRegistry.scene_for(id)) as PackedScene
	if packed == null:
		packed = load(StageRegistry.COLOSSEUM)
	_stage = packed.instantiate() as Stage
	if _stage is ThemedStage:
		(_stage as ThemedStage).fighter_id = id
	_stage.show_behind_parent = true   # debajo del dibujo del propio nodo, que en esta parte no pinta
	add_child(_stage)
	move_child(_stage, 0)

func _update_shake() -> void:
	var amp := 0.0
	amp = maxf(amp, 7.0 * (1.0 - _ph(T_BLAST, T_BLAST + 1.2)) if _t >= T_BLAST else 0.0)
	amp = maxf(amp, 4.0 * (1.0 - _ph(T_JUDGE, T_JUDGE + 1.5)) if _t >= T_JUDGE else 0.0)
	amp = maxf(amp, 6.0 * (1.0 - _ph(T_CLASH, T_CLASH + 0.5)) if _t >= T_CLASH else 0.0)
	amp = maxf(amp, 5.0 * (1.0 - _ph(T_LOGO, T_LOGO + 0.5)) if _t >= T_LOGO else 0.0)
	for w in WORLDS:
		if _t >= w[0] and _t < w[0] + 0.4:
			amp = maxf(amp, 3.0 * (1.0 - (_t - w[0]) / 0.4))
	_shake = Vector2((_h(_t * 91.0) - 0.5), (_h(_t * 57.0 + 3.0) - 0.5)) * 2.0 * amp
	_world.position = _shake

func _put(id: StringName, x: float, y: float, h: float, face: int, pose: StringName, alpha: float = 1.0, rot: float = 0.0) -> void:
	if alpha <= 0.01:
		return
	var r: FighterRenderer = _fighters[id]
	var s := h / maxf(r.approx_height(), 1.0)
	r.visible = true
	r.scale = Vector2(s * face, s)
	r.position = Vector2(x, y)
	r.rotation = rot
	r.pose_name = pose
	r.modulate.a = alpha
	r.z_index = int(y)

func _place_fighters() -> void:
	for r in _fighters.values():
		(r as FighterRenderer).visible = false
		(r as FighterRenderer).rotation = 0.0
	var t := _t
	if t < T_COLLIDE:
		_place_scientists()
	elif t < T_RUINS:
		_place_world()
	elif t < T_SELECT:
		_place_ruins()
	elif t < T_CIRCLE:
		_place_select()
	elif t < T_BUILD:
		_place_circle()
	else:
		_place_duel()

func _place_scientists() -> void:
	for i in SCIENTISTS.size():
		var e: Array = SCIENTISTS[i]
		var a := _ph(e[3], e[3] + 0.6)
		var x: float = e[2]
		var pose := &"idle"
		var face := 1 if x < W * 0.5 else -1
		if i == 0:
			# Tesla camina hasta la palanca de la izquierda y la acciona.
			var w := _ph(14.0, 15.0)
			x = lerpf(x, 66.0, _ease(w))
			if w > 0.0 and w < 1.0:
				pose = &"walk"
			face = -1 if w > 0.0 else 1
		var y := 212.0
		var h := 86.0
		var rot := 0.0
		if _t >= T_BLAST:
			# Los absorbe el Nexo: giran hacia la grieta y se encogen.
			var p := _ease((_t - 20.0) / 7.0)
			x = lerpf(x, W * 0.5, p)
			y = lerpf(y, 100.0, p)
			h = lerpf(h, 14.0, p)
			rot = p * 14.0
			a *= 1.0 - _ph(25.0, 27.5)
			pose = &"hit"
		elif _t >= T_LEVER and i == 0:
			pose = &"idle"
		_put(e[0], x, y, h, face, pose, a, rot)

func _place_world() -> void:
	var idx := _world_index()
	var lt := _t - float(WORLDS[idx][0])
	var a := clampf(lt / 0.35, 0.0, 1.0)
	match idx:
		0: _put(&"cleopatra", 300.0, 204.0, 108.0, -1, &"idle", a)
		1: _put(&"julio_cesar", 150.0, 204.0, 108.0, 1, &"victory", a)
		2: _put(&"gengis_kan", lerpf(60.0, 350.0, lt / 5.5), 204.0, 108.0, 1, &"run", a)
		3: _put(&"pachacutec", 213.0, 204.0, 116.0, 1, &"idle", a)
		4:
			_put(&"lautaro", 130.0, 204.0, 108.0, 1, &"idle", a)
			_put(&"janequeo", 296.0, 204.0, 108.0, -1, &"idle", a)

func _place_ruins() -> void:
	for i in RUINS.size():
		var lt := _t - (T_RUINS + 0.2 + i * 0.9)
		var a := clampf(lt / 0.25, 0.0, 1.0) * (1.0 - _ph(80.0, 83.0))
		var bob := 0.0 if _t < T_JUDGE else sin(_t * 1.6 + i) * 1.5 * _ph(T_JUDGE, T_JUDGE + 3.0)
		_put(RUINS[i][0], RUINS[i][1], 200.0 + bob, 92.0, 1 if i < 3 else -1, &"idle", a)

func _select_index() -> int:
	return clampi(int((_t - T_SELECT) / SELECT_STEP), 0, CAST.size() - 1)

func _place_select() -> void:
	var i := _select_index()
	var lt := _t - (T_SELECT + i * SELECT_STEP)
	var slide := _ease(lt / 0.2)
	_put(CAST[i][0], lerpf(-60.0, 142.0, slide), 206.0, 132.0, 1, &"victory" if lt > 0.25 else &"idle")

func _circle_pos(i: int) -> Vector3:
	var a := TAU * i / CAST.size() + (_t - T_CIRCLE) * 0.25 - PI * 0.5
	var arrive := _ease((_t - T_CIRCLE - i * 0.06) / 1.2)
	var dep := sin(a)   # -1 al fondo, 1 al frente
	var target := Vector2(W * 0.5 + cos(a) * 158.0, 168.0 + dep * 26.0)
	var from := Vector2(142.0, 206.0)
	var p := from.lerp(target, arrive)
	return Vector3(p.x, p.y, lerpf(132.0, 62.0 + dep * 20.0, arrive))

func _place_circle() -> void:
	for i in CAST.size():
		var v := _circle_pos(i)
		_put(CAST[i][0], v.x, v.y, v.z, 1 if v.x < W * 0.5 else -1, &"idle")

func _duel_x(side: int) -> float:
	var run := _ease((_t - 111.7) / 3.3)
	if _t >= T_CLASH:
		run = 1.0
	return lerpf(30.0, 192.0, run) if side == 0 else lerpf(396.0, 234.0, run)

func _place_duel() -> void:
	if _t >= T_LOGO - 0.3:
		return
	var hit := _t >= T_CLASH
	var pose_l: StringName = &"straight" if hit else &"run"
	var pose_r: StringName = &"straight" if hit else &"run"
	_put(&"lautaro", _duel_x(0), 206.0, 116.0, 1, pose_l)
	_put(&"julio_cesar", _duel_x(1), 206.0, 116.0, -1, pose_r)
	if hit and not _clash_frozen:
		_clash_frozen = true
		Sfx.play(&"hit_heavy")
		Sfx.play(&"cannon")
	(_fighters[&"lautaro"] as FighterRenderer).set_process(not hit or _t < T_CLASH + 0.04)
	(_fighters[&"julio_cesar"] as FighterRenderer).set_process(not hit or _t < T_CLASH + 0.04)

# =========================================================================
#  Fondo (debajo de los luchadores)
# =========================================================================
func _draw() -> void:
	draw_set_transform(_shake, 0.0, Vector2.ONE)
	if _t < T_COLLIDE:
		_bg_lab()
	elif _t < T_RUINS:
		pass   # el escenario del luchador se ve a través (hijo con show_behind_parent)
	elif _t < T_SELECT:
		_bg_ruins()
		if _t >= T_JUDGE:
			_nexo_sphere(self)
		if _t >= T_ARENA:
			_bg_arena(self, _ease((_t - T_ARENA) / 8.0))
	elif _t < T_LOGO - 0.3:
		_bg_arena(self, 1.0)
		if _t < T_CIRCLE:
			_select_backdrop()
		elif _t < T_BUILD:
			_circle_floor()
		else:
			_duel_backdrop()
	else:
		_bg_logo()

# --- I y II: el laboratorio -----------------------------------------------
func _spin_phase() -> float:
	var ph := minf(_t, T_BLAST)
	return ph + 2.4 * pow(maxf(0.0, ph - T_LEVER), 2.0)

func _bg_lab() -> void:
	var t := _t
	var dt := t - T_BLAST
	draw_rect(Rect2(0, 0, W, H), VOID)
	if t < T_BLAST + 0.05:
		_lab_room(t)
	else:
		_nexo_swirl(dt)
		_debris(dt)
		_crack(dt)

func _lab_room(t: float) -> void:
	var sp := _spin_phase()
	# Bóveda: costillas que convergen y arcos concéntricos.
	for i in range(-7, 8):
		draw_line(Vector2(W * 0.5, -30), Vector2(W * 0.5 + i * 62.0, H), Color(BRASS_D, 0.5), 1.0)
	for r in [110.0, 190.0, 270.0, 350.0]:
		draw_arc(Vector2(W * 0.5, 270.0), r, PI, TAU, 56, Color(BRASS_D, 0.55), 1.0)
	# Reloj del Origen: empieza en primer plano y se aleja hasta un plano general.
	var c := Vector2(W * 0.5, 106.0)
	var R := lerpf(124.0, 62.0, _ease(t / 12.0))
	_gear(self, c + Vector2(-R * 1.55, 24), R * 0.62, 14, sp * 0.45, BRASS_D, VOID)
	_gear(self, c + Vector2(R * 1.55, 24), R * 0.62, 14, -sp * 0.45 + 0.2, BRASS_D, VOID)
	_gear(self, c + Vector2(-R * 0.95, -R * 0.78), R * 0.3, 10, -sp * 0.9, BRASS, VOID)
	_gear(self, c + Vector2(R * 0.95, -R * 0.78), R * 0.3, 10, sp * 0.9, BRASS, VOID)
	draw_circle(c, R + 7, BRASS_D)
	draw_arc(c, R + 4, 0, TAU, 64, BRASS, 5.0)
	draw_arc(c, R - 6, 0, TAU, 64, BRASS_D.lightened(0.25), 2.0)
	draw_circle(c, R - 8, Color("120a1c"))
	var glow := 0.5 + 0.5 * sin(t * 3.0)
	for k in 14:
		var a := TAU * k / 14.0 + sp * 0.12
		var p0 := c + Vector2.from_angle(a) * (R - 10)
		var p1 := c + Vector2.from_angle(a) * (R * 0.55)
		var pl := c + Vector2.from_angle(a + 0.13) * (R * 0.78)
		draw_colored_polygon(PackedVector2Array([p0, pl, p1]), Color(CYAN, 0.35 + 0.25 * glow))
		draw_line(p0, p1, Color(CYAN, 0.9), 1.0)
	_gear(self, c, R * 0.32, 12, -sp * 0.6, BRASS, Color("120a1c"))
	# Manecillas imposibles: una gira al revés y otra a velocidades distintas.
	draw_line(c, c + Vector2.from_angle(sp * 0.7) * R * 0.78, NEXO_GOLD, 2.0)
	draw_line(c, c + Vector2.from_angle(-sp * 3.1) * R * 0.55, CYAN, 1.0)
	# Bobinas con arcos eléctricos hacia la máquina.
	for sx in [96.0, 330.0]:
		draw_circle(Vector2(sx, 46), 9, BRASS)
		draw_circle(Vector2(sx, 46), 6, Color("2a1830"))
		draw_rect(Rect2(sx - 2, 55, 4, 40), BRASS_D)
	var charge := 0.35 + 0.65 * _ph(11.0, T_LEVER)
	var q := floorf(t * 14.0)
	for i in 3:
		if _h(q + i * 5.0) < charge:
			_bolt(self, Vector2(96, 46), c + Vector2.from_angle(_h(q + i) * TAU) * R * 0.9, q + i, CYAN, 1.0)
			_bolt(self, Vector2(330, 46), c + Vector2.from_angle(_h(q + i + 9) * TAU) * R * 0.9, q + i + 40, VIOLET, 1.0)
	# Palanca maestra a la izquierda.
	draw_rect(Rect2(20, 160, 34, 52), Color("1a1220"))
	draw_rect(Rect2(20, 160, 34, 52), BRASS, false, 1.0)
	var lever := lerpf(-0.9, 0.9, _ease((t - T_LEVER) / 0.3))
	var piv := Vector2(37, 196)
	var tip := piv + Vector2(sin(lever), -cos(lever)) * 26.0
	draw_line(piv, tip, Color("c0c0d0"), 3.0)
	draw_circle(tip, 4, Color("c02028") if t < T_LEVER else Color("40ff70"))
	draw_circle(piv, 3, BRASS)

# --- Después de la explosión ----------------------------------------------
func _crack(dt: float) -> void:
	var grow := _ease(dt / 1.2)
	var pts := _crack_points(H * 0.5 - H * 0.5 * grow, H * 0.5 + H * 0.5 * grow, 4.0, 46.0)
	var wob := 0.7 + 0.3 * sin(dt * 9.0)
	draw_polyline(pts, Color(VIOLET, 0.25 * wob), 22.0)
	draw_polyline(pts, Color(VIOLET, 0.6), 10.0)
	draw_polyline(pts, NEXO_GOLD, 5.0)
	draw_polyline(pts, Color("02000a"), 2.5)

func _nexo_swirl(dt: float) -> void:
	var c := Vector2(W * 0.5, 106.0)
	var grow := _ease(dt / 6.0)
	var fade := 1.0 - _ph(30.0, 32.5)
	for i in 6:
		draw_circle(c, (30.0 + i * 26.0) * grow, Color(VIOLET, 0.07 * fade))
	for i in 110:
		var dir := 1.0 if i % 2 == 0 else -1.0
		var a := _h(i) * TAU + dt * (0.5 + _h(i + 7.0)) * dir
		var r := grow * (14.0 + _h(i + 3.0) * 190.0)
		var p := c + Vector2(cos(a) * r, sin(a) * r * 0.62)
		var col := [NEXO_GOLD, CYAN, VIOLET][i % 3] as Color
		draw_circle(p, 1.5 + _h(i + 11.0) * 4.5, Color(col, 0.85 * fade))

func _debris(dt: float) -> void:
	var fade := 1.0 - _ph(T_BLAST + 3.0, T_BLAST + 7.0)
	if fade <= 0.0:
		return
	var c := Vector2(W * 0.5, 106.0)
	for i in 46:
		var a := _h(i) * TAU
		var v := Vector2.from_angle(a) * (60.0 + _h(i + 5.0) * 230.0)
		var p := c + v * dt + Vector2(0, 90.0 * dt * dt)
		var col := [CYAN, BRASS, Color("ffffff")][i % 3] as Color
		_quad(self, p, 2.0 + _h(i + 2.0) * 7.0, 2.0 + _h(i + 8.0) * 5.0, dt * (2.0 + _h(i)) * 3.0, Color(col, fade))

# --- Ruinas, esfera y coliseo ---------------------------------------------
func _bg_ruins() -> void:
	var bands := [Color("05020a"), Color("0a0415"), Color("12081f"), Color("1c0c2c"), Color("2a1238"), Color("3a1a40")]
	for i in bands.size():
		draw_rect(Rect2(0, i * 32, W, 32), bands[i])
	for i in 36:
		draw_rect(Rect2(_h(i) * W, _h(i + 9.0) * 120.0, 1, 1), Color(1, 1, 1, 0.3 + 0.4 * _h(i + 2.0)))
	# Trozos de mundo flotando en el cielo.
	for i in 9:
		var p := Vector2(_h(i + 1.0) * W, 30.0 + _h(i + 4.0) * 90.0 + sin(_t * 0.5 + i) * 3.0)
		_quad(self, p, 8.0 + _h(i + 6.0) * 22.0, 4.0 + _h(i + 3.0) * 8.0, _h(i) - 0.5 + sin(_t * 0.3 + i) * 0.1, Color("1c1224"))
	# Suelo volcánico con grietas de lava y columnas rotas.
	draw_rect(Rect2(0, 196, W, 44), Color("0c060f"))
	draw_rect(Rect2(0, 196, W, 1), Color("5a2028"))
	for i in 6:
		var x := 20.0 + i * 74.0 + _h(i) * 20.0
		var hh := 20.0 + _h(i + 5.0) * 34.0
		draw_rect(Rect2(x, 196 - hh, 9, hh), Color("160c1c"))
		draw_rect(Rect2(x - 2, 196 - hh, 13, 3), Color("22122a"))
	for i in 5:
		var pts := _crack_points(197.0, 240.0, i * 11.0, 60.0)
		for k in pts.size():
			pts[k].x = 30.0 + i * 85.0 + (pts[k].x - W * 0.5)
		draw_polyline(pts, Color(NEXO_GOLD, 0.5 + 0.3 * sin(_t * 2.0 + i)), 1.0)
	# Bloques de piedra que levitan hacia la esfera.
	if _t > T_JUDGE + 4.0:
		for i in 16:
			var rise := _ease((_t - T_JUDGE - 4.0 - _h(i) * 3.0) / 6.0)
			var p := Vector2(20.0 + _h(i + 1.0) * (W - 40.0), 188.0 - rise * (70.0 + _h(i + 4.0) * 80.0))
			_quad(self, p, 6.0 + _h(i + 2.0) * 12.0, 4.0 + _h(i + 6.0) * 9.0, rise * (1.0 + _h(i)), Color("2a1c34"))
			draw_rect(Rect2(p.x - 2, p.y - 2, 4, 1), Color(NEXO_GOLD, 0.5 * rise))

func _nexo_sphere(ci: CanvasItem) -> void:
	var grow := _ease((_t - T_JUDGE) / 3.0)
	if grow <= 0.0:
		return
	var c := Vector2(W * 0.5, 76.0 + sin(_t * 1.1) * 2.0)
	var r := 26.0 * grow
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	for i in 5:
		ci.draw_circle(c, r * (2.4 - i * 0.35), Color(NEXO_GOLD, 0.05 + 0.02 * i))
	ci.draw_circle(c, r + 3.0, Color(VIOLET, 0.7))
	ci.draw_circle(c, r, NEXO_GOLD)
	ci.draw_circle(c, r * 0.72, Color("fff0a0"))
	ci.draw_circle(c, r * 0.38, Color.WHITE)
	for k in 3:
		var a0 := _t * (1.2 + k * 0.5) + k * 2.1
		ci.draw_arc(c, r * (1.25 + k * 0.18), a0, a0 + 2.2, 24, [CYAN, VIOLET, CYAN][k] as Color, 2.0)
	ci.draw_arc(c, r * 1.6 + pulse * 3.0, 0, TAU, 48, Color(CYAN, 0.35), 1.0)

func _bg_arena(ci: CanvasItem, a: float) -> void:
	if a <= 0.0:
		return
	# Gradas en tres pisos con arcos; el público espectral las va llenando.
	ci.draw_rect(Rect2(0, 0, W, 176), Color(VOID, a))
	var orbit := sin((_t - T_JUDGE) * 0.45)
	var fill := _ease((_t - 80.0) / 10.0)
	for row in 3:
		var y := 70.0 + row * 36.0
		var shift := orbit * (6.0 + row * 8.0)
		ci.draw_rect(Rect2(0, y, W, 36), Color(0.07 + row * 0.015, 0.03, 0.12 + row * 0.02, a))
		ci.draw_rect(Rect2(0, y, W, 1), Color(CYAN, 0.5 * a))
		for k in range(-2, 24):
			var x := k * 20.0 + shift
			ci.draw_rect(Rect2(x, y + 12, 12, 22), Color(0.02, 0.01, 0.05, a))
			var hs := _h(k * 7.0 + row * 31.0)
			if hs < fill:
				var bob := sin(_t * 3.0 + k) * 1.0
				ci.draw_rect(Rect2(x + 4, y + 17 + bob, 4, 7), Color(CYAN.lerp(Color.WHITE, 0.4), 0.55 * a))
				ci.draw_rect(Rect2(x + 4, y + 14 + bob, 4, 3), Color(CYAN.lerp(Color.WHITE, 0.4), 0.7 * a))
	# Arena de roca y cristal negro.
	ci.draw_rect(Rect2(0, 176, W, 64), Color(0.03, 0.015, 0.06, a))
	ci.draw_rect(Rect2(0, 176, W, 2), Color(NEXO_GOLD, 0.6 * a))
	for i in 9:
		ci.draw_line(Vector2(W * 0.5 + (i - 4) * 14.0, 178), Vector2(W * 0.5 + (i - 4) * 70.0, 240), Color(VIOLET, 0.25 * a), 1.0)

func _select_backdrop() -> void:
	var i := _select_index()
	var lt := _t - (T_SELECT + i * SELECT_STEP)
	var col: Color = CAST[i][2]
	# Foco de luz y aura del luchador actual.
	draw_colored_polygon(PackedVector2Array([Vector2(142, 0), Vector2(60, 206), Vector2(224, 206)]), Color(col, 0.12))
	for k in 5:
		draw_circle(Vector2(142, 150), 70.0 - k * 12.0, Color(col, 0.05))
	_aura(self, Vector2(142, 150), col, CAST[i][3], _t, 1.8)
	draw_ellipse_floor(Vector2(142, 207), 60.0, col)
	# Barras diagonales de "corte" al cambiar de luchador.
	var cut := 1.0 - clampf(lt / 0.15, 0.0, 1.0)
	if cut > 0.0:
		for k in 8:
			draw_rect(Rect2(k * 60.0 - 40.0 + lt * 400.0, 0, 18, H), Color(col, 0.18 * cut))

func draw_ellipse_floor(c: Vector2, rx: float, col: Color) -> void:
	draw_set_transform(c + _shake, 0.0, Vector2(1, 0.22))
	draw_circle(Vector2.ZERO, rx, Color(col, 0.35))
	draw_circle(Vector2.ZERO, rx * 0.7, Color(col, 0.2))
	draw_set_transform(_shake, 0.0, Vector2.ONE)

func _circle_floor() -> void:
	var a := _ease((_t - T_CIRCLE) / 1.5)
	draw_set_transform(Vector2(W * 0.5, 184) + _shake, 0.0, Vector2(1, 0.2))
	for k in 3:
		var col := [NEXO_GOLD, CYAN, VIOLET][k] as Color
		draw_arc(Vector2.ZERO, 150.0 - k * 10.0, 0, TAU, 64, Color(col, 0.7 * a), 3.0)
		draw_circle(Vector2.ZERO, 120.0 - k * 22.0, Color(col, 0.05 * a))
	draw_set_transform(_shake, 0.0, Vector2.ONE)

func _duel_backdrop() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.35))
	var run := _ease((_t - 111.7) / 3.3)
	# Rayas de velocidad mientras corren.
	if _t < T_CLASH:
		for i in 14:
			var y := 120.0 + _h(i) * 84.0
			var x := fposmod(_h(i + 3.0) * W - _t * 600.0 * (1.0 if i % 2 == 0 else -1.0), W + 80.0) - 40.0
			draw_rect(Rect2(x, y, 40.0 + 40.0 * run, 1), Color(CYAN, 0.35))

func _bg_logo() -> void:
	draw_rect(Rect2(0, 0, W, H), VOID)
	var lt := _t - T_LOGO
	var c := Vector2(W * 0.5, 100.0)
	var k := _ease(lt / 1.2)
	for i in 28:
		var a0 := TAU * i / 28.0 + _t * 0.15
		var col := (NEXO_GOLD if i % 2 == 0 else (CYAN if i % 4 == 1 else VIOLET))
		var p1 := c + Vector2.from_angle(a0) * 420.0
		var p2 := c + Vector2.from_angle(a0 + 0.07) * 420.0
		draw_colored_polygon(PackedVector2Array([c, p1, p2]), Color(col, 0.10 * k))
	for i in 5:
		draw_circle(c, 90.0 - i * 16.0, Color(NEXO_GOLD, 0.04 * k))
	for i in 40:
		var p := Vector2(_h(i) * W, fposmod(_h(i + 5.0) * H - _t * (8.0 + _h(i + 2.0) * 20.0), H))
		draw_rect(Rect2(p, Vector2(1, 1)), Color(NEXO_GOLD, 0.6))

# =========================================================================
#  Auras de poder
# =========================================================================
func _aura(ci: CanvasItem, c: Vector2, col: Color, kind: int, t: float, s: float) -> void:
	match kind:
		0:   # rayos
			var q := floorf(t * 12.0)
			for i in 6:
				var a := _h(q * 7.0 + i) * TAU
				_bolt(ci, c + Vector2.from_angle(a) * 12.0 * s, c + Vector2.from_angle(a + (_h(q + i) - 0.5)) * 52.0 * s, q + i, col, 1.5, 8.0)
		1:   # llamas
			for i in 30:
				var k := fposmod(t * 0.9 + _h(i), 1.0)
				var p := c + Vector2((_h(i + 2.0) - 0.5) * 56.0 * s * (1.0 - k * 0.5), 44.0 * s - k * 120.0 * s)
				var sz := 4.0 * (1.0 - k) + 1.0
				ci.draw_rect(Rect2(p, Vector2(sz, sz)), Color(col, 1.0 - k))
		2:   # órbita
			for i in 10:
				var a := t * 2.4 + TAU * i / 10.0
				var p := c + Vector2(cos(a) * 46.0 * s, sin(a) * 18.0 * s)
				ci.draw_circle(p, 2.5, Color(col, 0.55 if sin(a) < 0.0 else 1.0))
			ci.draw_arc(c, 40.0 * s, 0, TAU, 40, Color(col, 0.3), 1.0)
		3:   # destellos
			for i in 14:
				var a := TAU * i / 14.0 + t * 0.4
				var d := Vector2.from_angle(a)
				ci.draw_line(c + d * 16.0 * s, c + d * (56.0 + 12.0 * sin(t * 5.0 + i)) * s, Color(col, 0.65), 2.0)

# =========================================================================
#  Primer plano (encima de los luchadores): efectos, textos, subtítulos
# =========================================================================
func _draw_fx() -> void:
	var t := _t
	if t < 14.0:
		_fx_scientists()
	if t >= T_LEVER and t < T_BLAST:
		_fx_blackout()
	if t >= T_BLAST and t < T_COLLIDE:
		_fx_blast()
	if t >= T_COLLIDE and t < T_RUINS:
		_fx_world()
	if t >= T_RUINS and t < T_ARENA + 4.0:
		_fx_ruins()
	if t >= T_SELECT and t < T_CIRCLE:
		_fx_select()
	if t >= T_CIRCLE and t < T_BUILD:
		_fx_circle()
	if t >= T_BUILD and t < T_LOGO - 0.3:
		_fx_duel()
	if t >= T_LOGO - 0.3:
		_fx_logo()
	_fx_cards()
	_fx_subtitles()
	if t < 3.0:
		HKTheme.draw_text(_fx, Vector2(0, 232), "CUALQUIER TECLA: SALTAR", 8, Color(HKTheme.MUTED, 1.0 - _ph(2.0, 3.0)),
			HORIZONTAL_ALIGNMENT_RIGHT, W - 6, 1)
	# Fundido inicial desde negro.
	if t < 1.2:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 1.0 - t / 1.2))
	# Fundido de salida al final de la fusión.
	if t > T_END + 4.0:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, _ph(T_END + 4.0, T_END + 6.0)))

func _fx_scientists() -> void:
	for i in SCIENTISTS.size():
		var e: Array = SCIENTISTS[i]
		var a := _ph(e[3], e[3] + 0.6)
		if a <= 0.0:
			continue
		var x: float = e[2]
		if i == 0:
			x = lerpf(x, 66.0, _ease(_ph(14.0, 15.0)))
		_txt(_fx, 118.0, e[1], 8, Color(HKTheme.GOLD, a), x - 40.0, 80.0)
		# Cada uno con lo suyo en la mano.
		var hand := Vector2(x + (14.0 if x < W * 0.5 and i != 0 else -14.0), 170.0)
		if i == 0 and _t >= 15.0:
			continue
		match i:
			0:
				_fx.draw_rect(Rect2(hand.x - 4, hand.y - 4, 8, 8), BRASS)
				_bolt(_fx, hand, hand + Vector2(10, -16), floorf(_t * 16.0), CYAN, 1.0, 3.0)
			1:
				_fx.draw_circle(hand, 6, BRASS)
				_fx.draw_circle(hand, 4.5, Color("f4ead0"))
				_fx.draw_line(hand, hand + Vector2.from_angle(_t * 5.0) * 4.0, Color.BLACK, 1.0)
				_fx.draw_line(hand, hand + Vector2.from_angle(-_t * 9.0) * 3.0, Color.BLACK, 1.0)
			2:
				_fx.draw_circle(hand, 8, Color(0.3, 1.0, 0.4, 0.25 + 0.15 * sin(_t * 4.0)))
				_fx.draw_rect(Rect2(hand.x - 2, hand.y - 4, 4, 8), Color("60ff70"))
			3:
				var tri := PackedVector2Array([hand + Vector2(0, -20), hand + Vector2(-9, -3), hand + Vector2(9, -3)])
				_fx.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(NEXO_GOLD, 0.5 + 0.4 * sin(_t * 5.0)), 1.0)
				_fx.draw_line(hand + Vector2(0, -3), hand + Vector2(-6, 6), Color("c0c0d0"), 1.0)
				_fx.draw_line(hand + Vector2(0, -3), hand + Vector2(6, 6), Color("c0c0d0"), 1.0)

func _fx_blackout() -> void:
	# Se apagan las luces y queda el silencio absoluto antes de la explosión.
	var a := 0.97 * _ease((_t - T_LEVER - 0.2) / 0.8)
	_fx.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, a))
	if _t > T_LEVER + 1.0:
		# Solo un hilo de luz cian que tiembla en el centro.
		var w := 2.0 + 3.0 * _ph(T_LEVER + 1.0, T_BLAST)
		_fx.draw_rect(Rect2(W * 0.5 - w * 0.5, 96, w, 20), Color(CYAN, 0.35 + 0.4 * _h(floorf(_t * 30.0))))

func _fx_blast() -> void:
	var dt := _t - T_BLAST
	if dt < 0.8:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 0.9, 1.0 - dt / 0.8))
	if dt < 1.6:
		var r := dt * 380.0
		_fx.draw_arc(Vector2(W * 0.5, 106), r, 0, TAU, 72, Color(NEXO_GOLD, 1.0 - dt / 1.6), 4.0)
		_fx.draw_arc(Vector2(W * 0.5, 106), r * 0.7, 0, TAU, 72, Color(CYAN, 0.8 * (1.0 - dt / 1.6)), 2.0)
	# Fundido a negro hacia el siguiente capítulo.
	_fx.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, _ph(31.5, T_COLLIDE)))

func _fx_world() -> void:
	var idx := _world_index()
	var w: Array = WORLDS[idx]
	var lt := _t - float(w[0])
	_fx.draw_rect(Rect2(0, 0, W, H), w[3])
	match idx:
		0:   # auroras cian y hologramas rotos
			for k in 4:
				var pts := PackedVector2Array()
				for x in range(0, int(W) + 12, 12):
					pts.append(Vector2(x, 22.0 + k * 11.0 + sin(x * 0.03 + _t * 1.3 + k) * 7.0))
				_fx.draw_polyline(pts, Color(CYAN if k % 2 == 0 else Color("60ff90"), 0.35), 3.0)
			for k in 3:
				if _h(floorf(_t * 6.0) + k) > 0.3:
					_fx.draw_rect(Rect2(40 + k * 90, 80 + k * 14, 50, 30), Color(CYAN, 0.45), false, 1.0)
		1:   # ceniza naranja
			for k in 40:
				var p := Vector2(fposmod(_h(k) * W + _t * 30.0, W), fposmod(_h(k + 5.0) * H + _t * 22.0, H))
				_fx.draw_rect(Rect2(p, Vector2(1, 1)), Color("ffa040"))
		2:   # polvo de la estepa
			for k in 18:
				var p := Vector2(fposmod(_h(k) * W - _t * 160.0, W + 60.0) - 30.0, 120.0 + _h(k + 2.0) * 90.0)
				_fx.draw_line(p, p + Vector2(26, 0), Color(0.8, 0.85, 1.0, 0.25), 1.0)
		3:   # grietas de lava dorada
			for k in 4:
				var pts := _crack_points(110.0, 240.0, k * 13.0, 80.0)
				for j in pts.size():
					pts[j].x = 40.0 + k * 115.0 + (pts[j].x - W * 0.5)
				_fx.draw_polyline(pts, Color(NEXO_GOLD, 0.35), 6.0)
				_fx.draw_polyline(pts, Color("fff0a0"), 1.5)
		4:   # dos lunas y un cielo desgarrado
			_fx.draw_circle(Vector2(88, 46), 15, Color("e8e8f8"))
			_fx.draw_circle(Vector2(82, 42), 3, Color("c8c8dc"))
			_fx.draw_circle(Vector2(336, 62), 10, Color("d8d0f0"))
			var tear := _crack_points(0.0, 150.0, 70.0, 70.0)
			_fx.draw_polyline(tear, Color(VIOLET, 0.5), 6.0)
			_fx.draw_polyline(tear, Color("02000a"), 2.0)
	# Cortes de glitch: el tiempo se está rompiendo.
	var q := floorf(_t * 9.0)
	for k in 2:
		if _h(q + k * 3.0) > 0.55:
			var y := _h(q + k) * H
			_fx.draw_rect(Rect2(0, y, W, 2 + _h(q) * 5.0), Color(CYAN if k == 0 else VIOLET, 0.28))
	# Rótulo del mundo y destello de entrada.
	var shown := int(lt * 30.0)
	_txt(_fx, 40.0, (w[2] as String).left(shown), 8, HKTheme.GOLD, 0.0, W)
	if lt < 0.3:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(0.8, 0.7, 1.0, 0.8 * (1.0 - lt / 0.3)))

func _fx_ruins() -> void:
	# Columnas de luz donde cae cada luchador.
	for i in RUINS.size():
		var lt := _t - (T_RUINS + 0.2 + i * 0.9)
		if lt > -0.3 and lt < 0.6:
			var w := 16.0 * (1.0 - absf(lt - 0.15) / 0.5)
			_fx.draw_rect(Rect2(RUINS[i][1] - w * 0.5, 0, w, 200), Color(NEXO_GOLD, 0.45))
	if _t < T_RUINS + 0.7:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 0.9, 0.7, 0.6 * (1.0 - (_t - T_RUINS) / 0.7)))
	if _t < T_RUINS + 4.5:
		_txt(_fx, 40.0, "UN MISMO CAMPO DE RUINAS", 8, Color(HKTheme.GOLD, 1.0 - _ph(T_RUINS + 3.5, T_RUINS + 4.5)))
	if _t >= T_JUDGE and _t < T_JUDGE + 0.5:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 0.9, 0.7 * (1.0 - (_t - T_JUDGE) / 0.5)))

func _fx_select() -> void:
	var i := _select_index()
	var lt := _t - (T_SELECT + i * SELECT_STEP)
	var d: FighterData = (_fighters[CAST[i][0]] as FighterRenderer).data
	var col: Color = CAST[i][2]
	var slide := _ease((lt - 0.05) / 0.2)
	var x := lerpf(470.0, 236.0, slide)
	_fx.draw_rect(Rect2(x - 8, 70, 220, 62), Color(0.03, 0.01, 0.06, 0.78))
	_fx.draw_rect(Rect2(x - 8, 70, 3, 62), col)
	HKTheme.draw_text(_fx, Vector2(x, 92), d.short_name.to_upper(), 16, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
	HKTheme.draw_text(_fx, Vector2(x, 108), d.era.to_upper(), 8, HKTheme.MUTED.lightened(0.25), HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	HKTheme.draw_text(_fx, Vector2(x, 124), CAST[i][1], 8, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	HKTheme.draw_text(_fx, Vector2(W - 70, 22), "%02d / %02d" % [i + 1, CAST.size()], 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 2)
	if lt < 0.1:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.3 * (1.0 - lt / 0.1)))

func _fx_circle() -> void:
	_txt(_fx, 40.0, "QUINCE LUCHADORES. UN SOLO TRONO.", 8, Color(HKTheme.GOLD, _ph(T_CIRCLE + 0.5, T_CIRCLE + 1.5)))
	# Nombre del luchador que pasa al frente del círculo.
	if _t > T_CIRCLE + 2.0:
		var front := 0
		for i in CAST.size():
			if _circle_pos(i).y > _circle_pos(front).y:
				front = i
		var v := _circle_pos(front)
		var d: FighterData = (_fighters[CAST[front][0]] as FighterRenderer).data
		_txt(_fx, 202.0, d.short_name.to_upper(), 8, CAST[front][2], v.x - 60.0, 120.0, 2)
	if _t < T_CIRCLE + 0.2:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.6 * (1.0 - (_t - T_CIRCLE) / 0.2)))

func _fx_duel() -> void:
	if _t < T_BUILD + 0.25:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.9 * (1.0 - (_t - T_BUILD) / 0.25)))
	if _t >= T_CLASH:
		var dt := _t - T_CLASH
		var c := Vector2(213.0, 150.0)
		# Explosión dorada y cian: líneas radiales y onda expansiva.
		var reach := minf(dt, 0.25) * 900.0 + dt * 40.0
		for i in 26:
			var a := TAU * i / 26.0 + _h(i) * 0.2
			var col := NEXO_GOLD if i % 2 == 0 else CYAN
			_fx.draw_line(c + Vector2.from_angle(a) * reach * 0.25, c + Vector2.from_angle(a) * reach * (0.6 + _h(i + 3.0) * 0.5), col, 2.0 if i % 3 else 4.0)
		_fx.draw_arc(c, minf(dt, 0.4) * 500.0, 0, TAU, 64, Color(NEXO_GOLD, 0.8), 5.0)
		_fx.draw_circle(c, 30.0 * (1.0 + dt), Color(1, 1, 1, 0.9 * (1.0 - clampf(dt / 0.3, 0.0, 1.0))))
		if dt < 0.12:
			_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 1.0 - dt / 0.12))
		# Cuadro congelado: viñeta y corte a negro.
		_fx.draw_rect(Rect2(0, 0, W, H), Color(0.0, 0.0, 0.1, 0.25 * _ph(T_CLASH + 0.15, T_CLASH + 0.5)))
		if _t >= T_CLASH + 0.65:
			_fx.draw_rect(Rect2(0, 0, W, H), Color.BLACK)

func _fx_logo() -> void:
	var lt := _t - T_LOGO
	if lt < 0.0:
		_fx.draw_rect(Rect2(0, 0, W, H), Color.BLACK)
		return
	var y := 78.0
	var pivot := Vector2(W * 0.5, y + 10.0)
	# Golpe de entrada: el título cae grande y se asienta.
	var s := lerpf(2.4, 1.0, _ease(lt / 0.28))
	var a := clampf(lt / 0.1, 0.0, 1.0)
	_fx.draw_set_transform_matrix(Transform2D(0.0, Vector2(s, s), 0.0, pivot * (1.0 - s)))
	if a > 0.01:
		_txt(_fx, y + 2, "HISTORY", 24, Color(Color("5a0a10"), a), 2.0, W, 0)
		_txt(_fx, y, "HISTORY", 24, Color(HKTheme.PAPER, a), 0.0, W, 4)
		_txt(_fx, y + 37, "COMBAT", 32, Color(Color("5a0a10"), a), 3.0, W, 0)
		var glow := 0.5 + 0.5 * sin(_t * 3.0)
		_txt(_fx, y + 34, "COMBAT", 32, Color(HKTheme.GOLD.lerp(Color("fff0a0"), glow * 0.4), a), 0.0, W, 4)
	_fx.draw_set_transform_matrix(Transform2D.IDENTITY)
	if lt > 0.3:
		_fx.draw_rect(Rect2(110, y + 44, 206, 1), Color(HKTheme.GOLD_DARK, _ph(T_LOGO + 0.3, T_LOGO + 0.9)))
	var ta := _ph(T_LOGO + 1.0, T_LOGO + 2.0)
	if ta > 0.01:
		_txt(_fx, y + 62, "LA HISTORIA SE ESCRIBE A GOLPES.", 8, Color(HKTheme.BLOOD.lightened(0.4), ta), 0.0, W, 2)
	if lt > 0.0 and lt < 0.4:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 0.95, 0.7, 0.8 * (1.0 - lt / 0.4)))
	if _t > T_LOGO + 3.0:
		var on := int(_t * 2.0) % 2 == 0
		if on:
			_txt(_fx, 190.0, "[ PRESS START ]", 8, HKTheme.GOLD, 0.0, W, 2)
	if _t > T_LOGO + 5.0:
		var qa := maxf(_ph(T_LOGO + 5.0, T_LOGO + 6.5), 0.01)
		_txt(_fx, 212.0, "¿QUIÉN MERECE CONTROLAR EL DESTINO", 8, Color(HKTheme.PAPER, qa), 0.0, W, 2)
		_txt(_fx, 224.0, "DE TODA LA HISTORIA?", 8, Color(HKTheme.PAPER, qa), 0.0, W, 2)

func _fx_cards() -> void:
	for c in CARDS:
		var lt := _t - float(c[0])
		if lt < 0.0 or lt > 3.2:
			continue
		var a := minf(clampf(lt / 0.4, 0.0, 1.0), 1.0 - clampf((lt - 2.5) / 0.7, 0.0, 1.0))
		var txt: String = c[1]
		var w := HKTheme.text_width(txt, 8)
		_fx.draw_rect(Rect2(W * 0.5 - w * 0.5 - 8, 8, w + 16, 15), Color(0.03, 0.01, 0.06, 0.7 * a))
		_fx.draw_rect(Rect2(W * 0.5 - w * 0.5 - 8, 22, w + 16, 1), Color(HKTheme.GOLD_DARK, a))
		_txt(_fx, 19.0, txt, 8, Color(HKTheme.GOLD, a), 0.0, W, 1)

func _fx_subtitles() -> void:
	for s in _subs:
		if _t >= s[0] and _t < s[1]:
			var lines: PackedStringArray = (s[2] as String).split("\n")
			var a := minf(clampf((_t - s[0]) / 0.15, 0.0, 1.0), clampf((s[1] - _t) / 0.15, 0.0, 1.0))
			var h := 8.0 + lines.size() * 11.0
			var y0 := 237.0 - h
			_fx.draw_rect(Rect2(0, y0, W, h + 3.0), Color(0.02, 0.0, 0.04, 0.62 * a))
			for i in lines.size():
				_txt(_fx, y0 + 12.0 + i * 11.0, lines[i], 8, Color(HKTheme.PAPER, a), 0.0, W, 2)
			return
