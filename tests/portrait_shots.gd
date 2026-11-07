## Retratos transparentes de TODOS los luchadores (requiere renderizado real, no --headless).
## Uso: godot --path . res://tests/PortraitShots.tscn -- <carpeta> [id1,id2,...]
extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "user://portraits"
	DirAccess.make_dir_recursive_absolute(dir)
	get_tree().current_scene = null
	var ids: Array = []
	if args.size() > 1:
		ids = Array(args[1].split(","))
	else:
		for d in FighterRegistry.all():
			ids.append(str(d.id))
		ids.append("el_nexo")
	_run.call_deferred(dir, ids)

func _run(dir: String, ids: Array) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 760)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	for id in ids:
		var r := FighterRenderer.new()
		vp.add_child(r)
		r.setup(FighterRegistry.get_by_id(StringName(id)))
		r.pose_name = &"idle"
		r.position = Vector2(320, 730)
		r.scale = Vector2(6.0, 6.0)
		for k in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(dir.path_join("%s.png" % id))
		print("retrato: ", id)
		r.queue_free()
		await get_tree().process_frame
	get_tree().quit()
