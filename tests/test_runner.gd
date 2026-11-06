## Pruebas automáticas de extremo a extremo (sin ventana).
## Uso:  godot --headless --path . res://tests/TestRunner.tscn [-- --only=historia]
## Simula pulsaciones REALES de teclado (InputEventKey con las teclas del
## Input Map) y recorre: menú -> selección -> combate -> rondas -> resultados.
extends Node

var passed: int = 0
var failed: int = 0
var log_lines: PackedStringArray = []

func _ready() -> void:
	# Las pruebas deben poder correr con la escena principal cambiando.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El runner deja de ser la "escena actual" para sobrevivir a los cambios de escena.
	get_tree().current_scene = null
	# Las partidas de Historia de las pruebas van a su propio archivo: así no pisan las reales ni se arrastran de una corrida a otra.
	Backend.story_path = "user://story_runner.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Backend.story_path))
	_run.call_deferred()

func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  [OK]   ", label)
	else:
		failed += 1
		print("  [FAIL] ", label)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func key(physical: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical
	ev.keycode = physical
	ev.pressed = pressed
	Input.parse_input_event(ev)

func tap(physical: Key, hold_frames: int = 2) -> void:
	key(physical, true)
	await frames(hold_frames)
	key(physical, false)
	await frames(1)

func scene() -> Node:
	return get_tree().current_scene

func wait_scene(scene_name: String, max_frames: int = 120) -> bool:
	for i in max_frames:
		await frames(1)
		if scene() and scene().name == scene_name and not Game.is_changing_scene():
			return true
	return false

# ==========================================================================
func _run() -> void:
	print("\n=== HISTORY COMBAT · PRUEBAS AUTOMÁTICAS ===")
	if OS.get_cmdline_user_args().has("--only=historia"):
		# Solo el modo Historia (va al final de la lista y es lo que más tarda en llegar).
		await frames(30)
		await _test_arcade()
		_test_story_choice()
		print("\n=== RESULTADO: %d OK, %d FALLOS ===" % [passed, failed])
		get_tree().quit(1 if failed > 0 else 0)
		return
	_test_resources()
	_test_catalogs()
	_test_profile_helpers()
	await _test_locked_select()
	await _test_ranking_filters()
	await _test_menu_to_fight()
	await _test_fight()
	await _test_powers()
	await _test_ultimates()
	await _test_rounds_and_results()
	await _test_soak()
	await _test_arcade()
	_test_story_choice()
	print("\n=== RESULTADO: %d OK, %d FALLOS ===" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func _test_resources() -> void:
	print("\n# Datos y escenas")
	for path in ["res://scenes/MainMenu.tscn", "res://scenes/CharacterSelect.tscn", "res://scenes/Fight.tscn",
			"res://scenes/Results.tscn", "res://scenes/fighters/Fighter.tscn", "res://ui/HUD.tscn",
			"res://stages/colosseum/Colosseum.tscn", "res://scenes/Story.tscn", "res://scenes/Roster.tscn", "res://scenes/Credits.tscn", "res://scenes/StorySaves.tscn"]:
		var ps := load(path) as PackedScene
		check(ps != null and ps.can_instantiate(), "escena carga: " + path)
	var roster := FighterRegistry.all()
	check(roster.size() == 57, "roster con 57 luchadores (%d)" % roster.size())
	var seen := {}
	for d in roster:
		check(not seen.has(d.id), "id único: %s" % d.id)
		seen[d.id] = true
	for d in roster:
		check(d.validate().is_empty(), "ficha completa: %s" % d.id)
		check(d.year != 0 or d.id == &"jesus_de_nazaret", "año de la línea del tiempo definido: %s" % d.id)
	for d in roster:
		var sp := StageRegistry.scene_for(d.id)
		var ps := load(sp) as PackedScene
		check(ps != null and ps.can_instantiate(), "escenario de %s carga (%s)" % [d.id, sp.get_file()])
		check(d.id == &"julio_cesar" or not StageRegistry.def_for(d.id).is_empty(), "escenario propio definido: %s" % d.id)
	for a in ["p1_left", "p1_right", "p1_jump", "p1_crouch", "p1_block", "p1_punch_light", "p1_punch_heavy",
			"p1_special_1", "p1_kick_light", "p1_kick_heavy", "p1_special_2"]:
		var b: String = a.replace("p1_", "p2_")
		check(InputMap.has_action(a) and InputMap.has_action(b), "acciones registradas: %s / %s" % [a, b])
	# Los controles de P1 y P2 no comparten ninguna tecla.
	var keys1 := {}
	var shared := 0
	for a in InputMap.get_actions():
		if String(a).begins_with("p1_"):
			for e in InputMap.action_get_events(a):
				keys1[(e as InputEventKey).physical_keycode] = true
	for a in InputMap.get_actions():
		if String(a).begins_with("p2_"):
			for e in InputMap.action_get_events(a):
				if keys1.has((e as InputEventKey).physical_keycode):
					shared += 1
	check(shared == 0, "P1 y P2 no comparten teclas")

## Cada luchador tiene que estar en todos los catálogos que lo usan; si falta en uno, el juego no avisa:
## cae en silencio en la última época, en un texto vacío o en un aviso en mitad del combate.
func _test_catalogs() -> void:
	print("\n# Catálogos")
	var ids: Array[StringName] = []
	for d in FighterRegistry.all():
		ids.append(d.id)
	# Plantel y carpetas: ninguna ficha .tres olvidada fuera de FighterRegistry.ROSTER.
	var dirs := DirAccess.get_directories_at("res://fighters")
	var in_roster := {}
	for path in FighterRegistry.ROSTER:
		in_roster[path.get_base_dir().get_file()] = true
	var forgotten: Array[String] = []
	for dir in dirs:
		if not in_roster.has(dir) and dir != String(FighterRegistry.NEXO_ID):
			forgotten.append(dir)
	check(forgotten.is_empty(), "no hay fichas fuera del plantel (%s)" % ", ".join(forgotten))
	var misnamed: Array[String] = []
	for path in FighterRegistry.ROSTER:
		if path != "res://fighters/%s/%s.tres" % [path.get_base_dir().get_file(), path.get_base_dir().get_file()]:
			misnamed.append(path)
	check(misnamed.is_empty(), "cada ficha vive en fighters/<id>/<id>.tres (%s)" % ", ".join(misnamed))
	# Modo Historia: cada luchador, en una época y solo en una.
	var chapter_of := {}
	var dupes: Array[String] = []
	for chapter in Game.STORY_CHAPTERS:
		for id in chapter[1]:
			if chapter_of.has(id):
				dupes.append(str(id))
			chapter_of[id] = chapter[0]
	check(dupes.is_empty(), "nadie está en dos épocas (%s)" % ", ".join(dupes))
	var no_chapter: Array[String] = []
	for id in ids:
		if not chapter_of.has(id) and not StoryCampaign.PLAYABLE_ONLY.has(id):
			no_chapter.append(str(id))
	check(no_chapter.is_empty(), "todo luchador es rival de una época o solo para elegir (faltan: %s)" % ", ".join(no_chapter))
	var both: Array[String] = []
	for id in StoryCampaign.PLAYABLE_ONLY:
		if chapter_of.has(id):
			both.append(str(id))
	check(both.is_empty(), "los de solo elegir no son rivales (%s)" % ", ".join(both))
	var unknown_in_chapter: Array[String] = []
	for id in chapter_of:
		if not FighterRegistry.has(id):
			unknown_in_chapter.append(str(id))
	check(unknown_in_chapter.is_empty(), "las épocas no nombran a nadie que no exista (%s)" % ", ".join(unknown_in_chapter))
	var bad_ref: Array[String] = []
	for chapter_index in Game.STORY_BOSSES:
		if not FighterRegistry.has(Game.STORY_BOSSES[chapter_index]):
			bad_ref.append("jefe %s" % Game.STORY_BOSSES[chapter_index])
	for id in Game.STORY_CREATORS:
		if not FighterRegistry.has(id):
			bad_ref.append("creador %s" % id)
	check(bad_ref.is_empty(), "jefes y creadores apuntan a luchadores que existen (%s)" % ", ".join(bad_ref))
	# Textos de la pantalla de personajes.
	var no_lore: Array[String] = []
	for id in ids:
		var lore := RosterLore.get_lore(id)
		for line in lore:
			if str(line).strip_edges().is_empty():
				no_lore.append(str(id))
				break
	check(no_lore.is_empty(), "todos tienen sus 4 textos en RosterLore (faltan: %s)" % ", ".join(no_lore))
	# Poderes y ultimates: el id de la ficha debe existir en PowerEffects (si no, solo avisa a mitad del combate).
	var powers := _match_arms("res://scripts/power_effects.gd", "static func cast(", "static func reflect(")
	var ult_kinds := _match_arms("res://scripts/power_effects.gd", "static func _cast_ultimate(", "static func _ult_barrage(")
	check(powers.size() >= 40 and ult_kinds.size() >= 11, "se leen los poderes (%d) y tipos de ultimate (%d) de PowerEffects" % [powers.size(), ult_kinds.size()])
	var bad_power: Array[String] = []
	var everyone: Array[FighterData] = FighterRegistry.all().duplicate()
	everyone.append(FighterRegistry.get_by_id(FighterRegistry.NEXO_ID))
	for d in everyone:
		for slot in [&"special_1", &"special_2", &"ultimate"]:
			var atk: AttackData = d.get_attack(slot)
			if atk == null:
				continue
			if atk.power != &"" and not powers.has(atk.power):
				bad_power.append("%s/%s: poder «%s»" % [d.id, slot, atk.power])
			if atk.kind == AttackData.Kind.ULTIMATE and not ult_kinds.has(atk.ult_kind):
				bad_power.append("%s: ult_kind «%s»" % [d.id, atk.ult_kind])
	check(bad_power.is_empty(), "los poderes y ultimates de las fichas existen en PowerEffects (%s)" % ", ".join(bad_power))
	# El validador detecta datos rotos.
	var broken := FighterRegistry.get_by_id(&"napoleon").duplicate() as FighterData
	broken.punch_light = broken.punch_light.duplicate() as AttackData
	broken.punch_light.startup = 0
	broken.punch_light.hitbox_size = Vector2.ZERO
	broken.strength = 0.0
	var errors := broken.validate()
	check(errors.size() >= 3, "validate() detecta startup 0, hitbox sin tamaño y fuerza 0 (%d problemas)" % errors.size())
	var bad_status := AttackData.new()
	bad_status.status = &"congelar"
	bad_status.status_frames = 10
	check(not bad_status.validate("x").is_empty(), "validate() detecta un estado alterado desconocido")
	check(FighterRegistry.get_by_id(FighterRegistry.NEXO_ID).validate().is_empty(), "la ficha del Nexo también es válida")

## Ids de las ramas `&"id":` de un `match` de un script, entre dos funciones (para comprobar que las fichas
## no piden un poder que el motor no conoce).
func _match_arms(path: String, from_func: String, to_func: String) -> Array[StringName]:
	var out: Array[StringName] = []
	var text := FileAccess.get_file_as_string(path)
	var start := text.find(from_func)
	var stop := text.find(to_func, start + 1)
	if start < 0 or stop < 0:
		return out
	var re := RegEx.new()
	re.compile("(?m)^\t\t&\"([a-z_0-9]+)\":")
	for m in re.search_all(text.substr(start, stop - start)):
		out.append(StringName(m.get_string(1)))
	return out


func _test_profile_helpers() -> void:
	print("
# Ligas y fechas del perfil")
	check(League.info(1000)["name"] == "BRONCE" and League.info(1100)["name"] == "PLATA", "1000 es Bronce y 1100 es Plata")
	check(League.info(1299)["name"] == "PLATA" and League.info(1300)["name"] == "ORO", "el límite Plata/Oro está en 1300")
	check(League.info(1500)["name"] == "DIAMANTE" and League.info(5000)["next_name"] == "", "Diamante es la última liga")
	check(League.info(1000)["to_next"] == 100 and is_equal_approx(League.info(1200)["progress"], 0.5), "faltan 100 para Plata y a 1200 va a la mitad hacia Oro")
	check(League.info(-50)["progress"] == 0.0, "con puntos negativos la barra no va por debajo de 0")
	check(League.change_text(1090, 1106) == "¡SUBISTE A PLATA!" and League.change_text(1290, 1500) == "¡SUBISTE A DIAMANTE!", "al cruzar el límite se avisa la subida")
	check(League.change_text(1105, 1089) == "BAJASTE A BRONCE", "y la bajada")
	check(League.change_text(1000, 1016) == "" and League.change_text(1600, 1584) == "", "sin cambio de liga no hay aviso")

	# Fuente: las mayúsculas acentuadas usan el glifo sin tilde; las minúsculas conservan la suya.
	var font := HKTheme.font() as FontFile
	var raw := load(HKTheme.FONT_PATH) as FontFile
	var glyph := func(f: FontFile, ch: String) -> int: return f.get_glyph_index(8, ch.unicode_at(0), 0)
	var plain_ok := true
	for accented in HKTheme.PLAIN_CAPITALS:
		plain_ok = plain_ok and glyph.call(font, accented) == glyph.call(font, HKTheme.PLAIN_CAPITALS[accented])
	check(plain_ok, "Á É Í Ó Ú Ü se dibujan como A E I O U")
	check(glyph.call(font, "ó") != glyph.call(font, "o") and glyph.call(font, "Ñ") != glyph.call(font, "N"), "ó y Ñ no se tocan")
	check(glyph.call(raw, "Ó") != glyph.call(raw, "O"), "el archivo de la fuente sigue igual (el cambio es en memoria)")

	# Temporadas
	check(Season.name_of("2026-11") == "NOVIEMBRE 2026" and Season.name_of("2027-01") == "ENERO 2027", "nombre de la temporada")
	check(Season.name_of("") == "" and Season.name_of("2026-13") == "" and Season.name_of("x-y") == "", "un id raro no tiene nombre")
	var t0 := Time.get_unix_time_from_datetime_string("2026-11-20T12:00:00")
	check(Season.days_left("2026-12-01T00:00:00.000Z", t0) == 11, "faltan 11 días (redondeando hacia arriba)")
	check(Season.time_left_text("2026-12-01T00:00:00.000Z", t0) == "QUEDAN 11 DÍAS", "texto de lo que queda")
	check(Season.time_left_text("2026-12-01T00:00:00.000Z", t0 + 9.0 * 86400.0) == "QUEDAN 2 DÍAS", "día y medio: 2 días")
	check(Season.time_left_text("2026-12-01T00:00:00.000Z", t0 + 10.0 * 86400.0) == "ÚLTIMAS HORAS", "el último día")
	check(Season.days_left("2026-12-01T00:00:00.000Z", t0 + 30.0 * 86400.0) == 0, "terminada: 0, no negativo")
	check(Season.summary({"rank": 1, "league": "diamond"}) == PackedStringArray(["PUESTO 1 · LIGA DIAMANTE",
		"MARCO DIAMANTE DE TEMPORADA", "TÍTULO CAMPEÓN DE TEMPORADA"]), "aviso del campeón: liga, marco y título")
	check(Season.summary({"rank": 3, "league": "gold"})[2] == "TÍTULO PODIO DE TEMPORADA", "el tercero gana el título del podio")
	check(Season.summary({"rank": 8, "league": "bronze"}).size() == 2 and Season.summary({"rank": 8, "league": "bronze"})[1].begins_with("SIN PREMIO"),
		"en Bronce no hay premio")
	var old_seen := Season.seen_path
	Season.seen_path = "user://seasons_seen_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Season.seen_path))
	check(Season.last_seen("cuenta-a") == "", "al principio no se ha visto ninguna")
	Season.mark_seen("cuenta-a", "2026-11")
	check(Season.last_seen("cuenta-a") == "2026-11" and Season.last_seen("cuenta-b") == "", "se recuerda por cuenta")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Season.seen_path))
	Season.seen_path = old_seen
	var now := Time.get_unix_time_from_datetime_string("2026-11-02T12:00:00")
	check(MatchRow.format_ago("2026-11-02T11:59:30.000Z", now) == "AHORA", "hace 30 s: AHORA")
	check(MatchRow.format_ago("2026-11-02T11:45:00.000Z", now) == "15M", "hace 15 min: 15M")
	check(MatchRow.format_ago("2026-11-02T09:00:00.000Z", now) == "3H", "hace 3 h: 3H")
	check(MatchRow.format_ago("2026-10-31T12:00:00.000Z", now) == "2D", "hace 2 días: 2D")
	check(MatchRow.format_ago("2026-10-19T12:00:00.000Z", now) == "2SEM", "hace 14 días: 2SEM")
	check(MatchRow.format_ago("2026-08-01T12:00:00.000Z", now) == "3MES", "hace ~3 meses: 3MES")
	check(MatchRow.format_ago("", now) == "" and MatchRow.format_ago("ayer", now) == "", "fecha vacía o rara: sin texto")

	# Estadísticas con mis duelos (el más reciente primero)
	var ms := [
		{"result": "win", "delta": 16, "my_fighter": "tesla", "opponent_fighter": "napoleon"},
		{"result": "win", "delta": 14, "my_fighter": "tesla", "opponent_fighter": "napoleon"},
		{"result": "loss", "delta": -15, "my_fighter": "tesla", "opponent_fighter": "rasputin"},
		{"result": "loss", "delta": -17, "my_fighter": "tesla", "opponent_fighter": "rasputin"},
		{"result": "loss", "delta": -16, "my_fighter": "einstein", "opponent_fighter": "hitler"},
	]
	var mine := ProfileStats.by_fighter(ms)
	check(mine.size() == 2 and mine[0]["id"] == "tesla" and mine[0]["total"] == 4 and mine[0]["wins"] == 2 and mine[0]["losses"] == 2, "por luchador: Tesla 2-2 va primero")
	check(mine[1]["id"] == "einstein" and ProfileStats.win_rate(mine[1]) == 0.0, "Einstein 0-1: porcentaje 0")
	var bw := ProfileStats.best_and_worst(ProfileStats.by_fighter(ms, "opponent_fighter"))
	check(bw["best"]["id"] == "napoleon" and bw["worst"]["id"] == "rasputin", "mejor rival Napoleón (2-0) y peor Rasputín (0-2)")
	check(bw["best"]["total"] == 2, "Hitler (1 duelo) no cuenta: se piden al menos 2")
	check(ProfileStats.best_and_worst([])["best"].is_empty(), "sin duelos no hay mejor ni peor rival")
	var one := ProfileStats.best_and_worst(ProfileStats.by_fighter(ms.slice(0, 2), "opponent_fighter"))
	check(not one["best"].is_empty() and one["worst"].is_empty(), "con un solo rival no es a la vez el mejor y el peor")
	check(ProfileStats.by_fighter([{"result": "win"}]).is_empty(), "un duelo sin luchador se ignora")
	var series := ProfileStats.points_series(ms, 1000)
	check(series.size() == 6 and series[5] == 1000, "la serie termina en los puntos actuales (%s)" % str(series))
	check(series[0] == 1000 - 16 - 14 + 15 + 17 + 16 and series[4] == 984, "la serie se reconstruye restando los deltas hacia atrás")
	check(ProfileStats.points_series(ms, 1000, 2).size() == 3, "max_matches limita la serie")
	check(ProfileStats.points_series([], 1000).size() == 1, "sin duelos la serie es solo el valor actual")

	# Ajustes de volumen
	check(is_equal_approx(Settings.step_to_db(Settings.STEPS), 0.0), "volumen al máximo: 0 dB (sin cambio)")
	check(Settings.step_to_db(0) <= -80.0 and Settings.step_to_db(5) < Settings.step_to_db(6), "volumen 0 es silencio y sube con cada paso")
	check(Settings.step_to_db(99) == 0.0 and Settings.step_to_db(-3) <= -80.0, "los pasos fuera de rango se recortan")
	var old_path := Settings.path
	var old_master := Settings.master
	var old_effects := Settings.effects
	Settings.path = "user://settings_test.cfg"
	Settings.master = 3
	Settings.effects = 7
	Settings.save()
	Settings.master = 10
	Settings.effects = 10
	Settings.load_settings()
	check(Settings.master == 3 and Settings.effects == 7, "los ajustes guardados se recuperan")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.load_settings()
	check(Settings.master == Settings.STEPS and Settings.effects == Settings.STEPS, "sin archivo: volumen al máximo")
	Settings.path = old_path
	Settings.master = old_master
	Settings.effects = old_effects

	# Desbloqueos
	var old_unlocks_path := Unlocks.path
	var old_user := Backend.user_id
	var old_mode := Game.mode
	var old_p2 := Game.p2_fighter_id
	Unlocks.path = "user://unlocks_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Backend.user_id = ""
	var starters_exist := true
	for id in Unlocks.STARTERS:
		starters_exist = starters_exist and FighterRegistry.has(id)
	check(Unlocks.STARTERS.size() == StoryCampaign.PLAYABLE_ONLY.size() and starters_exist, "se empieza con los buenos (%d) y todos existen en el plantel" % Unlocks.STARTERS.size())
	var base_unlocked := Unlocks.STARTERS.size()
	check(Unlocks.fighters_unlocked() == base_unlocked, "al principio solo están desbloqueados los iniciales")
	check(Unlocks.fighter_unlocked(&"lautaro") and not Unlocks.fighter_unlocked(&"donald_trump") and not Unlocks.fighter_unlocked(&"nikola_tesla"), "Lautaro es inicial; Trump y Tesla se desbloquean en la historia")
	check(Unlocks.add("fighter", "donald_trump") and not Unlocks.add("fighter", "donald_trump"), "añadir devuelve true solo la primera vez")
	check(Unlocks.fighter_unlocked(&"donald_trump") and Unlocks.fighters_unlocked() == base_unlocked + 1, "lo ganado cuenta como desbloqueado")
	Backend.user_id = "cuenta-a"
	check(not Unlocks.fighter_unlocked(&"donald_trump"), "otra cuenta no hereda lo del invitado")
	Unlocks.add("ending", "repair")
	check(Unlocks.endings_seen().size() == 1 and Unlocks.endings_seen()[0] == &"repair", "se anota el final visto")
	check(Unlocks.merge([{"kind": "ending", "key": "rewrite"}, {"kind": "ending", "key": "repair"}]) and Unlocks.endings_seen().size() == 2,
		"merge añade lo nuevo de la cuenta y no duplica")
	check(not Unlocks.merge([{"kind": "ending", "key": "rewrite"}]), "merge sin novedades no cambia nada")
	check(Unlocks.as_dicts().size() == 2 and Unlocks.as_dicts()[0].has("kind"), "as_dicts da el formato del servidor")
	Backend.user_id = ""
	check(Unlocks.fighter_unlocked(&"donald_trump"), "volver al invitado: sus desbloqueos siguen")
	Game.mode = Game.Mode.ARCADE
	Game.p2_fighter_id = &"hernan_cortes"
	Game.story_record_win()
	check(Unlocks.fighter_unlocked(&"hernan_cortes"), "vencer a un rival en la historia lo desbloquea")
	Game.p2_fighter_id = Game.STORY_NEXO_ID
	Game.story_record_win()
	check(not Unlocks.has("fighter", "el_nexo"), "vencer al Nexo no lo desbloquea como luchador")
	Game.mode = Game.Mode.VERSUS
	Game.p2_fighter_id = &"kim_jong_un"
	Game.story_record_win()
	check(not Unlocks.fighter_unlocked(&"kim_jong_un"), "fuera de la historia no se desbloquea nada")
	# La selección de personaje consulta cada casilla en cada redibujo: no puede leer el archivo cada vez.
	var reads_before := Unlocks.disk_reads
	for i in 100:
		Unlocks.fighters_unlocked()
		Unlocks.has("fighter", "donald_trump")
	check(Unlocks.disk_reads == reads_before, "consultar desbloqueos no vuelve a leer el archivo (%d lecturas)" % (Unlocks.disk_reads - reads_before))
	Unlocks.add("fighter", "kim_jong_un")
	check(Unlocks.fighter_unlocked(&"kim_jong_un") and Unlocks.disk_reads == reads_before, "lo recién desbloqueado se ve sin releer el archivo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Unlocks.path = old_unlocks_path
	Backend.user_id = old_user
	Game.mode = old_mode
	Game.p2_fighter_id = old_p2

	# Cosméticos y logros
	var frames_ok := true
	for k in Cosmetics.FRAMES:
		frames_ok = frames_ok and str(k).begins_with("frame_") and Cosmetics.frame_name(str(k)) != ""
	var titles_ok := true
	for k in Cosmetics.TITLES:
		titles_ok = titles_ok and str(k).begins_with("title_") and Cosmetics.title_name(str(k)) != ""
	check(frames_ok and titles_ok, "todos los marcos y títulos tienen nombre y su prefijo")
	var rewards_exist := true
	for e in Cosmetics.ENDING_REWARDS:
		check(Unlocks.ENDINGS.has(e), "la recompensa del final %s es de un final que existe" % e)
		for k in Cosmetics.ENDING_REWARDS[e]:
			rewards_exist = rewards_exist and (Cosmetics.FRAMES.has(k) or Cosmetics.TITLES.has(k))
	for k in Cosmetics.ACHIEVEMENT_REWARDS:
		rewards_exist = rewards_exist and Cosmetics.TITLES.has(Cosmetics.ACHIEVEMENT_REWARDS[k])
	check(rewards_exist, "cada recompensa apunta a un marco o título del catálogo")
	check(Cosmetics.frame_name("frame_inventado") == "" and Cosmetics.title_name("title_inventado") == "", "lo que no conoce no tiene nombre (no se muestra)")
	check(Cosmetics.frame_color("frame_inventado") == HKTheme.GOLD_DARK, "un marco desconocido usa el borde normal")
	var old_cosm_path := Unlocks.path
	var old_cosm_user := Backend.user_id
	Unlocks.path = "user://unlocks_cosm_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Backend.user_id = ""
	check(Cosmetics.owned_frames().is_empty() and Cosmetics.owned_titles().is_empty(), "al principio no se tiene ningún cosmético")
	Cosmetics.grant_ending(&"repair")
	check(Cosmetics.owned_frames() == ["frame_gold"] and Cosmetics.owned_titles() == ["title_guardian"], "ver un final da su marco y su título")
	var fresh := Cosmetics.grant_achievements([{"key": "first_win", "done": true}, {"key": "wins_50", "done": false}, {"key": "streak_5", "done": true}, {"key": "otro", "done": true}])
	check(Cosmetics.owned_titles().has("title_first_blood") and Cosmetics.owned_titles().has("title_unstoppable"), "los logros cumplidos dan su título")
	check(fresh == ["title_first_blood", "title_unstoppable"], "devuelve los títulos nuevos para anunciarlos")
	check(Cosmetics.grant_achievements([{"key": "first_win", "done": true}]).is_empty(), "uno que ya se tenía no se anuncia otra vez")
	check(not Cosmetics.owned_titles().has("title_legend"), "un logro sin cumplir no da nada")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Unlocks.path = old_cosm_path
	Backend.user_id = old_cosm_user
	var merged := Achievements.merge([{"key": "first_win", "progress": 1, "goal": 1, "done": true}, {"key": "wins_10", "progress": 4, "goal": 10, "done": false}])
	check(merged.size() == Achievements.LIST.size() and merged[0]["name"] == "PRIMERA SANGRE" and merged[0]["done"], "merge: respeta el orden y marca lo cumplido")
	check(merged[1]["progress"] == 4 and merged[1]["goal"] == 10 and not merged[1]["done"], "merge: trae el progreso del servidor")
	check(merged[2]["progress"] == 0 and merged[2]["goal"] >= 1, "merge: lo que el servidor no manda sale a 0")
	check(Achievements.done_count(merged) == 1, "done_count cuenta los cumplidos")
	var hidden: Dictionary = merged[Achievements.LIST.map(func(e): return e[0]).find(Achievements.HIDDEN)]
	check(hidden["name"] == "???" and hidden["desc"] != "", "el logro oculto no dice su nombre hasta cumplirlo")
	var shown := Achievements.merge([{"key": Achievements.HIDDEN, "progress": 1, "goal": 1, "done": true}])
	check(shown[Achievements.LIST.map(func(e): return e[0]).find(Achievements.HIDDEN)]["name"] == "EL TIEMPO LIBRE", "cumplido, ya se muestra")
	check(Achievements.merge([]).size() == Achievements.LIST.size(), "sin respuesta del servidor salen todos a 0")

	# Lo ganado sin cuenta pasa a la cuenta
	var guest_path := Unlocks.path
	var guest_user := Backend.user_id
	Unlocks.path = "user://unlocks_guest_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Backend.user_id = ""
	Unlocks.add("fighter", "kim_jong_un")
	Unlocks.add("ending", "repair")
	check(not Unlocks.adopt_guest(), "sin sesión no se pasa nada")
	Backend.user_id = "cuenta-a"
	Unlocks.add("ending", "repair")
	check(Unlocks.adopt_guest(), "al entrar en una cuenta, lo del invitado se le pasa")
	check(Unlocks.fighter_unlocked(&"kim_jong_un") and Unlocks.as_dicts().size() == 2, "la cuenta tiene lo suyo y lo del invitado, sin duplicar")
	check(not Unlocks.adopt_guest(), "pasarlo otra vez no añade nada")
	Backend.user_id = "cuenta-b"
	Unlocks.adopt_guest()
	check(not Unlocks.fighter_unlocked(&"kim_jong_un"), "lo del invitado va a una sola cuenta, no a todas")
	Backend.user_id = ""
	check(Unlocks.items().is_empty(), "el invitado queda vacío tras pasarlo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Unlocks.path = guest_path
	Backend.user_id = guest_user

	# Amigos
	var friends := [
		{"username": "zeta", "status": "friend", "points": 1000},
		{"username": "Beto", "status": "outgoing", "points": 1000},
		{"username": "ana", "status": "friend", "points": 1000},
		{"username": "Carla", "status": "incoming", "points": 1000},
		{"username": "Dani", "status": "incoming", "points": 1000},
	]
	var sorted_friends := FriendsScreen.sort_entries(friends)
	var order := sorted_friends.map(func(f): return f["username"])
	check(order == ["Carla", "Dani", "ana", "zeta", "Beto"], "amigos: primero las solicitudes que me hacen, luego los amigos y al final las enviadas (%s)" % str(order))
	check(friends[0]["username"] == "zeta", "ordenar no toca la lista original")
	check(FriendsScreen.pending_count(friends) == 2 and FriendsScreen.pending_count([]) == 0, "se cuentan las solicitudes por contestar")
	var old_cache := Backend.friends_cache
	Backend.friends_cache = friends
	check(Backend.friend_status("ANA") == "friend" and Backend.friend_status("carla") == "incoming", "friend_status no distingue mayúsculas")
	check(Backend.friend_status("beto") == "outgoing" and Backend.friend_status("Nadie") == "", "sin relación devuelve vacío")
	Backend.friends_cache = old_cache
	Game.challenge_code = "ABCD2345"
	Game.challenge_opponent = "Ana"
	Game.drop_challenge()
	check(Game.challenge_code == "" and Game.challenge_opponent == "", "soltar el reto lo limpia")

func _test_locked_select() -> void:
	print("\n# Selección: un luchador bloqueado no se confirma con el teclado")
	var old_path := Unlocks.path
	var old_user := Backend.user_id
	var old_mode := Game.mode
	Unlocks.path = "user://unlocks_select_test.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Backend.user_id = ""
	Game.mode = Game.Mode.ARCADE
	get_tree().change_scene_to_file(Game.SCENE_SELECT)
	check(await wait_scene("CharacterSelect"), "la selección del modo Historia abre")
	var sel := scene() as CharacterSelect
	await frames(3)
	check(Unlocks.fighter_unlocked(sel.roster[sel.cursor[1]].id), "el cursor empieza en un luchador desbloqueado (Trump está bloqueado)")
	sel.cursor[1] = FighterRegistry.index_of(&"donald_trump")
	await tap(KEY_U)
	await frames(15)   # deja que la selección consuma la pulsación mientras el cursor sigue en el bloqueado
	check(not sel.confirmed[1] and is_instance_valid(sel) and scene() == sel, "con U sobre un bloqueado no se confirma ni empieza la historia")
	# La rejilla solo muestra a los buenos: ningún villano, ambicioso ni creador, y están todos los buenos.
	var shown := 0
	var only_good := true
	for l in sel._era_lists:
		for idx in l:
			shown += 1
			if not Unlocks.STARTERS.has(sel.roster[idx].id):
				only_good = false
	check(only_good and shown == Unlocks.STARTERS.size(),
		"en la historia solo se muestran los buenos (%d de %d), nunca un villano, ambicioso o creador" % [shown, Unlocks.STARTERS.size()])
	# Y al moverse con D el cursor nunca cae en un rival (pocas pulsaciones y largas: en modo sin ventana las rápidas se pierden).
	var never_rival := true
	for i in 6:
		await tap(KEY_D, 6)
		if not is_instance_valid(sel) or scene() != sel:
			never_rival = false
			break
		if not Unlocks.STARTERS.has(sel.roster[sel.cursor[1]].id):
			never_rival = false
	check(never_rival, "moviéndose con D el cursor nunca cae en un rival")
	# Aunque ya se haya vencido a alguien en otra partida, sigue sin poder elegirse.
	Unlocks.add("fighter", "adolf_hitler")
	check(not Unlocks.STARTERS.has(&"adolf_hitler") and sel._is_locked(FighterRegistry.index_of(&"adolf_hitler")), "haber vencido a Hitler no lo hace elegible en la historia")
	await tap(KEY_ESCAPE, 6)
	check(await wait_scene("MainMenu", 240), "ESC vuelve al menú")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Unlocks.path))
	Unlocks.path = old_path
	Backend.user_id = old_user
	Game.mode = old_mode

func _test_ranking_filters() -> void:
	print("\n# Ranking: filtros de 7 días y por luchador")
	check(Backend._ranking_query(false, "") == "" and Backend._ranking_query(false, "", 100) == "?limit=100", "sin filtros no se añade nada")
	check(Backend._ranking_query(true, "napoleon", 100) == "?limit=100&period=week&fighter=napoleon", "con los dos filtros")
	# Sin servidor: la lista sale vacía al momento y se prueban solo los botones.
	ServerConfig.override_ws = "ws://127.0.0.1:1/ws"
	Game.ranking_week = false
	Game.ranking_fighter = ""
	get_tree().change_scene_to_file(Game.SCENE_RANKING)
	check(await wait_scene("Ranking"), "abre el ranking")
	await frames(3)
	var back := get_viewport().gui_get_focus_owner() as Button
	check(back != null and back.text == "VOLVER", "empieza con VOLVER elegido")
	await tap(KEY_LEFT)
	await tap(KEY_LEFT)
	var period := get_viewport().gui_get_focus_owner() as Button
	check(period != null and period.text == "SIEMPRE", "izquierda lleva a los otros botones (sin sesión no hay GLOBAL/AMIGOS)")
	await tap(KEY_ENTER)
	check(Game.ranking_week and period.text == "7 DIAS", "ENTER cambia a los últimos 7 días")
	await tap(KEY_RIGHT)
	await tap(KEY_ENTER)
	check(await wait_scene("AvatarPicker"), "LUCHADOR abre la rejilla de luchadores")
	await frames(3)
	await tap(KEY_RIGHT)
	await tap(KEY_ENTER)
	check(await wait_scene("Ranking"), "elegir uno vuelve al ranking")
	var first := str(FighterRegistry.all()[0].id)
	check(Game.ranking_fighter == first and Game.ranking_week, "con el filtro puesto (%s) y sin perder el de 7 días" % Game.ranking_fighter)
	await frames(3)
	var fighter_btn := get_viewport().gui_get_focus_owner() as Button
	check(fighter_btn != null and fighter_btn.text == HKTheme.fold(FighterRegistry.all()[0].short_name.to_upper().left(12)),
		"el foco vuelve al botón del luchador, que lo nombra")
	await tap(KEY_ENTER)
	check(await wait_scene("AvatarPicker"), "se vuelve a abrir")
	await frames(3)
	await tap(KEY_LEFT)
	await tap(KEY_ENTER)
	check(await wait_scene("Ranking") and Game.ranking_fighter == "", "la casilla \"?\" quita el filtro")
	await tap(KEY_ESCAPE)
	check(await wait_scene("MainMenu"), "ESC vuelve al menú")
	Game.ranking_week = false
	ServerConfig.override_ws = ""

func _test_menu_to_fight() -> void:
	print("\n# Menú -> Selección -> Combate")
	get_tree().change_scene_to_file(Game.SCENE_MENU)
	check(await wait_scene("MainMenu"), "el juego arranca en el menú principal")
	var play := scene().get_node("Buttons/Play") as Button
	# Con una partida guardada en el equipo el foco es de CONTINUAR (a propósito); si no, de ARCADE.
	var cont := scene().get_node("Buttons/Continue") as Button
	check(play.has_focus() or (cont.visible and cont.has_focus()), "el menú abre con el foco en ARCADE (o en CONTINUAR si hay partida guardada)")
	check(scene().get_node_or_null("Buttons/Versus") == null, "el menú ya no tiene VERSUS LOCAL")
	# Las pruebas de combate usan el modo de dos jugadores en el mismo equipo (fuera del menú).
	Game.mode = Game.Mode.VERSUS
	get_tree().change_scene_to_file(Game.SCENE_SELECT)
	check(await wait_scene("CharacterSelect"), "la selección de luchador abre en el modo de dos jugadores")
	check(not Game.is_vs_cpu(), "dos jugadores: sin CPU")
	await frames(5)
	await tap(KEY_U)        # P1 confirma
	await tap(KEY_KP_1)     # P2 confirma con el numpad
	check(await wait_scene("Fight", 240), "con ambos confirmados empieza el combate")

func rematch_text_is(text: String) -> bool:
	var b := scene().get_node_or_null("Buttons/Rematch") as Button
	return b != null and b.visible and b.text == text

func _fight() -> CombatManager:
	return scene() as CombatManager

func _wait_fight_phase() -> bool:
	for i in 300:
		await frames(1)
		var c := _fight()
		if c and c.round_manager.phase == RoundManager.Phase.FIGHT:
			return true
	return false

## Coloca a los luchadores a una distancia, con vida y energía llenas.
func _setup_duel(distance: float) -> void:
	var c := _fight()
	c.reset_round()
	c.p1.position.x = 160
	c.p2.position.x = 160 + distance
	c.p1.energy = 100.0
	c.p2.energy = 100.0
	c.set_controls(true)
	await frames(3)

func _test_fight() -> void:
	print("\n# Combate")
	check(await _wait_fight_phase(), "ROUND 1 / FIGHT! y se habilitan los controles")
	var c := _fight()
	var p1 := c.p1
	var p2 := c.p2
	check(p1.data.id == &"donald_trump" and p2.data.id == &"napoleon", "P1=Trump, P2=Napoleón")
	check(p1.facing == 1 and p2.facing == -1, "se miran el uno al otro")

	# --- Movimiento P1 (WASD) ---
	await _setup_duel(120)
	var x0 := p1.position.x
	key(KEY_D, true); await frames(20); key(KEY_D, false); await frames(2)
	check(p1.position.x > x0 + 15, "P1 camina a la derecha con D (%.1f -> %.1f)" % [x0, p1.position.x])
	x0 = p1.position.x
	key(KEY_A, true); await frames(20); key(KEY_A, false); await frames(2)
	check(p1.position.x < x0 - 10, "P1 camina a la izquierda con A")
	key(KEY_W, true); await frames(12)
	check(p1.position.y < p1.floor_y - 20 and p1.state == Fighter.State.JUMP, "P1 salta con W")
	key(KEY_W, false); await frames(60)
	check(p1.is_on_ground() and p1.state == Fighter.State.IDLE, "P1 aterriza y vuelve a IDLE")
	key(KEY_S, true); await frames(3)
	check(p1.state == Fighter.State.CROUCH, "P1 se agacha con S")
	check(p1._hurt_shape.size.y < p1.data.stand_height, "hurtbox más baja al agacharse")
	key(KEY_S, false); await frames(2)
	key(KEY_SPACE, true); await frames(3)
	check(p1.state == Fighter.State.BLOCK, "P1 bloquea con ESPACIO")
	key(KEY_U, true); await frames(3); key(KEY_U, false); await frames(3)
	check(p1.state == Fighter.State.BLOCK, "bloqueando no se puede atacar")
	key(KEY_SPACE, false); await frames(3)

	# --- Abajo + ataque: barrido, aunque se pulsen a la vez ---
	await _setup_duel(60)
	key(KEY_S, true); key(KEY_J, true); await frames(3)
	check(p1.state == Fighter.State.ATTACK and p1.attack_crouching and p1.get_pose_name() == &"sweep",
		"↓ + patada pulsadas a la vez: barrido")
	key(KEY_J, false); key(KEY_S, false); await frames(40)
	await _setup_duel(60)
	key(KEY_S, true); await frames(5); key(KEY_U, true); await frames(3)
	check(p1.state == Fighter.State.ATTACK and p1.attack_crouching, "↓ mantenido + puño: ataque agachado")
	key(KEY_U, false); key(KEY_S, false); await frames(40)

	# --- Correr: doble toque adelante y atrás ---
	await _setup_duel(200)
	var walk_dx := 0.0
	x0 = p1.position.x
	key(KEY_D, true); await frames(10); key(KEY_D, false)
	walk_dx = p1.position.x - x0
	await frames(30)
	check(not p1.running, "un solo toque no corre")
	x0 = p1.position.x
	key(KEY_D, true); await frames(3); key(KEY_D, false); await frames(3)
	key(KEY_D, true); await frames(10)
	check(p1.running and p1.get_pose_name() == &"run", "doble toque adelante: P1 corre")
	key(KEY_D, false); await frames(3)
	check(not p1.running, "soltar la dirección corta la carrera")
	check(p1.position.x - x0 > walk_dx * 1.4, "correr avanza más que caminar (%.1f vs %.1f)" % [p1.position.x - x0, walk_dx])
	await frames(30)
	x0 = p1.position.x
	key(KEY_A, true); await frames(3); key(KEY_A, false); await frames(3)
	key(KEY_A, true); await frames(10)
	check(p1.state == Fighter.State.BACKDASH and not p1.running and p1.position.x < x0 - 15,
		"doble toque atrás: P1 hace un backdash")
	key(KEY_A, false); await frames(30)
	key(KEY_D, true); await frames(3); key(KEY_D, false); await frames(25)
	key(KEY_D, true); await frames(5)
	check(not p1.running, "toques demasiado separados no corren")
	key(KEY_D, false); await frames(10)
	await _setup_duel(120)

	# --- Movimiento P2 (flechas + numpad) ---
	var x2 := p2.position.x
	key(KEY_LEFT, true); await frames(20); key(KEY_LEFT, false); await frames(2)
	check(p2.position.x < x2 - 15, "P2 camina a la izquierda con ←")
	x2 = p2.position.x
	key(KEY_RIGHT, true); await frames(20); key(KEY_RIGHT, false); await frames(2)
	check(p2.position.x > x2 + 10, "P2 camina a la derecha con →")
	key(KEY_UP, true); await frames(12)
	check(p2.state == Fighter.State.JUMP, "P2 salta con ↑")
	key(KEY_UP, false); await frames(60)
	key(KEY_DOWN, true); await frames(3)
	check(p2.state == Fighter.State.CROUCH, "P2 se agacha con ↓")
	key(KEY_DOWN, false); await frames(2)
	key(KEY_KP_0, true); await frames(3)
	check(p2.state == Fighter.State.BLOCK, "P2 bloquea con Numpad 0")
	key(KEY_KP_0, false); await frames(3)

	# --- Los seis ataques de cada jugador hacen daño exactamente una vez ---
	var p1_keys := {&"punch_light": KEY_U, &"punch_heavy": KEY_I, &"special_1": KEY_O,
		&"kick_light": KEY_J, &"kick_heavy": KEY_K, &"special_2": KEY_L}
	var p2_keys := {&"punch_light": KEY_KP_1, &"punch_heavy": KEY_KP_2, &"special_1": KEY_KP_3,
		&"kick_light": KEY_KP_4, &"kick_heavy": KEY_KP_5, &"special_2": KEY_KP_6}
	for slot in p1_keys:
		await _attack_test(p1, p2, slot, p1_keys[slot])
	for slot in p2_keys:
		await _attack_test(p2, p1, slot, p2_keys[slot])

	# --- Bloqueo reduce el daño ---
	await _setup_duel(40)
	key(KEY_KP_0, true); await frames(3)
	var hp := p2.health
	await tap(KEY_I)
	await frames(30)
	var blocked_dmg := hp - p2.health
	var full := p1.data.punch_heavy.damage * p1.data.strength / p2.data.resistance
	check(blocked_dmg > 0.0 and blocked_dmg < full * 0.3, "bloqueo reduce el daño (%.2f de %.2f)" % [blocked_dmg, full])
	key(KEY_KP_0, false); await frames(3)

	# --- Ataques simultáneos: intercambio de golpes ---
	await _setup_duel(40)
	var h1 := p1.health
	var h2 := p2.health
	# Los puños débiles de cada luchador tienen su propio startup: se adelanta al más lento
	# para que los dos golpes lleguen en el mismo frame.
	var d1 := p1.data.punch_light.startup
	var d2 := p2.data.punch_light.startup
	if d2 > d1:
		key(KEY_KP_1, true); await frames(d2 - d1); key(KEY_U, true)
	else:
		key(KEY_U, true); await frames(d1 - d2); key(KEY_KP_1, true)
	await frames(2)
	key(KEY_U, false); key(KEY_KP_1, false)
	await frames(30)
	check(p1.health < h1 and p2.health < h2, "ambos atacan a la vez y ambos reciben daño (%.1f / %.1f)" % [h1 - p1.health, h2 - p2.health])

	# --- Energía: sin energía no hay especial ---
	await _setup_duel(60)
	p1.energy = 0.0
	await tap(KEY_O)
	await frames(2)
	check(p1.state != Fighter.State.ATTACK, "sin energía no se lanza el especial")

	# --- Nadie atraviesa al rival ni sale de la arena ---
	await _setup_duel(40)
	key(KEY_D, true); key(KEY_LEFT, true)
	await frames(60)
	key(KEY_D, false); key(KEY_LEFT, false)
	await frames(2)
	check(p1.position.x < p2.position.x, "los cuerpos no se atraviesan caminando")
	p1.position.x = 30
	key(KEY_A, true); await frames(40); key(KEY_A, false); await frames(2)
	check(p1.position.x >= p1.bounds.x, "P1 no sale por el borde izquierdo")
	# Salto cruzado: puede pasar por encima y no quedarse atascado
	await _setup_duel(36)
	key(KEY_D, true); key(KEY_W, true)
	await frames(6)
	key(KEY_W, false)
	await frames(60)
	key(KEY_D, false)
	await frames(10)
	check(p1.is_on_ground() and absf(p1.position.x - p2.position.x) >= (p1.data.body_width + p2.data.body_width) * 0.39,
		"tras un salto encima del rival nadie queda superpuesto")
	check(p1.state == Fighter.State.IDLE, "P1 no queda bloqueado tras el salto (estado %s)" % p1.state_name())

func _attack_test(attacker: Fighter, defender: Fighter, slot: StringName, k: Key) -> void:
	var atk := attacker.data.get_attack(slot)
	var dist := 70.0 if (atk.is_projectile() or atk.is_power()) else 34.0
	if atk.dash_speed > 0.0:
		dist = 80.0
	await _setup_duel(dist)
	if attacker.player_id == 2:
		# Intercambiar lados: P2 a la izquierda mirando a P1
		attacker.position.x = 160
		defender.position.x = 160 + dist
		await frames(2)
	var hp := defender.health
	var hits := 0
	var passive_mult := Passives.outgoing_mult(attacker, defender, atk)
	key(k, true); await frames(2); key(k, false)
	var last := hp
	for i in 90:
		await frames(1)
		if defender.health < last - 0.001:
			hits += 1
			last = defender.health
	var expected := atk.damage * attacker.data.strength / defender.data.resistance * passive_mult
	var dealt := hp - defender.health
	if atk.is_power():
		# Los poderes pueden repartir el daño en varios impactos (ráfagas).
		check(hits >= 1 and dealt > 0.0 and dealt <= expected + 0.05,
			"P%d %s (%s): %d impactos, daño %.2f (máx. %.2f)" % [attacker.player_id, slot, atk.display_name, hits, dealt, expected])
		return
	check(hits == 1 and absf(dealt - expected) < 0.05,
		"P%d %s (%s): %d impacto, daño %.2f (esperado %.2f)" % [attacker.player_id, slot, atk.display_name, hits, dealt, expected])

## Lanza el poder especial (special_2) de los 50 luchadores contra un rival
## parado y comprueba que conecta, que su efecto especial ocurre y que las
## entidades desaparecen solas.
func _test_powers() -> void:
	print("\n# Poderes especiales de los 50 luchadores")
	var c := _fight()
	Engine.time_scale = 3.0
	for d in FighterRegistry.all():
		var atk := d.special_2
		c.round_manager.time_left = 99.0   # que no acabe la ronda por tiempo
		await _setup_duel(70)
		c.p1.setup(d, 1, c.p1.input)
		c.p1.position.x = 160
		c.p1.energy = 100.0
		c.p1.controls_enabled = true
		c.p2.position.x = 160 + (40 if not (atk.is_power() or atk.is_projectile()) else 70)
		await frames(3)
		var hp2 := c.p2.health
		var energy_before := c.p1.energy
		var min_y1 := 0.0
		var min_y2 := 0.0
		var min_x2 := 9999.0
		var max_slow := 0
		var max_invert := 0
		var max_root := 0
		var max_shield := 0
		var max_back := 0.0
		var swapped := false
		c.p1.input.press(&"special_2")
		for i in 150:
			await frames(1)
			min_y1 = minf(min_y1, c.p1.position.y - c.p1.floor_y)
			min_y2 = minf(min_y2, c.p2.position.y - c.p2.floor_y)
			min_x2 = minf(min_x2, c.p2.position.x)
			max_slow = maxi(max_slow, c.p2.slow_frames)
			max_invert = maxi(max_invert, c.p2.invert_frames)
			max_root = maxi(max_root, c.p2.root_frames)
			max_shield = maxi(max_shield, c.p1.shield_frames)
			max_back = maxf(max_back, 160.0 - c.p2.position.x)
			if c.p1.position.x > c.p2.position.x:
				swapped = true
		var dealt := hp2 - c.p2.health
		var cap := atk.damage * d.strength / c.p2.data.resistance * _passive_max_mult(d) + 0.05 + _passive_extra_damage(d)
		if atk.power == &"chilean_way":
			# El escudo no hace daño: se comprueba que se activa (la onda devuelta se prueba en MechanicsTest).
			check(max_shield > 0, "%s: «%s» activa el escudo" % [d.id, atk.display_name])
		else:
			check(dealt > 0.0 and dealt <= cap, "%s: «%s» conecta (daño %.1f, máx. %.1f, hp0 %.1f, hp1 %.1f)" % [d.id, atk.display_name, dealt, cap, hp2, c.p2.health])
		match atk.power:
			&"relativity": check(max_slow > 0, "%s: ralentiza al rival" % d.id)
			&"state_siege": check(max_root > 0, "%s: inmoviliza al rival" % d.id)
			&"andean_quake": check(min_y2 < -5.0, "%s: el terremoto lanza al rival (%.1f px)" % [d.id, min_y2])
			&"dark_hypnosis": check(max_invert > 0, "%s: invierte los controles del rival" % d.id)
			&"gravity_flip": check(min_y2 < -5.0, "%s: el rival flota (%.1f px)" % [d.id, min_y2])
			&"mind_web": check(max_invert > 0, "%s: la red sintérgica invierte los controles del rival" % d.id)
			&"black_hole":
				check(min_x2 < 70.0 + 160.0 - 20.0, "%s: el agujero negro atrae al rival (x mín. %.0f)" % [d.id, min_x2])
				check(min_y2 < -5.0, "%s: el estallido lanza al rival (%.1f px)" % [d.id, min_y2])
			&"enlightenment": check(min_y1 < -5.0, "%s: se eleva (%.1f px)" % [d.id, min_y1])
			&"desert_ghost": check(swapped, "%s: reaparece detrás del rival" % d.id)
			&"divine_light": check(c.p1.energy > energy_before - atk.energy_cost + 20.0, "%s: recupera energía (%.0f)" % [d.id, c.p1.energy])
			&"socratic": check(max_invert > 0, "%s: las preguntas confunden al rival" % d.id)
			&"gravity_absolute": check(min_y2 < -5.0, "%s: el rival queda suspendido (%.1f px)" % [d.id, min_y2])
			&"art_of_war": check(swapped, "%s: reaparece detrás del rival" % d.id)
			&"the_prince": check(swapped and max_root > 0, "%s: reaparece detrás y atrapa al rival" % d.id)
			&"death_shot": check(max_slow > 0, "%s: la mira ralentiza al rival" % d.id)
		# Todas las entidades deben desaparecer solas.
		for i in 200:
			if c.projectiles_root.get_child_count() == 0:
				break
			await frames(1)
		check(c.projectiles_root.get_child_count() == 0, "%s: no quedan efectos en pantalla" % d.id)
	Engine.time_scale = 1.0
	# Las rondas ganadas por tiempo durante la prueba ensucian el marcador: se recarga el combate.
	get_tree().change_scene_to_file(Game.SCENE_FIGHT)
	await wait_scene("Fight", 240)
	await _wait_fight_phase()

## Lanza el ultimate de los 50 luchadores contra un rival parado: tiene que ser una escena
## de varios golpes que no pase de su daño base, con su ambiente de pantalla, y todo debe
## desaparecer solo.
func _test_ultimates() -> void:
	print("
# Ultimates de los 50 luchadores")
	var c := _fight()
	Engine.time_scale = 3.0
	var kinds := {}
	for d in FighterRegistry.all():
		var atk := d.ultimate
		c.round_manager.time_left = 99.0
		await _setup_duel(70)
		c.p1.setup(d, 1, c.p1.input)
		c.p1.position.x = 160
		c.p1.energy = 100.0
		c.p1.controls_enabled = true
		c.p2.position.x = 230
		await frames(3)
		var hp2 := c.p2.health
		var fx_seen := false
		c.p1.input.press(&"special_1")
		c.p1.input.press(&"special_2")
		for i in 420:
			await frames(1)
			fx_seen = fx_seen or is_instance_valid(c.ult_fx)
		var dealt := hp2 - c.p2.health
		var cap := atk.damage * d.strength / c.p2.data.resistance * _passive_max_mult(d) + 0.05 + _passive_extra_damage(d)
		kinds[atk.ult_kind] = true
		check(atk.is_power() and atk.ult_kind != &"", "%s: «%s» es un ultimate de tipo %s" % [d.id, atk.display_name, atk.ult_kind])
		check(dealt > 0.0 and dealt <= cap, "%s: «%s» conecta (daño %.1f, máx. %.1f)" % [d.id, atk.display_name, dealt, cap])
		check(fx_seen and not is_instance_valid(c.ult_fx), "%s: el ambiente aparece y se retira solo" % d.id)
		check(c.projectiles_root.get_child_count() == 0, "%s: no quedan efectos en pantalla" % d.id)
		c.p2.health = c.p2.data.max_health
	check(kinds.size() >= 9, "hay %d tipos distintos de ultimate" % kinds.size())
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(Game.SCENE_FIGHT)
	await wait_scene("Fight", 240)
	await _wait_fight_phase()

func _test_rounds_and_results() -> void:
	print("\n# Rondas y resultados")
	var c := _fight()
	var rm := c.round_manager
	rm.pause_scale = 0.05
	# Ronda 1: P1 gana por K.O.
	await _setup_duel(34)
	c.p2.health = 1.0
	await tap(KEY_U)
	var saw_ko := false
	for i in 20:
		await frames(1)
		if c.p2.state == Fighter.State.KO:
			saw_ko = true
			break
	check(saw_ko, "con 0 de vida el luchador queda K.O.")
	await frames(10)
	check(rm.wins[1] == 1, "la ronda 1 se suma a P1")
	for i in 200:
		await frames(1)
		if rm.phase == RoundManager.Phase.INTRO or rm.round_number == 2:
			break
	check(rm.round_number == 2, "empieza la ronda 2")
	check(Game.stage_owner(1) == Game.p1_fighter_id and Game.stage_owner(2) == Game.p2_fighter_id and Game.stage_owner(3) == Game.p1_fighter_id, "escenarios: R1 de P1, R2 de P2, R3 de P1")
	check(c.stage_name() == StageRegistry.name_for(Game.p2_fighter_id), "la ronda 2 se juega en el escenario de P2 (%s)" % c.stage_name())
	check(c.stage_holder.get_child_count() == 1, "solo hay un escenario cargado")
	check(c.p1.health == c.p1.data.max_health and c.p2.health == c.p2.data.max_health, "la ronda 2 empieza con vida llena")
	check(await _wait_fight_phase(), "ronda 2 en juego")
	# Ronda 2: se agota el tiempo y P2 tiene más vida -> gana P2
	c.p1.health = c.p1.data.max_health * 0.4
	rm.time_left = 0.2
	await frames(20)
	check(rm.wins[2] == 1, "tiempo agotado: gana quien tiene más vida (P2)")
	check(await _wait_fight_phase(), "ronda 3 en juego")
	check(rm.round_number == 3, "contador de rondas = 3")
	# Ronda 3: empate por tiempo con la misma vida
	rm.time_left = 0.2
	await frames(20)
	check(rm.wins[1] == 1 and rm.wins[2] == 1, "misma vida al acabar el tiempo = empate")
	check(await _wait_fight_phase(), "ronda 4 en juego")
	# Ronda 4: P1 gana el combate por K.O.
	await _setup_duel(34)
	c.p2.health = 1.0
	await tap(KEY_U)
	check(await wait_scene("Results", 400), "al ganar 2 rondas aparece la pantalla de victoria")
	check(Game.last_winner == 1 and Game.last_p1_rounds == 2 and Game.last_p2_rounds == 1, "resultado guardado: P1 gana 2-1")
	await frames(5)
	await tap(KEY_ENTER)   # REVANCHA tiene el foco
	check(await wait_scene("Fight"), "REVANCHA reinicia el combate")
	var c2 := _fight()
	check(c2.round_manager.round_number == 1 and c2.round_manager.wins[1] == 0, "la revancha empieza de cero")

## Prueba de resistencia: dos "jugadores" aleatorios pelean miles de frames.
## Comprueba que nadie sale de la arena ni queda atascado en un estado.
func _test_soak() -> void:
	print("\n# Prueba de resistencia (entradas aleatorias)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var frames_run := 0
	var out_of_bounds := 0
	var stuck := 0
	var attacks := 0
	var counter := {"hits": 0}
	var matches := 0
	var c := _fight()
	c.round_manager.pause_scale = 0.05
	c.hit_landed.connect(func(_a, _d, _k, _r): counter.hits += 1)
	var moves: Array[StringName] = [&"left", &"right", &"jump", &"crouch", &"block"]
	while frames_run < 6000:
		var cur := _fight()
		if cur == null:
			# Pantalla de resultados: volver a pelear.
			if scene() and scene().name == "Results":
				matches += 1
				get_tree().change_scene_to_file(Game.SCENE_FIGHT)
				await frames(5)
				cur = _fight()
				if cur:
					cur.round_manager.pause_scale = 0.05
					cur.hit_landed.connect(func(_a, _d, _k, _r): counter.hits += 1)
			else:
				await frames(1)
			continue
		for f in cur.fighters:
			var inp := f.input
			if rng.randf() < 0.08:
				inp.release_all()
				if rng.randf() < 0.7:
					inp.hold(moves[rng.randi() % moves.size()])
			if rng.randf() < 0.06:
				inp.press(InputManager.ATTACK_ACTIONS[rng.randi() % 6])
			if f.state == Fighter.State.ATTACK and f.state_frames == 1:
				attacks += 1
			if f.position.x < f.bounds.x - 0.5 or f.position.x > f.bounds.y + 0.5 or f.position.y > f.floor_y + 0.5:
				out_of_bounds += 1
			if f.state in [Fighter.State.ATTACK, Fighter.State.HIT] and f.state_frames > 240:
				stuck += 1
		await frames(1)
		frames_run += 1
	check(out_of_bounds == 0, "nadie sale de la arena (%d frames)" % frames_run)
	check(stuck == 0, "nadie queda atascado en ATAQUE/DAÑO")
	check(attacks > 50 and counter.hits > 10, "hubo combate real: %d ataques, %d impactos, %d combates completos" % [attacks, counter.hits, matches])

## Desde la pantalla de la historia hasta el combate: Enter salta la tarjeta, avanza las escenas de diálogo y,
## cuando aparece, pulsa ¡COMBATIR! (la intro y las escenas solo se saltan con Enter).
func _story_to_fight() -> bool:
	for i in 150:
		await frames(24)
		if scene() == null or scene().name != "Story":
			break
		await tap(KEY_ENTER)
	return await wait_scene("Fight", 240)

## ¿Sale este luchador como rival en alguna época?
func _is_story_rival_id(id: StringName) -> bool:
	for chap in Game.STORY_CHAPTERS:
		if (chap[1] as Array).has(id):
			return true
	return false

## Modo Historia (arcade): menú -> selección de J1 -> pantalla de la línea del tiempo ->
## combate contra la CPU -> escalera de rivales, continuaciones, jefe secreto y fin de partida.
func _test_arcade() -> void:
	print("\n# Arcade (1 jugador contra la CPU)")
	Game.difficulty = Game.Difficulty.NORMAL
	get_tree().change_scene_to_file(Game.SCENE_MENU)
	check(await wait_scene("MainMenu"), "vuelve al menú principal")
	var diff := scene().get_node("Buttons/Difficulty") as Button
	check(diff.text == "DIFICULTAD  < NORMAL >", "el botón muestra la dificultad")
	diff.grab_focus()
	await frames(2)
	await tap(KEY_ENTER)
	check(Game.difficulty == Game.Difficulty.HARD and diff.text == "DIFICULTAD  < DIFÍCIL >", "DIFICULTAD pasa a DIFÍCIL")
	await tap(KEY_ENTER)
	await tap(KEY_ENTER)
	check(Game.difficulty == Game.Difficulty.NORMAL, "DIFICULTAD da la vuelta a NORMAL")
	await tap(KEY_LEFT)
	check(Game.difficulty == Game.Difficulty.EASY and diff.has_focus(), "izquierda baja la dificultad sin mover el foco")
	await tap(KEY_RIGHT)
	check(Game.difficulty == Game.Difficulty.NORMAL, "derecha la vuelve a subir")
	(scene().get_node("Buttons/Play") as Button).grab_focus()
	await frames(2)
	await tap(KEY_ENTER)
	check(await wait_scene("CharacterSelect"), "ARCADE abre la selección de luchador")
	check(Game.is_vs_cpu() and scene().confirmed[2], "en arcade solo elige J1 (la CPU ya está lista)")
	await frames(5)
	await tap(KEY_U)
	check(await wait_scene("Story", 240), "con J1 confirmado se muestra la línea del tiempo")
	var ladder := Game.arcade_ladder
	var rivals_total := 0
	for chap in Game.STORY_CHAPTERS:
		rivals_total += (chap[1] as Array).size()
	var expected := rivals_total - (1 if _is_story_rival_id(Game.p1_fighter_id) else 0) + 1   # rivales menos el jugador, más el Nexo
	check(ladder.size() == expected, "la escalera tiene %d rivales (%d)" % [expected, ladder.size()])
	var ordered := true
	for i in range(1, ladder.size()):
		if Game.story_chapter_of(ladder[i]) < Game.story_chapter_of(ladder[i - 1]):
			ordered = false
	check(ordered, "los capítulos van del más reciente al más antiguo")
	var assigned := {}
	for chap in Game.STORY_CHAPTERS:
		for fid in chap[1]:
			assigned[fid] = assigned.get(fid, 0) + 1
	var missing := 0
	for d in FighterRegistry.all():
		var n: int = assigned.get(d.id, 0)
		if n != (0 if StoryCampaign.PLAYABLE_ONLY.has(d.id) else 1):
			missing += 1
	check(missing == 0, "cada rival está en una sola época y los de solo elegir en ninguna (%d mal asignados)" % missing)
	for ch in Game.STORY_CHAPTERS.size():
		var creators_here := 0
		for fid in Game.STORY_CHAPTERS[ch][1]:
			if Game.STORY_CREATORS.has(fid):
				creators_here += 1
		check(creators_here == 1, "la época %d tiene un creador del Reloj poseído" % (ch + 1))
	check(ladder[ladder.size() - 1] == Game.STORY_NEXO_ID, "el Nexo cierra la escalera")
	check(FighterRegistry.get_by_id(Game.STORY_NEXO_ID).id == Game.STORY_NEXO_ID, "la ficha del Nexo carga")
	var nexo_in_roster := false
	for d in FighterRegistry.all():
		nexo_in_roster = nexo_in_roster or d.id == Game.STORY_NEXO_ID
	check(not nexo_in_roster, "el Nexo no se puede elegir (no está en el roster)")
	for ch in Game.STORY_BOSSES:
		var boss: StringName = Game.STORY_BOSSES[ch]
		var at := ladder.find(boss)
		check(at == -1 or Game.story_is_chapter_boss(at), "%s cierra su capítulo" % boss)
	check(Game.story_nexo_reaction().is_empty(), "el primer capítulo no tiene reacción del Nexo")
	var sin_escena := 0
	for id in ladder:
		if StoryScenes.lines(id, Game.p1_fighter_id).is_empty():
			sin_escena += 1
	check(sin_escena == 0, "todos los rivales tienen su escena de diálogo (%d sin ella)" % sin_escena)
	check(not ladder.has(&"jesus_de_nazaret") and not ladder.has(&"papa_francisco") and not ladder.has(&"lautaro"), "los buenos (Jesús, el Papa, Lautaro) no son rivales")
	var possession_ok := true
	for i in ladder.size() - 1:
		if Game.story_possession_follows(i) and not Game.story_is_chapter_boss(i):
			possession_ok = false
	check(possession_ok, "el creador poseído entra justo tras el jefe de su época")
	check(Game.story_chapter_start(0), "el primer combate abre el capítulo I")
	check(await _story_to_fight(), "COMBATIR empieza el combate")
	var c := _fight()
	var seen := {}
	for id in ladder:
		seen[id] = true
	check(seen.size() == ladder.size() and not seen.has(Game.p1_fighter_id), "rivales sin repetir y sin incluir al jugador")
	check(c.p2.data.id == ladder[0] and Game.arcade_stage == 0, "el primer rival es el primero de la escalera")
	check(c.stage_name() == StageRegistry.name_for(Game.stage_owner(2)) and Game.stage_owner(2) == StringName(StageDefsCity.PREFIX + String(ladder[0])), "arcade: el rival aparece en la ciudad invadida por su ejército")
	check(c.ai != null and not c.p2.input.use_keyboard, "P2 lo maneja la CPU y no el teclado")
	check(absf(c.ai.level - 0.5) < 0.001, "nivel de IA NORMAL = 0.5 (%.2f)" % c.ai.level)
	check(await _wait_fight_phase(), "ROUND 1 / FIGHT!")

	Engine.time_scale = 3.0
	# --- La CPU ataca y hace daño a un jugador quieto ---
	var stats := {"cpu_hits": 0, "cpu_attacks": 0, "blocked": 0}
	c.hit_landed.connect(func(a, _d, _k, r):
		if a == c.p2:
			stats.cpu_hits += 1
		elif r.blocked:
			stats.blocked += 1)
	c.p2.attack_started.connect(func(_f, _a): stats.cpu_attacks += 1)
	c.round_manager.pause_scale = 0.05
	var start_x := c.p2.position.x
	for i in 1500:
		await frames(1)
		if stats.cpu_hits > 0:
			break
	check(stats.cpu_attacks > 0 and stats.cpu_hits > 0, "la CPU se acerca y golpea (%d ataques, %d impactos)" % [stats.cpu_attacks, stats.cpu_hits])
	check(absf(c.p2.position.x - start_x) > 10.0 or stats.cpu_hits > 0, "la CPU se mueve sola")

	# --- La CPU bloquea (nivel máximo, golpes fuertes de P1) ---
	c.ai = AIController.new(c.p2, c.p1, 1.0)
	stats.blocked = 0
	for i in 25:
		await _setup_duel(34)
		c.p1.input.press(&"punch_heavy")
		await frames(45)
		if stats.blocked > 0:
			break
	check(stats.blocked > 0, "la CPU de nivel máximo bloquea golpes (%d bloqueados)" % stats.blocked)

	# --- Resistencia: la CPU contra entradas aleatorias ---
	var saved_rounds := Game.rounds_to_win
	var saved_max := Game.max_rounds
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out_of_bounds := 0
	var stuck := 0
	stats.cpu_attacks = 0
	var moves: Array[StringName] = [&"left", &"right", &"jump", &"crouch", &"block"]
	for i in 3000:
		var inp := c.p1.input
		if rng.randf() < 0.08:
			inp.release_all()
			if rng.randf() < 0.7:
				inp.hold(moves[rng.randi() % moves.size()])
		if rng.randf() < 0.06:
			inp.press(InputManager.ATTACK_ACTIONS[rng.randi() % 6])
		for f in c.fighters:
			if f.position.x < f.bounds.x - 0.5 or f.position.x > f.bounds.y + 0.5 or f.position.y > f.floor_y + 0.5:
				out_of_bounds += 1
			if f.state in [Fighter.State.ATTACK, Fighter.State.HIT] and f.state_frames > 240:
				stuck += 1
		await frames(1)
	check(out_of_bounds == 0, "con la CPU peleando nadie sale de la arena")
	check(stuck == 0, "con la CPU peleando nadie queda atascado")
	check(stats.cpu_attacks > 30, "la CPU pelea de verdad (%d ataques)" % stats.cpu_attacks)
	Game.rounds_to_win = saved_rounds
	Game.max_rounds = saved_max
	Engine.time_scale = 1.0

	# --- Escalera: ganar pasa al siguiente rival y sube el nivel ---
	Game.set_match_result(1, 2, 0)
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	check(await wait_scene("Results"), "pantalla de resultados del arcade")
	var rematch := scene().get_node("Buttons/Rematch") as Button
	check(Game.arcade_outcome() == &"next" and rematch.text == "SIGUIENTE COMBATE", "tras ganar se ofrece SIGUIENTE COMBATE")
	check(not (scene().get_node("Buttons/Select") as Button).visible, "en arcade no se puede cambiar de luchador")
	await frames(5)
	await tap(KEY_ENTER)
	check(await wait_scene("Story", 240), "SIGUIENTE COMBATE abre la línea del tiempo")
	await frames(10)
	check(await _story_to_fight(), "COMBATIR abre el combate")
	c = _fight()
	check(Game.arcade_stage == 1 and c.p2.data.id == ladder[1], "el segundo combate es contra el segundo rival")
	var expected_level := 0.5 + 0.5 / (ladder.size() - 1.0)
	check(absf(c.ai.level - expected_level) < 0.001, "la CPU sube de nivel: %.3f" % c.ai.level)

	# --- Perder: continuar gasta una revancha y repite rival ---
	Game.set_match_result(2, 0, 2)
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	check(await wait_scene("Results"), "resultados tras perder")
	rematch = scene().get_node("Buttons/Rematch") as Button
	check(rematch.text == "REVANCHA", "tras perder se ofrece REVANCHA (%s)" % rematch.text)
	await frames(5)
	await tap(KEY_ENTER)
	check(await wait_scene("Fight", 240), "REVANCHA repite el combate")
	check(Game.story_continues_used == 1 and Game.arcade_stage == 1 and _fight().p2.data.id == ladder[1], "cuenta la revancha y repite el mismo rival")

	# --- Revanchas ilimitadas: perder nunca termina la partida ---
	Game.set_match_result(2, 0, 2)
	check(Game.arcade_outcome() == &"retry", "las revanchas son ilimitadas: perder siempre permite reintentar")
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	check(await wait_scene("Results"), "resultados tras otra derrota")
	rematch = scene().get_node("Buttons/Rematch") as Button
	check(rematch.visible and rematch.text == "REVANCHA", "sigue ofreciendo REVANCHA")
	await frames(5)

	# --- Ganar el último combate completa el arcade ---
	Game.arcade_stage = ladder.size() - 1
	Game.set_match_result(1, 2, 0)
	check(Game.arcade_outcome() == &"complete", "ganar al último rival completa el arcade")
	get_tree().change_scene_to_file(Game.SCENE_RESULTS)
	check(await wait_scene("Results"), "resultados del arcade completado")
	check(rematch_text_is("EL DESTINO"), "historia completada: se ofrece EL DESTINO (final con elección)")

	# --- El jefe de cada época sale reforzado; el Nexo, más aún y con la IA al máximo ---
	var boss_at := -1   # el último jefe de época antes del Nexo (tras él viene el creador poseído)
	for i in ladder.size() - 1:
		if Game.story_is_chapter_boss(i):
			boss_at = i
	check(boss_at >= 0, "hay jefes de época antes del Nexo")
	Game.arcade_stage = boss_at
	Game.p2_fighter_id = ladder[boss_at]
	var boss_base := FighterRegistry.get_by_id(ladder[boss_at]).max_health
	check(Game.story_is_chapter_boss(boss_at) and Game.p2_data().max_health > boss_base, "el jefe de la época tiene más vida")
	if Game.story_possession_follows(boss_at):
		Game.arcade_stage = boss_at + 1
		Game.p2_fighter_id = ladder[boss_at + 1]
		var creator_base := FighterRegistry.get_by_id(ladder[boss_at + 1]).max_health
		check(Game.story_is_creator(boss_at + 1) and Game.p2_data().max_health > creator_base, "el creador poseído también sale reforzado")
	Game.arcade_stage = ladder.size() - 1
	Game.p2_fighter_id = ladder[ladder.size() - 1]
	var nexo_base := FighterRegistry.get_by_id(Game.STORY_NEXO_ID).max_health
	check(Game.is_story_nexo_fight() and Game.p2_data().max_health > nexo_base * 1.4, "el Nexo tiene mucha más vida")
	check(Game.ai_level() == 1.0, "el Nexo usa la IA al máximo")
	check(Game.story_chapter_of(Game.STORY_NEXO_ID) == Game.STORY_CHAPTERS.size(), "el Nexo tiene su propio capítulo")
	# La IA depende de cuántos villanos se han vencido, no de su lugar en la lista.
	Game.p2_fighter_id = ladder[2]
	Game.story_beaten.clear()
	Game.story_beaten[0] = true
	Game.story_beaten[1] = true
	Game.arcade_stage = 2
	var lvl_a := Game.ai_level()
	Game.story_beaten.clear()
	Game.story_beaten[3] = true
	Game.story_beaten[5] = true
	Game.arcade_stage = 4
	check(is_equal_approx(lvl_a, Game.ai_level()), "la IA no cambia con el orden en que se vencen los villanos")
	Game.story_beaten[4] = true
	check(Game.ai_level() > lvl_a, "la IA sube al vencer más villanos")
	Game.story_beaten.clear()
	Game.mode = Game.Mode.VERSUS

## Modo Historia: el jugador elige a quién detener dentro de cada época y debe vencerlos a todos (el jefe, el último)
## antes de pasar a la siguiente. Solo lógica: sin pantallas.
func _test_story_choice() -> void:
	print("\n# Historia: elegir a quién detener")
	Game.mode = Game.Mode.ARCADE
	Game.start_story(&"napoleon")
	var ladder := Game.arcade_ladder
	var ch0: Array[int] = []
	for i in ladder.size():
		if Game.story_chapter_of(ladder[i]) == 0 and not Game.story_is_creator(i):
			ch0.append(i)
	var boss0: int = -1
	for i in ch0:
		if Game.story_is_chapter_boss(i):
			boss0 = i
	var others: Array[int] = ch0.filter(func(i): return i != boss0)
	check(boss0 >= 0 and others.size() >= 3, "la primera época tiene varios villanos y un jefe (%d)" % others.size())
	check(Game.story_candidates() == others, "al empezar se puede elegir a cualquiera menos al jefe")
	check(not Game.story_available(boss0), "el jefe está bloqueado al principio")
	check(Game.story_chapter_fresh() and Game.story_beaten.is_empty(), "al empezar la época es nueva y no hay combates ganados")
	check(Game.story_frontier() == 0 and Game.story_snapshot()["stage"] == 0, "se guarda el primer combate sin ganar")
	# Elegir al último de la lista: no obliga a seguir el orden.
	var pick: int = others[others.size() - 1]
	Game.story_pick(pick)
	check(Game.arcade_stage == pick and Game.p2_fighter_id == ladder[pick], "se puede elegir a un villano que no es el primero")
	Game.arcade_advance()
	check(Game.story_beaten.has(pick) and Game.story_last_won == pick, "vencerlo lo marca como liberado")
	check(Game.arcade_stage != pick and Game.story_available(Game.arcade_stage), "después se ofrece otro villano")
	check(not Game.story_chapter_fresh(), "la época ya no es nueva")
	check(Game.story_snapshot()["stage"] == 0, "lo guardado sigue siendo el primer combate sin ganar")
	# Vencer a todos menos al jefe, en orden libre.
	var left: Array[int] = others.filter(func(i): return i != pick)
	left.reverse()
	for k in left.size():
		check(not Game.story_available(boss0), "el jefe sigue bloqueado con %d villanos por vencer" % (left.size() - k))
		Game.story_pick(left[k])
		Game.arcade_advance()
	check(Game.story_available(boss0) and Game.story_candidates() == [boss0], "al vencer a todos los demás solo queda el jefe")
	check(Game.arcade_stage == boss0, "el jefe es lo que se ofrece")
	# Al caer el jefe entra solo el creador poseído y, al vencerlo, empieza la época siguiente.
	var chapter_before := Game.story_current_chapter()
	Game.arcade_advance()
	check(Game.story_is_creator(Game.arcade_stage), "al caer el jefe entra el creador poseído")
	check(Game.story_candidates().is_empty(), "el creador no se elige: entra solo")
	Game.arcade_advance()
	check(Game.story_current_chapter() == chapter_before + 1, "vencido el creador se pasa a la época siguiente")
	check(Game.story_chapter_fresh() and not Game.story_candidates().is_empty(), "la nueva época ofrece sus villanos")
	check(Game.story_fragment_earned(0), "se recupera el fragmento del Reloj de la época vencida")
	# Retomar la partida: lo guardado es el primer combate sin ganar y los anteriores cuentan como vencidos.
	var save := Game.story_snapshot()
	check(Game.story_resume(save) and Game.story_beaten.size() == int(save["stage"]), "al retomar, todo lo anterior está vencido")
	Game.mode = Game.Mode.VERSUS

## Daño máximo extra que puede sumar la pasiva del atacante durante la prueba (la radiación de Curie).
func _passive_extra_damage(d: FighterData) -> float:
	if d.passive == &"radiactividad":
		return Passives.CURIE_DAMAGE * float(Passives.CURIE_TICKS / Passives.CURIE_EVERY)
	return 0.0

## Mayor multiplicador de daño que la pasiva del atacante puede aplicar a un ataque (1.0 = ninguno).
func _passive_max_mult(d: FighterData) -> float:
	if not Passives.CFG.has(d.passive):
		return 1.0
	var cfg: Array = Passives.CFG[d.passive]
	match cfg[0]:
		Passives.DAMAGE_LOW_HP, Passives.RANGE_FAR, Passives.RANGE_NEAR:
			return 1.0 + float(cfg[2])
		Passives.OPENING, Passives.PROJECTILE_DAMAGE, Passives.FULL_ENERGY_DAMAGE:
			return 1.0 + float(cfg[1])
	return 1.0
