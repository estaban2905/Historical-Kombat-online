## Editar perfil: cambiar de avatar, de nombre (una vez cada 7 días) y de contraseña (no en cuentas de Google).
## Cada bloque tiene su botón y avisa del resultado arriba. ESC o VOLVER regresa al perfil.
extends Control

const FORM_WIDTH := 220.0

var _form: VBoxContainer
var _status: Label
var _name: LineEdit
var _save_name: Button
var _current: LineEdit
var _new_pass: LineEdit
var _save_pass: Button
var _avatar_btn: Button
var _back: Button
var _busy: bool = false

func _ready() -> void:
	theme = HKTheme.theme()
	if not Backend.is_logged_in():
		Game.goto.call_deferred(Game.SCENE_MENU)
		return
	_form = VBoxContainer.new()
	_form.position = Vector2((426 - FORM_WIDTH) / 2.0, 44)
	_form.custom_minimum_size = Vector2(FORM_WIDTH, 0)
	_form.add_theme_constant_override("separation", 3)
	add_child(_form)

	# Dos líneas con ajuste de texto: un mensaje largo no debe ensanchar el formulario.
	_status = Label.new()
	_status.custom_minimum_size = Vector2(FORM_WIDTH, 20)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", HKTheme.GOLD)
	_form.add_child(_status)

	_avatar_btn = _button("CAMBIAR AVATAR")
	_name = _field("NOMBRE DE JUGADOR", 16)
	_name.text = Backend.username()
	_save_name = _button("GUARDAR NOMBRE")
	var buttons: Array[Button] = [_avatar_btn, _save_name]
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
	_save_name.pressed.connect(_on_save_name)
	_name.text_submitted.connect(func(_t: String): _on_save_name())
	_back.pressed.connect(func(): Game.goto(Game.SCENE_PROFILE))
	for b in buttons:
		b.focus_entered.connect(func(): Sfx.play(&"select"))
		b.pressed.connect(func(): Sfx.play(&"confirm"))
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
	HKTheme.draw_text(self, Vector2(0, 28), "EDITAR PERFIL", 16, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426, 3)
