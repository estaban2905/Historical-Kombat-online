## Captura cada poder especial en pleno combate (requiere renderizado real, no --headless).
## Uso: godot --path . res://tests/PowerScreenshots.tscn -- <carpeta_salida> [id1,id2,...]
## Sin lista de ids captura una selección de poderes representativos.
extends Node

# [lanzador, rival, frames hasta la captura]
const DEFAULTS := {
	"donald_trump": ["napoleon", 40],
	"xi_jinping": ["napoleon", 50],
	"napoleon": ["donald_trump", 38],
	"cristobal_colon": ["napoleon", 55],
	"julio_cesar": ["napoleon", 70],
	"cleopatra": ["donald_trump", 36],
	"leonardo_da_vinci": ["napoleon", 55],
	"charles_darwin": ["napoleon", 36],
	"gengis_kan": ["napoleon", 50],
	"albert_einstein": ["napoleon", 36],
}

var out_dir: String = "user://power_shots"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	get_tree().current_scene = null
	_run.call_deferred(args[1].split(",") if args.size() > 1 else PackedStringArray(DEFAULTS.keys()))

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run(ids: PackedStringArray) -> void:
	var idx := 0
	for id in ids:
		var info: Array = DEFAULTS.get(id, ["napoleon", 45])
		Game.p1_fighter_id = StringName(id)
		Game.p2_fighter_id = StringName(info[0])
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
		await frames(info[1])
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png(out_dir.path_join("%02d_%s.png" % [idx, id]))
		print("captura: ", id)
		idx += 1
	get_tree().quit()
