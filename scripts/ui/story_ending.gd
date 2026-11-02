## FINAL del MODO HISTORIA: el Nexo ofrece su poder al último en pie y el jugador decide qué hacer
## con el tiempo. Cada decisión tiene su animación con la voz del Nexo y después el epílogo del
## luchador del jugador.
##   0  el Nexo habla        CONTINUAR
##   1  la elección          REPARAR EL TIEMPO / REESCRIBIRLO / LIBERAR EL TIEMPO (oculta)
##   2  la animación         cualquier tecla la salta
##   3  el epílogo           CONTINUAR
##   4  la lección del tiempo  VER CRÉDITOS
## LIBERAR solo aparece si se llegó hasta aquí sin gastar ninguna revancha.
## La voz sale de tools/gen_story_voice.py (end_1 a end_5, mismo texto que los subtítulos).
class_name StoryEnding
extends Control

const W := 426.0
const H := 240.0
const MUSIC_FROM := 66.0
const NEXO_GOLD := Color("ffd24a")
const CYAN := Color("35e6ff")
const VIOLET := Color("9a4dff")
## Colores de los cinco fragmentos de tiempo (una época cada uno), de la I a la V.
const SHARD_COLORS: Array[Color] = [Color("35e6ff"), Color("c8b080"), Color("d08a30"), Color("d8c090"), Color("ffd24a")]
const CLOCK_C := Vector2(213.0, 70.0)
const CLOCK_R := 38.0

const NEXO_LINES: Array = [
	["ME HAS VENCIDO. TODAS LAS ÉPOCAS", "CAYERON ANTE TI Y AHORA ESPERAN."],
	["EL PODER DEL NEXO ES TUYO.", "¿QUÉ HARÁS CON EL TIEMPO?"],
]
## Por decisión: voz (end_N), título, color del título y subtítulos de la animación.
const ENDINGS := {
	&"repair": {"voice": 3, "title": "EL TIEMPO SANA", "color": Color("ffd24a"),
		"subs": ["QUE CADA UNO VUELVA A SU TIEMPO.", "QUE EL MUNDO RECUERDE SUS ERRORES,", "Y APRENDA DE ELLOS."],
		"lesson": ["LA HISTORIA NO SE BORRA:", "SE RECUERDA Y SE APRENDE."]},
	&"rewrite": {"voice": 4, "title": "LA HISTORIA REESCRITA", "color": Color("ff7050"),
		"subs": ["QUE EL TIEMPO SEA TUYO.", "PERO QUIEN ESCRIBE LA HISTORIA A SU IMAGEN,", "TERMINA REPITIÉNDOLA."],
		"lesson": ["QUIEN REESCRIBE LA HISTORIA A SU MEDIDA", "ACABA REPITIENDO SUS ERRORES."]},
	&"free": {"voice": 5, "title": "EL TIEMPO LIBRE", "color": Color("70e0ff"),
		"subs": ["NI TÚ, NI YO.", "QUE EL TIEMPO SEA DE TODOS,", "Y QUE CADA GENERACIÓN APRENDA DE LA ANTERIOR."],
		"lesson": ["EL TIEMPO ES DE TODOS:", "CADA GENERACIÓN APRENDE DE LA ANTERIOR."]},
}
## Epílogos propios: id -> [reparar, reescribir]. El resto usa una plantilla.
const EPILOGUES := {
	&"napoleon": ["VUELVE A SU CAMPAÑA,\nSABIENDO DÓNDE DETENERSE.\nEL INVIERNO LE ENSEÑÓ\nMÁS QUE UN TRIUNFO.",
		"CORONA UN IMPERIO SIN FIN,\nPERO SOLO, Y SIN QUIEN\nSE ATREVA A CONTRADECIRLO."],
	&"julio_cesar": ["CRUZA EL RUBICÓN OTRA VEZ,\nPERO ESCUCHA EL AVISO\nDE LOS IDUS DE MARZO.",
		"ROMA NUNCA CAE:\nEL TIEMPO SE LLAMA CÉSAR.\nNADIE LO CONTRADICE."],
	&"cleopatra": ["REGRESA AL NILO Y GOBIERNA,\nAPRENDIENDO EN QUIÉN\nCONFIAR.",
		"EGIPTO DURA PARA SIEMPRE,\nBAJO UN TRONO QUE YA\nNO ESCUCHA A NADIE."],
	&"lautaro": ["VUELVE A LA ARAUCANÍA,\nLLEVANDO LA LECCIÓN\nDE CADA BATALLA.",
		"LA TIERRA NO CONOCE\nOTRO TOQUI QUE ÉL.\nNADIE APRENDE A LIDERAR."],
	&"arturo_prat": ["PISA LA ESMERALDA Y\nSU SACRIFICIO SE RECUERDA\nCOMO UN EJEMPLO.",
		"EL ABORDAJE SE REPITE\nY EL MAR ES SUYO,\nPERO SIN NADA QUE ENSEÑAR."],
	&"albert_einstein": ["APAGA EL RELOJ Y LE PIDE\nPERDÓN AL TIEMPO.\nAPRENDE: SABER NO BASTA.",
		"ESCRIBE UNA ECUACIÓN NUEVA:\nLA DEL UNIVERSO,\nY NADIE PUEDE REVISARLA."],
	&"nikola_tesla": ["DESMONTA LA MÁQUINA:\nLA ENERGÍA LLEGA A TODOS\nY NADIE QUEDA A OSCURAS.",
		"EL MUNDO SE ENCIENDE\nCON SU CORRIENTE,\nSOLO SI ÉL LO PERMITE."],
	&"marie_curie": ["CIERRA LA GRIETA CON\nSU PROPIA LUZ Y APRENDE\nA CUIDAR LO QUE CREA.",
		"SU RADIACIÓN ILUMINA\nCADA ÉPOCA,\nY TAMBIÉN LAS ENFERMA."],
	&"leonardo_da_vinci": ["GUARDA LOS PLANOS DEL RELOJ.\nAHORA SABE QUE NO TODO\nLO POSIBLE SE DEBE HACER.",
		"DISEÑA EL TIEMPO COMO\nSU OBRA MAESTRA,\nSIN BORRADORES NI ERRORES."],
	&"alejandro_magno": ["REGRESA A BABILONIA Y\nVIVE MÁS DE 32 AÑOS,\nAPRENDIENDO A GOBERNAR.",
		"SU IMPERIO NO TIENE\nLÍMITE NI FIN,\nNI QUIEN DIGA BASTA."],
	&"jesus_de_nazaret": ["DEVUELVE A CADA UNO\nA SU LUGAR Y PERDONA:\nEL ERROR TAMBIÉN ENSEÑA.",
		"NO REESCRIBE NADA:\nPERDONA Y ENSEÑA\nA CORREGIR LOS ERRORES."],
}

var _step: int = 0
var _t: float = 0.0
var _ending: StringName = &"repair"
var _fighter: FighterRenderer
var _btns: Array[Button] = []
var _voice: AudioStreamPlayer
var _voice_at: float = 0.0
var _voice_started: bool = true
var _music: AudioStreamPlayer
var _anim_end: float = 8.0

func _ready() -> void:
	theme = HKTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	bg.show_title = false
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)
	for i in 3:
		_btns.append(_button())
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = 2.0
	add_child(_voice)
	_music = AudioStreamPlayer.new()
	_music.stream = load("res://assets/music/intro.ogg") as AudioStream
	_music.volume_db = -16.0
	add_child(_music)
	_music.play(MUSIC_FROM)
	_say(1, 0.6)
	_show_buttons()

func _button() -> Button:
	var b := Button.new()
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	add_child(b)
	return b

## Programa la voz `end_<n>` para que suene `delay` segundos después de empezar el paso.
func _say(n: int, delay: float) -> void:
	_voice.stop()
	_voice.stream = load("res://assets/sounds/story/end_%d.wav" % n) as AudioStream
	_voice_at = delay
	_voice_started = false

func _free_unlocked() -> bool:
	return Game.story_continues_used == 0

func _next() -> void:
	Sfx.play(&"confirm")
	_step += 1
	_t = 0.0
	_say(2, 0.4)
	_show_buttons()

func _choose(ending: StringName) -> void:
	Sfx.play(&"fight")
	_ending = ending
	_step = 2
	_t = 0.0
	_fighter = FighterRenderer.new()
	add_child(_fighter)
	move_child(_fighter, 1)
	_fighter.setup(Game.p1_data())
	_say(ENDINGS[ending]["voice"], 1.0)
	var len_s: float = _voice.stream.get_length() if _voice.stream else 6.0
	_anim_end = 1.0 + len_s + 1.6
	_show_buttons()

func _go_epilogue() -> void:
	_voice.stop()
	_voice_started = true
	_step = 3
	_t = 0.0
	_show_buttons()

## La enseñanza del final: una frase sola sobre fondo oscuro antes de los créditos.
func _go_lesson() -> void:
	Sfx.play(&"confirm")
	_step = 4
	_t = 0.0
	_show_buttons()

func _show_buttons() -> void:
	for b in _btns:
		b.visible = false
		for c in b.pressed.get_connections():
			b.pressed.disconnect(c.callable)
	match _step:
		0:
			_place(_btns[0], "CONTINUAR", Vector2(158, 214), 110, _next)
		1:
			_place(_btns[0], "REPARAR EL TIEMPO", Vector2(118, 152), 190, _choose.bind(&"repair"))
			_place(_btns[1], "REESCRIBIRLO", Vector2(118, 172), 190, _choose.bind(&"rewrite"))
			if _free_unlocked():
				_place(_btns[2], "LIBERAR EL TIEMPO", Vector2(118, 192), 190, _choose.bind(&"free"))
		3:
			_place(_btns[0], "CONTINUAR", Vector2(236, 214), 110, _go_lesson)
		4:
			_place(_btns[0], "VER CRÉDITOS", Vector2(158, 214), 110, func(): Game.goto(Game.SCENE_CREDITS))
	for b in _btns:
		if b.visible:
			b.grab_focus()
			break

func _place(b: Button, text: String, pos: Vector2, width: float, action: Callable) -> void:
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(width, 16)
	b.visible = true
	b.pressed.connect(action)

func _unhandled_input(event: InputEvent) -> void:
	if _step != 2 or _t < 0.4:
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		_go_epilogue()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_t += delta
	if not _voice_started and _t >= _voice_at and _voice.stream:
		_voice_started = true
		_voice.play()
	var quiet := _voice.playing
	_music.volume_db = move_toward(_music.volume_db, -22.0 if quiet else -14.0, 20.0 * delta)
	if _step == 2 and _t >= _anim_end:
		_go_epilogue()
	_place_fighter()
	queue_redraw()

func _place_fighter() -> void:
	if _fighter == null:
		return
	_fighter.visible = _step != 4
	if _step == 2:
		var s := clampf(84.0 / maxf(_fighter.approx_height(), 1.0), 0.6, 1.4)
		_fighter.scale = Vector2(s, s)
		_fighter.position = Vector2(213.0, 206.0)
		_fighter.pose_name = &"victory" if _ending == &"rewrite" else &"idle"
		_fighter.modulate.a = clampf(_t / 1.5, 0.0, 1.0)
	else:
		var s2 := clampf(110.0 / maxf(_fighter.approx_height(), 1.0), 0.8, 1.6)
		_fighter.scale = Vector2(s2, s2)
		_fighter.position = Vector2(100.0, 206.0)
		_fighter.pose_name = &"victory"
		_fighter.modulate.a = 1.0

static func _h(i: float) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)

static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func _ph(a: float, b: float) -> float:
	return clampf((_t - a) / (b - a), 0.0, 1.0)

# =========================================================================
#  Dibujo
# =========================================================================
func _draw() -> void:
	match _step:
		0, 1:
			draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.02, 0.05, 0.7))
			_draw_nexo_speech()
		2:
			_draw_decision()
		3:
			draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.02, 0.05, 0.7))
			_draw_epilogue()
		_:
			_draw_lesson()

func _draw_nexo_speech() -> void:
	var lines: Array = NEXO_LINES[_step]
	var a := clampf(_t / 0.8, 0.0, 1.0)
	HKTheme.draw_text(self, Vector2(0, 56), "EL NEXO", 16, NEXO_GOLD * Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, W, 3)
	for i in lines.size():
		HKTheme.draw_text(self, Vector2(0, 100 + i * 14), lines[i], 8, HKTheme.PAPER * Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, W, 2)
	if _step == 1:
		if _free_unlocked():
			HKTheme.draw_text(self, Vector2(0, 140), "NO GASTASTE NINGUNA REVANCHA: SE ABRE UN TERCER CAMINO.", 8,
				Color("70e0ff"), HORIZONTAL_ALIGNMENT_CENTER, W, 1)
		else:
			HKTheme.draw_text(self, Vector2(0, 140), "TU DECISIÓN CAMBIARÁ TODAS LAS ÉPOCAS.", 8,
				HKTheme.MUTED.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER, W, 1)

## Un fragmento del reloj (un quinto del círculo) desplazado y girado.
func _shard(i: int, offset: Vector2, rot: float, alpha: float) -> void:
	var a0 := -PI * 0.5 + TAU * i / 5.0
	var pts := PackedVector2Array([CLOCK_C])
	for k in 9:
		pts.append(CLOCK_C + Vector2.from_angle(a0 + TAU / 5.0 * k / 8.0) * CLOCK_R)
	for k in pts.size():
		pts[k] = CLOCK_C + (pts[k] - CLOCK_C).rotated(rot) + offset
	var col: Color = SHARD_COLORS[i]
	draw_colored_polygon(pts, Color(col.darkened(0.55), alpha))
	var edge := pts.duplicate()
	edge.append(pts[0])
	draw_polyline(edge, Color(col, alpha), 1.5)

func _clock_hands(speed: float, alpha: float, col: Color) -> void:
	draw_circle(CLOCK_C, 3.0, Color(col, alpha))
	draw_line(CLOCK_C, CLOCK_C + Vector2.from_angle(_t * 0.25 * speed - PI * 0.5) * CLOCK_R * 0.55, Color(col, alpha), 2.5)
	draw_line(CLOCK_C, CLOCK_C + Vector2.from_angle(_t * 1.4 * speed - PI * 0.5) * CLOCK_R * 0.8, Color(col, alpha), 1.5)
	for k in 12:
		var a := TAU * k / 12.0
		draw_line(CLOCK_C + Vector2.from_angle(a) * (CLOCK_R - 5.0), CLOCK_C + Vector2.from_angle(a) * (CLOCK_R - 1.0), Color(col, alpha * 0.8), 1.5)

func _draw_decision() -> void:
	var fade_in := _ph(0.0, 0.6)
	var fade_out := _ph(_anim_end - 0.7, _anim_end)
	match _ending:
		&"repair": _decision_repair()
		&"rewrite": _decision_rewrite()
		_: _decision_free()
	var info: Dictionary = ENDINGS[_ending]
	var ta := _ph(0.4, 1.2) * (1.0 - fade_out)
	var title: String = info["title"]
	var tw := HKTheme.text_width(title, 8) + 24.0
	draw_rect(Rect2(W * 0.5 - tw * 0.5, 8, tw, 17), Color(0.03, 0.01, 0.06, 0.72 * ta))
	HKTheme.draw_text(self, Vector2(0, 21), title, 8, Color(info["color"], ta), HORIZONTAL_ALIGNMENT_CENTER, W, 1)
	_draw_ending_subs(info["subs"])
	if _t < 3.0:
		HKTheme.draw_text(self, Vector2(0, 36), "CUALQUIER TECLA: SALTAR", 8, Color(HKTheme.MUTED, 1.0 - _ph(2.0, 3.0)),
			HORIZONTAL_ALIGNMENT_RIGHT, W - 6, 1)
	if fade_in < 1.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.02, 0.05, 1.0 - fade_in))
	if fade_out > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(0.03, 0.02, 0.05, fade_out))

func _draw_ending_subs(subs: Array) -> void:
	var len_s: float = _voice.stream.get_length() if _voice.stream else 6.0
	var total := 0.0
	for s in subs:
		total += float((s as String).length() + 6)
	var t0 := 1.0
	for s in subs:
		var d: float = len_s * float((s as String).length() + 6) / total
		if _t >= t0 and _t < t0 + d:
			var a := minf(clampf((_t - t0) / 0.15, 0.0, 1.0), clampf((t0 + d - _t) / 0.15, 0.0, 1.0))
			draw_rect(Rect2(0, 207, W, 22), Color(0.02, 0.0, 0.04, 0.66 * a))
			HKTheme.draw_text(self, Vector2(0, 222), s, 8, Color(HKTheme.PAPER, a), HORIZONTAL_ALIGNMENT_CENTER, W, 2)
			return
		t0 += d

func _bands(colors: Array) -> void:
	var h := 200.0 / colors.size()
	for i in colors.size():
		draw_rect(Rect2(0, i * h, W, h + 1.0), Color(colors[i]))

# --- Reparar: los fragmentos vuelven, la grieta se sella y el reloj marcha ---
func _decision_repair() -> void:
	_bands(["0a0618", "12102a", "1c1840", "2a2050", "3a2c5c"])
	var join := _ease(_ph(0.8, 3.6))
	var sealed := _ph(3.6, 4.4)
	for i in 5:
		var mid := -PI * 0.5 + TAU * (i + 0.5) / 5.0
		var drift := Vector2(sin(_t * 1.3 + i), cos(_t * 1.1 + i)) * 5.0 * (1.0 - join)
		_shard(i, Vector2.from_angle(mid) * 58.0 * (1.0 - join) + drift, (1.0 - join) * (0.7 + 0.4 * sin(i * 2.0)), 1.0)
	if join >= 1.0:
		for i in 5:
			var a := -PI * 0.5 + TAU * i / 5.0
			draw_line(CLOCK_C, CLOCK_C + Vector2.from_angle(a) * CLOCK_R, Color(NEXO_GOLD, 0.9 * sealed), 2.0)
		draw_arc(CLOCK_C, CLOCK_R + 3.0, 0, TAU, 56, Color(NEXO_GOLD, sealed), 3.0)
		_clock_hands(1.0, sealed, Color("fff4c0"))
		for k in 3:
			draw_circle(CLOCK_C, (CLOCK_R + 10.0 + k * 14.0) * (0.6 + 0.4 * sealed), Color(NEXO_GOLD, 0.06 * sealed))
	if _t >= 3.6 and _t < 4.2:
		draw_rect(Rect2(0, 0, W, H), Color(1, 0.95, 0.7, 0.55 * (1.0 - (_t - 3.6) / 0.6)))
	# Destellos dorados que suben una vez sellada la grieta.
	for i in 40:
		var p := fposmod(_t * (0.15 + _h(i) * 0.2) + _h(i + 3.0), 1.0)
		draw_rect(Rect2(20.0 + _h(i + 1.0) * (W - 40.0), 200.0 - p * 190.0, 1.5, 1.5), Color(NEXO_GOLD, 0.8 * sealed * (1.0 - p)))
	draw_rect(Rect2(0, 206, W, 34), Color(0.03, 0.015, 0.06))
	draw_rect(Rect2(0, 206, W, 1), Color(NEXO_GOLD, 0.5))

# --- Reescribir: los fragmentos giran hacia el jugador y estalla su poder ----
func _decision_rewrite() -> void:
	_bands(["0a0204", "1c0608", "2c0a10", "40101a", "561a24"])
	var spin := _ease(_ph(0.8, 3.8))
	var burst := _ph(3.8, 4.6)
	# Rayos violeta y rojos que giran detrás de la figura.
	for k in 16:
		var a := _t * 0.2 + TAU * k / 16.0
		draw_line(Vector2(213, 130), Vector2(213, 130) + Vector2.from_angle(a) * 300.0, Color(VIOLET if k % 2 else Color("ff3a2a"), 0.07 + 0.08 * burst), 6.0)
	if burst < 1.0:
		for i in 5:
			var mid := -PI * 0.5 + TAU * (i + 0.5) / 5.0 + spin * TAU * 1.5
			var d := 58.0 * (1.0 - spin)
			_shard(i, Vector2.from_angle(mid) * d, spin * 6.0, 1.0 - burst)
	_clock_hands(8.0 if spin >= 1.0 else 2.0, 0.35 + 0.4 * burst, Color("ffb090"))
	# Aura de poder tras el jugador.
	var aura := _ease(_ph(3.6, 5.2))
	for k in 5:
		draw_circle(Vector2(213, 150), (46.0 + k * 22.0) * aura, Color(Color("ff5a3a").lerp(VIOLET, k / 4.0), 0.07))
	draw_arc(Vector2(213, 150), 70.0 * aura, 0, TAU, 56, Color(NEXO_GOLD, 0.6 * aura), 3.0)
	if _t >= 3.8 and _t < 4.4:
		draw_rect(Rect2(0, 0, W, H), Color(1, 0.8, 0.6, 0.6 * (1.0 - (_t - 3.8) / 0.6)))
	for i in 50:
		var p := fposmod(_t * (0.2 + _h(i) * 0.3) + _h(i + 3.0), 1.0)
		draw_rect(Rect2(10.0 + _h(i + 1.0) * (W - 20.0), 206.0 - p * 200.0, 2, 2), Color(Color("ff7050"), 0.8 * (1.0 - p)))
	draw_rect(Rect2(0, 206, W, 34), Color(0.05, 0.01, 0.02))
	draw_rect(Rect2(0, 206, W, 1), Color(Color("ff5a3a"), 0.7))

# --- Liberar: los fragmentos se disuelven en luz y el tiempo fluye solo ------
func _decision_free() -> void:
	var dawn := _ease(_ph(1.0, 6.0))
	var top := Color("0a1830").lerp(Color("6aa8d8"), dawn)
	var bottom := Color("1e4a80").lerp(Color("d8f0ff"), dawn)
	for i in 8:
		draw_rect(Rect2(0, i * 25.0, W, 26.0), top.lerp(bottom, i / 7.0))
	var scatter := _ease(_ph(0.6, 4.0))
	if scatter < 1.0:
		for i in 5:
			var mid := -PI * 0.5 + TAU * (i + 0.5) / 5.0
			_shard(i, Vector2.from_angle(mid) * (6.0 + 110.0 * scatter), scatter * 1.2, 1.0 - scatter)
	# Los fragmentos se vuelven luciérnagas que vagan libres.
	for i in 90:
		var born := _h(i) * 1.6
		var life := _ph(0.6 + born, 2.4 + born)
		var ang := _h(i + 1.0) * TAU
		var dist := 12.0 + life * (40.0 + _h(i + 2.0) * 140.0)
		var pos := CLOCK_C + Vector2.from_angle(ang + sin(_t * 0.6 + i) * 0.3) * dist + Vector2(0, sin(_t + i) * 4.0)
		var col: Color = SHARD_COLORS[i % 5].lerp(Color.WHITE, 0.5)
		draw_rect(Rect2(pos, Vector2(2, 2)), Color(col, life * (0.5 + 0.5 * sin(_t * 3.0 + i))))
	# Una esfera suave de luz sustituye al reloj: nadie controla el tiempo.
	var orb := _ease(_ph(2.4, 5.0))
	for k in 5:
		draw_circle(CLOCK_C, (22.0 + k * 16.0) * orb, Color(1, 1, 1, 0.07))
	draw_circle(CLOCK_C, 14.0 * orb, Color(1, 1, 1, 0.85))
	# Un río de luz fluye por el suelo.
	draw_rect(Rect2(0, 206, W, 34), Color("0e2a4a"))
	for i in 24:
		var x := fposmod(i * 19.0 - _t * 40.0, W + 20.0) - 10.0
		draw_rect(Rect2(x, 212.0 + (i % 3) * 8.0, 14.0, 1), Color(0.7, 0.9, 1.0, 0.5))
	draw_rect(Rect2(0, 206, W, 1), Color(0.8, 0.95, 1.0, 0.6))

func _draw_lesson() -> void:
	var info: Dictionary = ENDINGS[_ending]
	var col: Color = info["color"]
	var a := _ph(0.2, 1.4)
	draw_rect(Rect2(0, 0, W, H), Color(0.02, 0.01, 0.04, 0.92))
	for i in 40:
		var p := fposmod(_t * (0.1 + _h(i) * 0.15) + _h(i + 3.0), 1.0)
		draw_rect(Rect2(10.0 + _h(i + 1.0) * (W - 20.0), H - p * H, 2, 2), Color(col, 0.5 * (1.0 - p) * a))
	var tw := HKTheme.text_width("LECCIÓN DEL TIEMPO", 16) + 30.0
	draw_rect(Rect2(W * 0.5 - tw * 0.5, 66, tw, 1), Color(col, a))
	draw_rect(Rect2(W * 0.5 - tw * 0.5, 104, tw, 1), Color(col, a))
	HKTheme.draw_text(self, Vector2(0, 94), "LECCIÓN DEL TIEMPO", 16, Color(col, a), HORIZONTAL_ALIGNMENT_CENTER, W, 3)
	var lines: Array = info["lesson"]
	for i in lines.size():
		HKTheme.draw_text(self, Vector2(0, 132 + i * 14), lines[i], 8, Color(HKTheme.PAPER, _ph(0.8 + i * 0.5, 1.8 + i * 0.5)), HORIZONTAL_ALIGNMENT_CENTER, W, 2)

func _draw_epilogue() -> void:
	var d := Game.p1_data()
	var info: Dictionary = ENDINGS[_ending]
	# El título ocupa todo el ancho; el texto del luchador va a la derecha de su figura.
	HKTheme.draw_text(self, Vector2(0, 34), info["title"], 16, info["color"], HORIZONTAL_ALIGNMENT_CENTER, W, 3)
	var x := 186.0
	var w := 236.0
	HKTheme.draw_text(self, Vector2(x, 60), d.display_name.to_upper(), 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, w, 2)
	HKTheme.draw_text(self, Vector2(x, 72), d.era, 8, HKTheme.MUTED.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, w, 1)
	var lines := epilogue_lines(d, _ending)
	for i in lines.size():
		HKTheme.draw_text(self, Vector2(x, 108 + i * 12), lines[i], 8, Color("e8d8b8"), HORIZONTAL_ALIGNMENT_CENTER, w, 1)

## Texto de despedida del luchador según la decisión (&"repair", &"rewrite" o &"free"):
## lo que aprendió o lo que le costó.
static func epilogue_lines(d: FighterData, ending: StringName) -> PackedStringArray:
	if ending == &"free":
		return PackedStringArray(["%s SUELTA EL PODER" % d.short_name.to_upper(), "Y VUELVE A SU ÉPOCA.", "EL TIEMPO ES DE TODOS:", "APRENDER ES COMPARTIR."])
	if EPILOGUES.has(d.id):
		return PackedStringArray((EPILOGUES[d.id][0 if ending == &"repair" else 1] as String).split("\n"))
	if ending == &"repair":
		return PackedStringArray(["%s REGRESA A SU ÉPOCA" % d.short_name.to_upper(), "(%s) Y EL MUNDO" % d.era.to_upper(), "RECUERDA SUS ERRORES", "Y APRENDE DE ELLOS."])
	return PackedStringArray(["%s TOMA EL NEXO" % d.short_name.to_upper(), "Y REESCRIBE LA HISTORIA,", "PERO PRONTO REPITE", "LO QUE QUISO CORREGIR."])
