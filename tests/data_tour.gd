## Recorre las pantallas con una cuenta llena de datos (ver tests/populate_dev.sh) y saca una captura de
## cada una. Necesita ventana (las capturas son del render). Los errores de script salen en la consola.
## Uso:  godot --path . res://tests/DataTour.tscn -- --url=ws://127.0.0.1:8790/ws --out=<carpeta>
##         [--email=max@sim.com]
extends Node

var _out := "user://tour"
var _email := "max@sim.com"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--url="):
			ServerConfig.override_ws = arg.trim_prefix("--url=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--email="):
			_email = arg.trim_prefix("--email=")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()

func scene() -> Node:
	return get_tree().current_scene

func seconds(s: float) -> void:
	var until := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame

func wait_scene(scene_name: String, timeout_s: float = 20.0) -> bool:
	var until := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		if scene() and scene().name == scene_name and not Game.is_changing_scene():
			return true
	print("FALLO: no se abrió %s" % scene_name)
	return false

## Espera a que la pantalla deje de cargar (su variable _loading), como mucho `timeout_s`.
func wait_loaded(timeout_s: float = 20.0) -> void:
	var until := Time.get_ticks_msec() + int(timeout_s * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
		var s := scene()
		if s != null and not ("_loading" in s and s._loading):
			break
	await seconds(0.6)

func shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file_name))
	print("captura: ", file_name)

func open(path: String, scene_name: String) -> bool:
	Game.goto(path)
	if not await wait_scene(scene_name):
		return false
	await wait_loaded()
	return true

func _run() -> void:
	# Archivos locales aparte: no se mezclan con los del juego de quien lo ejecuta.
	Backend.session_path = "user://sim_session_tour.cfg"
	Backend.story_path = "user://sim_story.cfg"
	Unlocks.path = "user://sim_unlocks.cfg"
	Season.seen_path = "user://sim_seasons_seen.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Season.seen_path))
	if not await Backend.check_available():
		_quit("FALLO: el servidor no responde", 1)
		return
	var r := await Backend.sign_in(_email, "secreto1")
	if not r.ok:
		_quit("FALLO al entrar: %s" % r.error, 1)
		return
	print("CUENTA %s · %d puntos" % [Backend.username(), int(Backend.profile.get("points", 0))])

	# Menú: al entrar, el aviso de la temporada que terminó.
	if await open(Game.SCENE_MENU, "MainMenu"):
		await seconds(6.0)
		await shot("01_menu_fin_temporada.png")
		if scene()._challenge_box != null:
			scene()._close_challenge()
		await seconds(0.5)
		await shot("02_menu.png")

	# Ranking: global, con su temporada; con una fila elegida; 7 días; por luchador; amigos.
	Game.ranking_friends = false
	Game.ranking_week = false
	Game.ranking_fighter = ""
	if await open(Game.SCENE_RANKING, "Ranking"):
		await seconds(1.0)
		await shot("03_ranking_global.png")
		scene()._sel = 1
		await seconds(0.3)
		await shot("04_ranking_fila_elegida.png")
		scene()._sel = -1
		await scene()._set_filter(false, true, "")
		await wait_loaded()
		await shot("05_ranking_7_dias.png")
		await scene()._set_filter(false, false, "napoleon")
		await wait_loaded()
		await shot("06_ranking_napoleon.png")
		await scene()._set_filter(true, false, "")
		await wait_loaded()
		await shot("07_ranking_amigos.png")
		Game.ranking_friends = false

	# Perfil: las cuatro pestañas.
	if await open(Game.SCENE_PROFILE, "Profile"):
		for tab in 4:
			scene()._select_tab(tab)
			await seconds(0.5)
			await shot("%02d_perfil_%s.png" % [8 + tab, scene().TAB_NAMES[tab].to_lower()])

	if await open(Game.SCENE_ACHIEVEMENTS, "Achievements"):
		await shot("12_logros.png")
	if await open(Game.SCENE_EDIT_PROFILE, "EditProfile"):
		await shot("13_editar_perfil.png")
	if await open(Game.SCENE_FRIENDS, "Friends"):
		await shot("14_amigos.png")

	# Perfiles de otros: una amiga, uno que me pidió amistad y una a la que se la pedí yo.
	var others := [["Ana_Sim", "15_perfil_amiga"], ["Dani_Sim", "16_perfil_solicitud_recibida"], ["Eva_Sim", "17_perfil_solicitud_enviada"]]
	for o in others:
		Game.view_player(o[0], Game.SCENE_RANKING)
		if await wait_scene("PlayerProfile"):
			await wait_loaded()
			await shot("%s.png" % o[1])

	Game.picker_purpose = "avatar"
	if await open(Game.SCENE_AVATAR, "AvatarPicker"):
		await shot("18_avatar.png")
	_quit("RECORRIDO: OK", 0)

func _quit(message: String, code: int) -> void:
	print(message)
	Backend._forget_session()
	get_tree().quit(code)
