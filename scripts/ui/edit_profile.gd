## Editar perfil: avatar, marco y título (los que se han desbloqueado), nombre (una vez cada 7 días) y
## contraseña (no en cuentas de Google). Marco y título se cambian con izquierda/derecha y se guardan al
## momento; cada bloque avisa del resultado arriba. ESC o VOLVER regresa al perfil.
extends Control

const FORM_WIDTH := 260.0

var _form: VBoxContainer
var _status: Label
var _frame_btn: Button
var _title_btn: Button
var _name: LineEdit
var _save_name: Button
var _current: LineEdit
var _new_pass: LineEdit
var _save_pass: Button
var _avatar_btn: Button
var _back: Button
var _busy: bool = false
## Lo que se puede elegir: "" (ninguno) y después lo desbloqueado. El índice es el que lleva puesto.
var _frames: Array[String] = [""]
var _titles: Array[String] = [""]
var _frame_i: int = 0
var _title_i: int = 0

func _ready() -> void:
	theme = HKTheme.theme()
	if not Backend.is_logged_in():
		Game.goto.call_deferred(Game.SCENE_MENU)
		return
	_frames.append_array(Cosmetics.owned_frames())
	_titles.append_array(Cosmetics.owned_titles())
	_frame_i = maxi(_frames.find(Backend.frame()), 0)
	_title_i = maxi(_titles.find(Backend.title()), 0)

	_form = VBoxContainer.new()
	_form.position = Vector2((426 - FORM_WIDTH) / 2.0, 36)
	_form.custom_minimum_size = Vector2(FORM_WIDTH, 0)
	_form.add_theme_constant_override("separation", 2)
	add_child(_form)

	# Dos líneas con ajuste de texto: un mensaje largo no debe ensanchar el formulario.
	_status = Label.new()
	_status.custom_minimum_size = Vector2(FORM_WIDTH, 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", HKTheme.GOLD)
	_form.add_child(_status)

	_avatar_btn = _button("CAMBIAR AVATAR")
	_frame_btn = _button("")
	_title_btn = _button("")
	_name = _field("NOMBRE DE JUGADOR", 16)
	_name.text = Backend.username()
	_save_name = _button("GUARDAR NOMBRE")
	var buttons: Array[Button] = [_avatar_btn, _frame_btn, _title_btn, _save_name]
	if not Backend.is_google_account():
		_current = _field("CONTRASEÑA ACTUAL", 128)
		_current.secret = true
		_new_pass = _field("CONTRASEÑA NUEVA", 128)
		_new_pass.secret = true
		_save_pass = _button("CAMBIAR CONTRASEÑA")
		buttons.append(_save_pass)
		_save_pass.pressed.connect(_on_save_password)
		_new_pass.text_submitted.connect(func(_t: String): _on_save_password())
	_back = _button("VOLVER")
	buttons.append(_back)
	_avatar_btn.pressed.connect(func(): Game.goto(Game.SCENE_AVATAR))
	_frame_btn.gui_input.connect(_on_cosmetic_input.bind(_frame_btn, "frame"))
	_title_btn.gui_input.connect(_on_cosmetic_input.bind(_title_btn, "title"))
	_frame_btn.pressed.connect(_cycle.bind("frame", 1))
	_title_btn.pressed.connect(_cycle.bind("title", 1))
	_save_name.pressed.connect(_on_save_name)
	_name.text_submitted.connect(func(_t: String): _on_save_name())
	_back.pressed.connect(func(): Game.goto(Game.SCENE_PROFILE))
	for b in buttons:
		b.focus_entered.connect(func(): Sfx.play(&"select"))
		b.pressed.connect(func(): Sfx.play(&"confirm"))
	_refresh_cosmetics()
	_avatar_btn.grab_focus()

func _field(placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(FORM_WIDTH, 15)
	e.max_length = max_len
	_form.add_child(e)
	return e

func _button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(FORM_WIDTH, 16)
	_form.add_child(b)
	return b

## "MARCO < DORADO >" y "TITULO < GUARDIAN DEL TIEMPO >": lo que lleva puesto, y NINGUNO si nada.
func _refresh_cosmetics() -> void:
	var frame := Cosmetics.frame_name(_frames[_frame_i]) if _frames[_frame_i] != "" else "NINGUNO"
	var title := Cosmetics.title_name(_titles[_title_i]) if _titles[_title_i] != "" else "NINGUNO"
	_frame_btn.text = HKTheme.fold("MARCO  < %s >" % frame)
	_title_btn.text = HKTheme.fold("TITULO  < %s >" % title)
	# Sin nada que elegir el botón no hace nada: se ve apagado.
	_frame_btn.modulate = Color.WHITE if _frames.size() > 1 else Color(1, 1, 1, 0.5)
	_title_btn.modulate = Color.WHITE if _titles.size() > 1 else Color(1, 1, 1, 0.5)

func _on_cosmetic_input(event: InputEvent, button: Button, which: String) -> void:
	var step := 0
	if event.is_action_pressed(&"ui_left"):
		step = -1
	elif event.is_action_pressed(&"ui_right"):
		step = 1
	if step != 0:
		_cycle(which, step)
		button.accept_event()

## Pasa al siguiente (o anterior) cosmético desbloqueado y lo guarda en la cuenta; si falla, vuelve al anterior.
func _cycle(which: String, step: int) -> void:
	if _busy:
		return
	var options := _frames if which == "frame" else _titles
	if options.size() <= 1:
		_status.text = "TODAVÍA NO TIENES %s: VE UN FINAL DEL MODO HISTORIA" % ("MARCOS" if which == "frame" else "TÍTULOS")
		Sfx.play(&"denied")
		return
	var previous := _frame_i if which == "frame" else _title_i
	var next := posmod(previous + step, options.size())
	if which == "frame":
		_frame_i = next
	else:
		_title_i = next
	_refresh_cosmetics()
	_set_busy(true, "GUARDANDO...")
	var r := await Backend.set_cosmetics({which: options[next]})
	if not r.ok:
		if which == "frame":
			_frame_i = previous
		else:
			_title_i = previous
		_refresh_cosmetics()
		_fail(r.error)
		return
	_set_busy(false, "")

func _set_busy(busy: bool, message: String = "") -> void:
	_busy = busy
	_status.text = message
	for c in [_name, _current, _new_pass]:
		if c:
			c.editable = not busy
	for b in [_avatar_btn, _save_name, _save_pass, _back]:
		if b:
			b.disabled = busy

func _fail(message: String) -> void:
	_set_busy(false, message)
	Sfx.play(&"denied")

func _on_save_name() -> void:
	if _busy:
		return
	var chosen := _name.text.strip_edges()
	var bad := Backend.validate_username(chosen)
	if bad != "":
		_fail(bad)
		return
	if chosen == Backend.username():
		_status.text = "ESE YA ES TU NOMBRE"
		return
	_set_busy(true, "GUARDANDO...")
	var r := await Backend.set_username(chosen)
	if not r.ok:
		_fail(r.error)
		return
	_set_busy(false, "NOMBRE CAMBIADO")
	Sfx.play(&"confirm")

func _on_save_password() -> void:
	if _busy:
		return
	if _current.text == "":
		_fail("ESCRIBE TU CONTRASEÑA ACTUAL")
		return
	if _new_pass.text.length() < 6:
		_fail("CONTRASEÑA: MÍNIMO 6 CARACTERES")
		return
	_set_busy(true, "GUARDANDO...")
	var r := await Backend.change_password(_current.text, _new_pass.text)
	if not r.ok:
		_fail(r.error)
		return
	_current.text = ""
	_new_pass.text = ""
	_set_busy(false, "CONTRASEÑA CAMBIADA")
	Sfx.play(&"confirm")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Game.goto(Game.SCENE_PROFILE)
		get_viewport().set_input_as_handled()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 426, 240), HKTheme.INK)
	HKTheme.draw_text(self, Vector2(0, 24), "EDITAR PERFIL", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
