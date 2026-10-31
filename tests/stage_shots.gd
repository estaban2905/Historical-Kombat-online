## Captura el escenario de cada luchador (requiere renderizado real, no --headless).
## Uso: godot --path . res://tests/StageShots.tscn -- <carpeta_salida> [id1 id2 ...]
extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "user://stage_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ids: Array[StringName] = []
	for i in range(1, args.size()):
		ids.append(StringName(args[i]))
	if ids.is_empty():
		for d in FighterRegistry.all():
			ids.append(d.id)
	get_tree().current_scene = null
	_run.call_deferred(out_dir, ids)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run(out_dir: String, ids: Array[StringName]) -> void:
	for id in ids:
		Game.mode = Game.Mode.VERSUS
		Game.p1_fighter_id = id
		Game.p2_fighter_id = id
		get_tree().change_scene_to_file(Game.SCENE_FIGHT)
		await frames(5)
		var c := get_tree().current_scene as CombatManager
		while c.round_manager.phase != RoundManager.Phase.FIGHT:
			await frames(1)
		await frames(40)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s.png" % id))
		print("captura: ", id)
	get_tree().quit()
