## Autoload "Game": estado global de la partida y cambios de escena.
##   - Qué luchador eligió cada jugador y qué escenario se usa.
##   - Reglas del combate (rondas, tiempo).
##   - Resultado del último combate (para la pantalla de victoria y la revancha).
extends Node

const SCENE_LOGIN := "res://scenes/Login.tscn"
const SCENE_MENU := "res://scenes/MainMenu.tscn"
const SCENE_SELECT := "res://scenes/CharacterSelect.tscn"
const SCENE_FIGHT := "res://scenes/Fight.tscn"
const SCENE_RESULTS := "res://scenes/Results.tscn"
const SCENE_CONTROLS := "res://scenes/Controls.tscn"
const SCENE_LOBBY := "res://scenes/OnlineLobby.tscn"
const SCENE_PROFILE := "res://scenes/Profile.tscn"
const SCENE_RANKING := "res://scenes/Ranking.tscn"
const SCENE_AVATAR := "res://scenes/AvatarPicker.tscn"
const SCENE_SETTINGS := "res://scenes/Settings.tscn"
const SCENE_PLAYER := "res://scenes/PlayerProfile.tscn"
const SCENE_EDIT_PROFILE := "res://scenes/EditProfile.tscn"
const SCENE_ACHIEVEMENTS := "res://scenes/Achievements.tscn"
const SCENE_FRIENDS := "res://scenes/Friends.tscn"
const SCENE_ROSTER := "res://scenes/Roster.tscn"
const SCENE_CREDITS := "res://scenes/Credits.tscn"
const SCENE_STORY := "res://scenes/Story.tscn"
const SCENE_STORY_SAVES := "res://scenes/StorySaves.tscn"
const SCENE_STORY_ENDING :="res://scenes/StoryEnding.tscn"

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
## VERSUS: dos jugadores en el mismo equipo. No está en el menú: solo lo usan las pruebas y las herramientas.
## TRAINING: modo entrenamiento (muñeco, vida infinita y frame data; ver training_mode.gd).
## ONLINE: duelo contra otra persona por internet (ver online.gd).
enum Mode { VERSUS, ARCADE, TRAINING, ONLINE }
enum Difficulty { EASY, NORMAL, HARD }

const DIFFICULTY_NAMES: Array[String] = ["FÁCIL", "NORMAL", "DIFÍCIL"]
## Nivel base de la IA (0..1) por dificultad; el arcade lo sube en cada combate.
const DIFFICULTY_LEVEL: Array[float] = [0.2, 0.5, 0.8]
## Las revanchas del modo Historia son ilimitadas: perder nunca termina la partida.
## La constante solo se conserva por compatibilidad con partidas guardadas; el contador de revanchas
## gastadas (story_continues_used) sigue alimentando las reacciones del Nexo.
const ARCADE_CONTINUES := 3
## Jefe final: el Nexo cierra la escalera tras la última época.
const STORY_NEXO_ID := FighterRegistry.NEXO_ID
## Contenido narrativo (épocas, jefes, creadores y frases): ver StoryCampaign.
const STORY_NEXO_NAME := StoryCampaign.NEXO_NAME
const STORY_CHAPTERS := StoryCampaign.CHAPTERS
const STORY_BOSSES := StoryCampaign.BOSSES
const STORY_CREATORS: Array[StringName] = StoryCampaign.CREATORS
const STORY_NEXO_LINES := StoryCampaign.NEXO_LINES
const STORY_NEXO_REACT_FLAWLESS := StoryCampaign.NEXO_REACT_FLAWLESS
const STORY_NEXO_REACT_WOUNDED := StoryCampaign.NEXO_REACT_WOUNDED
const STORY_NEXO_REACT_WORN := StoryCampaign.NEXO_REACT_WORN
## Refuerzo [vida, fuerza, resistencia] del jefe de cada época.
const BOSS_BOOST := [1.12, 1.05, 1.0]
## Refuerzo del Nexo, el jefe final (sus fases lo suben aún más durante el combate).
const NEXO_BOOST := [1.5, 1.1, 1.05]

var mode: Mode = Mode.VERSUS
var difficulty: Difficulty = Difficulty.NORMAL
## Modo Historia (Mode.ARCADE): rivales en orden de la línea del tiempo, el combate actual
## y las revanchas que quedan en el capítulo.
var arcade_ladder: Array[StringName] = []
var arcade_stage: int = 0
var arcade_continues: int = ARCADE_CONTINUES
## Revanchas gastadas en toda la partida.
var story_continues_used: int = 0
## Veces que un creador del Reloj te venció: con 0 se abre el final oculto (liberarlos sin que te venzan).
## Solo vale durante la sesión: el servidor guarda la partida con un esquema cerrado (sin este campo), así que
## al retomar una partida guardada vuelve a 0.
var story_creator_losses: int = 0
## Verdadero al llegar a la pantalla de la historia desde la posesión: el combate sigue solo tras la escena.
var story_possessed_entry: bool = false
## Fichas reforzadas de los jefes (se crean una vez por combate).
var _boss_cache := {}

# --- Efectos ---
## Sangre de los golpes fuertes: estrellitas y sudor (por defecto), roja o ninguna.
enum Gore { SOFT, RED, OFF }
const GORE_NAMES: Array[String] = ["SUAVE", "ROJA", "NO"]
var gore: Gore = Gore.SOFT

func cycle_gore() -> void:
	gore = ((int(gore) + 1) % GORE_NAMES.size()) as Gore

func gore_name() -> String:
	return GORE_NAMES[gore]

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _changing: bool = false
## true solo mientras se funde a negro: otro goto() en ese tramo se ignora.
var _fading_out: bool = false
var _fade_in: Tween

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
	get_tree().node_added.connect(_on_node_added)

## El botón bajo el ratón recibe el foco: así solo hay uno resaltado, lo mueva el teclado, el mando o el ratón.
func _on_node_added(node: Node) -> void:
	var b := node as Button
	if b != null:
		b.mouse_entered.connect(_focus_hovered.bind(b))

func _focus_hovered(b: Button) -> void:
	if b.disabled or b.focus_mode == Control.FOCUS_NONE or b.has_focus() or not b.is_visible_in_tree():
		return
	# Escribiendo en un campo, pasar el ratón por un botón no debe quitarle el foco.
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	b.grab_focus()

func _exit_tree() -> void:
	# Las cachés estáticas retienen recursos; se liberan al salir.
	FighterRegistry.clear_cache()
	StageRegistry.clear_cache()
	HKTheme.clear_cache()

func p1_data() -> FighterData:
	return FighterRegistry.get_by_id(p1_fighter_id)

func p2_data() -> FighterData:
	var base := FighterRegistry.get_by_id(p2_fighter_id)
	if mode != Mode.ARCADE or arcade_ladder.is_empty():
		return base
	var boost := _boss_boost()
	if boost.is_empty():
		return base
	var key := "%s:%d" % [p2_fighter_id, arcade_stage]
	if not _boss_cache.has(key):
		var d := base.duplicate() as FighterData
		d.max_health *= boost[0]
		d.strength *= boost[1]
		d.resistance *= boost[2]
		_boss_cache[key] = d
	return _boss_cache[key]

## Refuerzo del rival actual del modo Historia (vacío = ninguno).
func _boss_boost() -> Array:
	if is_story_nexo_fight():
		return NEXO_BOOST
	if story_is_chapter_boss(arcade_stage) or story_is_creator(arcade_stage):
		return BOSS_BOOST
	return []

## Luchador cuyo escenario se usa en la ronda dada. En versus, la ronda 1
## es el escenario de P1, la 2 el de P2, y así alternando. En el modo Historia (arcade), todas las
## rondas son en la ciudad invadida con el ejército del rival ("city:<id>"), salvo el Nexo, que
## pelea en su propia Torre del Reloj.
func stage_owner(round_number: int) -> StringName:
	if mode == Mode.ARCADE:
		if is_story_nexo_fight():
			return p2_fighter_id
		return StringName(StageDefsCity.PREFIX + String(p2_fighter_id))
	return p1_fighter_id if round_number % 2 == 1 else p2_fighter_id

## Reto entre amigos en curso: código de la sala privada y nombre del amigo ("" = ninguno: cola pública).
var challenge_code: String = ""
var challenge_opponent: String = ""

## Deja el reto en curso (salir de la selección o de la sala): avisa a la cuenta para que el amigo no lo siga viendo.
func drop_challenge() -> void:
	if challenge_code != "":
		Backend.cancel_challenge(challenge_code)   # sin esperar: si falla, caduca solo
	challenge_code = ""
	challenge_opponent = ""

## Perfil de otro jugador que se está viendo y escena a la que vuelve VOLVER.
var viewed_player: String = ""
var viewed_return: String = SCENE_RANKING
## Filtros del ranking (se conservan al abrir un perfil o elegir luchador y volver): AMIGOS, últimos 7 días y luchador.
var ranking_friends: bool = false
var ranking_week: bool = false
var ranking_fighter: String = ""
## Para qué se abre la rejilla de luchadores (AvatarPicker): "avatar" o "ranking" (filtro por luchador).
var picker_purpose: String = "avatar"

## Abre el perfil de un jugador; VOLVER regresa a `back_scene`.
func view_player(player_name: String, back_scene: String) -> void:
	viewed_player = player_name
	viewed_return = back_scene
	goto(SCENE_PLAYER)

## A dónde vuelve VOLVER en la pantalla recién abierta: la que la abrió, si lo indicó en `goto` ("" = el menú).
var back_scene: String = ""

func back_target() -> String:
	return back_scene if back_scene != "" else SCENE_MENU

## Cambia de escena con un fundido a negro; `back_to` es la escena a la que vuelve su botón VOLVER.
## Una escena que redirige en cuanto carga (p. ej. el login sin cuentas, con el servidor
## local respondiendo en milisegundos) llama aquí durante el fundido de entrada: ese
## fundido se corta y se encadena el nuevo cambio en vez de ignorarlo.
func goto(scene_path: String, back_to: String = "") -> void:
	if _fading_out:
		return
	back_scene = back_to
	_changing = true
	_fading_out = true
	if _fade_in:
		_fade_in.kill()
	get_tree().paused = false
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.18)
	await tw.finished
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("No se pudo cargar la escena %s (error %d)" % [scene_path, err])
	_fading_out = false
	var tw2 := create_tween()
	_fade_in = tw2
	tw2.tween_property(_fade_rect, "color:a", 0.0, 0.22)
	await tw2.finished
	if _fade_in == tw2:
		_fade_in = null
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

## true si P2 es una persona remota (duelo online).
func is_online() -> bool:
	return mode == Mode.ONLINE

## step = 1 sube de nivel y -1 baja (dando la vuelta).
func cycle_difficulty(step: int = 1) -> void:
	difficulty = posmod(int(difficulty) + step, DIFFICULTY_NAMES.size()) as Difficulty

func difficulty_name() -> String:
	return DIFFICULTY_NAMES[difficulty]

## Nivel de la IA (0..1): base de la dificultad + 0.04 por combate superado.
func ai_level() -> float:
	var level := DIFFICULTY_LEVEL[difficulty]
	if mode == Mode.ARCADE and not arcade_ladder.is_empty():
		if is_story_nexo_fight():
			return 1.0
		# Sube de forma pareja a lo largo de toda la escalera (hasta +0.5 al llegar al final).
		level += 0.5 * arcade_stage / maxf(arcade_ladder.size() - 1.0, 1.0)
	return clampf(level, 0.0, 1.0)

## Empieza el modo Historia: todos los luchadores menos el jugador,
## del más reciente al más antiguo.
func start_story(player_id: StringName) -> void:
	mode = Mode.ARCADE
	p1_fighter_id = player_id
	arcade_ladder = story_ladder_for(player_id)
	arcade_stage = 0
	arcade_continues = ARCADE_CONTINUES
	story_continues_used = 0
	story_creator_losses = 0
	_boss_cache.clear()
	if not arcade_ladder.is_empty():
		p2_fighter_id = arcade_ladder[0]

## La escalera del modo Historia para quien juega con `player_id` (sin tocar la partida en curso).
func story_ladder_for(player_id: StringName) -> Array[StringName]:
	var rivals: Array[FighterData] = []
	for d in FighterRegistry.all():
		# Solo rivales: los buenos (StoryCampaign.PLAYABLE_ONLY) no están en ninguna época.
		if d.id != player_id and _is_story_rival(d.id):
			rivals.append(d)
	rivals.sort_custom(_story_before)
	var ladder: Array[StringName] = []
	for d in rivals:
		ladder.append(d.id)
	ladder.append(STORY_NEXO_ID)
	return ladder

## Vencer a un rival en el modo Historia lo desbloquea para siempre (el Nexo no: es el final).
func story_record_win() -> void:
	if mode == Mode.ARCADE and p2_fighter_id != STORY_NEXO_ID:
		Unlocks.add("fighter", str(p2_fighter_id))

## Lo mínimo para retomar la partida (la escalera se recalcula con start_story al restaurar).
func story_snapshot() -> Dictionary:
	return {
		"fighter": str(p1_fighter_id),
		"stage": arcade_stage,
		"continues": arcade_continues,
		"continues_used": story_continues_used,
		"difficulty": int(difficulty),
	}

## Guarda la partida en curso (equipo y cuenta). Se llama al empezar y tras cada combate.
func story_autosave() -> void:
	Backend.save_story(story_snapshot())

## Guarda la partida como quedará al pasar al combate siguiente (sin avanzarlo todavía).
func story_autosave_next() -> void:
	var s := story_snapshot()
	var next_stage := mini(arcade_stage + 1, arcade_ladder.size() - 1)
	s["stage"] = next_stage
	if story_chapter_start(next_stage):
		s["continues"] = ARCADE_CONTINUES
	Backend.save_story(s)

## Guarda la partida como quedará al gastar una revancha (sin gastarla todavía).
func story_autosave_retry() -> void:
	var s := story_snapshot()
	s["continues_used"] = story_continues_used + 1
	Backend.save_story(s)

## Retoma una partida guardada. Devuelve false (sin tocar nada) si ya no es válida,
## por ejemplo si el luchador o el combate ya no existen en esta versión.
func story_resume(save: Dictionary) -> bool:
	var id := StringName(str(save.get("fighter", "")))
	var found := false
	for d in FighterRegistry.all():
		if d.id == id:
			found = true
	if not found:
		return false
	var diff := int(save.get("difficulty", Difficulty.NORMAL))
	if diff < 0 or diff >= DIFFICULTY_NAMES.size():
		return false
	var old_difficulty := difficulty
	start_story(id)
	var stage := int(save.get("stage", 0))
	if stage < 0 or stage >= arcade_ladder.size():
		difficulty = old_difficulty
		return false
	difficulty = diff as Difficulty
	arcade_stage = stage
	arcade_continues = clampi(int(save.get("continues", ARCADE_CONTINUES)), 0, ARCADE_CONTINUES)
	story_continues_used = maxi(int(save.get("continues_used", 0)), 0)
	p2_fighter_id = arcade_ladder[arcade_stage]
	return true

## ¿Sale este luchador como rival en alguna época del modo Historia?
func _is_story_rival(fighter_id: StringName) -> bool:
	for chapter in STORY_CHAPTERS:
		if (chapter[1] as Array).has(fighter_id):
			return true
	return false

## Orden de la escalera: por época del más reciente al más antiguo y, dentro de una, por año, salvo el jefe de la
## época (el último de los rivales) y el creador poseído, que cierra la época después de él.
func _story_before(a: FighterData, b: FighterData) -> bool:
	var ca := _chapter_of_id(a.id)
	var cb := _chapter_of_id(b.id)
	if ca != cb:
		return ca < cb
	var creator_a: bool = STORY_CREATORS.has(a.id)
	var creator_b: bool = STORY_CREATORS.has(b.id)
	if creator_a != creator_b:
		return creator_b
	var boss_a: bool = STORY_BOSSES.get(ca, &"") == a.id
	var boss_b: bool = STORY_BOSSES.get(cb, &"") == b.id
	if boss_a != boss_b:
		return boss_b
	return a.year > b.year

func _chapter_of_id(fighter_id: StringName) -> int:
	for i in STORY_CHAPTERS.size():
		if (STORY_CHAPTERS[i][1] as Array).has(fighter_id):
			return i
	return STORY_CHAPTERS.size() - 1

## Lo que dice el Nexo al abrir un capítulo que no es el primero (vacío en el primero).
func story_nexo_reaction() -> Array:
	if arcade_stage == 0:
		return []
	if story_continues_used == 0:
		return STORY_NEXO_REACT_FLAWLESS
	return STORY_NEXO_REACT_WOUNDED if story_continues_used <= 2 else STORY_NEXO_REACT_WORN

## Consejo de uno de los creadores del Reloj tras una derrota: [nombre, texto]. Rota de creador y de consejo
## según las revanchas gastadas, para que cada derrota enseñe algo distinto.
func story_defeat_tip() -> Array:
	var tips: Array = StoryCampaign.DEFEAT_TIPS
	var entry: Array = tips[story_continues_used % tips.size()]
	var list: Array = entry[1]
	var d := FighterRegistry.get_by_id(entry[0])
	return [d.short_name, list[(story_continues_used / tips.size()) % list.size()]]

## Época (índice en STORY_CHAPTERS) a la que pertenece un luchador.
func story_chapter_of(fighter_id: StringName) -> int:
	if fighter_id == STORY_NEXO_ID:
		return STORY_CHAPTERS.size()
	return _chapter_of_id(fighter_id)

## ¿El rival actual es el Nexo, el jefe final?
func is_story_nexo_fight() -> bool:
	return mode == Mode.ARCADE and p2_fighter_id == STORY_NEXO_ID

func story_chapter_name(chapter: int) -> String:
	return STORY_CHAPTERS[chapter][0] if chapter < STORY_CHAPTERS.size() else STORY_NEXO_NAME

## ¿El combate `stage` abre un capítulo nuevo?
func story_chapter_start(stage: int) -> bool:
	return stage == 0 or story_chapter_of(arcade_ladder[stage]) != story_chapter_of(arcade_ladder[stage - 1])

## ¿Es el último combate de su época (el creador poseído, o el jefe si no hay creador)?
func story_is_chapter_end(stage: int) -> bool:
	return stage >= arcade_ladder.size() - 1 or story_chapter_of(arcade_ladder[stage + 1]) != story_chapter_of(arcade_ladder[stage])

## ¿Es el jefe de la época? Es el último rival antes del creador poseído (o el último de la época si no hay creador).
func story_is_chapter_boss(stage: int) -> bool:
	if STORY_CREATORS.has(arcade_ladder[stage]):
		return false
	return story_is_chapter_end(stage) or story_possession_follows(stage)

## ¿Tras este combate el Nexo posee a un creador del Reloj, que pelea en la misma batalla?
func story_possession_follows(stage: int) -> bool:
	return mode == Mode.ARCADE and stage + 1 < arcade_ladder.size() and STORY_CREATORS.has(arcade_ladder[stage + 1]) \
		and story_chapter_of(arcade_ladder[stage + 1]) == story_chapter_of(arcade_ladder[stage])

## Se vuelve a la pantalla de la historia desde un combate ganado al jefe, sin pasar por los resultados:
## el creador poseído entra y sigue la pelea. Hace lo mismo que los resultados al ganar (guardar y desbloquear).
func story_possession_begin() -> void:
	story_record_win()
	story_autosave_next()
	arcade_advance()
	story_possessed_entry = true
	goto(SCENE_STORY)

## ¿Ya se recuperó el fragmento del Reloj de esa época? Se gana al vencer a su jefe: no hace falta guardarlo,
## sale de hasta dónde se ha llegado (arcade_stage).
func story_fragment_earned(chapter: int) -> bool:
	var boss_stage := -1
	for i in arcade_ladder.size():
		if story_chapter_of(arcade_ladder[i]) == chapter:
			boss_stage = i
	return boss_stage >= 0 and arcade_stage > boss_stage

## Cuántos fragmentos del Reloj lleva el jugador (de 0 a STORY_CHAPTERS.size()).
func story_fragments() -> int:
	var n := 0
	for c in STORY_CHAPTERS.size():
		if story_fragment_earned(c):
			n += 1
	return n

## ¿El combate `stage` es contra uno de los creadores del Reloj?
func story_is_creator(stage: int) -> bool:
	return STORY_CREATORS.has(arcade_ladder[stage])

## Qué toca tras el último combate:
##   next = siguiente rival
##   complete = historia ganada · retry = repetir rival gastando una revancha · over = sin revanchas
func arcade_outcome() -> StringName:
	if last_winner == 1:
		if arcade_stage < arcade_ladder.size() - 1:
			return &"next"
		return &"complete"
	return &"retry"

func arcade_advance() -> void:
	arcade_stage = mini(arcade_stage + 1, arcade_ladder.size() - 1)
	p2_fighter_id = arcade_ladder[arcade_stage]
	# Cada capítulo nuevo devuelve las revanchas.
	if story_chapter_start(arcade_stage):
		arcade_continues = ARCADE_CONTINUES

func arcade_use_continue() -> void:
	if story_is_creator(arcade_stage):
		story_creator_losses += 1
	story_continues_used += 1
