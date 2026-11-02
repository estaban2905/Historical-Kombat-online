## Pantalla de inicio de sesión / registro. Es la escena principal del juego.
##   - Sin servidor, o con un servidor sin cuentas: pasa directo al menú (el juego funciona offline).
##   - Con una sesión guardada: la recupera y pasa al menú.
##   - Si no: formulario de ENTRAR / CREAR CUENTA, CONTINUAR CON GOOGLE (solo en la web),
##     o JUGAR SIN CUENTA.
extends Control

const FORM_WIDTH := 240.0

var _registering: bool = false
var _busy: bool = false
## ID token de Google a la espera de que el jugador (nuevo) elija su nombre. "" = no hay.
var _google_cred: String = ""
## Hueco del formulario sobre el que se coloca el botón HTML de Google (null si no hay Google).
var _google_slot: Control
var _google_shown: bool = false
var _google_rect: Rect2

var _form: VBoxContainer
var _status: Label
var _email: LineEdit
var _password: LineEdit
var _username: LineEdit
var _submit: Button
var _toggle: Button
var _guest: Button

func _ready() -> void:
	theme = HKTheme.theme()
	get_tree().paused = false
	if Backend.is_logged_in() or Backend.guest:
		_go_menu.call_deferred()
		return
	_build_form()
	_set_busy(true, "CONECTANDO...")
	if not await Backend.check_available():
		# Sin servidor (o sin cuentas) se juega igual: arcade, versus y entrenamiento no lo necesitan.
		_go_menu()
		return
	if Backend.has_saved_session():
		var r := await Backend.restore_session()
		if r.ok:
			_go_menu()
			return
		_set_busy(false, r.error)
	else:
		_set_busy(false)
	_email.grab_focus()

func _go_menu() -> void:
	Game.goto(Game.SCENE_MENU)

func _exit_tree() -> void:
	if _google_shown:
		GoogleSignIn.hide()

## Coloca el botón de Google sobre su hueco (solo mientras el formulario está libre)
## y recoge el ID token cuando el jugador elige cuenta.
func _process(_delta: float) -> void:
	if _google_slot == null:
		return
	if _busy or _google_cred != "":
		if _google_shown:
			GoogleSignIn.hide()
			_google_shown = false
		return
	var rect := _google_slot.get_global_rect()
	if not _google_shown or rect != _google_rect:
		GoogleSignIn.show(rect)
		_google_shown = true
		_google_rect = rect
	var cred := GoogleSignIn.take_credential()
	if cred != "":
		_on_google(cred)

func _build_form() -> void:
	_form = VBoxContainer.new()
	_form.position = Vector2((426 - FORM_WIDTH) / 2.0, 88)
	_form.custom_minimum_size = Vector2(FORM_WIDTH, 0)
	_form.add_theme_constant_override("separation", 4)
	add_child(_form)

	# Dos líneas con ajuste de texto: un mensaje largo no debe ensanchar el formulario.
	_status = Label.new()
	_status.custom_minimum_size = Vector2(FORM_WIDTH, 20)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", HKTheme.GOLD)
	_form.add_child(_status)

	_email = _field("EMAIL")
	_username = _field("NOMBRE DE JUGADOR")
	_password = _field("CONTRASEÑA")
	_password.secret = true

	_submit = _button("ENTRAR")
	_toggle = _button("CREAR CUENTA NUEVA")
	if GoogleSignIn.available():
		_google_slot = Control.new()
		_google_slot.custom_minimum_size = Vector2(FORM_WIDTH, 20)
		_form.add_child(_google_slot)
	_guest = _button("JUGAR SIN CUENTA")
	_submit.pressed.connect(_on_submit)
	_toggle.pressed.connect(_on_toggle)
	_guest.pressed.connect(_on_guest)
	for f in [_email, _username, _password]:
		f.text_submitted.connect(func(_t: String): _on_submit())
	for b in [_submit, _toggle, _guest]:
		b.focus_entered.connect(func(): Sfx.play(&"select"))
		b.pressed.connect(func(): Sfx.play(&"confirm"))
	_set_registering(false)

func _field(placeholder: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.custom_minimum_size = Vector2(FORM_WIDTH, 15)
	e.max_length = 64
	_form.add_child(e)
	return e

func _button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(FORM_WIDTH, 16)
	_form.add_child(b)
	return b

func _set_registering(value: bool) -> void:
	_registering = value
	_google_cred = ""
	_email.visible = true
	_password.visible = true
	_username.visible = value
	_submit.text = "CREAR CUENTA" if value else "ENTRAR"
	_toggle.text = "YA TENGO CUENTA" if value else "CREAR CUENTA NUEVA"
	_status.text = ""

func _set_busy(busy: bool, message: String = "") -> void:
	_busy = busy
	_status.text = message
	for c in [_email, _username, _password]:
		c.editable = not busy
	for b in [_submit, _toggle, _guest]:
		b.disabled = busy
	if _form:
		_form.visible = true

func _on_toggle() -> void:
	if _busy:
		return
	# Con un token de Google pendiente, este botón cancela y vuelve al formulario normal.
	_set_registering(false if _google_cred != "" else not _registering)

## El jugador eligió su cuenta de Google. Si ya existe, entra; si es nueva, pide un nombre.
func _on_google(cred: String) -> void:
	_google_cred = cred
	await _finish_google("")

func _finish_google(player_name: String) -> void:
	_set_busy(true, "CONECTANDO...")
	var r := await Backend.sign_in_google(_google_cred, player_name)
	if r.ok:
		_go_menu()
		return
	if r.need_username or (player_name != "" and r.error == "ESE NOMBRE YA ESTÁ EN USO"):
		_ask_google_username(r.error)
		return
	_set_registering(false)
	_set_busy(false, r.error)
	Sfx.play(&"denied")

## Cuenta de Google nueva: solo falta elegir el nombre de jugador (el email lo da Google).
func _ask_google_username(message: String) -> void:
	_email.visible = false
	_password.visible = false
	_username.visible = true
	_submit.text = "CONTINUAR"
	_toggle.text = "CANCELAR"
	_set_busy(false, message if message != "" else "ELIGE TU NOMBRE DE JUGADOR")
	_username.grab_focus()

func _on_submit() -> void:
	if _busy:
		return
	if _google_cred != "":
		var chosen := _username.text.strip_edges()
		var bad := Backend.validate_username(chosen)
		if bad != "":
			_status.text = bad
			Sfx.play(&"denied")
			return
		await _finish_google(chosen)
		return
	var email := _email.text.strip_edges()
	var name := _username.text.strip_edges()
	var problem := Backend.validate_credentials(email, _password.text, name, _registering)
	if problem != "":
		_status.text = problem
		Sfx.play(&"denied")
		return
	_set_busy(true, "CONECTANDO...")
	var r: Dictionary
	if _registering:
		r = await Backend.sign_up(email, _password.text, name)
	else:
		r = await Backend.sign_in(email, _password.text)
	if not r.ok:
		_set_busy(false, r.error)
		Sfx.play(&"denied")
		return
	_go_menu()

func _on_guest() -> void:
	Backend.guest = true
	_go_menu()
