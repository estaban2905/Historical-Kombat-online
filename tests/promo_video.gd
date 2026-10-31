## Vídeo promocional: título, varios combates de la CPU contra sí misma y cierre.
## Se graba con el modo Movie Maker de Godot (renderizado real, no --headless):
##   godot --path . res://tests/PromoVideo.tscn --write-movie promo.avi --resolution 1280x720
## Después se puede convertir con ffmpeg (ver tools/ o el README del vídeo).
extends Node

## [luchador 1, luchador 2, velocidad de la intro (1 = normal), ticks de pelea, ¿termina en K.O.?]
const CLIPS: Array = [
	[&"napoleon", &"julio_cesar", 1.0, 330, true],
	[&"cleopatra", &"gengis_kan", 0.25, 300, false],
	[&"nikola_tesla", &"marie_curie", 0.25, 300, true],
	[&"alejandro_magno", &"abraham_lincoln", 0.25, 330, true],
]
const AI_LEVEL := 0.9

var combat: CombatManager
var ai1: AIController
var ai2: AIController

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	# Que ninguna ronda termine la partida y cambie de escena.
	Game.mode = Game.Mode.VERSUS
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	_run.call_deferred()

func _physics_process(_delta: float) -> void:
	if combat and is_instance_valid(combat):
		ai1.think()
		ai2.think()

func _run() -> void:
	await _title_card("30 LUCHADORES · ARCADE · VERSUS", 3.0, &"napoleon", &"donald_trump")
	for clip in CLIPS:
		await _play_clip(clip)
	await _title_card("UN ESCENARIO Y PODERES PROPIOS POR LUCHADOR", 3.5, &"cleopatra", &"gengis_kan")
	await Game.fade_to_black(0.4)
	get_tree().quit()

# --------------------------------------------------------------------------
func _play_clip(clip: Array) -> void:
	Game.p1_fighter_id = clip[0]
	Game.p2_fighter_id = clip[1]
	combat = load(Game.SCENE_FIGHT).instantiate() as CombatManager
	combat.get_node("RoundManager").pause_scale = clip[2]
	add_child(combat)
	for f in combat.fighters:
		f.input.use_keyboard = false
	ai1 = AIController.new(combat.p1, combat.p2, AI_LEVEL)
	ai2 = AIController.new(combat.p2, combat.p1, AI_LEVEL)
	Game.fade_from_black(0.2)
	while combat.round_manager.phase != RoundManager.Phase.FIGHT:
		await get_tree().physics_frame
	var start := combat.tick_count
	var ko_forced := false
	while combat.tick_count - start < clip[3]:
		await get_tree().physics_frame
		var t := combat.tick_count - start
		# Energía llena de vez en cuando para que se vean los poderes especiales.
		if t % 80 == 20:
			for f in combat.fighters:
				f.add_energy(100.0)
		# Para acabar en K.O.: el rival más débil queda tocado a mitad del clip.
		if clip[4] and not ko_forced and t > clip[3] * 0.55:
			ko_forced = true
			combat.p2.health = minf(combat.p2.health, 14.0)
			combat.p2.health_changed.emit(combat.p2)
	if clip[4]:
		# Deja que el K.O. ocurra y se vea la celebración.
		var guard := 0
		while combat.round_manager.phase == RoundManager.Phase.FIGHT and guard < 240:
			guard += 1
			await get_tree().physics_frame
		for i in 100:
			await get_tree().physics_frame
	await Game.fade_to_black(0.2)
	var old := combat
	combat = null
	remove_child(old)
	old.queue_free()

func _title_card(subtitle: String, seconds: float, left_id: StringName, right_id: StringName) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = HKTheme.theme()
	var bg := Control.new()
	bg.set_script(load("res://scripts/ui/menu_background.gd"))
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.set("title_y", 50.0)
	root.add_child(bg)
	for side in [[left_id, 62.0, 1.0], [right_id, 364.0, -1.0]]:
		var r := FighterRenderer.new()
		root.add_child(r)
		r.setup(FighterRegistry.get_by_id(side[0]))
		r.position = Vector2(side[1], 226)
		r.scale.x = side[2]
	var label := Label.new()
	label.text = subtitle
	label.position = Vector2(0, 150)
	label.size = Vector2(426, 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", HKTheme.GOLD)
	root.add_child(label)
	add_child(root)
	Game.fade_from_black(0.3)
	await get_tree().create_timer(seconds, true).timeout
	await Game.fade_to_black(0.25)
	remove_child(root)
	root.queue_free()
