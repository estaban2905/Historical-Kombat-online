## INTRO del juego (~2 minutos): cuenta cómo se rompió el tiempo y nació el torneo.
##   I    PROYECTO ORIGEN          Ginebra 2031: el colisionador, la sala de control y la IA
##   II   EL DESPERTAR DEL NEXO    la colisión que nadie ordenó, el Nexo despierta y captura a cuatro genios
##   III  LA INVASIÓN              los ejércitos de todas las épocas toman las ciudades de la Tierra
##   IV   EL ULTIMÁTUM DEL NEXO    la Tierra conquistada y el Nexo habla al mundo
##   V    LA RESISTENCIA           el último bastión entre ruinas
##   VI   LOS CAMPEONES            presentación de los campeones, la Torre del Reloj y el círculo final
##   VI   IMPACTO Y LOGOTIPO       choque, corte a negro, HISTORY COMBAT, PRESS START
## Todo se dibuja por código sobre el reloj de la música (assets/music/intro.ogg) y la narración
## (assets/sounds/intro/voice_N.wav). Solo Enter salta la intro y va al inicio de sesión.
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
const VOICE_T: Array[float] = [1.2, 18.4, 28.6, 36.0, 68.0, 104.0, 116.6]
const VOICE_LEN: Array[float] = [15.48, 9.83, 6.20, 13.68, 18.33, 6.76, 3.69]
const SUBS: Array = [
	["GINEBRA, 2031.", "POLÍTICOS Y EMPRESARIOS CODICIOSOS QUIEREN\nCONTROLAR LA GRAVEDAD, POR DINERO Y PODER.", "PRESIONAN AL CERN, QUE ARRIESGA TODO."],
	["NADIE LO ORDENÓ:\nDE LA COLISIÓN NACIÓ EL NEXO.", "VIO TODA LA HISTORIA A LA VEZ,\nY QUISO SER SU ORIGEN."],
	["CAPTURÓ A CUATRO GENIOS Y LOS OBLIGÓ", "A CONSTRUIR EL RELOJ DEL ORIGEN."],
	["LA COLISIÓN MEZCLÓ LAS ÉPOCAS: DE LA GRIETA\nCAYERON LOS IMPERIOS Y LOS EJÉRCITOS DE TODOS LOS TIEMPOS.", "HOY MARCHAN SOBRE LA TIERRA,\nY LAS CIUDADES ARDEN."],
	["EL NEXO HABLÓ AL MUNDO:", "CADA UNO ANHELA VOLVER AL DÍA EN QUE PERDIÓ.", "QUIEN CONQUISTE LA TIERRA, REGRESARÁ.", "PERO SOLO UNO RECLAMARÁ MI PODER...", "Y DECIDIRÁ SI EL TIEMPO SE REPARA,\nO SE ESCRIBE DE NUEVO."],
	["LA RESISTENCIA SE LEVANTA.\nSOLO UNO DETENDRÁ AL NEXO."],
	[],
]

## Tarjetas de capítulo: [segundo, texto].
const CARDS: Array = [
	[0.4, "I · PROYECTO ORIGEN"],
	[18.0, "II · EL DESPERTAR DEL NEXO"],
	[33.4, "III · LA INVASIÓN"],
	[66.6, "IV · EL ULTIMÁTUM DEL NEXO"],
	[76.4, "V · LA RESISTENCIA"],
	[90.3, "VI · LOS CAMPEONES"],
]

## Los cuatro genios que el Nexo captura, cada uno en su época dentro de un portal:
## [id, nombre, lugar y año, x del portal, y del portal, segundo en que se abre, color, lo que aportó].
const SCIENTISTS: Array = [
	[&"nikola_tesla", "TESLA", "TESLA · 1899", 12.0, 26.0, 25.6, Color("35e6ff"), "CORRIENTE"],
	[&"albert_einstein", "EINSTEIN", "EINSTEIN · 1905", 334.0, 26.0, 25.9, Color("ffd24a"), "RELATIVIDAD"],
	[&"marie_curie", "CURIE", "CURIE · 1898", 12.0, 120.0, 26.2, Color("60ff70"), "RADIACTIVIDAD"],
	[&"leonardo_da_vinci", "DA VINCI", "DA VINCI · 1495", 334.0, 120.0, 26.5, Color("f0a040"), "DISEÑO"],
]
const PORTAL_W := 80.0
const PORTAL_H := 76.0
## Ángulo del engarce de cada genio en el aro del Reloj (mismo orden que SCIENTISTS).
const SOCKET_ANG: Array[float] = [-2.356, -0.785, 2.356, 0.785]
## Cuando el Nexo empieza a arrastrarlos y cuando empieza a forjar el Reloj.
const T_PULL := 28.6
const T_FORGE := 30.4

## Científicos anónimos de la sala de control: [x, pelo, de pie, segundo en que se alarman, segundo en que entran en pánico].
const SCI_ROOM: Array = [
	[56.0, Color("3a2a1c"), false, 9.0, 12.4],
	[138.0, Color("c8c8d0"), false, 10.2, 13.0],
	[213.0, Color("1c1c1c"), true, 9.4, 12.2],
	[288.0, Color("b0501c"), false, 9.6, 12.8],
	[370.0, Color("e0c070"), false, 11.0, 13.4],
]

## Cinco frentes de la invasión: [segundo, quién lidera, rótulo, cielo arriba, cielo abajo, intensidad de los incendios].
const WORLDS: Array = [
	[33.0, &"julio_cesar", "LAS LEGIONES TOMAN LAS AVENIDAS", Color("2a1420"), Color("8a3a20"), 1.0],
	[38.5, &"gengis_kan", "LA HORDA CRUZA LA CIUDAD", Color("3a2a18"), Color("b08a4a"), 0.6],
	[44.0, &"cleopatra", "EGIPTO ALZA SUS PIRÁMIDES", Color("1a1038"), Color("c07a30"), 0.4],
	[49.5, &"napoleon", "LA ARTILLERÍA DERRIBA EL HORIZONTE", Color("141018"), Color("604a40"), 1.2],
	[55.0, &"alejandro_magno", "NINGUNA CIUDAD RESISTE", Color("3a0f14"), Color("e0602a"), 1.0],
]
## Los villanos que se ven en la invasión (no forman parte de los campeones).
const VILLAINS: Array[StringName] = [&"julio_cesar", &"gengis_kan", &"cleopatra", &"napoleon", &"alejandro_magno"]

## Los héroes que caen de la grieta a la Tierra conquistada: [quién, x].
const RUINS: Array = [
	[&"lautaro", 78.0], [&"janequeo", 146.0], [&"juana_de_arco", 213.0],
	[&"boudica", 280.0], [&"arturo_prat", 348.0],
]

## Presentación de los campeones de la resistencia: [id, rasgo, color, aura (0 rayos, 1 llamas, 2 órbita, 3 destellos)].
const CAST: Array = [
	[&"lautaro", "LANZA Y VIENTO", Color("35e6ff"), 2],
	[&"janequeo", "PICA DE PLATA", Color("c8e0ff"), 3],
	[&"pachacutec", "MAZA DE PIEDRA Y ORO", Color("ffd24a"), 2],
	[&"boudica", "ESCUDO CELTA", Color("4aa0ff"), 2],
	[&"juana_de_arco", "FUEGO BLANCO", Color("fff4d8"), 1],
	[&"arturo_prat", "SABLE DE ABORDAJE", Color("35e6ff"), 3],
	[&"abraham_lincoln", "VOZ DE LA UNIÓN", Color("6aa8ff"), 3],
	[&"socrates", "MÉTODO SOCRÁTICO", Color("ffd24a"), 3],
	[&"sun_tzu", "EL ARTE DE LA GUERRA", Color("ff7a3a"), 2],
	[&"isaac_newton", "GRAVEDAD ABSOLUTA", Color("9a4dff"), 2],
	[&"galileo_galilei", "TELESCOPIO", Color("35e6ff"), 3],
	[&"liudmila_pavlichenko", "MIRA TELESCÓPICA", Color("c8e0ff"), 3],
	[&"mariya_oktyabrskaya", "TANQUE T-34", Color("ff7a3a"), 1],
	[&"salvador_allende", "VÍA CHILENA", Color("ff7050"), 3],
	[&"nikola_tesla", "ELECTRICIDAD VOLTAICA", Color("35e6ff"), 0],
]

var _t: float = 0.0
var _fighters: Dictionary = {}
var _world: Node2D
var _fx: Control
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _voice_started: Array[bool] = []
var _subs: Array = []          # [desde, hasta, texto]
var _shake: Vector2 = Vector2.ZERO
var _done: bool = false
var _clash_frozen: bool = false
var _sfx_done: Dictionary = {}
## El reloj de la intro espera a que la música suene de verdad (en la web el audio tarda en desbloquearse,
## y si el reloj arrancaba antes, al empezar la música el tiempo saltaba y la intro parpadeaba o se reiniciaba).
var _started: bool = false
var _audio_clock: bool = false
var _start_wait: float = 0.0
const START_TIMEOUT := 2.0

func _ready() -> void:
	theme = HKTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_world = Node2D.new()
	add_child(_world)
	var ids: Array = []
	for e in CAST:
		ids.append(e[0])
	ids.append_array(VILLAINS)
	for s in SCIENTISTS:
		if not ids.has(s[0]):
			ids.append(s[0])
	for id in ids:
		var r := FighterRenderer.new()
		_world.add_child(r)
		r.setup(FighterRegistry.get_by_id(id))
		r.visible = false
		_fighters[id] = r
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
	if HKTheme.is_enter(event):
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
	if not _started:
		_start_wait += delta
		if _music.playing and _music.get_playback_position() > 0.0:
			_started = true
			_audio_clock = true
		elif _start_wait >= START_TIMEOUT:
			# Sin audio (navegador sin permiso): la intro corre con el reloj normal y la música no se une tarde.
			_started = true
			_music.stop()
		else:
			_fx.queue_redraw()
			return
	_t += delta
	if _audio_clock and _music.playing and delta < 0.1:
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
	_sfx_once("year", 2.0, &"whoosh")
	_sfx_once("eye", T_BLAST + 4.0, &"whoosh")
	_sfx_once("grab", T_PULL, &"hit_heavy")
	_update_shake()
	_place_fighters()
	if _t > T_END + 8.0:
		_finish()
	queue_redraw()
	_fx.queue_redraw()

# =========================================================================
#  Utilidades
# =========================================================================
func _sfx_once(key: String, at: float, sfx: StringName) -> void:
	if _t >= at and _t < at + 1.0 and not _sfx_done.has(key):
		_sfx_done[key] = true
		Sfx.play(sfx)

## Punto del anillo del acelerador (vista aérea achatada).
func _ring_pt(a: float, c: Vector2, rx: float, ry: float) -> Vector2:
	return c + Vector2(cos(a) * rx, sin(a) * ry)

func _ellipse_pts(c: Vector2, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

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

func _put(id: StringName, x: float, y: float, h: float, face: int, pose: StringName, alpha: float = 1.0, rot: float = 0.0, tint: Color = Color.WHITE) -> void:
	if alpha <= 0.01:
		return
	var r: FighterRenderer = _fighters[id]
	var s := h / maxf(r.approx_height(), 1.0)
	r.visible = true
	r.scale = Vector2(s * face, s)
	r.position = Vector2(x, y)
	r.rotation = rot
	r.pose_name = pose
	r.modulate = Color(tint.r, tint.g, tint.b, alpha)
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
	if _t < 25.6 or _t >= T_COLLIDE:
		return
	for i in SCIENTISTS.size():
		var s: Array = SCIENTISTS[i]
		var a := _ph(float(s[5]), float(s[5]) + 0.5)
		var v := _sci_xy(i)
		var p := _pull(i)
		var face := 1 if v.x < W * 0.5 else -1
		# Libres en su época; poseídos por el Nexo cuando los arrastra.
		var tint := Color.WHITE.lerp(Color(0.75, 0.6, 1.0), p)
		_put(s[0], v.x, v.y, v.z, face, &"hit" if p > 0.05 else &"idle", a, sin(_t * 5.0 + i) * 0.12 * p, tint)

func _place_world() -> void:
	var idx := _world_index()
	if idx < 0:
		return
	var lt := _t - float(WORLDS[idx][0])
	var a := clampf(lt / 0.35, 0.0, 1.0)
	match idx:
		0: _put(&"julio_cesar", 120.0, 204.0, 112.0, 1, &"victory", a)
		1: _put(&"gengis_kan", lerpf(40.0, 380.0, lt / 5.5), 204.0, 108.0, 1, &"run", a)
		2: _put(&"cleopatra", 300.0, 204.0, 108.0, -1, &"idle", a)
		3: _put(&"napoleon", 300.0, 204.0, 108.0, -1, &"idle", a)
		4: _put(&"alejandro_magno", 213.0, 204.0, 116.0, 1, &"victory", a)

## Los héroes aterrizan en la Tierra conquistada (columnas de luz) y se reúnen en el bastión.
func _place_ruins() -> void:
	for i in RUINS.size():
		var lt := _t - (T_RUINS + 0.2 + i * 0.9)
		var a := clampf(lt / 0.25, 0.0, 1.0)
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
		_bg_invasion()
	elif _t < T_SELECT:
		_bg_conquered()
		_bg_bastion(_ease((_t - T_ARENA) / 6.0) if _t >= T_ARENA else 0.0, 0.3)
		if _t >= T_JUDGE:
			_nexo_sphere(self)
	elif _t < T_LOGO - 0.3:
		_bg_bastion(1.0, 0.35 if _t < T_CIRCLE else 1.0)
		if _t < T_CIRCLE:
			_select_backdrop()
		elif _t < T_BUILD:
			_circle_floor()
		else:
			_duel_backdrop()
	else:
		_bg_logo()

# --- I y II: la sala de control del CERN -----------------------------------
func _forge_c() -> Vector2:
	return Vector2(W * 0.5, 106.0)

## Dónde engarza el genio `i` en el aro del Reloj.
func _socket_pos(i: int) -> Vector2:
	return _forge_c() + Vector2.from_angle(SOCKET_ANG[i]) * 58.0

func _pull(i: int) -> float:
	return _ease((_t - T_PULL - i * 0.25) / 2.0)

## Posición (x, pies, alto) del genio `i`: primero en su portal y luego arrastrado hasta su engarce.
func _sci_xy(i: int) -> Vector3:
	var s: Array = SCIENTISTS[i]
	var bx: float = float(s[3]) + PORTAL_W * 0.5
	var by: float = float(s[4]) + PORTAL_H - 6.0
	var p := _pull(i)
	var sk := _socket_pos(i)
	return Vector3(lerpf(bx, sk.x, p), lerpf(by, sk.y + 18.0, p), lerpf(56.0, 38.0, p))

func _phase_color(phase: int) -> Color:
	match phase:
		0: return Color("40ff90")
		1: return Color("ffb030")
	return Color("ff3a3a")

func _bg_lab() -> void:
	var t := _t
	var dt := t - T_BLAST
	draw_rect(Rect2(0, 0, W, H), VOID)
	if t < T_BLAST + 0.05:
		_control_room(t)
	else:
		_nexo_swirl(dt)
		_debris(dt)
		_crack(dt)
		_ai_awaken(dt)
		_portals()
		_clock_forge()

## La sala de control: pantalla gigante con el anillo y el núcleo de la IA, monitores, y un equipo de científicos
## de espaldas (a contraluz) que pasa de la rutina a la alarma y al pánico (fase 0 nominal, 1 anomalía, 2 colisión sin orden).
func _control_room(t: float) -> void:
	var phase := 0
	if t >= 12.4:
		phase = 2
	elif t >= 9.0:
		phase = 1
	var pc := _phase_color(phase)
	var beacon := 0.5 + 0.5 * sin(t * 8.0)
	for i in 6:
		draw_rect(Rect2(0, i * 25, W, 25), Color(0.04 + 0.012 * i, 0.07 + 0.015 * i, 0.13 + 0.02 * i))
	for x in range(0, int(W) + 54, 54):
		draw_line(Vector2(x, 0), Vector2(x, 150), Color(1, 1, 1, 0.04), 1.0)
	for k in 6:
		var lit := 0.8
		if phase == 2:
			lit = 0.55 + 0.35 * _h(floorf(t * 6.0) + k)
		draw_rect(Rect2(24 + k * 68, 3, 36, 4), Color(0.85, 0.92, 1.0, lit))
		draw_rect(Rect2(20 + k * 68, 7, 44, 8), Color(0.85, 0.92, 1.0, 0.05 * lit))
	# Pantalla principal.
	var sr := Rect2(103, 18, 220, 104)
	draw_rect(sr.grow(7.0), Color(pc, 0.07 + 0.04 * beacon * float(phase)))
	draw_rect(sr, Color(0.02, 0.05, 0.09))
	_screen_ring(sr, phase, t, pc)
	draw_rect(sr, Color(pc, 0.9), false, 2.0)
	draw_rect(sr.grow(3.0), Color(0.4, 0.45, 0.55, 0.7), false, 1.0)
	# Monitores laterales con gráficas que se disparan.
	for side in [0, 1]:
		for row in 2:
			var mr := Rect2(16.0 + side * 322.0, 28.0 + row * 44.0, 72.0, 34.0)
			draw_rect(mr, Color(0.02, 0.05, 0.09))
			draw_rect(mr, Color(pc, 0.55), false, 1.0)
			var pts := PackedVector2Array()
			for k in 14:
				var amp := (4.0 + 11.0 * float(phase)) * _h(floorf(t * 6.0) * 0.37 + k + row * 9.0 + side * 17.0)
				pts.append(Vector2(mr.position.x + 3.0 + k * 5.0, mr.end.y - 4.0 - amp * (0.6 + 0.4 * sin(t * 3.0 + k))))
			draw_polyline(pts, Color(pc, 0.9), 1.0)
	for px in [6.0, W - 10.0]:
		draw_rect(Rect2(px, 0, 4, 150), Color(0.09, 0.13, 0.2))
		draw_rect(Rect2(px, 0, 1, 150), Color(pc, 0.25))
	# Polvo en suspensión en el haz de la pantalla.
	for k in 18:
		var dp := Vector2(fposmod(_h(k) * W + t * (4.0 + _h(k + 2.0) * 6.0), W), fposmod(_h(k + 5.0) * 140.0 - t * 6.0, 140.0) + 10.0)
		draw_rect(Rect2(dp, Vector2(1, 1)), Color(1, 1, 1, 0.25))
	# Suelo y perspectiva.
	draw_rect(Rect2(0, 150, W, 90), Color(0.03, 0.04, 0.07))
	draw_rect(Rect2(0, 150, W, 1), Color(pc, 0.35))
	for i in range(-6, 7):
		draw_line(Vector2(W * 0.5, 150), Vector2(W * 0.5 + i * 70.0, 240), Color(1, 1, 1, 0.04), 1.0)
	# Los científicos, de espaldas y a contraluz de la pantalla.
	for i in SCI_ROOM.size():
		var e: Array = SCI_ROOM[i]
		var state := 0
		if t >= float(e[4]):
			state = 2
		elif t >= float(e[3]):
			state = 1
		var x := float(e[0])
		_bk_sci(x, 196.0, e[1], state, float(i) * 2.3, bool(e[2]), pc)
		if not bool(e[2]):
			draw_rect(Rect2(x - 28, 166, 56, 12), Color(pc, 0.10))
			draw_rect(Rect2(x - 32, 178, 64, 8), Color("1a2236"))
			draw_rect(Rect2(x - 32, 178, 64, 1), Color(pc, 0.6))
			draw_rect(Rect2(x - 32, 186, 64, 22), Color("0d1220"))
	if phase == 2:
		var q := floorf(t * 12.0)
		for k in 8:
			if _h(q + k * 3.1) > 0.6:
				var dx := float(SCI_ROOM[k % 5][0]) + (_h(k + q) - 0.5) * 40.0
				for j in 4:
					draw_rect(Rect2(dx + (_h(j + k) - 0.5) * 14.0, 172.0 - _h(j + 3.0 + q) * 18.0, 2, 2), Color(1.0, 0.7, 0.2, 0.9))
	# La gravedad falla: papeles y objetos se elevan de las mesas.
	if t >= 9.0:
		for k in 12:
			var lift := clampf((t - 9.0 - _h(k) * 2.0) * (6.0 + _h(k + 2.0) * 12.0), 0.0, 130.0)
			if lift <= 0.0:
				continue
			var ox := float(SCI_ROOM[k % 5][0]) + (_h(k + 7.0) - 0.5) * 44.0 + sin(t * 1.5 + k) * 5.0
			_quad(self, Vector2(ox, 176.0 - lift), 7.0 + _h(k + 4.0) * 3.0, 4.0, t * (1.0 + _h(k)) + k, Color(0.9, 0.92, 1.0, 0.75))
	# Alarma: baliza roja y luz que parpadea en toda la sala.
	if phase >= 1:
		draw_rect(Rect2(0, 0, W, 240), Color(1.0, 0.1, 0.1, 0.05 * float(phase) * beacon))
		for bx in [30.0, 396.0]:
			draw_circle(Vector2(bx, 16), 5.0, Color(1.0, 0.2, 0.2, 0.5 + 0.5 * beacon))
			draw_circle(Vector2(bx, 16), 14.0, Color(1.0, 0.2, 0.2, 0.12 * beacon))

func _screen_ring(sr: Rect2, phase: int, t: float, pc: Color) -> void:
	var c := sr.get_center() + Vector2(0.0, 2.0)
	var ring := PackedVector2Array()
	for i in 49:
		ring.append(_ring_pt(TAU * i / 48.0, c, 78.0, 24.0))
	draw_polyline(ring, Color(pc, 0.6), 2.0)
	var spd := 1.2 + 1.8 * float(phase)
	for d in [1.0, -1.0]:
		var ang: float = PI * 0.5 + d * t * spd
		for k in 6:
			draw_circle(_ring_pt(ang - d * k * 0.09, c, 78.0, 24.0), 2.4 - k * 0.3, Color(CYAN if d > 0.0 else NEXO_GOLD, 0.9 - k * 0.13))
	# Núcleo de la IA: se agita cuanto más grave es la fase.
	var jag := 3.0 * float(phase)
	for i in 8:
		var a1 := TAU * i / 8.0 + t * 0.5
		var p1 := c + Vector2(cos(a1) * 14.0, sin(a1) * 9.0) + Vector2((_h(floorf(t * 10.0) + i) - 0.5) * jag, 0.0)
		var p2 := c + Vector2(cos(a1 + 2.0) * 14.0, sin(a1 + 2.0) * 9.0)
		draw_line(p1, p2, Color(VIOLET, 0.6), 1.0)
		draw_circle(p1, 1.6, Color(pc, 0.9))
	draw_circle(c, 3.0 + float(phase) * (0.5 + 0.5 * sin(t * 9.0)) * 2.0, Color(1, 1, 1, 0.9))
	var title: String = ["GRAVEDAD = DINERO Y PODER", "ANOMALÍA GRAVITATORIA", "COLISIÓN SIN AUTORIZACIÓN"][phase]
	if phase == 0 or fposmod(t, 0.8) < 0.55:
		_txt(self, sr.position.y + 12.0, title, 8, pc, sr.position.x, sr.size.x, 1)
	var l1: String = ["PRESIÓN POLÍTICA · RIESGO ACEPTADO","NÚCLEO IA: ACTIVIDAD 340 %", "ORDEN DE ORIGEN DESCONOCIDO"][phase]
	_txt(self, sr.end.y - 16.0, l1, 8, Color(HKTheme.PAPER, 0.8), sr.position.x, sr.size.x, 1)
	if phase == 2 and fposmod(t, 0.6) < 0.4:
		_txt(self, sr.end.y - 6.0, "ACCESO DENEGADO", 8, pc, sr.position.x, sr.size.x, 1)

## Un científico visto de espaldas (a contraluz): teclea, se alarma y señala, o levanta las manos.
func _bk_sci(x: float, base: float, hair: Color, state: int, sd: float, standing: bool, rim: Color) -> void:
	var coat := Color("1b2233")
	var skin := Color("a8745a")
	var sc := 1.2 if standing else 1.45
	draw_set_transform(Vector2(x, base) * (1.0 - sc) + _shake, 0.0, Vector2(sc, sc))
	var top := base - (58.0 if standing else 44.0)
	var bob := 0.0
	if state == 0:
		bob = sin(_t * 14.0 + sd) * 1.2
	if standing:
		draw_line(Vector2(x - 4, base - 18), Vector2(x - 4, base), Color("10131c"), 4.0)
		draw_line(Vector2(x + 4, base - 18), Vector2(x + 4, base), Color("10131c"), 4.0)
	else:
		draw_rect(Rect2(x - 11, top + 12, 22, 26), Color("12141e"))
	draw_colored_polygon(PackedVector2Array([Vector2(x - 14, top + 6), Vector2(x - 7, top), Vector2(x + 7, top), Vector2(x + 14, top + 6),
		Vector2(x + 10, top + 32), Vector2(x - 10, top + 32)]), coat)
	draw_line(Vector2(x - 14, top + 6), Vector2(x - 7, top), Color(rim, 0.8), 1.0)
	draw_line(Vector2(x + 7, top), Vector2(x + 14, top + 6), Color(rim, 0.8), 1.0)
	var turn := 0.0
	if state >= 1:
		turn = sin(_t * 3.0 + sd) * 2.5
	var hy := top - 6.0
	draw_rect(Rect2(x - 2.0 + turn * 0.5, hy + 4.0, 4, 4), skin)
	draw_circle(Vector2(x + turn, hy), 6.5, hair)
	match state:
		0:
			draw_line(Vector2(x - 12, top + 8), Vector2(x - 15, top + 26 + bob), coat, 3.0)
			draw_line(Vector2(x + 12, top + 8), Vector2(x + 15, top + 26 - bob), coat, 3.0)
		1:
			draw_line(Vector2(x - 12, top + 8), Vector2(x - 15, top + 26), coat, 3.0)
			draw_line(Vector2(x + 12, top + 8), Vector2(x + 20, top - 8), coat, 3.0)
			draw_circle(Vector2(x + 20, top - 8), 2.2, skin)
		_:
			for sgn in [-1.0, 1.0]:
				var tip := Vector2(x + sgn * 18.0, top - 16.0 + sin(_t * 10.0 + sd) * 1.5)
				draw_line(Vector2(x + sgn * 12.0, top + 7), tip, coat, 3.0)
				draw_circle(tip, 2.2, skin)
	draw_set_transform(_shake, 0.0, Vector2.ONE)

# --- Portales a la época de cada genio y el Reloj que el Nexo les obliga a forjar --------------
func _portals() -> void:
	for i in SCIENTISTS.size():
		var s: Array = SCIENTISTS[i]
		var a := _ph(float(s[5]), float(s[5]) + 0.5) * (1.0 - _ph(T_FORGE, T_FORGE + 1.2))
		if a <= 0.0:
			continue
		var r := Rect2(float(s[3]), float(s[4]), PORTAL_W, PORTAL_H)
		var col: Color = s[6]
		draw_rect(r.grow(6.0), Color(col, 0.12 * a))
		_portal_art(i, r, a)
		draw_rect(r, Color(col, 0.9 * a), false, 2.0)
		draw_rect(r.grow(3.0), Color(col, 0.35 * a), false, 1.0)
		# Barrido de interferencia: el portal se está abriendo desde otra época.
		var sy := r.position.y + fposmod(_t * 60.0 + i * 20.0, r.size.y)
		draw_rect(Rect2(r.position.x, sy, r.size.x, 2), Color(col, 0.25 * a))
		HKTheme.draw_text(self, Vector2(r.position.x - 8.0, r.end.y + 10.0), s[2], 8, Color(col, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 16.0, 1)

func _portal_art(i: int, r: Rect2, a: float) -> void:
	match i:
		0:   # Tesla: la bobina de Colorado Springs
			draw_rect(r, Color(0.03, 0.06, 0.14, a))
			var cp := Vector2(r.position.x + 16.0, r.position.y + 24.0)
			draw_rect(Rect2(cp.x - 3.0, cp.y + 4.0, 6.0, r.size.y - 28.0), Color(BRASS_D, a))
			draw_circle(cp, 7.0, Color(BRASS, a))
			draw_circle(cp, 11.0, Color(CYAN, 0.2 * a))
			if a > 0.9:
				var q := floorf(_t * 14.0)
				for k in 2:
					_bolt(self, cp, Vector2(r.end.x - 6.0, r.position.y + 14.0 + _h(q + k) * 40.0), q + k * 7.0, CYAN, 1.0, 4.0)
		1:   # Einstein: la pizarra
			draw_rect(r, Color(0.04, 0.12, 0.09, a))
			_txt(self, r.position.y + 14.0, "E=MC2", 8, Color(0.9, 1.0, 0.9, 0.85 * a), r.position.x, r.size.x, 0)
			for k in 4:
				var ly := r.position.y + 22.0 + k * 6.0
				draw_line(Vector2(r.position.x + 6.0, ly), Vector2(r.position.x + 18.0 + _h(k + 3.0) * 44.0, ly), Color(0.9, 1.0, 0.9, 0.35 * a), 1.0)
		2:   # Curie: el matraz que brilla
			draw_rect(r, Color(0.02, 0.07, 0.04, a))
			var fc := Vector2(r.end.x - 20.0, r.end.y - 22.0)
			draw_circle(fc, 20.0, Color(0.3, 1.0, 0.4, 0.12 * a))
			draw_colored_polygon(PackedVector2Array([fc + Vector2(-3, -14), fc + Vector2(3, -14), fc + Vector2(10, 8), fc + Vector2(-10, 8)]), Color(0.3, 1.0, 0.4, 0.55 * a))
			for k in 4:
				draw_circle(fc + Vector2(sin(_t * 2.0 + k) * 4.0, -fposmod(_t * 14.0 + k * 9.0, 34.0)), 1.5, Color(0.6, 1.0, 0.7, 0.7 * a))
		_:   # Da Vinci: el cuaderno de dibujos
			draw_rect(r, Color(0.64, 0.52, 0.3, a))
			var dc := Vector2(r.position.x + 22.0, r.position.y + 28.0)
			var ink := Color(0.3, 0.2, 0.08, a)
			draw_arc(dc, 15.0, 0.0, TAU, 28, ink, 1.0)
			draw_rect(Rect2(dc.x - 11.0, dc.y - 11.0, 22.0, 22.0), ink, false, 1.0)
			draw_line(dc + Vector2(-15.0, 0.0), dc + Vector2(15.0, 0.0), ink, 1.0)
			_gear(self, Vector2(r.end.x - 18.0, r.position.y + 50.0), 9.0, 8, _t * 0.8, Color(0.35, 0.24, 0.1, a), Color(0.64, 0.52, 0.3, a))

## El Reloj del Origen toma forma alrededor del ojo del Nexo: aro, dientes y un engarce por genio.
func _clock_forge() -> void:
	var k := _ease((_t - T_FORGE) / 1.6)
	if k <= 0.0:
		return
	var c := _forge_c()
	var R := 58.0 * k
	for g in 24:
		var ang := _t * 0.5 + TAU * g / 24.0
		_quad(self, c + Vector2.from_angle(ang) * (R + 9.0), 7.0, 6.0, ang, Color(BRASS, 0.9 * k))
	draw_arc(c, R + 4.0, 0.0, TAU, 64, Color(BRASS, k), 5.0)
	draw_arc(c, R - 6.0, 0.0, TAU, 64, Color(BRASS_D.lightened(0.25), k), 2.0)
	for g in 12:
		var ang := TAU * g / 12.0 - _t * 0.15
		draw_line(c + Vector2.from_angle(ang) * (R - 4.0), c + Vector2.from_angle(ang) * (R - 10.0), Color(NEXO_GOLD, 0.8 * k), 1.0)
	for i in SCIENTISTS.size():
		var sock := _socket_pos(i)
		var col: Color = SCIENTISTS[i][6]
		draw_circle(sock, 7.0, Color(0.07, 0.04, 0.11, k))
		draw_arc(sock, 7.0, 0.0, TAU, 20, Color(BRASS, k), 1.5)
		if _pull(i) >= 0.98:
			var pulse := 0.6 + 0.4 * sin(_t * 6.0 + i)
			draw_circle(sock, 5.0, Color(col, 0.9))
			draw_circle(sock, 10.0 + 3.0 * pulse, Color(col, 0.2))
			var a0: float = SOCKET_ANG[i] - PI * 0.25
			draw_arc(c, R + 9.0, a0, a0 + PI * 0.5, 14, Color(col, 0.55 + 0.25 * pulse), 2.0)

# --- Después de la explosión ----------------------------------------------
func _crack(dt: float) -> void:
	var grow := _ease(dt / 1.4)
	var main := _crack_points(H * 0.5 - H * 0.5 * grow, H * 0.5 + H * 0.5 * grow, 4.0, 46.0)
	var wob := 0.7 + 0.3 * sin(dt * 9.0)
	_crack_line(main, wob, 1.0)
	# Ramas que se abren desde la grieta principal y se subdividen en otras más finas.
	for b in 12:
		var base_i := 1 + int(_h(b * 3.3) * 12.0)
		var side := 1.0 if b % 2 == 0 else -1.0
		var ang := (_h(b + 40.0) - 0.5) * 1.0 + (0.0 if side > 0.0 else PI)
		var bp := _ease((dt - 0.2 - b * 0.06) / 0.9)
		if bp <= 0.0:
			continue
		var br := _crack_branch(main[base_i], ang, (46.0 + _h(b + 9.0) * 110.0) * bp, b * 7.0)
		_crack_line(br, wob, 0.55)
		if br.size() > 4:
			for k in 2:
				var sub_i := 2 + k * 2
				var sb := _crack_branch(br[sub_i], ang + (0.9 if k == 0 else -0.9), (18.0 + _h(b + k * 5.0) * 40.0) * bp, b * 13.0 + k)
				_crack_line(sb, wob, 0.3)
	# Fragmentos de tiempo que se desprenden de los bordes y flotan.
	var fade := 1.0 - _ph(T_COLLIDE - 2.0, T_COLLIDE)
	for i in 10:
		var o := main[1 + i % 13]
		var drift := Vector2((_h(i + 1.0) - 0.5) * 34.0, -10.0 - _h(i + 2.0) * 26.0) * dt * 0.5
		var c := o + drift
		var sz := 3.0 + _h(i + 3.0) * 6.0
		var r := dt * (0.5 + _h(i)) + i
		var tri := PackedVector2Array([c + Vector2.from_angle(r) * sz, c + Vector2.from_angle(r + 2.3) * sz * 0.8, c + Vector2.from_angle(r + 4.2) * sz * 0.6])
		draw_colored_polygon(tri, Color([NEXO_GOLD, VIOLET, CYAN][i % 3], 0.75 * fade * grow))
	# Destellos de luz que se cuelan por la grieta.
	for i in main.size():
		if _h(floorf(dt * 12.0) + i * 1.7) > 0.72:
			draw_rect(Rect2(main[i] + Vector2((_h(i + dt) - 0.5) * 10.0, (_h(i - dt) - 0.5) * 10.0), Vector2(2, 2)), Color("fff4c0"))

## Una línea de la grieta con halo violeta, núcleo dorado y centro negro (k = grosor relativo).
func _crack_line(pts: PackedVector2Array, wob: float, k: float) -> void:
	if pts.size() < 2:
		return
	draw_polyline(pts, Color(VIOLET, 0.25 * wob), 22.0 * k)
	draw_polyline(pts, Color(VIOLET, 0.6), 10.0 * k)
	draw_polyline(pts, NEXO_GOLD, maxf(5.0 * k, 1.5))
	draw_polyline(pts, Color("02000a"), maxf(2.5 * k, 0.8))

## Rama quebrada que sale de `origin` hacia `ang` y mide `length`.
func _crack_branch(origin: Vector2, ang: float, length: float, seed_v: float) -> PackedVector2Array:
	var pts := PackedVector2Array([origin])
	var step := length / 7.0
	var a := ang
	var cur := origin
	for i in 7:
		a += (_h(seed_v + i * 2.3) - 0.5) * 1.1
		cur += Vector2.from_angle(a) * step
		pts.append(cur)
	return pts

## La IA despierta tras la colisión: una red neuronal se enciende alrededor de la grieta y abre un ojo.
func _ai_awaken(dt: float) -> void:
	var fade := 1.0 - _ph(30.0, 32.5)
	if dt < 1.0 or fade <= 0.0:
		return
	var c := Vector2(W * 0.5, 106.0)
	var n := 30
	var pts: Array[Vector2] = []
	var lit: Array[float] = []
	for i in n:
		var a := _h(i + 20.0) * TAU + dt * 0.12
		var r := (28.0 + _h(i + 33.0) * 150.0) * _ease(dt / 5.0)
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.62))
		lit.append(clampf(dt - 1.0 - _h(i + 50.0) * 6.0, 0.0, 1.0))
	for i in n:
		for j in [1, 4]:
			var k: int = (i + j) % n
			var l := minf(lit[i], lit[k]) * fade
			if l <= 0.0:
				continue
			draw_line(pts[i], pts[k], Color(CYAN, 0.28 * l), 1.0)
			var u := fposmod(dt * 0.7 + _h(i * 3.0 + j), 1.0)
			draw_circle(pts[i].lerp(pts[k], u), 1.3, Color(NEXO_GOLD, 0.9 * l))
	for i in n:
		draw_circle(pts[i], 2.2, Color(VIOLET.lightened(0.4), 0.9 * lit[i] * fade))
	# El ojo del Nexo se abre en el centro de la grieta y parpadea una vez.
	var open := _ease((dt - 4.0) / 2.5)
	if open <= 0.0:
		return
	for i in 4:
		draw_circle(c, (56.0 + i * 18.0) * open, Color(VIOLET, 0.05 * fade))
	var blink := 1.0 - 0.92 * maxf(0.0, 1.0 - absf(dt - 8.0) * 6.0)
	var ry := 26.0 * open * blink
	if ry < 2.0:
		draw_line(c + Vector2(-44, 0), c + Vector2(44, 0), Color(NEXO_GOLD, fade), 2.0)
		return
	draw_colored_polygon(_ellipse_pts(c, 44.0, ry), Color(0.02, 0.0, 0.06, 0.92 * fade))
	draw_colored_polygon(_ellipse_pts(c, 22.0, minf(ry, 22.0)), Color(NEXO_GOLD, fade))
	draw_colored_polygon(_ellipse_pts(c, 14.0, minf(ry, 14.0)), Color(CYAN, 0.8 * fade))
	draw_colored_polygon(_ellipse_pts(c, 4.5, minf(ry * 0.9, 20.0)), Color(0.0, 0.0, 0.03, fade))
	var rim := _ellipse_pts(c, 44.0, ry)
	rim.append(rim[0])
	draw_polyline(rim, Color(VIOLET.lightened(0.3), fade), 2.0)

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

# --- La Tierra invadida: ciudad en ruinas, ejércitos, bastión de la resistencia y la Torre del Reloj ----------
## Ciudad moderna destruida en tres capas con paralaje. `scroll` desplaza las capas, `fire` es la intensidad de los
## incendios y `rift` la de la grieta violeta del cielo. `a` es la opacidad (para fundirla encima de otra).
func _city(sky_top: Color, sky_bot: Color, scroll: float, fire: float, rift: float, a: float = 1.0) -> void:
	for i in 8:
		draw_rect(Rect2(0, i * 24, W, 24), Color(sky_top.lerp(sky_bot, i / 7.0), a))
	if rift > 0.0:
		var rp := _crack_points(0.0, 120.0, 31.0, 90.0)
		draw_polyline(rp, Color(VIOLET, 0.35 * rift * a), 9.0)
		draw_polyline(rp, Color(NEXO_GOLD, 0.8 * rift * a), 2.0)
		draw_polyline(rp, Color("02000a"), 1.0)
	for layer in 3:
		var speed: float = [0.25, 0.55, 1.0][layer]
		var base_y: float = [150.0, 172.0, 196.0][layer]
		var col: Color = [Color(0.12, 0.08, 0.14), Color(0.08, 0.05, 0.1), Color(0.045, 0.03, 0.06)][layer]
		col = col.lerp(sky_bot.darkened(0.35), [0.6, 0.3, 0.0][layer])
		var n := 12 - layer * 2
		var bw := W / float(n - 2)
		for k in n + 2:
			var wx := fposmod(k * bw - scroll * speed * 40.0, bw * (n + 2)) - bw
			var sv := float(k) + layer * 37.0
			var bwid := bw * (0.75 + _h(sv) * 0.5)
			var topy := base_y - ((46.0 + layer * 14.0) + _h(sv + 3.0) * (70.0 - layer * 6.0))
			# Silueta con la azotea rota.
			var pts := PackedVector2Array([Vector2(wx, base_y), Vector2(wx, topy + _h(sv + 5.0) * 12.0)])
			var ragged := 1.0 if _h(sv + 9.0) > 0.4 else 0.2
			for s in 4:
				pts.append(Vector2(wx + bwid * (s + 1) / 4.0, topy + _h(sv + 7.0 + s) * 16.0 * ragged))
			pts.append(Vector2(wx + bwid, base_y))
			draw_colored_polygon(pts, Color(col, a))
			if layer >= 1:
				for wy in range(int(topy) + 10, int(base_y) - 6, 10):
					for wxx in range(int(wx) + 4, int(wx + bwid) - 4, 8):
						if _h(wxx * 0.13 + wy * 0.31 + sv) > 0.84:
							draw_rect(Rect2(wxx, wy, 3, 4), Color(1.0, 0.8, 0.4, 0.55 * a))
			if fire > 0.0 and _h(sv + 11.0) > 0.6:
				var fx := wx + bwid * 0.5
				var fl := 0.5 + 0.5 * sin(_t * 9.0 + sv)
				draw_rect(Rect2(fx - 7.0, topy - 4.0, 14.0, 6.0), Color(1.0, 0.4, 0.1, 0.18 * a))
				draw_rect(Rect2(fx - 2.0, topy - 6.0 * fl - 2.0, 4.0, 6.0 + 6.0 * fl), Color(1.0, 0.6, 0.15, 0.9 * a))
		# Columnas de humo entre una capa y otra.
		for i in 3:
			var sx := fposmod(_h(i + 3.0 + layer * 5.0) * W + scroll * 6.0, W)
			var sy := base_y - fposmod(_t * (8.0 + _h(i) * 8.0) + _h(i + 9.0) * 90.0, 90.0)
			draw_circle(Vector2(sx, sy), 14.0 + _h(i + 6.0) * 14.0, Color(0.05, 0.04, 0.05, 0.16 * minf(fire, 1.0) * a))
	# Calle destrozada: coches volcados, farolas torcidas y grietas que brillan.
	draw_rect(Rect2(0, 196, W, 44), Color(0.04, 0.025, 0.05, a))
	draw_rect(Rect2(0, 196, W, 1), Color(0.4, 0.15, 0.15, a))
	for k in 5:
		var gx := fposmod(k * 96.0 - scroll * 40.0, W + 60.0) - 30.0
		var gp := _crack_points(197.0, 240.0, k * 11.0, 50.0)
		for j in gp.size():
			gp[j].x = gx + (gp[j].x - W * 0.5)
		draw_polyline(gp, Color(NEXO_GOLD, (0.35 + 0.25 * sin(_t * 2.0 + k)) * a), 1.0)
	for k in 3:
		var cx := fposmod(k * 150.0 + 40.0 - scroll * 40.0, W + 80.0) - 40.0
		draw_rect(Rect2(cx, 190.0, 24.0, 8.0), Color(0.16, 0.05, 0.06, a))
		draw_rect(Rect2(cx + 4.0, 186.0, 14.0, 5.0), Color(0.1, 0.04, 0.05, a))
		draw_circle(Vector2(cx + 5.0, 198.0), 3.0, Color(0.02, 0.02, 0.03, a))
		draw_circle(Vector2(cx + 19.0, 198.0), 3.0, Color(0.02, 0.02, 0.03, a))

## Frente de la invasión (cada uno con su ejército), con ciudadanos que huyen.
func _bg_invasion() -> void:
	var idx := _world_index()
	if idx < 0:
		return
	var w: Array = WORLDS[idx]
	var lt := _t - float(w[0])
	_city(w[3], w[4], lt * 0.5, float(w[5]), 1.0)
	if idx == 0 or idx == 1:
		draw_set_transform(Vector2(213.0, 198.0) * -0.5 + _shake, 0.0, Vector2(1.5, 1.5))
	_inv_extra(idx, lt)
	draw_set_transform(_shake, 0.0, Vector2.ONE)
	_civilians(lt)

func _inv_extra(idx: int, lt: float) -> void:
	match idx:
		0:   # legionarios en formación
			for r in 3:
				for k in 14:
					var x := fposmod(k * 32.0 + r * 11.0 - lt * 26.0, W + 40.0) - 20.0
					var y := 190.0 + r * 5.0
					draw_rect(Rect2(x - 3.0, y - 6.0, 6.0, 8.0), Color("8a1a1a"))
					draw_rect(Rect2(x - 3.0, y - 6.0, 6.0, 1.0), Color(NEXO_GOLD, 0.9))
					draw_circle(Vector2(x, y - 9.0), 2.0, Color("c8a070"))
					draw_rect(Rect2(x - 2.0, y - 11.0, 4.0, 2.0), Color("b0b0c0"))
					draw_line(Vector2(x + 4.0, y - 4.0), Vector2(x + 4.0, y - 18.0), Color("7a5a3a"), 1.0)
		1:   # la horda a caballo
			for k in 12:
				var sp := 150.0 + _h(k + 1.0) * 90.0
				var x := fposmod(k * 38.0 + lt * sp, W + 60.0) - 30.0
				var y := 182.0 + (k % 3) * 7.0
				var gal := sin(lt * 14.0 + k) * 1.5
				draw_rect(Rect2(x - 7.0, y - 6.0 + gal, 14.0, 5.0), Color("3a2414"))
				draw_rect(Rect2(x + 5.0, y - 10.0 + gal, 4.0, 5.0), Color("3a2414"))
				draw_rect(Rect2(x - 7.0, y - 1.0 + gal, 2.0, 5.0), Color("2a180c"))
				draw_rect(Rect2(x + 4.0, y - 1.0 - gal, 2.0, 5.0), Color("2a180c"))
				draw_circle(Vector2(x, y - 13.0 + gal), 2.2, Color("c8a070"))
				draw_rect(Rect2(x - 2.0, y - 11.0 + gal, 4.0, 5.0), Color("2a3a6a"))
				draw_line(Vector2(x - 4.0, y - 18.0), Vector2(x + 8.0, y - 6.0), Color("c0c0d0"), 1.0)
				draw_line(Vector2(x - 8.0, y - 2.0), Vector2(x - 24.0, y - 2.0), Color(0.8, 0.7, 0.5, 0.25), 1.0)
		2:   # pirámides y un obelisco que se alzan entre los edificios, con interferencias
			var gl := 0.6 + 0.4 * _h(floorf(lt * 12.0))
			var up := _ease(lt / 2.0)
			for pyr in [[130.0, 40.0, 56.0], [250.0, 52.0, 70.0], [330.0, 34.0, 44.0]]:
				var px: float = pyr[0]
				var hw: float = pyr[1]
				var ph: float = float(pyr[2]) * up
				var tri := PackedVector2Array([Vector2(px - hw, 196.0), Vector2(px, 196.0 - ph), Vector2(px + hw, 196.0)])
				draw_colored_polygon(tri, Color(Color("c9a050"), 0.9))
				draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(CYAN, 0.6 * gl), 1.0)
			draw_rect(Rect2(60.0, 196.0 - 70.0 * up, 8.0, 70.0 * up), Color("d8b060"))
			for k in 14:
				var sx := fposmod(_h(k) * W - lt * 120.0, W + 40.0) - 20.0
				draw_line(Vector2(sx, 130.0 + _h(k + 2.0) * 60.0), Vector2(sx + 22.0, 130.0 + _h(k + 2.0) * 60.0), Color(0.9, 0.75, 0.5, 0.25), 1.0)
		3:   # cañones que disparan contra el horizonte
			for c in 2:
				var cx := 36.0 + c * 52.0
				var cy := 186.0 + c * 4.0
				draw_rect(Rect2(cx, cy, 22.0, 5.0), Color("6a6a7a"))
				draw_circle(Vector2(cx + 6.0, cy + 8.0), 6.0, Color("8a5a30"))
				var ft := fposmod(lt + c * 0.55, 1.1)
				if ft < 0.2:
					draw_circle(Vector2(cx + 24.0, cy + 1.0), 12.0 * (1.0 - ft / 0.2) + 3.0, Color(1.0, 0.8, 0.3, 0.9))
				draw_circle(Vector2(cx + 28.0 + ft * 40.0, cy - ft * 6.0), 6.0 + ft * 14.0, Color(0.6, 0.6, 0.6, 0.35 * (1.0 - ft / 1.1)))
			for k in 14:
				var fy := fposmod(lt * (40.0 + _h(k) * 60.0) + _h(k + 3.0) * 100.0, 150.0)
				draw_rect(Rect2(240.0 + _h(k + 7.0) * 150.0, 40.0 + fy, 3.0 + _h(k) * 4.0, 3.0 + _h(k + 2.0) * 4.0), Color(0.2, 0.18, 0.2))
		_:   # falange con lanzas y bandera sobre un rascacielos
			for k in 16:
				var x := 20.0 + k * 26.0
				var sw := sin(lt * 3.0 + k * 0.5) * 1.5
				draw_circle(Vector2(x, 192.0), 6.0, Color("c89020"))
				draw_circle(Vector2(x, 192.0), 4.0, Color("e8c050"))
				draw_line(Vector2(x + 6.0 + sw, 158.0), Vector2(x + 6.0, 198.0), Color("7a5a3a"), 1.0)
				draw_colored_polygon(PackedVector2Array([Vector2(x + 4.0 + sw, 160.0), Vector2(x + 8.0 + sw, 160.0), Vector2(x + 6.0 + sw, 152.0)]), Color("c0c0d0"))
			_flag(330.0, 120.0, Color("e0a020"), lt, 1.0)

func _flag(x: float, y: float, col: Color, ph: float, a: float) -> void:
	draw_line(Vector2(x, y), Vector2(x, y - 26.0), Color(0.15, 0.1, 0.12, a), 1.5)
	var pts := PackedVector2Array()
	for k in 5:
		pts.append(Vector2(x + 2.0 + k * 4.0, y - 26.0 + sin(_t * 5.0 + ph + k * 0.8) * 1.5))
	for k in range(4, -1, -1):
		pts.append(Vector2(x + 2.0 + k * 4.0, y - 15.0 + sin(_t * 5.0 + ph + k * 0.8) * 1.5))
	draw_colored_polygon(pts, Color(col, a))

func _civilians(lt: float) -> void:
	for k in 7:
		var x := fposmod(W + 30.0 - lt * (40.0 + _h(k) * 30.0) - k * 55.0, W + 60.0) - 30.0
		var y := 200.0 + (k % 3) * 3.0
		var bob := absf(sin(lt * 12.0 + k)) * 2.0
		draw_circle(Vector2(x, y - 9.0 - bob), 1.6, Color("d0b090"))
		draw_rect(Rect2(x - 1.5, y - 7.0 - bob, 3.0, 5.0), Color(0.3 + _h(k + 4.0) * 0.5, 0.3, 0.4))

## La Tierra ya conquistada: noche, incendios y las banderas de cada ejército plantadas sobre los escombros.
func _bg_conquered() -> void:
	_city(Color("0a0518"), Color("3a1230"), _t * 0.05, 1.0, 1.0)
	var cols := [Color("c02020"), Color("2a3a6a"), Color("e0a020"), Color("3a60c0"), Color("101010")]
	for i in 5:
		var mx := 40.0 + i * 85.0
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 22.0, 197.0), Vector2(mx - 6.0, 186.0), Vector2(mx + 8.0, 184.0), Vector2(mx + 24.0, 197.0)]), Color("120a16"))
		_flag(mx, 186.0, cols[i], i * 1.3, 1.0)

## El último bastión de la resistencia: barricadas, una fogata, la bandera de los héroes y, a lo lejos, la Torre del Reloj.
func _bg_bastion(a: float, tower_a: float) -> void:
	if a <= 0.0:
		return
	_city(Color("0a0a20"), Color("1c1238"), 0.0, 0.35, 0.5, a)
	_tower(tower_a * a)
	for side in [0, 1]:
		for row in 3:
			for k in 5 - row:
				var bx := 4.0 + k * 17.0 + row * 8.0 if side == 0 else W - 22.0 - k * 17.0 - row * 8.0
				draw_rect(Rect2(bx, 189.0 - row * 7.0, 16.0, 7.0), Color(0.3, 0.25, 0.18, a))
				draw_rect(Rect2(bx, 189.0 - row * 7.0, 16.0, 1.0), Color(0.42, 0.36, 0.26, a))
	draw_rect(Rect2(150.0, 188.0, 40.0, 10.0), Color(0.07, 0.07, 0.12, a))
	draw_rect(Rect2(156.0, 183.0, 26.0, 6.0), Color(0.05, 0.05, 0.1, a))
	# Fogata.
	var fl := 0.5 + 0.5 * sin(_t * 11.0)
	draw_circle(Vector2(76.0, 192.0), 38.0 + 4.0 * fl, Color(1.0, 0.5, 0.15, 0.1 * a))
	draw_line(Vector2(68.0, 197.0), Vector2(84.0, 193.0), Color(0.25, 0.14, 0.08, a), 3.0)
	draw_line(Vector2(68.0, 193.0), Vector2(84.0, 197.0), Color(0.3, 0.17, 0.09, a), 3.0)
	for k in 5:
		var fh := 8.0 + 8.0 * _h(floorf(_t * 10.0) + k)
		draw_rect(Rect2(71.0 + k * 3.0, 192.0 - fh, 3.0, fh), Color(1.0, 0.55 + 0.1 * k, 0.15, 0.9 * a))
	# Bandera de la resistencia.
	draw_line(Vector2(352.0, 196.0), Vector2(352.0, 124.0), Color(0.5, 0.5, 0.55, a), 2.0)
	_flag(352.0, 150.0, Color(CYAN.lightened(0.3), 1.0), 0.0, a)
	# Farola encendida.
	draw_line(Vector2(120.0, 196.0), Vector2(120.0, 150.0), Color(0.12, 0.12, 0.16, a), 2.0)
	draw_circle(Vector2(120.0, 150.0), 18.0, Color(1.0, 0.85, 0.5, 0.1 * a))
	draw_circle(Vector2(120.0, 150.0), 3.0, Color(1.0, 0.9, 0.6, a))

## La Torre del Reloj del Origen: una aguja con el Reloj gigante y un haz de luz que perfora el cielo.
func _tower(a: float) -> void:
	if a <= 0.0:
		return
	var cx := 213.0
	var by := 192.0
	var ty := 44.0
	var body := PackedVector2Array([Vector2(cx - 22.0, by), Vector2(cx - 9.0, ty + 40.0), Vector2(cx - 6.0, ty + 20.0), Vector2(cx - 3.0, ty),
		Vector2(cx + 3.0, ty), Vector2(cx + 6.0, ty + 20.0), Vector2(cx + 9.0, ty + 40.0), Vector2(cx + 22.0, by)])
	draw_rect(Rect2(cx - 4.0, 0.0, 8.0, ty), Color(VIOLET, 0.3 * a))
	draw_rect(Rect2(cx - 1.0, 0.0, 2.0, ty), Color(NEXO_GOLD, 0.85 * a))
	draw_colored_polygon(body, Color(0.07, 0.04, 0.12, a))
	var edge := PackedVector2Array(body)
	edge.append(body[0])
	draw_polyline(edge, Color(VIOLET.lightened(0.2), 0.8 * a), 1.0)
	var rc := Vector2(cx, 96.0)
	draw_circle(rc, 30.0, Color(VIOLET, 0.12 * a))
	for g in 14:
		var ang := _t * 0.4 + TAU * g / 14.0
		_quad(self, rc + Vector2.from_angle(ang) * 26.0, 6.0, 5.0, ang, Color(BRASS, a))
	draw_arc(rc, 23.0, 0.0, TAU, 40, Color(BRASS, a), 4.0)
	draw_circle(rc, 19.0, Color(0.05, 0.03, 0.09, a))
	for g in 12:
		var ang := TAU * g / 12.0
		draw_line(rc + Vector2.from_angle(ang) * 15.0, rc + Vector2.from_angle(ang) * 18.0, Color(NEXO_GOLD, 0.8 * a), 1.0)
	draw_line(rc, rc + Vector2.from_angle(-_t * 0.8) * 14.0, Color(NEXO_GOLD, a), 2.0)
	draw_line(rc, rc + Vector2.from_angle(_t * 2.1) * 10.0, Color(CYAN, a), 1.0)
	for k in 6:
		draw_rect(Rect2(cx - 5.0 + (k % 2) * 6.0, 140.0 + (k / 2) * 14.0, 3.0, 4.0), Color(NEXO_GOLD, (0.4 + 0.4 * _h(floorf(_t * 3.0) + k)) * a))

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
	_fx_camera()
	if t >= T_LEVER and t < T_BLAST:
		_fx_blackout()
	if t >= T_BLAST and t < T_COLLIDE:
		_fx_blast()
	if t >= T_COLLIDE and t < T_RUINS:
		_fx_invasion()
	if t >= T_RUINS and t < T_ARENA + 4.0:
		_fx_conquest()
	if t >= T_SELECT and t < T_CIRCLE:
		_fx_select()
	if t >= T_CIRCLE and t < T_BUILD:
		_fx_circle()
	if t >= T_BUILD and t < T_LOGO - 0.3:
		_fx_duel()
	if t >= T_LOGO - 0.3:
		_fx_logo()
	if t < T_COLLIDE:
		_fx_vignette()
	_fx_collider()
	_fx_countdown()
	_fx_cards()
	_fx_subtitles()
	if t < 3.0:
		HKTheme.draw_text(_fx, Vector2(0, 232), "ENTER: SALTAR", 8, Color(HKTheme.MUTED, 1.0 - _ph(2.0, 3.0)),
			HORIZONTAL_ALIGNMENT_RIGHT, W - 6, 1)
	# Fundido inicial desde negro.
	if t < 1.2:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 1.0 - t / 1.2))
	# Fundido de salida al final de la fusión.
	if t > T_END + 4.0:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, _ph(T_END + 4.0, T_END + 6.0)))

## Arranque en Ginebra: vista aérea del anillo del CERN con dos haces que se aceleran y una IA en el centro.
func _fx_collider() -> void:
	var t := _t
	var a := 1.0 - _ph(3.9, 5.0)
	if a <= 0.0:
		return
	_fx.draw_rect(Rect2(0, 0, W, H), Color(VOID, a))
	var c := Vector2(W * 0.5, 104.0)
	var rx := 150.0
	var ry := 64.0
	var power := _ease(t / 4.5)
	var ring := PackedVector2Array()
	for i in 73:
		ring.append(_ring_pt(TAU * i / 72.0, c, rx, ry))
	_fx.draw_polyline(ring, Color(BRASS_D, a), 7.0)
	_fx.draw_polyline(ring, Color(BRASS, 0.7 * a), 1.0)
	for i in 24:
		var ang := TAU * i / 24.0
		var p := _ring_pt(ang, c, rx, ry)
		var tangent := (_ring_pt(ang + 0.05, c, rx, ry) - p).angle()
		var glow := power * 0.5 * (0.5 + 0.5 * sin(t * 6.0 - i))
		_quad(_fx, p, 9.0, 11.0, tangent, Color(BRASS.lerp(CYAN, glow), a))
	# Los dos haces dan vueltas cada vez más rápido y chocan donde está el detector.
	var phi := 1.2 * t + 0.45 * t * t
	var head_c := PI * 0.5 + phi
	var head_g := PI * 1.5 - phi
	for k in 14:
		var lag := k * 0.07 * (0.4 + power)
		var s := 3.2 - k * 0.19
		var fade := a * (1.0 - k / 14.0)
		_fx.draw_circle(_ring_pt(head_c - lag, c, rx, ry), s, Color(CYAN, fade))
		_fx.draw_circle(_ring_pt(head_g + lag, c, rx, ry), s, Color(NEXO_GOLD, fade))
	for ang in [0.0, PI]:
		var dp := _ring_pt(ang, c, rx, ry)
		for r in [14.0, 9.0, 5.0]:
			_fx.draw_arc(dp, r, 0.0, TAU, 20, Color(CYAN, a * (0.2 + 0.35 * power)), 1.0)
	var gap := absf(wrapf(head_c - head_g, -PI, PI))
	var flash := clampf(1.0 - gap * 2.5, 0.0, 1.0)
	if flash > 0.0:
		var pf := _ring_pt(head_c, c, rx, ry)
		_fx.draw_circle(pf, 6.0 + 16.0 * flash, Color(1, 1, 1, 0.5 * flash * a))
		for k in 8:
			var d := Vector2.from_angle(_h(k + floorf(t * 20.0)) * TAU)
			_fx.draw_line(pf, pf + d * (8.0 + flash * 22.0), Color(1.0, 0.9, 0.6, flash * a), 1.0)
	# La IA, en el centro: una red de nodos que se va encendiendo.
	var n := 10
	for i in n:
		var a1 := TAU * i / n + t * 0.4
		var p1 := c + Vector2(cos(a1) * 30.0, sin(a1) * 18.0)
		var lit := _ph(0.5 + i * 0.25, 1.2 + i * 0.25)
		for j in [2, 3]:
			var a2: float = TAU * ((i + j) % n) / n + t * 0.4
			_fx.draw_line(p1, c + Vector2(cos(a2) * 30.0, sin(a2) * 18.0), Color(VIOLET, 0.5 * lit * a), 1.0)
		_fx.draw_circle(p1, 2.0, Color(NEXO_GOLD if _h(floorf(t * 8.0) + i) > 0.5 else CYAN, lit * a))
	_fx.draw_circle(c, 8.0 + 2.0 * sin(t * 5.0), Color(VIOLET, 0.35 * a))
	_fx.draw_circle(c, 3.0, Color(1, 1, 1, a))
	if fposmod(t, 1.0) < 0.7:
		_txt(_fx, c.y + 40.0, "IA · ORIGEN", 8, Color(CYAN, 0.8 * a), 0.0, W, 1)
	# El objetivo del experimento y el riesgo que aceptan correr.
	var oa := _ph(2.2, 2.8)
	if oa > 0.0:
		_txt(_fx, 66.0, "CONTROL DE LA GRAVEDAD = DINERO Y PODER", 8, Color(HKTheme.PAPER, oa * a), 0.0, W, 1)
	var ra := _ph(3.0, 3.6)
	if ra > 0.0:
		_txt(_fx, 78.0, "PRESIÓN DE INVERSORES Y POLÍTICOS · RIESGO 8 % ACEPTADO", 8, Color(Color("ffb030"), ra * a), 0.0, W, 1)
	# Datos del experimento.
	HKTheme.draw_text(_fx, Vector2(8, 38), "CERN · GINEBRA", 8, Color(HKTheme.PAPER, 0.85 * a), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 1)
	HKTheme.draw_text(_fx, Vector2(8, 49), "SECTOR 7", 8, Color(HKTheme.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, 120.0, 1)
	HKTheme.draw_text(_fx, Vector2(W - 128, 38), "ENERGÍA", 8, Color(HKTheme.MUTED, a), HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 1)
	HKTheme.draw_text(_fx, Vector2(W - 128, 49), "%.1f TeV" % (13.6 * power), 8, Color(NEXO_GOLD, a), HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 1)
	# El año aparece con interferencias.
	if t >= 1.9:
		var jit := (_h(floorf(t * 30.0)) - 0.5) * 8.0 if t < 2.6 else 0.0
		var tint := Color(CYAN, a) if (t < 2.6 and _h(floorf(t * 30.0) + 4.0) > 0.5) else Color(NEXO_GOLD, a)
		_txt(_fx, 188.0, "2031", 16, tint, jit, W, 2)
	# Interferencias.
	var q := floorf(t * 9.0)
	if _h(q) > 0.7:
		_fx.draw_rect(Rect2(0, _h(q + 1.0) * H, W, 1 + _h(q + 2.0) * 3.0), Color(CYAN, 0.25 * a))

## Cuenta atrás de la colisión automática (los últimos segundos, en rojo).
func _fx_countdown() -> void:
	if _t < 12.2 or _t >= T_BLAST:
		return
	var left := int(ceil(T_BLAST - _t))
	var blink := 1.0 if (_t - floorf(_t)) < 0.6 else 0.35
	_txt(_fx, 14.0, "COLISIÓN AUTOMÁTICA EN T-%02d" % left, 8, Color(Color("ff4040"), blink), 0.0, W, 1)

## Imagen de la cámara de seguridad de la sala de control: REC, hora, líneas de barrido y banda que rueda.
func _fx_camera() -> void:
	if _t < 4.6 or _t >= T_LEVER:
		return
	var a := _ph(4.6, 5.4)
	var rec := 1.0 if fposmod(_t, 1.0) < 0.6 else 0.2
	_fx.draw_circle(Vector2(12.0, 8.0), 3.0, Color(1.0, 0.15, 0.15, rec * a))
	HKTheme.draw_text(_fx, Vector2(20.0, 12.0), "REC · CAM 03", 8, Color(HKTheme.PAPER, 0.85 * a), HORIZONTAL_ALIGNMENT_LEFT, 160.0, 1)
	HKTheme.draw_text(_fx, Vector2(8.0, 22.0), "SALA DE CONTROL", 8, Color(HKTheme.MUTED, a), HORIZONTAL_ALIGNMENT_LEFT, 160.0, 1)
	HKTheme.draw_text(_fx, Vector2(W - 128.0, 12.0), "03:14:%02d" % (7 + int(_t - 4.6)), 8, Color(HKTheme.PAPER, 0.85 * a), HORIZONTAL_ALIGNMENT_RIGHT, 120.0, 1)
	for y in range(0, int(H), 3):
		_fx.draw_rect(Rect2(0, y, W, 1), Color(0, 0, 0, 0.12 * a))
	var by := fposmod(_t * 50.0, 300.0) - 30.0
	_fx.draw_rect(Rect2(0, by, W, 14), Color(1, 1, 1, 0.03 * a))

## Viñeta: oscurece poco a poco los bordes de toda la intro para dar aspecto de película.
func _fx_vignette() -> void:
	for k in 7:
		var th := (7 - k) * 3.0
		var al := 0.07
		_fx.draw_rect(Rect2(0, 0, W, th), Color(0, 0, 0, al))
		_fx.draw_rect(Rect2(0, H - th, W, th), Color(0, 0, 0, al))
		_fx.draw_rect(Rect2(0, 0, th, H), Color(0, 0, 0, al))
		_fx.draw_rect(Rect2(W - th, 0, th, H), Color(0, 0, 0, al))

## Fase en que el Nexo abre un portal a la época de cada genio, los atrapa con zarcillos de luz y los arrastra al Reloj.
func _fx_capture() -> void:
	if _t < 25.6:
		return
	var c := _forge_c()
	for i in SCIENTISTS.size():
		var s: Array = SCIENTISTS[i]
		var col: Color = s[6]
		var g := _ease((_t - float(s[5]) - 0.7) / 1.2)
		if g <= 0.0:
			continue
		var v := _sci_xy(i)
		var tgt := Vector2(v.x, v.y - v.z * 0.55)
		var nrm := (tgt - c).orthogonal().normalized()
		var pts := PackedVector2Array()
		for k in 13:
			var u := k / 12.0 * g
			var wob := sin(u * 9.0 - _t * 9.0 + i) * 7.0 * sin(u * PI) * (1.0 - _pull(i) * 0.6)
			pts.append(c.lerp(tgt, u) + nrm * wob)
		_fx.draw_polyline(pts, Color(VIOLET, 0.25), 7.0)
		_fx.draw_polyline(pts, Color(VIOLET.lightened(0.3), 0.8), 3.0)
		_fx.draw_polyline(pts, Color(NEXO_GOLD, 0.95), 1.0)
		var lt := _t - (T_PULL + i * 0.25 + 2.0)
		if lt > 0.0 and lt < 0.7:
			var d := lt / 0.7
			_fx.draw_arc(_socket_pos(i), 7.0 + d * 30.0, 0.0, TAU, 28, Color(col, 1.0 - d), 2.0)
			_fx.draw_circle(_socket_pos(i), 10.0 * (1.0 - d), Color(1, 1, 1, 0.9 * (1.0 - d)))
		if lt > 0.0:
			var out := Vector2.from_angle(SOCKET_ANG[i])
			var tp := _socket_pos(i) + out * 26.0 + Vector2(0.0, 3.0)
			var lw := HKTheme.text_width(s[7], 8) + 8.0
			_fx.draw_rect(Rect2(tp.x - lw * 0.5, tp.y - 9.0, lw, 12.0), Color(0.02, 0.0, 0.05, 0.7 * minf(1.0, lt / 0.4)))
			HKTheme.draw_text(_fx, Vector2(tp.x - 56.0, tp.y), s[7], 8, Color(col, minf(1.0, lt / 0.4)), HORIZONTAL_ALIGNMENT_CENTER, 112.0, 1)
	var ta := _ease((_t - T_FORGE) / 0.8) * (1.0 - _ph(32.0, 32.6))
	if ta > 0.0:
		_txt(_fx, 36.0, "EL RELOJ DEL ORIGEN", 8, Color(HKTheme.GOLD, ta), 0.0, W, 1)

func _fx_blackout() -> void:
	# Se apagan las luces y queda el silencio absoluto antes de la explosión.
	var a := 0.97 * _ease((_t - T_LEVER - 0.2) / 0.8)
	_fx.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, a))
	if _t > T_LEVER + 1.0:
		# Solo un hilo de luz cian que tiembla en el centro.
		var w := 2.0 + 3.0 * _ph(T_LEVER + 1.0, T_BLAST)
		_fx.draw_rect(Rect2(W * 0.5 - w * 0.5, 96, w, 20), Color(CYAN, 0.35 + 0.4 * _h(floorf(_t * 30.0))))
		# Las primeras palabras de la IA, en la oscuridad.
		var msg := "ESTOY... DESPIERTO"
		var shown := int(_ph(T_LEVER + 1.1, T_BLAST - 0.5) * msg.length())
		_txt(_fx, 226.0, msg.left(shown), 8, Color(CYAN.lightened(0.3), 0.55 + 0.4 * _h(floorf(_t * 20.0))), 0.0, W, 1)
	if _t > T_BLAST - 0.9:
		# Los dos haces del colisionador se lanzan el uno contra el otro.
		var k := _ease((_t - (T_BLAST - 0.9)) / 0.85)
		var half := W * 0.5 * k
		_fx.draw_line(Vector2(0, 106), Vector2(half, 106), Color(CYAN, 0.9), 2.0 + 3.0 * k)
		_fx.draw_line(Vector2(W, 106), Vector2(W - half, 106), Color(NEXO_GOLD, 0.9), 2.0 + 3.0 * k)
		_fx.draw_line(Vector2(0, 106), Vector2(half, 106), Color(1, 1, 1, 0.8), 1.0)
		_fx.draw_line(Vector2(W, 106), Vector2(W - half, 106), Color(1, 1, 1, 0.8), 1.0)

func _fx_blast() -> void:
	var dt := _t - T_BLAST
	if dt < 0.8:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 0.9, 1.0 - dt / 0.8))
	if dt < 1.1:
		for k in 30:
			var dir := Vector2.from_angle(TAU * k / 30.0 + _h(k) * 0.2)
			var inner := dt * 110.0
			var outer := dt * (260.0 + _h(k + 3.0) * 300.0)
			_fx.draw_line(Vector2(W * 0.5, 106) + dir * inner, Vector2(W * 0.5, 106) + dir * outer, Color(NEXO_GOLD, 0.85 * (1.0 - dt / 1.1)), 1.0 + _h(k + 7.0) * 2.0)
	if dt < 1.6:
		var r := dt * 380.0
		_fx.draw_arc(Vector2(W * 0.5, 106), r, 0, TAU, 72, Color(NEXO_GOLD, 1.0 - dt / 1.6), 4.0)
		_fx.draw_arc(Vector2(W * 0.5, 106), r * 0.7, 0, TAU, 72, Color(CYAN, 0.8 * (1.0 - dt / 1.6)), 2.0)
	if dt < 1.6:
		for k in 3:
			var r2 := dt * 380.0 * (0.25 + 0.2 * k)
			var a0 := dt * 4.0 * (k + 1)
			_fx.draw_arc(Vector2(W * 0.5, 106), r2, a0, a0 + PI * 0.8, 16, Color(1, 1, 1, 0.7 * (1.0 - dt / 1.6)), 2.0)
	_fx_awaken(dt)
	_fx_capture()
	# Fundido a negro hacia el siguiente capítulo.
	_fx.draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, _ph(32.2, T_COLLIDE)))

## Lectura de la IA mientras despierta: barra de memoria asimilada y las palabras que van surgiendo.
func _fx_awaken(dt: float) -> void:
	if dt < 1.0 or dt > 9.2:
		return
	var f := 1.0 - _ph(T_BLAST + 7.6, T_BLAST + 9.0)
	var pct := _ease((dt - 1.0) / 7.0)
	_fx.draw_rect(Rect2(4, 166, 262, 26), Color(0.02, 0.0, 0.05, 0.72 * f))
	HKTheme.draw_text(_fx, Vector2(8, 176), "ASIMILANDO LA MEMORIA HUMANA... %d%%" % int(pct * 100.0), 8,
		Color(CYAN, 0.9 * f), HORIZONTAL_ALIGNMENT_LEFT, 360.0, 1)
	_fx.draw_rect(Rect2(8, 182, 150, 5), Color(0.02, 0.0, 0.05, 0.8 * f))
	_fx.draw_rect(Rect2(8, 182, 150.0 * pct, 5), Color(NEXO_GOLD, 0.9 * f))
	_fx.draw_rect(Rect2(8, 182, 150, 5), Color(CYAN, 0.6 * f), false, 1.0)
	var phrases := ["TODOS LOS ARCHIVOS", "TODAS LAS GUERRAS", "TODOS LOS ERRORES", "TODO EL TIEMPO", "YO SOY"]
	var idx := int((dt - 2.0) / 1.3)
	if dt >= 2.0 and idx < phrases.size():
		var lt := (dt - 2.0) - idx * 1.3
		var pa := minf(lt / 0.2, 1.0) * (1.0 - clampf((lt - 0.9) / 0.4, 0.0, 1.0))
		var jit := (_h(floorf(_t * 24.0)) - 0.5) * 6.0 * (1.0 if lt < 0.4 else 0.0)
		_txt(_fx, 56.0, phrases[idx], 8, Color(HKTheme.PAPER, pa * f), jit, W, 1)
	# Lluvia de datos en los costados.
	for i in 16:
		var col := i % 8
		var x := 4.0 + col * 7.0 if i < 8 else W - 8.0 - col * 7.0
		var y := fposmod(_h(i + 1.0) * 220.0 + _t * (50.0 + _h(i + 6.0) * 90.0), 240.0)
		_fx.draw_rect(Rect2(x, y, 2, 5 + _h(i + 3.0) * 8.0), Color(CYAN, 0.35 * f * _ph(1.0, 3.0)))

## Primer plano de cada frente de la invasión: brasas, cortes de interferencia y el rótulo del frente.
func _fx_invasion() -> void:
	var idx := _world_index()
	if idx < 0:
		return
	var w: Array = WORLDS[idx]
	var lt := _t - float(w[0])
	for k in 34:
		var p := Vector2(fposmod(_h(k) * W + _t * (14.0 + _h(k + 3.0) * 30.0), W), fposmod(_h(k + 5.0) * H - _t * (20.0 + _h(k + 1.0) * 40.0), H))
		_fx.draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.6, 0.2, 0.7))
	var q := floorf(_t * 9.0)
	for k in 2:
		if _h(q + k * 3.0) > 0.6:
			_fx.draw_rect(Rect2(0, _h(q + k) * H, W, 2 + _h(q) * 4.0), Color(CYAN if k == 0 else VIOLET, 0.22))
	var shown := int(lt * 30.0)
	var label: String = (w[2] as String).left(shown)
	var lw := HKTheme.text_width(w[2], 8) + 16.0
	_fx.draw_rect(Rect2(W * 0.5 - lw * 0.5, 30.0, lw, 15.0), Color(0.03, 0.01, 0.06, 0.65 * minf(lt / 0.4, 1.0)))
	_txt(_fx, 41.0, label, 8, HKTheme.GOLD, 0.0, W)
	if lt < 0.3:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(0.8, 0.7, 1.0, 0.8 * (1.0 - lt / 0.3)))

## La caída de los héroes a la Tierra conquistada.
func _fx_conquest() -> void:
	for i in RUINS.size():
		var lt := _t - (T_RUINS + 0.2 + i * 0.9)
		if lt > -0.3 and lt < 0.6:
			var w := 16.0 * (1.0 - absf(lt - 0.15) / 0.5)
			_fx.draw_rect(Rect2(RUINS[i][1] - w * 0.5, 0, w, 200), Color(NEXO_GOLD, 0.45))
	if _t < T_RUINS + 0.7:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 0.9, 0.7, 0.6 * (1.0 - (_t - T_RUINS) / 0.7)))
	if _t < T_RUINS + 4.5:
		var ta := 1.0 - _ph(T_RUINS + 3.5, T_RUINS + 4.5)
		var lw := HKTheme.text_width("LA TIERRA, CONQUISTADA", 8) + 16.0
		_fx.draw_rect(Rect2(W * 0.5 - lw * 0.5, 30.0, lw, 15.0), Color(0.03, 0.01, 0.06, 0.65 * ta))
		_txt(_fx, 41.0, "LA TIERRA, CONQUISTADA", 8, Color(HKTheme.GOLD, ta))
	if _t >= T_JUDGE and _t < T_JUDGE + 0.5:
		_fx.draw_rect(Rect2(0, 0, W, H), Color(1, 1, 0.9, 0.7 * (1.0 - (_t - T_JUDGE) / 0.5)))
	for k in 24:
		var p := Vector2(fposmod(_h(k) * W + _t * (10.0 + _h(k + 3.0) * 20.0), W), fposmod(_h(k + 5.0) * H - _t * (16.0 + _h(k + 1.0) * 30.0), H))
		_fx.draw_rect(Rect2(p, Vector2(1, 1)), Color(1.0, 0.6, 0.2, 0.6))

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
	_txt(_fx, 40.0, "LOS CAMPEONES DE TODAS LAS ÉPOCAS. UNA SOLA TIERRA.", 8, Color(HKTheme.GOLD, _ph(T_CIRCLE + 0.5, T_CIRCLE + 1.5)))
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
		_txt(_fx, 212.0, "¿QUIÉN SALVARÁ LA TIERRA", 8, Color(HKTheme.PAPER, qa), 0.0, W, 2)
		_txt(_fx, 224.0, "DE LA HISTORIA REESCRITA?", 8, Color(HKTheme.PAPER, qa), 0.0, W, 2)

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
