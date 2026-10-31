## Autoload "Game": estado global de la partida y cambios de escena.
##   - Qué luchador eligió cada jugador y qué escenario se usa.
##   - Reglas del combate (rondas, tiempo).
##   - Resultado del último combate (para la pantalla de victoria y la revancha).
extends Node

const SCENE_MENU := "res://scenes/MainMenu.tscn"
const SCENE_SELECT := "res://scenes/CharacterSelect.tscn"
const SCENE_FIGHT := "res://scenes/Fight.tscn"
const SCENE_RESULTS := "res://scenes/Results.tscn"

const VERSION := "0.1.0"

# --- Configuración del combate ---
var p1_fighter_id: StringName = &"donald_trump"
var p2_fighter_id: StringName = &"napoleon"
var rounds_to_win: int = 2
var round_time: int = 99
## Tope de rondas para que una cadena de empates no sea infinita.
var max_rounds: int = 5

# --- Resultado del último combate ---
## 1 = gana P1, 2 = gana P2, 0 = empate.
var last_winner: int = 0
var last_p1_rounds: int = 0
var last_p2_rounds: int = 0

# --- Modos de juego ---
enum Mode { VERSUS, ARCADE }
enum Difficulty { EASY, NORMAL, HARD }

const DIFFICULTY_NAMES: Array[String] = ["FÁCIL", "NORMAL", "DIFÍCIL"]
## Nivel base de la IA (0..1) por dificultad; el arcade lo sube en cada combate.
const DIFFICULTY_LEVEL: Array[float] = [0.2, 0.5, 0.8]
const ARCADE_RIVALS := 6
const ARCADE_CONTINUES := 3

var mode: Mode = Mode.VERSUS
var difficulty: Difficulty = Difficulty.NORMAL
## Rivales del arcade en orden, el combate actual y las revanchas que quedan.
var arcade_ladder: Array[StringName] = []
var arcade_stage: int = 0
var arcade_continues: int = ARCADE_CONTINUES

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _changing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0.03, 0.02, 0.05, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)

func _exit_tree() -> void:
	# Las cachés estáticas retienen recursos; se liberan al salir.
	FighterRegistry.clear_cache()
	StageRegistry.clear_cache()
	HKTheme.clear_cache()

func p1_data() -> FighterData:
	return FighterRegistry.get_by_id(p1_fighter_id)

func p2_data() -> FighterData:
	return FighterRegistry.get_by_id(p2_fighter_id)

## Luchador cuyo escenario se usa en la ronda dada. En versus, la ronda 1
## es el escenario de P1, la 2 el de P2, y así alternando. En arcade, todas
## las rondas son en el escenario del rival.
func stage_owner(round_number: int) -> StringName:
	if mode == Mode.ARCADE:
		return p2_fighter_id
	return p1_fighter_id if round_number % 2 == 1 else p2_fighter_id

## Cambia de escena con un fundido a negro.
func goto(scene_path: String) -> void:
	if _changing:
		return
	_changing = true
	get_tree().paused = false
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.18)
	await tw.finished
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("No se pudo cargar la escena %s (error %d)" % [scene_path, err])
	var tw2 := create_tween()
	tw2.tween_property(_fade_rect, "color:a", 0.0, 0.22)
	await tw2.finished
	_changing = false

## Fundido a negro / desde negro (cambio de escenario entre rondas).
func fade_to_black(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, duration)
	await tw.finished

func fade_from_black(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 0.0, duration)
	await tw.finished

func is_changing_scene() -> bool:
	return _changing

func set_match_result(winner: int, p1_rounds: int, p2_rounds: int) -> void:
	last_winner = winner
	last_p1_rounds = p1_rounds
	last_p2_rounds = p2_rounds

# =========================================================================
#  Modo arcade (1 jugador contra la CPU)
# =========================================================================
## true si P2 lo maneja la CPU.
func is_vs_cpu() -> bool:
	return mode == Mode.ARCADE

func cycle_difficulty() -> void:
	difficulty = ((int(difficulty) + 1) % DIFFICULTY_NAMES.size()) as Difficulty

func difficulty_name() -> String:
	return DIFFICULTY_NAMES[difficulty]

## Nivel de la IA (0..1): base de la dificultad + 0.04 por combate superado.
func ai_level() -> float:
	var level := DIFFICULTY_LEVEL[difficulty]
	if mode == Mode.ARCADE:
		level += arcade_stage * 0.04
	return clampf(level, 0.0, 1.0)

## Empieza un arcade nuevo: rivales al azar (sin repetir ni incluir al jugador).
func start_arcade(player_id: StringName) -> void:
	mode = Mode.ARCADE
	p1_fighter_id = player_id
	var others: Array[StringName] = []
	for d in FighterRegistry.all():
		if d.id != player_id:
			others.append(d.id)
	others.shuffle()
	arcade_ladder.clear()
	for i in mini(ARCADE_RIVALS, others.size()):
		arcade_ladder.append(others[i])
	arcade_stage = 0
	arcade_continues = ARCADE_CONTINUES
	if not arcade_ladder.is_empty():
		p2_fighter_id = arcade_ladder[0]

## Qué toca tras el último combate:
##   next = siguiente rival · complete = arcade ganado
##   retry = repetir rival gastando una revancha · over = sin revanchas
func arcade_outcome() -> StringName:
	if last_winner == 1:
		return &"complete" if arcade_stage >= arcade_ladder.size() - 1 else &"next"
	return &"retry" if arcade_continues > 0 else &"over"

func arcade_advance() -> void:
	arcade_stage = mini(arcade_stage + 1, arcade_ladder.size() - 1)
	p2_fighter_id = arcade_ladder[arcade_stage]

func arcade_use_continue() -> void:
	arcade_continues = maxi(arcade_continues - 1, 0)
