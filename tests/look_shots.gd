## Captura el aspecto de los luchadores en fila (requiere renderizado real, no --headless).
## Uso: godot --path . res://tests/LookShots.tscn -- <carpeta> [id1,id2,...]
## Sin lista: mujeres y luchadores con rasgos propios, en dos imágenes.
extends Node

const GROUPS := [
	["cleopatra", "isabel_ii", "marie_curie", "janequeo", "boudica", "juana_de_arco", "napoleon", "donald_trump"],
	["augusto_pinochet", "salvador_allende", "papa_francisco", "ivan_el_terrible", "pachacutec", "lautaro", "julio_cesar", "rasputin"],
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "user://look_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	get_tree().current_scene = null
	var groups: Array = GROUPS
	if args.size() > 1:
		groups = [Array(args[1].split(","))]
	_run.call_deferred(dir, groups)

func _run(dir: String, groups: Array) -> void:
	var gi := 0
	for ids in groups:
		var bg := ColorRect.new()
		bg.color = Color("5a3a4a")
		bg.size = Vector2(426, 240)
		add_child(bg)
		var holders: Array[Node] = [bg]
		var n: int = ids.size()
		for i in n:
			var r := FighterRenderer.new()
			add_child(r)
			r.setup(FighterRegistry.get_by_id(StringName(ids[i])))
			r.pose_name = &"idle"
			r.position = Vector2(26 + i * (374.0 / maxf(n - 1, 1)), 150)
			r.scale = Vector2(1.6, 1.6)
			holders.append(r)
		for k in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir.path_join("look_%d.png" % gi))
		print("captura: look_%d.png" % gi)
		for h in holders:
			h.queue_free()
		await get_tree().process_frame
		gi += 1
	get_tree().quit()
