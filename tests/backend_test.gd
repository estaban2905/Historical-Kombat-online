## Pruebas del cliente de cuentas contra el servidor REAL de server/ (con base de datos).
## Uso (lo lanza tests/run_account_e2e.sh, que arranca el servidor de desarrollo):
##   godot --headless --path . res://tests/BackendTest.tscn -- --url=ws://127.0.0.1:18081/ws
## No toca tu sesión real: guarda la sesión en user://session_test.cfg y la borra al acabar.
extends Node

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
	var url := "ws://127.0.0.1:18081/ws"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--url="):
			url = arg.trim_prefix("--url=")
	Backend.session_path = "user://session_test.cfg"
	var suffix := str(Time.get_ticks_usec() % 1000000)
	var name := "T" + suffix
	var email := "t%s@test.com" % suffix
	print("\n=== HISTORY COMBAT · PRUEBAS DE CUENTAS (servidor real) ===")

	print("\n# Validación en el cliente")
	check(Backend.validate_credentials("a@b.co", "123456") == "", "datos correctos")
	check(Backend.validate_credentials("sin-arroba", "123456") != "", "email sin @ rechazado")
	check(Backend.validate_credentials("a@b.co", "123") != "", "contraseña corta rechazada")
	check(Backend.validate_credentials("a@b.co", "123456", "ab", true) != "", "nombre de 2 letras rechazado")
	check(Backend.validate_credentials("a@b.co", "123456", "con espacio", true) != "", "nombre con espacio rechazado")
	check(Backend.validate_credentials("a@b.co", "123456", "Max_29", true) == "", "nombre válido aceptado")

	print("\n# Direcciones")
	check(ServerConfig.to_http("wss://x.up.railway.app/ws") == "https://x.up.railway.app", "wss://.../ws → https://...")
	check(ServerConfig.to_http("ws://localhost:8787/ws") == "http://localhost:8787", "ws://.../ws → http://...")

	print("\n# Sin servidor")
	ServerConfig.override_ws = "ws://127.0.0.1:1/ws"
	check(not await Backend.check_available(), "servidor caído: no hay cuentas")
	check(not Backend.is_configured(), "is_configured() es false")
	var r := await Backend.sign_in("a@b.co", "123456")
	check(not r.ok and "CONEXIÓN" in r.error, "iniciar sesión sin servidor: " + str(r.error))

	print("\n# Registro")
	ServerConfig.override_ws = url
	check(await Backend.check_available(), "el servidor responde y tiene base de datos")
	check(Backend.is_configured(), "is_configured() es true")
	r = await Backend.sign_up(email, "secreto1", name)
	check(r.ok, "registrarse: " + str(r.get("error", "")))
	check(Backend.is_logged_in(), "tras registrarse hay sesión")
	check(Backend.username() == name, "perfil cargado: " + Backend.username())
	check(int(Backend.profile.get("points", -1)) == 1000, "arranca con 1000 puntos")
	check(Backend.has_saved_session(), "la sesión queda guardada en disco")
	r = await Backend.sign_up(email, "secreto1", "Otro_" + suffix)
	check(not r.ok and "EMAIL" in r.error, "email repetido: " + str(r.error))
	r = await Backend.sign_up("otro%s@test.com" % suffix, "secreto1", name)
	check(not r.ok and "NOMBRE" in r.error, "nombre repetido: " + str(r.error))

	print("\n# Cerrar e iniciar sesión")
	await Backend.sign_out()
	check(not Backend.is_logged_in(), "cerrar sesión")
	check(not Backend.has_saved_session(), "cerrar sesión borra la sesión guardada")
	r = await Backend.sign_in(email, "mala-clave")
	check(not r.ok and "INCORRECTOS" in r.error, "contraseña incorrecta: " + str(r.error))
	r = await Backend.sign_in(email, "secreto1")
	check(r.ok and Backend.is_logged_in(), "iniciar sesión con datos correctos")

	print("\n# Sesión recordada")
	var saved := Backend.load_saved_refresh_token()
	Backend._clear_state()
	check(not Backend.is_logged_in(), "estado en memoria vacío (juego reiniciado)")
	r = await Backend.restore_session()
	check(r.ok and Backend.is_logged_in(), "restaurar sesión guardada")
	check(Backend.username() == name, "perfil tras restaurar")
	check(Backend.load_saved_refresh_token() != saved, "el refresh token se renueva")
	Backend.access_token = "token-caducado"
	check(await Backend.fetch_profile(), "con el token caducado se renueva solo y sigue funcionando")
	check(await Backend.ensure_fresh_token(), "ensure_fresh_token con sesión válida")
	Backend._clear_state()
	var cfg := ConfigFile.new()
	cfg.set_value("session", "refresh_token", "token-que-el-servidor-rechaza-000000")
	cfg.save(Backend.session_path)
	r = await Backend.restore_session()
	check(not r.ok and not Backend.has_saved_session(), "un token rechazado se descarta")
	ServerConfig.override_ws = "ws://127.0.0.1:1/ws"
	cfg.save(Backend.session_path)
	r = await Backend.restore_session()
	check(not r.ok and Backend.has_saved_session(), "un fallo de red NO borra la sesión guardada")
	ServerConfig.override_ws = url

	print("\n# Ranking, historial y puntos")
	r = await Backend.sign_in(email, "secreto1")
	check(r.ok, "volver a entrar")
	var board := await Backend.fetch_ranking(10)
	var found := false
	for p in board:
		if p.get("username", "") == name:
			found = true
	check(found, "aparezco en el ranking (%d jugadores)" % board.size())
	check((await Backend.fetch_matches(5)).is_empty(), "sin duelos todavía: historial vacío")
	Backend.apply_settled({"ranked": true, "ok": true, "delta": 16, "points": 1016, "wins": 1, "losses": 0})
	check(int(Backend.profile.points) == 1016 and int(Backend.profile.wins) == 1, "apply_settled actualiza el perfil")
	Backend.apply_settled({"ranked": true, "ok": false, "points": 5})
	check(int(Backend.profile.points) == 1016, "un duelo no registrado no cambia los puntos")
	Backend.apply_settled({"ranked": false, "ok": true, "points": 5})
	check(int(Backend.profile.points) == 1016, "un duelo amistoso no cambia los puntos")

	await Backend.sign_out()
	Backend._forget_session()
	ServerConfig.override_ws = ""
	print("\n=== RESULTADO: %d OK, %d FALLOS ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
