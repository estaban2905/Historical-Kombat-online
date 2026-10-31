## Autoload "Backend": cuenta del jugador y comunicación con Supabase.
##   - Registro, inicio y cierre de sesión (Supabase Auth, por HTTP).
##   - Sesión recordada entre ejecuciones (solo el refresh token, en user://).
##   - Perfil del jugador (nombre, puntos, victorias, derrotas).
## Si no hay servidor configurado el juego funciona igual, sin cuentas.
##
## Configuración: backend_config.gd, o un archivo user://backend.cfg con
##   [supabase]
##   url="https://xxxx.supabase.co"
##   anon_key="..."
## Nunca pongas aquí la clave service_role: este código la expondría a todos.
extends Node

signal session_changed

## Archivo de la sesión guardada (las pruebas usan otro para no pisar el real).
var session_path: String = "user://session.cfg"
const CONFIG_PATH := "user://backend.cfg"
const Config := preload("res://scripts/autoload/backend_config.gd")
const REQUEST_TIMEOUT := 10.0

var url: String = ""
var anon_key: String = ""

var access_token: String = ""
var refresh_token: String = ""
var user_id: String = ""
var email: String = ""
## Fila de la tabla players del usuario: username, points, wins, losses.
var profile: Dictionary = {}
## true si el jugador eligió jugar sin cuenta en esta ejecución.
var guest: bool = false

func _ready() -> void:
	configure(Config.SUPABASE_URL, Config.SUPABASE_ANON_KEY)
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		configure(cfg.get_value("supabase", "url", url), cfg.get_value("supabase", "anon_key", anon_key))

func configure(p_url: String, p_anon_key: String) -> void:
	url = p_url.strip_edges().trim_suffix("/")
	anon_key = p_anon_key.strip_edges()

func is_configured() -> bool:
	return url != "" and anon_key != ""

func is_logged_in() -> bool:
	return access_token != ""

func username() -> String:
	return str(profile.get("username", email.get_slice("@", 0)))

func has_saved_session() -> bool:
	return load_saved_refresh_token() != ""

# =========================================================================
#  Cuenta
# =========================================================================
## Devuelve {ok: bool, error: String, needs_confirmation: bool}.
func sign_up(p_email: String, password: String, p_username: String) -> Dictionary:
	var r := await _request("POST", "/auth/v1/signup", {
		"email": p_email, "password": password, "data": {"username": p_username}}, false)
	if not r.ok:
		return {"ok": false, "error": _auth_error(r)}
	if r.data is Dictionary and r.data.has("access_token"):
		await _start_session(r.data)
		return {"ok": true, "needs_confirmation": false}
	# Con la confirmación por email activada, no hay sesión hasta confirmarla.
	return {"ok": true, "needs_confirmation": true}

## Devuelve {ok: bool, error: String}.
func sign_in(p_email: String, password: String) -> Dictionary:
	var r := await _request("POST", "/auth/v1/token?grant_type=password",
		{"email": p_email, "password": password}, false)
	if not r.ok:
		return {"ok": false, "error": _auth_error(r)}
	await _start_session(r.data)
	return {"ok": true}

## Recupera la sesión guardada. Devuelve {ok: bool, error: String}.
func restore_session() -> Dictionary:
	var token := load_saved_refresh_token()
	if token == "":
		return {"ok": false, "error": ""}
	var r := await _refresh(token)
	if not r.ok:
		# Un rechazo del servidor invalida el token; un fallo de red lo conserva.
		if r.code >= 400 and r.code < 500:
			_forget_session()
		return {"ok": false, "error": _auth_error(r)}
	return {"ok": true}

func sign_out() -> void:
	if is_logged_in() and is_configured():
		await _request("POST", "/auth/v1/logout", null, true)
	_clear_state()
	_forget_session()
	session_changed.emit()

## Vuelve a leer el perfil (puntos, victorias...). Devuelve true si lo logró.
func fetch_profile() -> bool:
	if not is_logged_in():
		return false
	var r := await _request("GET", "/rest/v1/players?id=eq.%s&select=username,points,wins,losses" % user_id, null, true)
	if r.ok and r.data is Array and not r.data.is_empty():
		profile = r.data[0]
		session_changed.emit()
		return true
	return false

# =========================================================================
#  Sesión
# =========================================================================
func _start_session(data: Dictionary) -> void:
	_apply_tokens(data)
	user_id = str(data.get("user", {}).get("id", user_id))
	email = str(data.get("user", {}).get("email", email))
	await fetch_profile()
	session_changed.emit()

func _apply_tokens(data: Dictionary) -> void:
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	var cfg := ConfigFile.new()
	cfg.set_value("session", "refresh_token", refresh_token)
	cfg.save(session_path)

func _refresh(token: String) -> Dictionary:
	var r := await _request("POST", "/auth/v1/token?grant_type=refresh_token", {"refresh_token": token}, false)
	if r.ok:
		await _start_session(r.data)
	return r

func load_saved_refresh_token() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(session_path) != OK:
		return ""
	return str(cfg.get_value("session", "refresh_token", ""))

func _forget_session() -> void:
	if FileAccess.file_exists(session_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(session_path))

func _clear_state() -> void:
	access_token = ""
	refresh_token = ""
	user_id = ""
	email = ""
	profile = {}

# =========================================================================
#  HTTP
# =========================================================================
## Devuelve {ok: bool, code: int, data: Variant}. code 0 = sin conexión.
## Si el servidor responde 401 a una petición con sesión, renueva el token
## una vez y reintenta.
func _request(method: String, path: String, body: Variant, use_token: bool, retry: bool = true) -> Dictionary:
	if not is_configured():
		return {"ok": false, "code": 0, "data": {"msg": "not_configured"}}
	var headers := PackedStringArray(["apikey: " + anon_key, "Content-Type: application/json"])
	headers.append("Authorization: Bearer " + (access_token if use_token and access_token != "" else anon_key))
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	add_child(http)
	var verb := HTTPClient.METHOD_GET
	match method:
		"POST": verb = HTTPClient.METHOD_POST
		"PATCH": verb = HTTPClient.METHOD_PATCH
		"DELETE": verb = HTTPClient.METHOD_DELETE
	var err := http.request(url + path, headers, verb, "" if body == null else JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": 0, "data": {}}
	var res: Array = await http.request_completed
	http.queue_free()
	var code: int = res[1] if res[0] == HTTPRequest.RESULT_SUCCESS else 0
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else {}
	if code == 401 and use_token and retry and refresh_token != "":
		var rr := await _refresh(refresh_token)
		if rr.ok:
			return await _request(method, path, body, true, false)
	return {"ok": code >= 200 and code < 300, "code": code, "data": data if data != null else {}}

## Mensaje en español para un error de Supabase Auth.
func _auth_error(r: Dictionary) -> String:
	if r.code == 0:
		return "SIN CONEXIÓN CON EL SERVIDOR"
	var d: Dictionary = r.data if r.data is Dictionary else {}
	var kind := str(d.get("error_code", d.get("error", "")))
	var msg := str(d.get("msg", d.get("message", d.get("error_description", ""))))
	match kind:
		"invalid_credentials": return "EMAIL O CONTRASEÑA INCORRECTOS"
		"user_already_exists", "email_exists": return "ESE EMAIL YA ESTÁ REGISTRADO"
		"weak_password": return "CONTRASEÑA DEMASIADO DÉBIL (MÍN. 6)"
		"email_not_confirmed": return "CONFIRMA TU EMAIL ANTES DE ENTRAR"
		"validation_failed", "email_address_invalid": return "EMAIL NO VÁLIDO"
		"over_request_rate_limit", "over_email_send_rate_limit": return "DEMASIADOS INTENTOS, ESPERA UN POCO"
	# El trigger de la base de datos rechaza nombres inválidos o repetidos.
	if "Database error" in msg:
		return "NOMBRE DE USUARIO NO VÁLIDO O YA EN USO"
	return "ERROR DEL SERVIDOR (%d)" % r.code

## Valida los datos del formulario antes de enviarlos. "" = correcto.
static func validate_credentials(p_email: String, password: String, p_username: String = "", registering: bool = false) -> String:
	if p_email.count("@") != 1 or "." not in p_email.get_slice("@", 1) or p_email.length() < 6:
		return "EMAIL NO VÁLIDO"
	if password.length() < 6:
		return "CONTRASEÑA: MÍNIMO 6 CARACTERES"
	if registering:
		var rx := RegEx.create_from_string("^[A-Za-z0-9_]{3,16}$")
		if rx.search(p_username) == null:
			return "NOMBRE: 3-16 LETRAS, NÚMEROS O _"
	return ""
