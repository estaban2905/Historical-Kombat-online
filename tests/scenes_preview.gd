## Ver las ESCENAS DE DIÁLOGO del Modo Historia, una tras otra, sin intro, sin globo y sin combatir.
##   godot --path . res://tests/ScenesPreview.tscn -- [--player=napoleon] [--scene=<id del rival>]
## Cada escena se ve como en el juego: la ciudad del rival, los dos luchadores y el diálogo con su voz.
##   ENTER        pasa a la frase siguiente (con voz, avanza sola al acabar)
##   → o N        salta a la escena siguiente      ← o P   vuelve a la anterior
##   ESC          cierra
## --scene=<id> empieza por esa escena (por ejemplo kim_jong_un, adolf_hitler, albert_einstein, el_nexo).
extends Node

const PLAYER_X := 80.0
const RIVAL_X := 346.0
const SPRITE_H := 96.0

var _player: StringName = &"napoleon"
var _ids: Array[StringName] = []
var _i: int = 0
var _ui: Control
var _dialogue: StoryDialogue
var _label: Label
var _changing: bool = false

func _ready() -> void:
	# Las vistas previas no guardan en la partida real del jugador.
	Backend.story_path = "user://story_preview.cfg"
	var only := &""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--player="):
			_player = StringName(arg.trim_prefix("--player="))
		elif arg.begins_with("--scene="):
			only = StringName(arg.trim_prefix("--scene="))
	Game.start_story(_player)
	for id in Game.arcade_ladder:
		if not StoryScenes.lines(id, _player).is_empty():
			_ids.append(id)
	if _ids.is_empty():
		push_error("No hay escenas")
		get_tree().quit()
		return
	if only != &"":
		var at := _ids.find(only)
		_i = maxi(at, 0)
		if at < 0:
			push_warning("No hay escena de %s; escenas: %s" % [only, _ids])
	print("%d escenas: %s" % [_ids.size(), _ids])
	_show(_i)

func _show(i: int) -> void:
	_changing = true
	_i = posmod(i, _ids.size())
	if _ui:
		_ui.queue_free()
	if _dialogue:
		_dialogue.queue_free()
	var id: StringName = _ids[_i]
	Game.arcade_stage = Game.arcade_ladder.find(id)
	Game.p2_fighter_id = id
	_ui = Control.new()
	_ui.theme = HKTheme.theme()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	var stage := _load_stage(Game.stage_owner(1))
	_add_fighter(Game.p1_data(), PLAYER_X, 1, stage)
	_add_fighter(Game.p2_data(), RIVAL_X, -1, stage)
	_label = Label.new()
	_label.position = Vector2(4, 2)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.text = "ESCENA %d/%d · %s  (← → cambia · ENTER sigue · ESC cierra)" % [_i + 1, _ids.size(), id]
	_ui.add_child(_label)
	_dialogue = StoryDialogue.new()
	_dialogue.lines = StoryScenes.lines(id, _player)
	_dialogue.scene_id = StoryScenes.scene_id(id, _player)
	_dialogue.finished.connect(func(): _show(_i + 1))
	add_child(_dialogue)
	_changing = false

func _load_stage(fighter_id: StringName) -> Stage:
	var packed := load(StageRegistry.scene_for(fighter_id)) as PackedScene
	if packed == null:
		packed = load(StageRegistry.COLOSSEUM)
	var stage := packed.instantiate() as Stage
	if stage is ThemedStage:
		(stage as ThemedStage).fighter_id = fighter_id
	stage.show_behind_parent = true
	_ui.add_child(stage)
	return stage

func _add_fighter(d: FighterData, x: float, facing: int, stage: Stage) -> void:
	var r := FighterRenderer.new()
	_ui.add_child(r)
	r.setup(d)
	r.pose_name = &"idle"
	var s := clampf(SPRITE_H / maxf(r.approx_height(), 1.0), 0.8, 1.5)
	r.scale = Vector2(s * facing, s)
	r.position = Vector2(x, stage.floor_y)

func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or _changing:
		return
	match k.keycode:
		KEY_RIGHT, KEY_N:
			_show(_i + 1)
		KEY_LEFT, KEY_P:
			_show(_i - 1)
		KEY_ESCAPE:
			get_tree().quit()
