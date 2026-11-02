## FINAL del MODO HISTORIA: el Nexo ofrece su poder al último en pie y el jugador decide
## si repara el tiempo o lo reescribe. Después se muestra el epílogo de su luchador.
##   0  el Nexo habla       ENTER avanza
##   1  la elección         REPARAR EL TIEMPO / REESCRIBIRLO
##   2  el epílogo          VER CRÉDITOS
extends Control

const W := 426.0
const NEXO_LINES: Array = [
	["ME HAS VENCIDO. TODAS LAS ÉPOCAS", "CAYERON ANTE TI Y AHORA ESPERAN."],
	["EL PODER DEL NEXO ES TUYO.", "¿QUÉ HARÁS CON EL TIEMPO?"],
]
## Epílogos propios: id -> [reparar, reescribir]. El resto usa una plantilla.
const EPILOGUES := {
	&"napoleon": ["VUELVE A SU CAMPAÑA Y ESTA VEZ\nSABE DÓNDE DETENERSE.", "CORONA UN IMPERIO QUE\nNINGÚN INVIERNO PUEDE ROMPER."],
	&"julio_cesar": ["CRUZA EL RUBICÓN POR ÚLTIMA VEZ\nY ESQUIVA LOS IDUS DE MARZO.", "ROMA NUNCA CAE: EL TIEMPO\nSE LLAMA CÉSAR."],
	&"cleopatra": ["REGRESA AL NILO Y GOBIERNA\nSIN QUE NADIE LA ENGAÑE.", "EGIPTO DURA PARA SIEMPRE\nBAJO SU ÁSPID DORADO."],
	&"lautaro": ["VUELVE A LA ARAUCANÍA\nCON LA VICTORIA ASEGURADA.", "LA TIERRA NO CONOCE\nOTRO TOQUI QUE ÉL."],
	&"arturo_prat": ["PISA LA ESMERALDA Y SU\nSACRIFICIO NO SE OLVIDA.", "EL ABORDAJE SE REPITE Y\nESTA VEZ EL MAR ES SUYO."],
	&"albert_einstein": ["APAGA EL RELOJ Y LE PIDE\nPERDÓN AL TIEMPO.", "ESCRIBE UNA ECUACIÓN\nNUEVA: LA DEL UNIVERSO."],
	&"nikola_tesla": ["DESMONTA LA MÁQUINA Y LA\nENERGÍA LLEGA A TODOS.", "EL MUNDO SE ENCIENDE\nCON SU CORRIENTE."],
	&"marie_curie": ["CIERRA LA GRIETA CON SU\nPROPIA LUZ.", "SU RADIACIÓN ILUMINA\nCADA ÉPOCA."],
	&"leonardo_da_vinci": ["GUARDA LOS PLANOS DEL RELOJ\nPARA QUE NADIE LOS USE.", "DISEÑA EL TIEMPO COMO\nSU OBRA MAESTRA."],
	&"alejandro_magno": ["REGRESA A BABILONIA Y\nVIVE MÁS DE 32 AÑOS.", "SU IMPERIO NO TIENE\nLÍMITE NI FIN."],
	&"jesus_de_nazaret": ["DEVUELVE A CADA UNO A SU\nLUGAR Y PERDONA.", "NO REESCRIBE NADA:\nLO REDIME TODO."],
}

var _step: int = 0
var _t: float = 0.0
var _fighter: FighterRenderer
var _repair: bool = true
var _btn_a: Button
var _btn_b: Button

func _ready() -> void:
	theme = HKTheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Control.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	bg.show_title = false
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)
	_btn_a = _button("CONTINUAR", Vector2(158, 214), Vector2(110, 16))
	_btn_a.pressed.connect(_next)
	_btn_b = _button("", Vector2(244, 196), Vector2(150, 16))
	_btn_a.grab_focus()
	_show_buttons()

func _button(text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = size
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	add_child(b)
	return b

func _next() -> void:
	Sfx.play(&"confirm")
	_step += 1
	_t = 0.0
	_show_buttons()

func _choose(repair: bool) -> void:
	Sfx.play(&"fight")
	_repair = repair
	_step = 2
	_t = 0.0
	_fighter = FighterRenderer.new()
	add_child(_fighter)
	move_child(_fighter, 1)
	var d := Game.p1_data()
	_fighter.setup(d)
	_fighter.pose_name = &"victory"
	var s := clampf(110.0 / maxf(_fighter.approx_height(), 1.0), 0.8, 1.6)
	_fighter.scale = Vector2(s, s)
	_fighter.position = Vector2(100, 206)
	_show_buttons()

func _show_buttons() -> void:
	for c in _btn_a.pressed.get_connections():
		_btn_a.pressed.disconnect(c.callable)
	for c in _btn_b.pressed.get_connections():
		_btn_b.pressed.disconnect(c.callable)
	_btn_b.visible = false
	match _step:
		0:
			_btn_a.text = "CONTINUAR"
			_btn_a.position = Vector2(158, 214)
			_btn_a.pressed.connect(_next)
		1:
			_btn_a.text = "REPARAR EL TIEMPO"
			_btn_a.position = Vector2(60, 196)
			_btn_a.custom_minimum_size = Vector2(150, 16)
			_btn_a.pressed.connect(_choose.bind(true))
			_btn_b.text = "REESCRIBIRLO"
			_btn_b.position = Vector2(216, 196)
			_btn_b.visible = true
			_btn_b.pressed.connect(_choose.bind(false))
		_:
			_btn_a.text = "VER CRÉDITOS"
			_btn_a.position = Vector2(236, 214)
			_btn_a.custom_minimum_size = Vector2(110, 16)
			_btn_a.pressed.connect(func(): Game.goto(Game.SCENE_CREDITS))
	_btn_a.grab_focus()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, W, 240), Color(0.03, 0.02, 0.05, 0.7))
	match _step:
		0, 1:
			var lines: Array = NEXO_LINES[_step]
			var a := clampf(_t / 0.8, 0.0, 1.0)
			HKTheme.draw_text(self, Vector2(0, 56), "EL NEXO", 16, Color("ffd24a") * Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, W, 3)
			for i in lines.size():
				HKTheme.draw_text(self, Vector2(0, 100 + i * 14), lines[i], 8, HKTheme.PAPER * Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, W, 2)
			if _step == 1:
				HKTheme.draw_text(self, Vector2(0, 176), "TU DECISIÓN CAMBIARÁ TODAS LAS ÉPOCAS.", 8, HKTheme.MUTED.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER, W, 1)
		_:
			_draw_epilogue()

func _draw_epilogue() -> void:
	var d := Game.p1_data()
	var x0 := 236.0
	var w := 340.0
	var title := "EL TIEMPO SANA" if _repair else "LA HISTORIA REESCRITA"
	HKTheme.draw_text(self, Vector2(x0 - 28, 40), title, 16, Color("ffd24a") if _repair else Color("ff7050"), HORIZONTAL_ALIGNMENT_CENTER, 220, 3)
	HKTheme.draw_text(self, Vector2(x0 - 28, 60), d.display_name.to_upper(), 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, 220, 2)
	HKTheme.draw_text(self, Vector2(x0 - 28, 72), d.era, 8, HKTheme.MUTED.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, 220, 1)
	var lines := epilogue_lines(d, _repair)
	for i in lines.size():
		HKTheme.draw_text(self, Vector2(x0 - 28, 108 + i * 12), lines[i], 8, Color("e8d8b8"), HORIZONTAL_ALIGNMENT_CENTER, 220, 1)

## Texto de despedida del luchador según la decisión. Sirve también para los tests.
static func epilogue_lines(d: FighterData, repair: bool) -> PackedStringArray:
	if EPILOGUES.has(d.id):
		return PackedStringArray((EPILOGUES[d.id][0 if repair else 1] as String).split("\n"))
	if repair:
		return PackedStringArray(["%s REGRESA A SU ÉPOCA" % d.short_name.to_upper(), "(%s) Y EL MUNDO" % d.era.to_upper(), "RECUERDA SU NOMBRE."])
	return PackedStringArray(["%s TOMA EL NEXO" % d.short_name.to_upper(), "Y REESCRIBE LA HISTORIA", "A SU IMAGEN."])
