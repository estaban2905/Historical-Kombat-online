## Captura pantallas de cada escena (requiere renderizado real, no --headless).
## Uso: godot --path . res://tests/ScreenshotRunner.tscn -- <carpeta_salida>
extends Node

var out_dir: String = "user://screenshots"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().current_scene = null
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file_name))
	print("captura: ", file_name, " ", img.get_size())

func _run() -> void:
	get_tree().change_scene_to_file(Game.SCENE_MENU)
	await frames(40)
	await shot("01_menu.png")
	get_tree().change_scene_to_file(Game.SCENE_SELECT)
	await frames(40)
	await shot("02_select.png")
	get_tree().change_scene_to_file(Game.SCENE_FIGHT)
	await frames(25)
	await shot("03_round1.png")
	var c := get_tree().current_scene as CombatManager
	while c.round_manager.phase != RoundManager.Phase.FIGHT:
		await frames(1)
	c.p1.position.x = 170
	c.p2.position.x = 236
	c.p1.energy = 100
	c.p2.energy = 100
	await frames(10)
	c.p1.input.press(&"kick_heavy")
	await frames(12)
	await shot("04_kick.png")
	await frames(30)
	c.p2.input.press(&"special_1")
	c.p1.input.hold(&"crouch")
	await frames(24)
	await shot("05_cannon.png")
	c.p1.input.hold(&"crouch", false)
	await frames(30)
	c.p1.position.x = 190
	c.p2.position.x = 228
	await frames(4)
	c.p1.input.press(&"special_2")
	await frames(19)
	await shot("06_golf.png")
	await frames(60)
	c.p2.input.hold(&"block")
	c.p1.input.press(&"special_1")
	await frames(24)
	await shot("07_megaphone_block.png")
	c.p2.input.hold(&"block", false)
	await frames(40)
	c.p2.input.press(&"special_2")
	await frames(14)
	await shot("08_charge.png")
	await frames(40)
	c.p2.health = 1
	c.p1.position.x = 200
	c.p2.position.x = 232
	await frames(3)
	c.p1.input.press(&"punch_heavy")
	await frames(40)
	await shot("09_ko.png")
	await frames(110)
	await shot("10_wins.png")
	Game.set_match_result(1, 2, 1)
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	await frames(40)
	await shot("11_results.png")
	# Resultados online: puntos contados, barra de liga y aviso de subida y de bajada (con la frase más larga).
	Game.mode = Game.Mode.ONLINE
	Online.side = 1
	Game.p1_fighter_id = &"kim_jong_un"
	Online.last_settled = {"ranked": true, "ok": true, "delta": 16, "points": 1104, "wins": 6, "losses": 4}
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	await frames(30)
	await shot("12_results_online_counting.png")
	(get_tree().current_scene as Control).set("_new_titles", ["title_first_blood"] as Array[String])
	await frames(60)
	await shot("13_results_online_up.png")
	Game.set_match_result(2, 1, 2)
	Online.last_settled = {"ranked": true, "ok": true, "delta": -15, "points": 1090, "wins": 6, "losses": 5, "reason": "forfeit"}
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	await frames(90)
	await shot("14_results_online_down.png")
	Online.last_settled = {}
	Game.mode = Game.Mode.VERSUS
	# Ranking con datos de ejemplo: avatar y más usado en cada fila, racha y tu fila fija abajo.
	var ids := ["napoleon", "cleopatra", "nikola_tesla", "", "kim_jong_un", "juana_de_arco", "gengis_kan", "rasputin",
		"albert_einstein", "lautaro", "abraham_lincoln", "papa_francisco"]
	var fake: Array = []
	for i in ids.size():
		fake.append({"username": "Jugador_%d" % (i + 1), "points": 1560 - i * 45, "wins": 30 - i * 2, "losses": 10 + i,
			"streak": 5 if i == 1 else 0, "avatar": ids[i] if ids[i] != "" else null,
			"favorite_fighter": ids[(i + 3) % ids.size()] if i != 6 else null})
	Backend.access_token = "captura"
	Backend.profile = {"username": "Jugador_12"}
	get_tree().change_scene_to_file(Game.SCENE_RANKING)
	var ranking := await _ranking_loaded()
	ranking._players = fake
	ranking._season = {"id": "2026-11", "ends_at": Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + 12 * 86400)}
	await frames(10)
	await shot("15_ranking.png")
	# Con filtros (7 días y un luchador): la columna de puntos es lo ganado, en verde o rojo.
	Game.ranking_week = true
	Game.ranking_fighter = "napoleon"
	for i in fake.size():
		fake[i]["gained"] = 64 - i * 16
	get_tree().change_scene_to_file(Game.SCENE_RANKING)
	ranking = await _ranking_loaded()
	ranking._players = fake.slice(0, 7)
	await frames(10)
	await shot("16_ranking_filtered.png")
	Game.ranking_week = false
	Game.ranking_fighter = ""
	# Aviso de fin de temporada en el menú.
	get_tree().change_scene_to_file(Game.SCENE_MENU)
	await frames(30)
	var menu := get_tree().current_scene
	if menu._challenge_box == null:
		menu._show_season_end({"season": "2026-10", "rank": 2, "league": "gold"})
	await frames(10)
	await shot("17_season_end.png")
	Backend.access_token = ""
	Backend.profile = {}
	get_tree().quit()

## Espera a que el ranking termine de pedir su lista (para poner luego los datos de ejemplo encima).
func _ranking_loaded() -> Node:
	await frames(5)
	var ranking := get_tree().current_scene
	for i in 600:
		if not ranking._loading:
			break
		await frames(1)
	return ranking
