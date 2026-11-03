## Autoload "Backend": cuenta del jugador y comunicación con el servidor (server/).
##   - Registro, inicio y cierre de sesión (rutas /auth/* del servidor, por HTTP).
##   - Sesión recordada entre ejecuciones (solo el refresh token, en user://).
##   - Perfil del jugador (nombre, puntos, victorias, derrotas), ranking e historial.
##   - Partida guardada del modo Historia: en la cuenta (servidor) y copia local de respaldo.
## Si el servidor no está o no tiene cuentas, el juego funciona igual, sin cuentas.
##
## La dirección del servidor se resuelve en server_config.gd.
extends Node

signal session_changed

## Archivo de la sesión guardada (las pruebas usan otro para no pisar el real).
var session_path: String = "user://session.cfg"
## Copia local de la partida de Historia, una sección por cuenta ("guest" sin sesión).
var story_path: String = "user://story_save.cfg"
const REQUEST_TIMEOUT := 10.0
## Respuesta rápida: no se espera 10 s para saber que el servidor no está.
const HEALTH_TIMEOUT := 4.0
## Se renueva el token si le quedan menos de 60 s de vida.
const TOKEN_MARGIN_MSEC := 60_000

var access_token: String = ""
var refresh_token: String = ""
var user_id: String = ""
## Perfil del jugador: username, points, wins, losses.
var profile: Dictionary = {}
## true si el jugador eligió jugar sin cuenta en esta ejecución.
var guest: bool = false
## true si se comprobó que el servidor responde y tiene cuentas (check_available).
var available: bool = false

var _access_expires_msec: int = 0

## ¿Hay cuentas disponibles? Es false hasta que check_available() lo confirme.
func is_configured() -> bool:
	return available

func is_logged_in() -> bool:
	return access_token != ""

func username() -> String:
	return str(profile.get("username", ""))

## true si la cuenta entra con Google: no tiene contraseña que cambiar.
func is_google_account() -> bool:
	return bool(profile.get("google_account", false))

## Marco y título que lleva puestos ("" = ninguno).
func frame() -> String:
	var f: Variant = profile.get("frame")
	return str(f) if f != null else ""

func title() -> String:
	var t: Variant = profile.get("title")
	return str(t) if t != null else ""

## Id del luchador elegido como retrato ("" = ninguno).
func avatar() -> String:
	var a: Variant = profile.get("avatar")
	return str(a) if a != null else ""

func has_saved_session() -> bool:
	return load_saved_refresh_token() != ""

## Pregunta al servidor si está vivo y tiene base de datos (GET /health).
func check_available() -> bool:
	var r := await _request("GET", "/health", null, false, true, HEALTH_TIMEOUT)
	available = r.ok and r.data is Dictionary and r.data.get("db", false) == true
	return available

# =========================================================================
#  Cuenta
# =========================================================================
## Devuelve {ok: bool, error: String}.
func sign_up(p_email: String, password: String, p_username: String) -> Dictionary:
	var r := await _request("POST", "/auth/register",
		{"email": p_email, "password": password, "username": p_username}, false)
	if not r.ok:
		return {"ok": false, "error": _error_text(r)}
	_start_session(r.data)
	return {"ok": true}

## Devuelve {ok: bool, error: String}.
func sign_in(p_email: String, password: String) -> Dictionary:
	var r := await _request("POST", "/auth/login", {"email": p_email, "password": password}, false)
	if not r.ok:
		return {"ok": false, "error": _error_text(r)}
	_start_session(r.data)
	return {"ok": true}

## Entra con el ID token de Google. Si la cuenta es nueva hace falta p_username: sin él
## devuelve {ok: false, need_username: true} para que la pantalla lo pida y reintente.
## Devuelve {ok: bool, error: String, need_username: bool}.
func sign_in_google(id_token: String, p_username: String = "") -> Dictionary:
	var body := {"id_token": id_token}
	if p_username != "":
		body["username"] = p_username
	var r := await _request("POST", "/auth/google", body, false)
	if not r.ok:
		var need: bool = r.data is Dictionary and str(r.data.get("error", "")) == "username_required"
		return {"ok": false, "error": "" if need else _error_text(r), "need_username": need}
	_start_session(r.data)
	return {"ok": true, "error": "", "need_username": false}

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
		return {"ok": false, "error": _error_text(r)}
	return {"ok": true}

func sign_out() -> void:
	if is_logged_in():
		await _request("POST", "/auth/logout", null, true)
	_clear_state()
	_forget_session()
	session_changed.emit()

## Vuelve a leer el perfil (puntos, victorias...). Devuelve true si lo logró.
func fetch_profile() -> bool:
	if not is_logged_in():
		return false
	var r := await _request("GET", "/me", null, true)
	if r.ok and r.data is Dictionary:
		profile = r.data
		session_changed.emit()
		return true
	return false

## Elige el retrato de la cuenta ("" lo quita). Devuelve true si el servidor lo guardó.
func set_avatar(fighter_id: String) -> bool:
	if not is_logged_in():
		return false
	var r := await _request("PATCH", "/me", {"avatar": fighter_id if fighter_id != "" else null}, true)
	if r.ok and r.data is Dictionary:
		profile = r.data
		session_changed.emit()
		return true
	return false

## Pone o quita el marco y/o el título: {"frame": "frame_gold"} o {"title": ""} (vacío = quitar). Solo los
## desbloqueados. Devuelve {ok: bool, error: String}.
func set_cosmetics(change: Dictionary) -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "SESIÓN CADUCADA, ENTRA DE NUEVO"}
	var body := {}
	for k in ["frame", "title"]:
		if change.has(k):
			body[k] = change[k] if str(change[k]) != "" else null
	var r := await _request("PATCH", "/me", body, true)
	if not r.ok or not r.data is Dictionary:
		return {"ok": false, "error": _error_text(r)}
	profile = r.data
	session_changed.emit()
	return {"ok": true, "error": ""}

## Mis logros ([{key, progress, goal, done}]). null si falla (para no confundirlo con "ninguno").
func fetch_achievements() -> Variant:
	if not is_logged_in():
		return null
	var r := await _request("GET", "/me/achievements", null, true)
	return r.data if r.ok and r.data is Array else null

## Cambia mi nombre (una vez cada 7 días). Devuelve {ok: bool, error: String}.
func set_username(new_name: String) -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "SESIÓN CADUCADA, ENTRA DE NUEVO"}
	var r := await _request("PATCH", "/me", {"username": new_name}, true)
	if not r.ok or not r.data is Dictionary:
		return {"ok": false, "error": _error_text(r)}
	profile = r.data
	session_changed.emit()
	return {"ok": true, "error": ""}

## Cambia mi contraseña (pide la actual; cierra las sesiones de otros equipos). Devuelve {ok, error}.
func change_password(current: String, new_password: String) -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "error": "SESIÓN CADUCADA, ENTRA DE NUEVO"}
	var r := await _request("POST", "/me/password", {"current_password": current, "new_password": new_password}, true)
	return {"ok": r.ok, "error": "" if r.ok else _error_text(r)}

## Perfil público de un jugador por su nombre: {username, points, wins, losses, avatar, rank,
## favorite_fighter, streak, recent}. {} si no existe o no hay conexión.
func fetch_player(player_name: String) -> Dictionary:
	var r := await _request("GET", "/players/%s" % player_name.uri_encode(), null, false)
	return r.data if r.ok and r.data is Dictionary else {}

## Lo desbloqueado en la cuenta ([{kind, key}]). null si falla (para no confundir "sin conexión" con "nada").
func fetch_unlocks() -> Variant:
	if not is_logged_in():
		return null
	var r := await _request("GET", "/me/unlocks", null, true)
	return r.data if r.ok and r.data is Array else null

## Añade desbloqueos a la cuenta. true si el servidor los guardó. Si falla (sin red), quedan en el equipo
## y la próxima sync_unlocks los sube.
func push_unlocks(items: Array) -> bool:
	if not is_logged_in() or items.is_empty():
		return false
	var r := await _request("PUT", "/me/unlocks", {"items": items}, true)
	return r.ok

## Une los desbloqueos del equipo con los de la cuenta (solo se añade): lo que falte en cada lado se copia al otro.
## Lo ganado sin cuenta en este equipo se pasa antes a la cuenta.
func sync_unlocks() -> void:
	if not is_logged_in():
		return
	Unlocks.adopt_guest()
	var remote: Variant = await fetch_unlocks()
	if remote == null:
		return
	Unlocks.merge(remote)
	var known := {}
	for u in remote:
		known["%s:%s" % [str(u.get("kind", "")), str(u.get("key", ""))]] = true
	var missing := Unlocks.as_dicts().filter(func(u: Dictionary) -> bool: return not known.has("%s:%s" % [u["kind"], u["key"]]))
	await push_unlocks(missing)

## Amigos y solicitudes ([{username, avatar, points, status}], status: "friend", "incoming" o "outgoing").
## null si falla. Deja la lista en friends_cache para consultarla sin red (friend_status).
var friends_cache: Array = []

func fetch_friends() -> Variant:
	if not is_logged_in():
		return null
	var r := await _request("GET", "/me/friends", null, true)
	if not r.ok or not r.data is Array:
		return null
	friends_cache = r.data
	return r.data

## Cómo es mi relación con un jugador según la última lista descargada: "friend", "incoming" (me pidió
## amistad), "outgoing" (se la pedí yo) o "" (ninguna).
func friend_status(player_name: String) -> String:
	for f in friends_cache:
		if str(f.get("username", "")).to_lower() == player_name.to_lower():
			return str(f.get("status", ""))
	return ""

## Pide amistad; si esa persona ya me la había pedido, quedan como amigos.
## Devuelve {ok, result ("requested", "accepted", "already_friends", "already_requested"), error}.
func request_friend(player_name: String) -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "result": "", "error": "SESIÓN CADUCADA, ENTRA DE NUEVO"}
	var r := await _request("POST", "/me/friends", {"username": player_name}, true)
	if not r.ok or not r.data is Dictionary:
		return {"ok": false, "result": "", "error": _error_text(r)}
	return {"ok": true, "result": str(r.data.get("result", "")), "error": ""}

## Quita un amigo, o cancela / rechaza una solicitud. true si el servidor lo hizo.
func remove_friend(player_name: String) -> bool:
	if not is_logged_in():
		return false
	var r := await _request("DELETE", "/me/friends/%s" % player_name.uri_encode(), null, true)
	return r.ok

## Ranking entre mis amigos y yo (mismo formato y filtros que fetch_ranking). Vacío si falla.
func fetch_friends_ranking(week: bool = false, fighter: String = "") -> Array:
	if not is_logged_in():
		return []
	var r := await _request("GET", "/me/friends/leaderboard" + _ranking_query(week, fighter), null, true)
	return r.data if r.ok and r.data is Array else []

## "?period=week&fighter=x" según los filtros ("" sin filtros).
static func _ranking_query(week: bool, fighter: String, limit: int = 0) -> String:
	var parts := PackedStringArray()
	if limit > 0:
		parts.append("limit=%d" % limit)
	if week:
		parts.append("period=week")
	if fighter != "":
		parts.append("fighter=%s" % fighter.uri_encode())
	return "?" + "&".join(parts) if not parts.is_empty() else ""

## Reta a un amigo: abre una sala privada de unos 2 minutos. Devuelve {ok, code, expires_in, error}.
func create_challenge(player_name: String) -> Dictionary:
	if not is_logged_in():
		return {"ok": false, "code": "", "expires_in": 0, "error": "SESIÓN CADUCADA, ENTRA DE NUEVO"}
	var r := await _request("POST", "/me/challenges", {"to": player_name}, true)
	if not r.ok or not r.data is Dictionary:
		return {"ok": false, "code": "", "expires_in": 0, "error": _error_text(r)}
	return {"ok": true, "code": str(r.data.get("code", "")), "expires_in": int(r.data.get("expires_in", 0)), "error": ""}

## Los retos que me han hecho ([{code, from, expires_in}]). Vacío si no hay o falla.
func fetch_challenges() -> Array:
	if not is_logged_in():
		return []
	var r := await _request("GET", "/me/challenges", null, true)
	return r.data if r.ok and r.data is Array else []

## Cancela mi reto o rechaza el que me hicieron.
func cancel_challenge(code: String) -> bool:
	if not is_logged_in() or code == "":
		return false
	var r := await _request("DELETE", "/me/challenges/%s" % code.uri_encode(), null, true)
	return r.ok

## Los mejores jugadores: [{username, points, wins, losses, avatar, favorite_fighter, streak}]. Vacío si falla.
## Con week, solo los duelos de los últimos 7 días; con fighter, solo los jugados con ese luchador. Con algún
## filtro cada fila trae además "gained" (puntos ganados con esos duelos) y salen solo quienes jugaron alguno.
func fetch_ranking(limit: int = 10, week: bool = false, fighter: String = "") -> Array:
	var r := await _request("GET", "/leaderboard" + _ranking_query(week, fighter, limit), null, false)
	return r.data if r.ok and r.data is Array else []

## Mis últimos duelos (solo con sesión). Vacío si falla.
func fetch_matches(limit: int = 8) -> Array:
	if not is_logged_in():
		return []
	var r := await _request("GET", "/me/matches?limit=%d" % limit, null, true)
	return r.data if r.ok and r.data is Array else []

# =========================================================================
#  Partida guardada del modo Historia
# =========================================================================
## Campos de la partida: fighter, stage, continues, continues_used, difficulty, saved_at.
const STORY_KEYS: Array[String] = ["fighter", "stage", "continues", "continues_used", "difficulty", "saved_at"]

func _story_section() -> String:
	return user_id if user_id != "" else "guest"

## La copia local de esta cuenta, o {} si no hay.
func story_local() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(story_path) != OK or not cfg.has_section(_story_section()):
		return {}
	var d := {}
	for k in STORY_KEYS:
		if not cfg.has_section_key(_story_section(), k):
			return {}
		d[k] = cfg.get_value(_story_section(), k)
	return d

func _write_story_local(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(story_path)   # conserva las secciones de otras cuentas
	if data.is_empty():
		if cfg.has_section(_story_section()):
			cfg.erase_section(_story_section())
	else:
		for k in STORY_KEYS:
			cfg.set_value(_story_section(), k, data[k])
	cfg.save(story_path)

## Guarda la partida: primero en este equipo y, con sesión, en la cuenta. Devuelve true si
## quedó también en el servidor (o si no hay sesión y no hacía falta).
func save_story(data: Dictionary) -> bool:
	data["saved_at"] = int(Time.get_unix_time_from_system())
	_write_story_local(data)
	if not is_logged_in():
		return true
	var r := await _request("PUT", "/me/story", data, true)
	return r.ok

## La partida a retomar: la más reciente entre la de este equipo y la de la cuenta.
## Si una está más atrasada que la otra, se actualiza. {} si no hay ninguna.
func load_story() -> Dictionary:
	var local := story_local()
	if not is_logged_in():
		return local
	var r := await _request("GET", "/me/story", null, true)
	if not r.ok or not r.data is Dictionary:
		# 404 = la cuenta no tiene partida; otro error (p. ej. sin red) = se usa la local.
		if r.code == 404 and not local.is_empty():
			await _request("PUT", "/me/story", local, true)
		return local
	var remote := _clean_story(r.data)
	if remote.is_empty():
		return local
	if local.is_empty() or int(remote["saved_at"]) >= int(local["saved_at"]):
		_write_story_local(remote)
		return remote
	await _request("PUT", "/me/story", local, true)
	return local

## Borra la partida (al terminar la historia o quedarse sin revanchas).
func clear_story() -> void:
	_write_story_local({})
	if is_logged_in():
		await _request("DELETE", "/me/story", null, true)

## Deja solo los campos esperados, con su tipo. {} si falta alguno.
func _clean_story(d: Dictionary) -> Dictionary:
	var out := {}
	for k in STORY_KEYS:
		if not d.has(k):
			return {}
		out[k] = str(d[k]) if k == "fighter" else int(d[k])
	return out

## Renueva el token si le queda poco de vida (antes de entrar a un duelo).
## Devuelve true si hay una sesión válida.
func ensure_fresh_token() -> bool:
	if not is_logged_in():
		return false
	if Time.get_ticks_msec() + TOKEN_MARGIN_MSEC < _access_expires_msec:
		return true
	var r := await _refresh(refresh_token)
	return r.ok

## Aplica los puntos que el servidor confirmó al terminar un duelo (mensaje "settled").
func apply_settled(msg: Dictionary) -> void:
	if not is_logged_in() or not msg.get("ranked", false) or not msg.get("ok", false):
		return
	profile["points"] = int(msg.get("points", profile.get("points", 0)))
	profile["wins"] = int(msg.get("wins", profile.get("wins", 0)))
	profile["losses"] = int(msg.get("losses", profile.get("losses", 0)))
	session_changed.emit()

# =========================================================================
#  Sesión
# =========================================================================
func _start_session(data: Dictionary) -> void:
	access_token = str(data.get("access_token", ""))
	refresh_token = str(data.get("refresh_token", ""))
	_access_expires_msec = Time.get_ticks_msec() + int(data.get("expires_in", 0)) * 1000
	profile = data.get("player", {})
	user_id = str(profile.get("id", ""))
	var cfg := ConfigFile.new()
	cfg.set_value("session", "refresh_token", refresh_token)
	cfg.save(session_path)
	session_changed.emit()

func _refresh(token: String) -> Dictionary:
	var r := await _request("POST", "/auth/refresh", {"refresh_token": token}, false)
	if r.ok:
		_start_session(r.data)
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
	profile = {}
	_access_expires_msec = 0

# =========================================================================
#  HTTP
# =========================================================================
## Devuelve {ok: bool, code: int, data: Variant}. code 0 = sin conexión.
## Si el servidor responde 401 a una petición con sesión, renueva el token
## una vez y reintenta.
func _request(method: String, path: String, body: Variant, use_token: bool,
		retry: bool = true, timeout: float = REQUEST_TIMEOUT) -> Dictionary:
	# Sin cuerpo no se declara JSON: el servidor rechaza un "application/json" vacío (DELETE, logout).
	var headers := PackedStringArray(["Content-Type: application/json"] if body != null else [])
	if use_token and access_token != "":
		headers.append("Authorization: Bearer " + access_token)
	var http := HTTPRequest.new()
	http.timeout = timeout
	add_child(http)
	var verb := HTTPClient.METHOD_GET
	match method:
		"POST": verb = HTTPClient.METHOD_POST
		"PUT": verb = HTTPClient.METHOD_PUT
		"PATCH": verb = HTTPClient.METHOD_PATCH
		"DELETE": verb = HTTPClient.METHOD_DELETE
	var err := http.request(ServerConfig.http_url() + path, headers, verb, "" if body == null else JSON.stringify(body))
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
			return await _request(method, path, body, true, false, timeout)
	return {"ok": code >= 200 and code < 300, "code": code, "data": data if data != null else {}}

## Mensaje en español para un error del servidor (que responde {error, message}).
func _error_text(r: Dictionary) -> String:
	if r.code == 0:
		return "SIN CONEXIÓN CON EL SERVIDOR"
	var d: Dictionary = r.data if r.data is Dictionary else {}
	match str(d.get("error", "")):
		"invalid_credentials": return "EMAIL O CONTRASEÑA INCORRECTOS"
		"email_taken": return "ESE EMAIL YA ESTÁ REGISTRADO"
		"username_taken": return "ESE NOMBRE YA ESTÁ EN USO"
		"invalid_google_token": return "NO SE PUDO VERIFICAR TU CUENTA DE GOOGLE"
		"google_disabled": return "GOOGLE NO ESTÁ DISPONIBLE"
		"invalid_request": return "DATOS NO VÁLIDOS"
		"rate_limited": return "DEMASIADOS INTENTOS, ESPERA UN POCO"
		"invalid_token": return "SESIÓN CADUCADA, ENTRA DE NUEVO"
		"username_cooldown": return "SOLO PUEDES CAMBIAR EL NOMBRE UNA VEZ CADA 7 DÍAS"
		"wrong_password": return "LA CONTRASEÑA ACTUAL NO ES CORRECTA"
		"no_password": return "TU CUENTA ENTRA CON GOOGLE: NO TIENE CONTRASEÑA"
		"player_not_found": return "JUGADOR NO ENCONTRADO"
		"not_unlocked": return "TODAVÍA NO HAS DESBLOQUEADO ESO"
		"cannot_friend_self": return "NO PUEDES SER TU PROPIO AMIGO"
		"friend_limit": return "YA TIENES DEMASIADOS AMIGOS Y SOLICITUDES"
		"not_friends": return "SOLO PUEDES RETAR A TUS AMIGOS"
		"cannot_challenge_self": return "NO PUEDES RETARTE A TI MISMO"
	return "ERROR DEL SERVIDOR (%d)" % r.code

## Valida los datos del formulario antes de enviarlos. "" = correcto.
static func validate_credentials(p_email: String, password: String, p_username: String = "", registering: bool = false) -> String:
	if p_email.count("@") != 1 or "." not in p_email.get_slice("@", 1) or p_email.length() < 6:
		return "EMAIL NO VÁLIDO"
	if password.length() < 6:
		return "CONTRASEÑA: MÍNIMO 6 CARACTERES"
	if registering:
		return validate_username(p_username)
	return ""

## Comprueba el nombre de jugador. "" = correcto.
static func validate_username(p_username: String) -> String:
	var rx := RegEx.create_from_string("^[A-Za-z0-9_]{3,16}$")
	if rx.search(p_username) == null:
		return "NOMBRE: 3-16 LETRAS, NÚMEROS O _"
	return ""
