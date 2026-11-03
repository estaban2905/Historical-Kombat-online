## Ajustes del jugador (volumen), guardados en user://settings.cfg y aplicados al arrancar (Sfx._ready).
## Cada volumen va de 0 (silencio) a STEPS (el original) en pasos iguales de sonoridad.
class_name Settings
extends RefCounted

const STEPS := 10
## Volumen base de los efectos (el de Sfx antes de existir los ajustes).
const SFX_BASE_DB := -6.0
const SILENT_DB := -80.0

## Para pruebas: otra ruta para no tocar los ajustes reales.
static var path: String = "user://settings.cfg"
## Volumen general (todo el juego) y de los efectos de sonido, en pasos de 0 a STEPS.
static var master: int = STEPS
static var effects: int = STEPS

## Decibelios de un paso: STEPS es 0 dB (sin cambio) y 0 es silencio.
static func step_to_db(step: int) -> float:
	var s := clampi(step, 0, STEPS)
	return SILENT_DB if s == 0 else linear_to_db(float(s) / float(STEPS))

static func load_settings() -> void:
	master = STEPS
	effects = STEPS
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	master = clampi(int(cfg.get_value("audio", "master", STEPS)), 0, STEPS)
	effects = clampi(int(cfg.get_value("audio", "effects", STEPS)), 0, STEPS)

static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "effects", effects)
	cfg.save(path)

## Pone en marcha los volúmenes guardados (bus general y efectos).
static func apply() -> void:
	AudioServer.set_bus_volume_db(0, step_to_db(master))
	Sfx.volume_db = SFX_BASE_DB + step_to_db(effects) if effects > 0 else SILENT_DB
