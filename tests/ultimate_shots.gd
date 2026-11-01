## Captura el ultimate de varios luchadores (cinemática, lanzamiento y efectos de pantalla).
## Requiere renderizado real (no --headless).
## Uso: godot --path . res://tests/UltimateShots.tscn -- <carpeta> [id1,id2,...] [rival]
extends Node

const DEFAULTS := ["kim_jong_un", "gengis_kan", "joseph_stalin", "nikola_tesla", "jesus_de_nazaret",
	"nicolas_maduro", "vladimir_putin", "saddam_hussein", "osama_bin_laden"]
## Fotogramas (tras pulsar) en los que se captura.
const SHOT_FRAMES := [20, 100, 140, 190]

var out_dir: String = "user://ultimate_shots"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().current_scene = null
	var ids: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray(DEFAULTS)
	_run.call_deferred(ids, args[2] if args.size() > 2 else "napoleon")

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run(ids: PackedStringArray, defender: String) -> void:
	for id in ids:
		Game.p1_fighter_id = StringName(id)
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
		c.p2.position.x = 235
		c.p1.energy = 100
		await frames(3)
		c.p1.input.press(&"special_1")
		c.p1.input.press(&"special_2")
		var done := 0
		for f in SHOT_FRAMES:
			await frames(f - done)
			done = f
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(out_dir.path_join("%s_%d.png" % [id, f]))
		print("captura: ", id)
	get_tree().quit()
