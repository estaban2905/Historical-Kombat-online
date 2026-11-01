## Captura la cinemática y el impacto del ultimate (requiere renderizado real, no --headless).
## Uso: godot --path . res://tests/UltimateShots.tscn -- <carpeta_salida> [id_lanzador] [id_rival]
extends Node

var out_dir: String = "user://ultimate_shots"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().current_scene = null
	_run.call_deferred(args[1] if args.size() > 1 else "napoleon", args[2] if args.size() > 2 else "donald_trump")

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(out_dir.path_join(file_name))
	print("captura: ", file_name)

func _run(attacker: String, defender: String) -> void:
	Game.p1_fighter_id = StringName(attacker)
	Game.p2_fighter_id = StringName(defender)
	get_tree().change_scene_to_file(Game.SCENE_FIGHT)
	for i in 120:
		await frames(1)
		if get_tree().current_scene is CombatManager:
			break
	var c := get_tree().current_scene as CombatManager
	while c.round_manager.phase != RoundManager.Phase.FIGHT:
		await frames(1)
	c.reset_round()
	c.p1.position.x = 150
	c.p2.position.x = 230
	c.p1.energy = 100
	await frames(3)
	await shot("0_listo.png")
	c.p1.input.press(&"special_1")
	c.p1.input.press(&"special_2")
	await frames(14)
	await shot("1_cinematica.png")
	await frames(c.cinematic_frames + 8)
	await shot("2_arranca.png")
	await frames(12)
	await shot("3_impacto.png")
	await frames(20)
	await shot("4_despues.png")
	get_tree().quit()
