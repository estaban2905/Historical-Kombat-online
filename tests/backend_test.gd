## Pruebas del cliente de cuentas contra un servidor falso (tests/mock_supabase.py).
## Uso:
##   python tests/mock_supabase.py            (en otra terminal)
##   godot --headless --path . res://tests/BackendTest.tscn
## No toca tu sesión real: guarda la sesión en user://session.cfg y la borra al acabar.
extends Node

const MOCK_URL := "http://127.0.0.1:54329"
const MOCK_KEY := "test-anon-key"

var passed: int = 0
var failed: int = 0

func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  [OK]   ", label)
	else:
		failed += 1
		print("  [FAIL] ", label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Backend.session_path = "user://session_test.cfg"
	print("\n=== HISTORY COMBAT · PRUEBAS DE CUENTAS ===")
	print("\n# Validación en el cliente")
	check(Backend.validate_credentials("a@b.co", "123456") == "", "datos correctos")
	check(Backend.validate_credentials("sin-arroba", "123456") != "", "email sin @ rechazado")
	check(Backend.validate_credentials("a@b.co", "123") != "", "contraseña corta rechazada")
	check(Backend.validate_credentials("a@b.co", "123456", "ab", true) != "", "nombre de 2 letras rechazado")
	check(Backend.validate_credentials("a@b.co", "123456", "con espacio", true) != "", "nombre con espacio rechazado")
	check(Backend.validate_credentials("a@b.co", "123456", "Max_29", true) == "", "nombre válido aceptado")

	print("\n# Sin servidor configurado")
	Backend.configure("", "")
	check(not Backend.is_configured(), "sin configuración se detecta")
	var r := await Backend.sign_in("a@b.co", "123456")
	check(not r.ok, "iniciar sesión falla sin romperse")

	print("\n# Registro e inicio de sesión")
	Backend.configure(MOCK_URL, MOCK_KEY)
	r = await Backend.sign_up("max@test.com", "secreto1", "Max_29")
	check(r.ok and not r.needs_confirmation, "registro correcto")
	check(Backend.is_logged_in(), "tras registrarse hay sesión")
	check(Backend.username() == "Max_29", "perfil cargado: " + Backend.username())
	check(int(Backend.profile.get("points", -1)) == 1000, "arranca con 1000 puntos")
	check(Backend.has_saved_session(), "la sesión queda guardada en disco")

	r = await Backend.sign_up("max@test.com", "secreto1", "Otro_Nombre")
	check(not r.ok and "REGISTRADO" in r.error, "email repetido: " + r.error)
	r = await Backend.sign_up("otro@test.com", "secreto1", "Max_29")
	check(not r.ok and "NOMBRE" in r.error, "nombre repetido: " + r.error)
	r = await Backend.sign_up("otro@test.com", "123", "Nuevo_1")
	check(not r.ok and "DÉBIL" in r.error, "contraseña débil en servidor: " + r.error)

	print("\n# Cerrar y recuperar sesión")
	await Backend.sign_out()
	check(not Backend.is_logged_in(), "cerrar sesión")
	check(not Backend.has_saved_session(), "cerrar sesión borra la sesión guardada")
	r = await Backend.sign_in("max@test.com", "mala")
	check(not r.ok and "INCORRECTOS" in r.error, "contraseña errónea: " + r.error)
	r = await Backend.sign_in("max@test.com", "secreto1")
	check(r.ok and Backend.is_logged_in(), "iniciar sesión con datos correctos")
	var saved := Backend.load_saved_refresh_token()
	# Simula cerrar y reabrir el juego: se pierde el estado en memoria pero no el archivo.
	Backend._clear_state()
	check(not Backend.is_logged_in(), "estado en memoria vacío (juego reiniciado)")
	r = await Backend.restore_session()
	check(r.ok and Backend.is_logged_in(), "restaurar sesión guardada")
	check(Backend.username() == "Max_29", "perfil tras restaurar")
	check(Backend.load_saved_refresh_token() != saved, "el refresh token se renueva")

	print("\n# Token caducado")
	var http := HTTPRequest.new()
	add_child(http)
	http.request(MOCK_URL + "/__expire", [], HTTPClient.METHOD_POST, "{}")
	await http.request_completed
	http.queue_free()
	check(await Backend.fetch_profile(), "con el token caducado se renueva solo y sigue funcionando")

	print("\n# Sesión inválida guardada")
	Backend._clear_state()
	var cfg := ConfigFile.new()
	cfg.set_value("session", "refresh_token", "basura")
	cfg.save(Backend.session_path)
	r = await Backend.restore_session()
	check(not r.ok and not Backend.has_saved_session(), "un token rechazado se descarta")

	print("\n# Servidor caído")
	Backend.configure("http://127.0.0.1:1", MOCK_KEY)
	r = await Backend.sign_in("max@test.com", "secreto1")
	check(not r.ok and "SIN CONEXIÓN" in r.error, "sin red: " + r.error)
	cfg.save(Backend.session_path)   # token "basura" guardado
	r = await Backend.restore_session()
	check(not r.ok and Backend.has_saved_session(), "un fallo de red NO borra la sesión guardada")

	# Limpieza
	Backend._clear_state()
	Backend._forget_session()
	print("\n=== RESULTADO: %d OK, %d FALLOS ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
