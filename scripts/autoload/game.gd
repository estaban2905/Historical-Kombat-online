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
const SCENE_STORY_ENDING := "res://scenes/StoryEnding.tscn"

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
## Jefe final: el Nexo cierra la escalera tras la última época.
const STORY_NEXO_ID := FighterRegistry.NEXO_ID
const STORY_NEXO_NAME := "EL JUICIO DEL NEXO"
## Épocas (fragmentos del tiempo roto) del más reciente al más antiguo: [nombre, [luchadores]]. Cada una cierra con
## su jefe (STORY_BOSSES) y dentro de la época se ordenan por año.
const STORY_CHAPTERS := [
	["EL MUNDO ACTUAL", [&"kim_jong_un", &"nicolas_maduro", &"osama_bin_laden", &"xi_jinping", &"vladimir_putin",
		&"pablo_escobar", &"papa_francisco", &"isabel_ii", &"donald_trump"]],
	["EL SIGLO XX", [&"saddam_hussein", &"fidel_castro", &"liudmila_pavlichenko", &"augusto_pinochet",
		&"salvador_allende", &"mariya_oktyabrskaya", &"benito_mussolini", &"joseph_stalin", &"rasputin",
		&"albert_einstein", &"adolf_hitler"]],
	["REVOLUCIONES Y PROGRESO", [&"arturo_prat", &"abraham_lincoln", &"charles_darwin", &"nikola_tesla",
		&"marie_curie", &"napoleon"]],
	["IMPERIOS Y DESCUBRIMIENTOS", [&"isaac_newton", &"janequeo", &"galileo_galilei", &"lautaro", &"ivan_el_terrible",
		&"nicolas_maquiavelo", &"moctezuma_ii", &"leonardo_da_vinci", &"cristobal_colon", &"pachacutec",
		&"juana_de_arco", &"gengis_kan", &"hernan_cortes"]],
	["LA ANTIGÜEDAD", [&"boudica", &"jesus_de_nazaret", &"cleopatra", &"alejandro_magno", &"aristoteles", &"platon",
		&"socrates", &"sun_tzu", &"confucio", &"buda", &"julio_cesar"]],
]
## Jefe de cada época (índice -> luchador), el más controvertido de su tiempo; va al final.
const STORY_BOSSES := {0: &"donald_trump", 1: &"adolf_hitler", 2: &"napoleon", 3: &"hernan_cortes",
	4: &"julio_cesar"}
## Los cuatro creadores del Reloj del Origen, repartidos por las épocas.
const STORY_CREATORS: Array[StringName] = [&"nikola_tesla", &"albert_einstein", &"marie_curie", &"leonardo_da_vinci"]
## Lo que está en juego en cada fragmento del tiempo (la animación de la época ya trae la voz del Nexo).
const STORY_NEXO_LINES := [
	["EL FRAGMENTO MÁS JOVEN DEL TIEMPO.", "CIÉRRALO O SE ROMPERÁ TODO."],
	["LA GRIETA SIGUE ABIERTA.", "NO DEJES QUE SE LLEVE OTRO SIGLO."],
	["LAS IDEAS QUE ROMPIERON EL TIEMPO", "SIGUEN GIRANDO EN ESTE FRAGMENTO."],
	["CORONAS Y FLOTAS TIRAN DEL TIEMPO", "HACIA DIRECCIONES OPUESTAS."],
	["EL FRAGMENTO MÁS ANTIGUO.", "SI CAE, TODO LO DEMÁS SE DERRUMBA."],
	["SOLO YO SOSTENGO TODAS LAS ÉPOCAS.", "ESTA ES LA PRUEBA FINAL."],
]
## Reacción del Nexo al empezar un capítulo, según las revanchas gastadas hasta ahora.
const STORY_NEXO_REACT_FLAWLESS := ["SIN UNA SOLA REVANCHA.", "EL TIEMPO TE RESPETA."]
const STORY_NEXO_REACT_WOUNDED := ["HAS CAÍDO, PERO TE LEVANTAS.", "EL TIEMPO TOMA NOTA."]
const STORY_NEXO_REACT_WORN := ["TANTAS CAÍDAS... ¿SEGURO", "QUE MERECES EL NEXO?"]
## Frases antes del combate: rival -> [línea 1, línea 2].
const STORY_VS := {
	&"el_nexo": ["EL PODER QUE SOSTIENE", "TODAS LAS ÉPOCAS."],
	&"albert_einstein": ["CREADOR DEL RELOJ: LO CONSTRUYÓ", "Y TEME SU PRECIO."],
	&"leonardo_da_vinci": ["CREADOR DEL RELOJ: DISEÑÓ", "EL MECANISMO DEL ORIGEN."],
	&"nikola_tesla": ["CREADOR DEL RELOJ: SU", "CORRIENTE ALIMENTÓ LA MÁQUINA."],
	&"marie_curie": ["CREADORA DEL RELOJ: SU", "LUZ ENCENDIÓ EL NÚCLEO."],
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
	&"jesus_de_nazaret": ["PREDICÓ EL PERDÓN.", "SU VARA TAMBIÉN GOLPEA."],
	&"alejandro_magno": ["NUNCA PERDIÓ UNA BATALLA.", "NO EMPEZARÁ AHORA."],
	&"sun_tzu": ["GANA SIN LUCHAR.", "TÚ LO ESTÁS HACIENDO MAL."],
	&"buda": ["LA PAZ INTERIOR", "TAMBIÉN GOLPEA."],
	&"adolf_hitler": ["SU IMPERIO DEBÍA DURAR MIL AÑOS.", "DURÓ DOCE."],
	&"joseph_stalin": ["ACERO EN EL NOMBRE.", "ACERO EN LOS PUÑOS."],
	&"donald_trump": ["EL ÚLTIMO EN LLEGAR", "SIEMPRE QUIERE LA CABECERA."],
	&"kim_jong_un": ["GOBIERNA UN PAÍS CERRADO.", "AQUÍ SOLO ENTRAN PUÑOS."],
	&"vladimir_putin": ["CINTURÓN NEGRO DE JUDO.", "NO SE LE DA LA ESPALDA."],
	&"xi_jinping": ["PACIENTE COMO UNA MURALLA.", "ESPERA TU ERROR."],
	&"nicolas_maduro": ["BAILA SALSA ENTRE GOLPES.", "NO CONFÍES EN SU RITMO."],
	&"benito_mussolini": ["EL DUCE SUBE AL BALCÓN", "A DAR SU ÚLTIMO DISCURSO."],
	&"saddam_hussein": ["REY DEL DESIERTO.", "SU TRONO ES ARENA."],
	&"osama_bin_laden": ["SE ESCONDE EN LA SOMBRA.", "ATACA SIN AVISAR."],
	&"fidel_castro": ["BAJÓ DE LA SIERRA", "A CAMBIAR UNA ISLA."],
	&"isabel_ii": ["SIETE DÉCADAS EN EL TRONO.", "NI UN GOLPE LA DESPEINA."],
	&"abraham_lincoln": ["ABOLIÓ LA ESCLAVITUD", "CON LAS MANOS Y UN HACHA."],
	&"papa_francisco": ["PASTOR DE LOS HUMILDES.", "TAMBIÉN SABE GOLPEAR."],
	&"rasputin": ["EL MONJE QUE NO MUERE.", "SU MIRADA TE CONTROLA."],
	&"pablo_escobar": ["PLATA O PLOMO.", "AQUÍ PAGAS EN GOLPES."],
	&"charles_darwin": ["SOBREVIVE EL MÁS ADAPTADO.", "A VER SI ERES TÚ."],
	&"galileo_galilei": ["LA TIERRA SE MUEVE.", "Y SU TELESCOPIO TAMBIÉN."],
	&"janequeo": ["LA TOQUI DEL SUR.", "SU PICA NO PERDONA."],
	&"pachacutec": ["TRANSFORMADOR DEL MUNDO.", "FUNDÓ EL TAHUANTINSUYO."],
	&"ivan_el_terrible": ["PRIMER ZAR DE RUSIA.", "SU FAMA ES SU ARMA."],
	&"boudica": ["REINA DE LOS ICENOS.", "ROMA TEMBLÓ ANTE ELLA."],
	&"arturo_prat": ["SALTÓ AL ABORDAJE", "SABIENDO QUE NO VOLVERÍA."],
	&"socrates": ["SOLO SÉ QUE NO SÉ NADA.", "PERO PEGA MUY FUERTE."],
	&"platon": ["FUNDÓ LA ACADEMIA.", "SU REPÚBLICA ES IMBATIBLE."],
	&"aristoteles": ["MAESTRO DE ALEJANDRO.", "SU LÓGICA ES IMPLACABLE."],
	&"confucio": ["PRIMERO EL ORDEN,", "DESPUÉS EL GOLPE."],
	&"isaac_newton": ["LA GRAVEDAD TIENE", "UN NOMBRE: ÉL."],
	&"nicolas_maquiavelo": ["EL FIN JUSTIFICA", "LOS MEDIOS. TODOS."],
	&"mariya_oktyabrskaya": ["VENDIÓ TODO PARA COMPRAR", "UN TANQUE: EL SUYO."],
	&"liudmila_pavlichenko": ["LADY DEATH: 309 BAJAS", "CONFIRMADAS EN LA GUERRA."],
}
## Frases cuando se enfrentan dos luchadores concretos, en cualquier orden: "id|id" -> líneas.
const STORY_VS_PAIR := {
	"salvador_allende|augusto_pinochet": ["LA MONEDA, 1973.", "AHORA SE DECIDE DE OTRO MODO."],
	"hernan_cortes|moctezuma_ii": ["DOS MUNDOS SE ENCUENTRAN", "EN TENOCHTITLAN."],
	"cristobal_colon|lautaro": ["EL DESCUBRIDOR Y EL TOQUI", "SE VEN LAS CARAS."],
	"napoleon|juana_de_arco": ["UN EMPERADOR Y UNA SANTA.", "TRES SIGLOS Y MEDIO ENTRE ELLOS."],
	"abraham_lincoln|charles_darwin": ["NACIERON EL MISMO DÍA.", "SOLO UNO SE QUEDA EN PIE."],
	"socrates|platon": ["MAESTRO Y DISCÍPULO.", "LA LECCIÓN SE DA A GOLPES."],
	"platon|aristoteles": ["EL DISCÍPULO CONTRA", "SU MAYOR RIVAL DE IDEAS."],
	"socrates|aristoteles": ["TRES SABIOS, UNA IDEA:", "EL MÁS FUERTE ENSEÑA."],
	"julio_cesar|cleopatra": ["ROMA Y EGIPTO,", "OTRA VEZ ENFRENTADAS."],
	"alejandro_magno|aristoteles": ["EL ALUMNO DEBE LA CLASE", "A SU MAESTRO."],
	"adolf_hitler|joseph_stalin": ["DOS TIRANOS, UN PACTO", "ROTO. FUEGO CRUZADO."],
	"adolf_hitler|benito_mussolini": ["EL EJE SE QUIEBRA.", "NO HAY ALIADOS EN EL NEXO."],
	"fidel_castro|donald_trump": ["MEDIO SIGLO DE ENEMISTAD.", "SALDADA EN UN RING."],
	"nikola_tesla|albert_einstein": ["DOS MENTES, UNA MÁQUINA.", "AHORA, UN SOLO GANADOR."],
	"marie_curie|nikola_tesla": ["LUZ CONTRA CORRIENTE.", "EL RELOJ LOS UNIÓ."],
}
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
	if is_story_nexo_fight():
		return NEXO_BOOST
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
	var rivals: Array[FighterData] = []
	for d in FighterRegistry.all():
		if d.id != player_id:
			rivals.append(d)
	rivals.sort_custom(_story_before)
	arcade_ladder.clear()
	for d in rivals:
		arcade_ladder.append(d.id)
	arcade_ladder.append(STORY_NEXO_ID)
	arcade_stage = 0
	arcade_continues = ARCADE_CONTINUES
	story_continues_used = 0
	_boss_cache.clear()
	if not arcade_ladder.is_empty():
		p2_fighter_id = arcade_ladder[0]

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
	s["continues"] = maxi(arcade_continues - 1, 0)
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

## Orden de la escalera: por capítulo del más reciente al más antiguo y, dentro de uno,
## por año, salvo el jefe designado del capítulo, que va al final.
func _story_before(a: FighterData, b: FighterData) -> bool:
	var ca := _chapter_of_id(a.id)
	var cb := _chapter_of_id(b.id)
	if ca != cb:
		return ca < cb
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

## Frase de presentación del rival: la del duelo concreto con el jugador si existe,
## y si no la del propio rival (vacía si no tiene).
func story_vs_lines(fighter_id: StringName) -> Array:
	for key in ["%s|%s" % [p1_fighter_id, fighter_id], "%s|%s" % [fighter_id, p1_fighter_id]]:
		if STORY_VS_PAIR.has(key):
			return STORY_VS_PAIR[key]
	return STORY_VS.get(fighter_id, [])

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

## ¿Es el último combate de su capítulo (el jefe)?
func story_is_chapter_boss(stage: int) -> bool:
	return stage >= arcade_ladder.size() - 1 or story_chapter_of(arcade_ladder[stage + 1]) != story_chapter_of(arcade_ladder[stage])

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
	return &"retry" if arcade_continues > 0 else &"over"

func arcade_advance() -> void:
	arcade_stage = mini(arcade_stage + 1, arcade_ladder.size() - 1)
	p2_fighter_id = arcade_ladder[arcade_stage]
	# Cada capítulo nuevo devuelve las revanchas.
	if story_chapter_start(arcade_stage):
		arcade_continues = ARCADE_CONTINUES

func arcade_use_continue() -> void:
	arcade_continues = maxi(arcade_continues - 1, 0)
	story_continues_used += 1
