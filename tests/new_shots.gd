## Captura los poderes y escenarios de los personajes nuevos (requiere renderizado real).
## Uso: godot --path . res://tests/NewShots.tscn -- <carpeta> [id1,id2,...]
extends Node

const NEW := ["janequeo", "lautaro", "pachacutec", "ivan_el_terrible", "boudica", "juana_de_arco",
	"augusto_pinochet", "salvador_allende", "arturo_prat", "socrates", "platon", "aristoteles", "sun_tzu",
	"confucio", "isaac_newton", "hernan_cortes", "moctezuma_ii", "nicolas_maquiavelo", "mariya_oktyabrskaya",
	"liudmila_pavlichenko"]
const FRAMES := {"janequeo": 36, "lautaro": 45, "pachacutec": 44, "ivan_el_terrible": 46, "boudica": 45,
	"juana_de_arco": 40, "augusto_pinochet": 36, "salvador_allende": 30, "arturo_prat": 40,
	"socrates": 40, "platon": 44, "aristoteles": 36, "sun_tzu": 34, "confucio": 40, "isaac_newton": 50,
	"hernan_cortes": 44, "moctezuma_ii": 40, "nicolas_maquiavelo": 40, "mariya_oktyabrskaya": 50,
	"liudmila_pavlichenko": 40}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var dir := args[0] if args.size() > 0 else "user://new_shots"
	DirAccess.make_dir_recursive_absolute(dir)
	get_tree().current_scene = null
	_run.call_deferred(dir, args[1].split(",") if args.size() > 1 else PackedStringArray(NEW))

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run(dir: String, ids: PackedStringArray) -> void:
	for id in ids:
		Game.p1_fighter_id = StringName(id)
		Game.p2_fighter_id = &"napoleon"
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
		c.set_controls(true)
		c.p1.input.press(&"special_2")
		await frames(FRAMES.get(id, 40))
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		img.save_png(dir.path_join("%s.png" % id))
		print("captura: ", id)
	get_tree().quit()
