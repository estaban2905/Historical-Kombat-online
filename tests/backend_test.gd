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
	check(Backend.validate_username("Max_29") == "" and Backend.validate_username("a b") != "", "validate_username")

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

	print("
# Partida guardada del modo Historia")
	Backend.story_path = "user://story_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Backend.story_path))
	check((await Backend.load_story()).is_empty(), "cuenta nueva: sin partida guardada")
	var save := {"fighter": "nikola_tesla", "stage": 7, "continues": 2, "continues_used": 1, "difficulty": 1}
	check(await Backend.save_story(save.duplicate()), "guardar la partida en la cuenta")
	check(Backend.story_local().get("stage", -1) == 7, "queda también una copia local")
	# Otro PC: sin copia local, la partida vuelve desde la cuenta.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Backend.story_path))
	check(Backend.story_local().is_empty(), "otro equipo: sin copia local")
	var got := await Backend.load_story()
	check(got.get("fighter", "") == "nikola_tesla" and int(got.get("stage", -1)) == 7, "la partida se recupera desde la cuenta")
	check(int(got.get("continues", -1)) == 2 and int(got.get("continues_used", -1)) == 1 and int(got.get("difficulty", -1)) == 1,
		"recupera revanchas y dificultad")
	check(Backend.story_local().get("stage", -1) == 7, "y se copia al equipo")
	# Un guardado más nuevo hecho desde otro equipo gana al local.
	var newer := save.duplicate()
	newer["stage"] = 9
	await Backend.save_story(newer)
	var stale := ConfigFile.new()
	for k in Backend.STORY_KEYS:
		stale.set_value(Backend.user_id, k, {"fighter": "nikola_tesla", "stage": 3, "continues": 3, "continues_used": 0,
			"difficulty": 1, "saved_at": 1}[k])
	stale.save(Backend.story_path)
	check(int((await Backend.load_story()).get("stage", -1)) == 9, "gana la partida más reciente (cuenta sobre copia vieja)")
	# Sin red se usa la copia local.
	ServerConfig.override_ws = "ws://127.0.0.1:1/ws"
	check(int((await Backend.load_story()).get("stage", -1)) == 9, "sin conexión se usa la copia local")
	ServerConfig.override_ws = url
	await Backend.clear_story()
	check(Backend.story_local().is_empty() and (await Backend.load_story()).is_empty(), "borrar quita la partida de equipo y cuenta")
	# Reanudar en el juego.
	check(Game.story_resume({"fighter": "nikola_tesla", "stage": 5, "continues": 1, "continues_used": 2, "difficulty": 1}),
		"Game.story_resume acepta una partida válida")
	check(Game.arcade_stage == 5 and Game.arcade_continues == 1 and Game.story_continues_used == 2
		and Game.p1_fighter_id == &"nikola_tesla" and Game.p2_fighter_id == Game.arcade_ladder[5], "y deja el juego en ese combate")
	check(Game.story_snapshot().get("stage", -1) == 5, "story_snapshot refleja el estado")
	check(not Game.story_resume({"fighter": "no_existe", "stage": 1, "continues": 1, "continues_used": 0, "difficulty": 1}),
		"un luchador que ya no existe se rechaza")
	check(not Game.story_resume({"fighter": "nikola_tesla", "stage": 9999, "continues": 1, "continues_used": 0, "difficulty": 1}),
		"un combate fuera de la escalera se rechaza")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Backend.story_path))

	print("
# Perfil público y editar perfil")
	var pub := await Backend.fetch_player(name)
	check(pub.get("username", "") == name and int(pub.get("rank", 0)) >= 1, "perfil público de un jugador (puesto %s)" % str(pub.get("rank")))
	check(not pub.has("email") and not pub.has("id") and pub.get("recent", null) is Array, "no trae email ni id, y sí la lista de duelos")
	check((await Backend.fetch_player("Nadie_" + suffix)).is_empty(), "un jugador que no existe devuelve vacío")
	check(not Backend.is_google_account(), "una cuenta con email no es de Google")
	var new_name := "N" + suffix
	r = await Backend.set_username(new_name)
	check(r.ok and Backend.username() == new_name, "cambiar el nombre: " + str(r.error))
	check((await Backend.fetch_player(name)).is_empty() and not (await Backend.fetch_player(new_name)).is_empty(),
		"el nombre viejo ya no existe y el nuevo sí")
	r = await Backend.set_username("Z" + suffix)
	check(not r.ok and "7 DÍAS" in r.error, "otro cambio seguido: en espera (" + str(r.error) + ")")
	r = await Backend.change_password("mala-clave", "nueva-clave")
	check(not r.ok and "ACTUAL" in r.error, "contraseña actual incorrecta: " + str(r.error))
	r = await Backend.change_password("secreto1", "nueva-clave")
	check(r.ok, "cambiar la contraseña: " + str(r.error))
	check(Backend.is_logged_in() and await Backend.fetch_profile(), "la sesión que la cambió sigue abierta")
	await Backend.sign_out()
	r = await Backend.sign_in(email, "secreto1")
	check(not r.ok, "la contraseña vieja ya no sirve")
	r = await Backend.sign_in(email, "nueva-clave")
	check(r.ok and Backend.username() == new_name, "la nueva sí sirve y trae el nombre nuevo")

	print("\n# Amigos y retos (dos cuentas)")
	var other_name := "F" + suffix
	var other_email := "f%s@test.com" % suffix
	await Backend.sign_out()
	r = await Backend.sign_up(other_email, "secreto1", other_name)
	check(r.ok and Backend.username() == other_name, "segunda cuenta: " + str(r.get("error", "")))
	r = await Backend.request_friend(new_name)
	check(r.ok and r.result == "requested", "pedir amistad: " + str(r.result) + str(r.error))
	await Backend.fetch_friends()
	check(Backend.friend_status(new_name) == "outgoing", "yo la veo como enviada")
	r = await Backend.request_friend(other_name)
	check(not r.ok and "AMIGO" in r.error, "no puedo ser mi propio amigo: " + str(r.error))
	r = await Backend.create_challenge(new_name)
	check(not r.ok and "AMIGOS" in r.error, "aún no somos amigos: no puedo retar (" + str(r.error) + ")")
	await Backend.sign_out()
	r = await Backend.sign_in(email, "nueva-clave")
	check(r.ok, "vuelvo a la primera cuenta")
	await Backend.fetch_friends()
	check(Backend.friend_status(other_name) == "incoming", "me llega como solicitud entrante")
	check(FriendsScreen.pending_count(Backend.friends_cache) == 1, "una solicitud por contestar")
	r = await Backend.request_friend(other_name)
	check(r.ok and r.result == "accepted", "aceptarla pidiéndola de vuelta: " + str(r.result))
	await Backend.fetch_friends()
	check(Backend.friend_status(other_name) == "friend", "ya somos amigos")
	var ranking_friends := await Backend.fetch_friends_ranking()
	var names := ranking_friends.map(func(p): return p.get("username", ""))
	check(names.has(new_name) and names.has(other_name) and names.size() == 2, "el ranking de amigos: yo y mi amigo (%s)" % str(names))
	var ch := await Backend.create_challenge(other_name)
	check(ch.ok and str(ch.code).length() == 8 and int(ch.expires_in) > 0, "retar a un amigo: " + str(ch.error))
	await Backend.sign_out()
	r = await Backend.sign_in(other_email, "secreto1")
	check(r.ok, "entro como el retado")
	var retos := await Backend.fetch_challenges()
	check(retos.size() == 1 and retos[0].get("from", "") == new_name and retos[0].get("code", "") == ch.code, "el retado ve el reto de " + new_name)
	check(await Backend.cancel_challenge(ch.code), "rechazar el reto")
	check((await Backend.fetch_challenges()).is_empty(), "ya no hay retos")
	check(await Backend.remove_friend(new_name), "quitar al amigo")
	await Backend.fetch_friends()
	check(Backend.friend_status(new_name) == "", "ya no somos amigos")

	print("\n# Desbloqueos de invitado, marcos y títulos")
	var real_unlocks := Unlocks.path
	Unlocks.path = "user://unlocks_backend_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	await Backend.sign_out()
	Unlocks.add("ending", "repair")
	Cosmetics.grant_ending(&"repair")
	check(Cosmetics.owned_frames() == ["frame_gold"], "sin cuenta se gana el marco dorado al ver un final")
	r = await Backend.sign_in(other_email, "secreto1")
	check(r.ok, "entro en la cuenta tras jugar sin ella")
	r = await Backend.set_cosmetics({"frame": "frame_gold"})
	check(not r.ok, "antes de sincronizar, el servidor no deja ponerse el marco: " + str(r.error))
	await Backend.sync_unlocks()
	var remote: Variant = await Backend.fetch_unlocks()
	var remote_items: Array = (remote as Array).map(func(u): return "%s:%s" % [u["kind"], u["key"]]) if remote is Array else []
	check(remote_items.has("ending:repair") and remote_items.has("cosmetic:frame_gold") and remote_items.has("cosmetic:title_guardian"),
		"lo ganado sin cuenta ya está en la cuenta del servidor (%s)" % str(remote_items))
	r = await Backend.set_cosmetics({"frame": "frame_gold", "title": "title_guardian"})
	check(r.ok and Backend.frame() == "frame_gold" and Backend.title() == "title_guardian", "ponerse marco y título: " + str(r.error))
	pub = await Backend.fetch_player(other_name)
	check(pub.get("frame") == "frame_gold" and pub.get("title") == "title_guardian", "los demás ven el marco y el título en mi perfil")
	r = await Backend.set_cosmetics({"frame": "frame_red"})
	check(not r.ok and Backend.frame() == "frame_gold", "un marco no ganado se rechaza y no cambia nada: " + str(r.error))
	r = await Backend.set_cosmetics({"title": ""})
	check(r.ok and Backend.title() == "" and Backend.frame() == "frame_gold", "quitar el título deja el marco")
	await Backend.sign_out()
	r = await Backend.sign_in(email, "nueva-clave")
	await Backend.sync_unlocks()
	check(r.ok and not Unlocks.has("ending", "repair"), "lo del invitado no pasa también a otra cuenta")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Unlocks.path = real_unlocks

	await Backend.sign_out()
	Backend._forget_session()
	ServerConfig.override_ws = ""
	print("\n=== RESULTADO: %d OK, %d FALLOS ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)
