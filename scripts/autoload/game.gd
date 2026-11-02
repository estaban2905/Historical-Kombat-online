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
const SCENE_ROSTER := "res://scenes/Roster.tscn"
const SCENE_CREDITS := "res://scenes/Credits.tscn"
const SCENE_STORY := "res://scenes/Story.tscn"

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
## TRAINING: modo entrenamiento (muñeco, vida infinita y frame data; ver training_mode.gd).
## ONLINE: duelo contra otra persona por internet (ver online.gd).
enum Mode { VERSUS, ARCADE, TRAINING, ONLINE }
enum Difficulty { EASY, NORMAL, HARD }

const DIFFICULTY_NAMES: Array[String] = ["FÁCIL", "NORMAL", "DIFÍCIL"]
## Nivel base de la IA (0..1) por dificultad; el arcade lo sube en cada combate.
const DIFFICULTY_LEVEL: Array[float] = [0.2, 0.5, 0.8]
## Revanchas por capítulo del modo Historia (se recuperan al empezar cada capítulo).
const ARCADE_CONTINUES := 3
## Jefe secreto: aparece tras el último capítulo si se llega sin gastar ninguna revancha.
const STORY_SECRET_ID := &"jesus_de_nazaret"
## Capítulos de la línea del tiempo, del más reciente al más antiguo: [nombre, año mínimo].
const STORY_CHAPTERS := [
	["EL MUNDO ACTUAL", 1940],
	["EL SIGLO XX", 1880],
	["CIENCIA E INDUSTRIA", 1800],
	["IMPERIOS Y DESCUBRIMIENTOS", 1400],
	["LA ANTIGÜEDAD", -100000],
]
const STORY_SECRET_NAME := "EL ÚLTIMO SECRETO"
## Los creadores del Reloj del Origen cierran su capítulo: capítulo (índice) -> luchador.
## Tesla y Curie, del mismo capítulo que Einstein, lo preceden como guardianes.
const STORY_BOSSES := {2: &"albert_einstein", 3: &"leonardo_da_vinci"}
## Palabras del Nexo al abrir cada capítulo (la última, para el jefe secreto).
const STORY_NEXO_LINES := [
	["LOS LÍDERES DE HOY CREEN", "QUE EL TIEMPO LES PERTENECE."],
	["UN SIGLO DE GUERRAS Y GRITOS.", "EL TIEMPO AÚN SANGRA."],
	["AQUÍ NACIÓ LA GRIETA: LAS MENTES", "QUE ARMARON EL RELOJ DEL ORIGEN."],
	["REINOS, FLOTAS Y CORONAS.", "DEMASIADO PODER, POCA MEMORIA."],
	["EL ORIGEN. AQUÍ EMPEZÓ TODO", "Y AQUÍ DECIDIRÁS CÓMO TERMINA."],
	["NO TODO LO QUE BRILLA ESTÁ VENCIDO.", "ÉL ESPERA DONDE EL TIEMPO NACE."],
]
## Frases antes del combate: rival -> [línea 1, línea 2].
const STORY_VS := {
	&"albert_einstein": ["JEFE: CREÓ EL RELOJ", "Y TEME SU PRECIO."],
	&"leonardo_da_vinci": ["JEFE: DISEÑÓ EL MECANISMO", "DEL RELOJ DEL ORIGEN."],
	&"nikola_tesla": ["GUARDIÁN: SU CORRIENTE", "ALIMENTÓ LA MÁQUINA."],
	&"marie_curie": ["GUARDIANA: SU LUZ", "ENCENDIÓ EL NÚCLEO."],
	&"salvador_allende": ["CAYÓ EN LA MONEDA.", "AQUÍ PELEA DE PIE."],
	&"augusto_pinochet": ["SE LLEVÓ EL PODER A LA FUERZA.", "AQUÍ NO HAY CUARTEL."],
	&"moctezuma_ii": ["SU IMPERIO CAYÓ ANTE", "UN PUÑADO DE ESPADAS."],
	&"hernan_cortes": ["CONQUISTÓ UN IMPERIO", "CON AUDACIA Y ACERO."],
	&"cristobal_colon": ["CRUZÓ EL OCÉANO", "Y CAMBIÓ EL MAPA."],
	&"lautaro": ["EL TOQUI QUE ENSEÑÓ", "A VENCER A CABALLO."],
	&"juana_de_arco": ["OYÓ VOCES Y LIDERÓ", "UN EJÉRCITO."],
	&"napoleon": ["CORONÓ SU PROPIO IMPERIO", "CON SUS MANOS."],
	&"gengis_kan": ["SU HORDA CRUZÓ", "MEDIO MUNDO."],
	&"cleopatra": ["LA ÚLTIMA FARAONA.", "SU ASTUCIA AFILA SU DAGA."],
	&"julio_cesar": ["LLEGÓ, VIO...", "Y VENCERÁ."],
	&"alejandro_magno": ["NUNCA PERDIÓ UNA BATALLA.", "NO EMPEZARÁ AHORA."],
	&"sun_tzu": ["GANA SIN LUCHAR.", "TÚ LO ESTÁS HACIENDO MAL."],
	&"buda": ["LA PAZ INTERIOR", "TAMBIÉN GOLPEA."],
	&"adolf_hitler": ["SU IMPERIO DEBÍA DURAR MIL AÑOS.", "DURÓ DOCE."],
	&"joseph_stalin": ["ACERO EN EL NOMBRE.", "ACERO EN LOS PUÑOS."],
	&"donald_trump": ["EL ÚLTIMO EN LLEGAR", "SIEMPRE QUIERE LA CABECERA."],
}
## Refuerzo [vida, fuerza, resistencia] del jefe de cada capítulo y del jefe secreto.
const BOSS_BOOST := [1.12, 1.05, 1.0]
const SECRET_BOOST := [1.6, 1.25, 1.1]

var mode: Mode = Mode.VERSUS
var difficulty: Difficulty = Difficulty.NORMAL
## Modo Historia (Mode.ARCADE): rivales en orden de la línea del tiempo, el combate actual
## y las revanchas que quedan en el capítulo.
var arcade_ladder: Array[StringName] = []
var arcade_stage: int = 0
var arcade_continues: int = ARCADE_CONTINUES
## Revanchas gastadas en toda la partida (si es 0 al final, aparece el jefe secreto).
var story_continues_used: int = 0
## true cuando el jefe secreto ya se añadió a la escalera.
var story_secret: bool = false
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
	if is_story_secret_fight():
		return SECRET_BOOST
	if story_is_chapter_boss(arcade_stage):
		return BOSS_BOOST
	return []

## Luchador cuyo escenario se usa en la ronda dada. En versus, la ronda 1
## es el escenario de P1, la 2 el de P2, y así alternando. En arcade, todas
## las rondas son en el escenario del rival.
func stage_owner(round_number: int) -> StringName:
	if mode == Mode.ARCADE:
		return p2_fighter_id
	return p1_fighter_id if round_number % 2 == 1 else p2_fighter_id

## Cambia de escena con un fundido a negro.
## Una escena que redirige en cuanto carga (p. ej. el login sin cuentas, con el servidor
## local respondiendo en milisegundos) llama aquí durante el fundido de entrada: ese
## fundido se corta y se encadena el nuevo cambio en vez de ignorarlo.
func goto(scene_path: String) -> void:
	if _fading_out:
		return
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
		if is_story_secret_fight():
			return 1.0
		# Sube de forma pareja a lo largo de toda la escalera (hasta +0.5 al llegar al final).
		level += 0.5 * arcade_stage / maxf(arcade_ladder.size() - 1.0, 1.0)
	return clampf(level, 0.0, 1.0)

## Empieza el modo Historia: todos los luchadores menos el jugador (y el jefe secreto),
## del más reciente al más antiguo.
func start_story(player_id: StringName) -> void:
	mode = Mode.ARCADE
	p1_fighter_id = player_id
	var rivals: Array[FighterData] = []
	for d in FighterRegistry.all():
		if d.id != player_id and d.id != STORY_SECRET_ID:
			rivals.append(d)
	rivals.sort_custom(_story_before)
	arcade_ladder.clear()
	for d in rivals:
		arcade_ladder.append(d.id)
	arcade_stage = 0
	arcade_continues = ARCADE_CONTINUES
	story_continues_used = 0
	story_secret = false
	_boss_cache.clear()
	if not arcade_ladder.is_empty():
		p2_fighter_id = arcade_ladder[0]

## Orden de la escalera: por capítulo del más reciente al más antiguo y, dentro de uno,
## por año, salvo el jefe designado del capítulo, que va al final.
func _story_before(a: FighterData, b: FighterData) -> bool:
	var ca := _year_chapter(a.year)
	var cb := _year_chapter(b.year)
	if ca != cb:
		return ca < cb
	var boss_a: bool = STORY_BOSSES.get(ca, &"") == a.id
	var boss_b: bool = STORY_BOSSES.get(cb, &"") == b.id
	if boss_a != boss_b:
		return boss_b
	return a.year > b.year

func _year_chapter(year: int) -> int:
	for i in STORY_CHAPTERS.size():
		if year >= STORY_CHAPTERS[i][1]:
			return i
	return STORY_CHAPTERS.size() - 1

## Frase de presentación del rival actual (vacía si no tiene).
func story_vs_lines(fighter_id: StringName) -> Array:
	return STORY_VS.get(fighter_id, [])

## true si al ganar el último combate toca enfrentarse al jefe secreto.
func _secret_unlocked() -> bool:
	return not story_secret and p1_fighter_id != STORY_SECRET_ID and story_continues_used == 0 \
		and FighterRegistry.get_by_id(STORY_SECRET_ID).id == STORY_SECRET_ID

## ¿El rival actual es el jefe secreto?
func is_story_secret_fight() -> bool:
	return story_secret and arcade_stage == arcade_ladder.size() - 1

## Capítulo (índice en STORY_CHAPTERS) al que pertenece un luchador. El jefe secreto va aparte.
func story_chapter_of(fighter_id: StringName) -> int:
	if fighter_id == STORY_SECRET_ID and p1_fighter_id != STORY_SECRET_ID:
		return STORY_CHAPTERS.size()
	return _year_chapter(FighterRegistry.get_by_id(fighter_id).year)

func story_chapter_name(chapter: int) -> String:
	return STORY_CHAPTERS[chapter][0] if chapter < STORY_CHAPTERS.size() else STORY_SECRET_NAME

## ¿El combate `stage` abre un capítulo nuevo?
func story_chapter_start(stage: int) -> bool:
	return stage == 0 or story_chapter_of(arcade_ladder[stage]) != story_chapter_of(arcade_ladder[stage - 1])

## ¿Es el último combate de su capítulo (el jefe)?
func story_is_chapter_boss(stage: int) -> bool:
	return stage >= arcade_ladder.size() - 1 or story_chapter_of(arcade_ladder[stage + 1]) != story_chapter_of(arcade_ladder[stage])

## Qué toca tras el último combate:
##   next = siguiente rival · secret = tras el último rival aparece el jefe secreto
##   complete = historia ganada · retry = repetir rival gastando una revancha · over = sin revanchas
func arcade_outcome() -> StringName:
	if last_winner == 1:
		if arcade_stage < arcade_ladder.size() - 1:
			return &"next"
		return &"secret" if _secret_unlocked() else &"complete"
	return &"retry" if arcade_continues > 0 else &"over"

func arcade_advance() -> void:
	if arcade_stage >= arcade_ladder.size() - 1 and _secret_unlocked():
		story_secret = true
		arcade_ladder.append(STORY_SECRET_ID)
	arcade_stage = mini(arcade_stage + 1, arcade_ladder.size() - 1)
	p2_fighter_id = arcade_ladder[arcade_stage]
	# Cada capítulo nuevo devuelve las revanchas.
	if story_chapter_start(arcade_stage):
		arcade_continues = ARCADE_CONTINUES

func arcade_use_continue() -> void:
	arcade_continues = maxi(arcade_continues - 1, 0)
	story_continues_used += 1
