## Checksum dorado: regresión de jugabilidad entre versiones.
## Juega varias peleas con entradas de semilla fija y compara el resumen del estado de cada segundo con
## los guardados en tests/golden_checksums.json. Si un cambio altera el balance, el frame data, un poder
## o cualquier regla sin querer, el resumen cambia y esta prueba lo dice. Si el cambio es intencionado,
## se regenera el archivo en el mismo PR.
##
## Uso:  godot --headless --fixed-fps 60 --path . res://tests/GoldenTest.tscn
##       godot --headless --fixed-fps 60 --path . res://tests/GoldenTest.tscn -- --update
##
## El resumen usa números en coma flotante: cada plataforma (Windows, Linux...) tiene su propio
## juego de referencias. Si no hay referencias para la plataforma actual, la prueba avisa y no falla;
## hay que generarlas allí con --update.
extends Node

const GOLDEN_PATH := "res://tests/golden_checksums.json"
const TICKS := 2400
const EVERY := 60
## [P1, P2, semilla]: elegidos para cubrir proyectiles, poderes con estado, invocaciones y ultimates.
const MATCHUPS: Array = [
	[&"napoleon", &"donald_trump", 1],
	[&"vladimir_putin", &"kim_jong_un", 2],
	[&"xi_jinping", &"julio_cesar", 3],
	[&"nikola_tesla", &"albert_einstein", 4],
	[&"juana_de_arco", &"hernan_cortes", 5],
	[&"sun_tzu", &"isaac_newton", 6],
	[&"cleopatra", &"gengis_kan", 7],
	[&"salvador_allende", &"adolf_hitler", 8],
	# Con pasiva: Rasputín (K.O. evitado), Curie (radiación), Buda (guardia) y Stalin (daño reducido).
	[&"rasputin", &"marie_curie", 9],
	[&"buda", &"joseph_stalin", 10],
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene = null
	_run.call_deferred()

func _key(m: Array) -> String:
	return "%s_vs_%s_s%d" % [m[0], m[1], m[2]]

func _run() -> void:
	print("\n=== HISTORY COMBAT · CHECKSUM DORADO ===")
	Game.rounds_to_win = 99
	Game.max_rounds = 99
	var update := "--update" in OS.get_cmdline_user_args()
	var platform := OS.get_name()
	var current := {}
	for m in MATCHUPS:
		current[_key(m)] = await ScriptedInputs.play(self, m[0], m[1], m[2], TICKS, EVERY)
	var file := {}
	if FileAccess.file_exists(GOLDEN_PATH):
		file = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	if update:
		file["snapshot_version"] = CombatManager.SNAPSHOT_VERSION
		var platforms: Dictionary = file.get("platforms", {})
		platforms[platform] = current
		file["platforms"] = platforms
		var out := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		out.store_string(JSON.stringify(file, "  ", true) + "\n")
		out.close()
		print("  Referencias de %s guardadas en %s (%d peleas)." % [platform, GOLDEN_PATH, current.size()])
		get_tree().quit(0)
		return
	var reference: Dictionary = file.get("platforms", {}).get(platform, {})
	if reference.is_empty():
		print("  SIN REFERENCIAS para %s: no se compara. Genera las de esta plataforma con --update." % platform)
		print("\n=== RESULTADO: 0 diferencias (sin referencias) ===")
		get_tree().quit(0)
		return
	if int(file.get("snapshot_version", 0)) != CombatManager.SNAPSHOT_VERSION:
		print("  [FAIL] las referencias son de otra versión del resumen: regenéralas con --update")
		get_tree().quit(1)
		return
	var failures := 0
	for m in MATCHUPS:
		var key := _key(m)
		var now: Array = current[key]
		var ref: Array = reference.get(key, [])
		var first := -1
		for i in maxi(now.size(), ref.size()):
			if i >= now.size() or i >= ref.size() or int(now[i]) != int(ref[i]):
				first = i
				break
		var ok := first == -1
		print("  [%s] %s%s" % ["OK  " if ok else "FAIL", key, "" if ok else " · primera diferencia en el segundo %d" % ((first + 1) * EVERY / 60)])
		if not ok:
			failures += 1
	print("\n=== RESULTADO: %d diferencias ===" % failures)
	get_tree().quit(1 if failures > 0 else 0)
