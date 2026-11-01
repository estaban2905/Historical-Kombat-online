## Prueba de humo de las pantallas del duelo online (sin servidor): menú, selección,
## lobby con servidor caído, resultados y pausa. Comprueba que cargan sin errores
## y que se comportan como toca cuando falla la conexión.
## Uso:  godot --headless --path . res://tests/OnlineUiTest.tscn
extends Node

var _failures := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func check(ok: bool, what: String) -> void:
	print("  [%s] %s" % ["OK  " if ok else "FAIL", what])
	if not ok:
		_failures += 1

func _show(path: String) -> Node:
	var n: Node = load(path).instantiate()
	add_child(n)
	return n

func _run() -> void:
	print("\n=== HISTORY COMBAT · PRUEBA DE PANTALLAS ONLINE ===")

	var menu := _show(Game.SCENE_MENU)
	var btn := menu.get_node_or_null("Buttons/Online") as Button
	check(btn != null and btn.text == "DUELO ONLINE", "el menú tiene el botón DUELO ONLINE")
	btn.pressed.emit()
	check(Game.mode == Game.Mode.ONLINE, "pulsarlo activa el modo ONLINE")
	menu.queue_free()

	var select := _show(Game.SCENE_SELECT)
	await get_tree().process_frame
	check(select._cpu and not select.confirmed[1] and select.confirmed[2],
		"selección online: solo elige el jugador local")
	select.queue_free()

	# Servidor inalcanzable: el lobby debe avisar, no colgarse.
	Online.url = "ws://127.0.0.1:1/ws"
	Game.p1_fighter_id = &"napoleon"
	var lobby := _show(Game.SCENE_LOBBY)
	var t := 0.0
	while lobby._error == "" and t < 12.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	check(lobby._error != "", "lobby con servidor caído muestra un error (%s)" % lobby._error)
	check(Online.state == Online.State.IDLE, "tras el fallo, Online queda libre")
	lobby.queue_free()

	# Resultados online: sin revancha, y gana quien corresponde.
	Game.set_match_result(2, 1, 2)
	Online.side = 2
	var results := _show(Game.SCENE_RESULTS)
	await get_tree().process_frame
	check(not results.btn_rematch.visible and not results.btn_select.visible and results.btn_menu.visible,
		"resultados online: solo se puede volver al menú")
	results.queue_free()

	# Pausa online: no congela el juego.
	var pause: CanvasLayer = load("res://scripts/ui/pause_menu.gd").new()
	add_child(pause)
	pause.open()
	check(not get_tree().paused, "la pausa online no detiene el árbol")
	pause.resume()
	pause.queue_free()

	Game.mode = Game.Mode.VERSUS
	print("\n=== RESULTADO: %d fallos ===" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
