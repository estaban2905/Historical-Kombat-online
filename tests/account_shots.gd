## Capturas de la pantalla de login y del menú con sesión (requiere render real
## y el servidor falso de tests/mock_supabase.py en marcha).
## Uso: godot --path . res://tests/AccountShots.tscn -- <carpeta_salida>
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
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file_name))
	print("captura: ", file_name)

func _run() -> void:
	Backend.session_path = "user://session_shots.cfg"
	Backend.configure("http://127.0.0.1:54329", "test-anon-key")
	get_tree().change_scene_to_file(Game.SCENE_LOGIN)
	await frames(30)
	await shot("login_1_entrar.png")
	var login := get_tree().current_scene
	login._set_registering(true)
	login._email.text = "max@test.com"
	login._username.text = "Max_29"
	login._password.text = "secreto1"
	await frames(5)
	await shot("login_2_registro.png")
	login._status.text = "EMAIL O CONTRASEÑA INCORRECTOS"
	await frames(3)
	await shot("login_3_error.png")
	var r := await Backend.sign_up("max@test.com", "secreto1", "Max_29")
	if not r.ok:
		await Backend.sign_in("max@test.com", "secreto1")
	get_tree().change_scene_to_file(Game.SCENE_MENU)
	await frames(30)
	await shot("menu_con_sesion.png")
	Backend._clear_state()
	Backend._forget_session()
	get_tree().quit()
