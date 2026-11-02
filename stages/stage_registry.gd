## Catálogo de escenarios: cada luchador tiene el suyo.
## Las definiciones están en stage_defs_a.gd ... stage_defs_d.gd (listas de
## operaciones de dibujo). Julio César usa el Coliseo original.
class_name StageRegistry
extends RefCounted

const THEMED := "res://stages/ThemedStage.tscn"
const COLOSSEUM := "res://stages/colosseum/Colosseum.tscn"
const COLOSSEUM_OWNER := &"julio_cesar"

static var _cache := {}

## Definición del escenario del luchador (vacía si usa una escena propia).
static func def_for(fighter_id: StringName) -> Dictionary:
	if fighter_id == COLOSSEUM_OWNER:
		return {}
	if not _cache.has(fighter_id):
		var d := StageDefsA.get_def(fighter_id)
		if d.is_empty():
			d = StageDefsB.get_def(fighter_id)
		if d.is_empty():
			d = StageDefsC.get_def(fighter_id)
		if d.is_empty():
			d = StageDefsD.get_def(fighter_id)
		_cache[fighter_id] = d
	return _cache[fighter_id]

static func scene_for(fighter_id: StringName) -> String:
	if fighter_id == COLOSSEUM_OWNER or def_for(fighter_id).is_empty():
		return COLOSSEUM
	return THEMED

static func name_for(fighter_id: StringName) -> String:
	if scene_for(fighter_id) == COLOSSEUM:
		return "EL COLISEO ROMANO"
	return def_for(fighter_id).get("name", "ESCENARIO")

static func clear_cache() -> void:
	_cache.clear()
