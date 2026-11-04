## Foto completa del estado de la simulación del combate, para poder VOLVER a ella (rollback).
##
## state_snapshot() de CombatManager es solo un resumen para comparar; esto guarda TODO lo que
## hace falta para seguir la pelea desde ese tick y obtener exactamente lo mismo que si nunca
## se hubiera interrumpido. La foto vive en memoria (no se escribe en disco), así que puede
## guardar referencias a Resources y a los dos luchadores sin copiarlos.
##
## Para no olvidar ningún campo, los luchadores y las entidades se guardan por reflexión: todas
## las variables del script, salvo las que se listan como presentación en SKIP_*. Un campo
## nuevo en Fighter o Projectile queda cubierto sin tocar este archivo; el test de rollback
## (tests/rollback_test.gd) comprueba que restaurar da el mismo resultado.
class_name SimState
extends RefCounted

## Variables de Fighter que no son estado de simulación: nodos, datos fijos o solo presentación.
const SKIP_FIGHTER: Array[StringName] = [
	&"data", &"input", &"opponent", &"_hurt_shape", &"_hit_shape", &"passive_pulses",
]
## Variables de Projectile que no se copian (derivadas o solo dibujo).
const SKIP_PROJECTILE: Array[StringName] = [&"_t"]

static var _names_cache: Dictionary = {}

## Nombres de las variables de script de `obj` (cacheado por script), sin las de `skip`.
static func _names(obj: Object, skip: Array[StringName]) -> Array[StringName]:
	var script: Script = obj.get_script()
	if _names_cache.has(script):
		return _names_cache[script]
	var out: Array[StringName] = []
	for p in obj.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var n := StringName(p["name"])
		if n in skip:
			continue
		out.append(n)
	_names_cache[script] = out
	return out

## Copia de un valor que la foto no debe compartir con la simulación viva.
static func _copy(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	return v

static func _grab(obj: Object, skip: Array[StringName]) -> Dictionary:
	var d := {}
	for n in _names(obj, skip):
		var v: Variant = obj.get(n)
		# Los nodos hijos (@onready) son presentación; los luchadores sí se guardan como referencia.
		if v is Node and not (v is Fighter):
			continue
		d[n] = _copy(v)
	return d

static func _put(obj: Object, d: Dictionary) -> void:
	for n in d:
		obj.set(n, _copy(d[n]))

## Quita ya los proyectiles destruidos que aún esperan a que el motor los libere al final del frame:
## para la simulación no existen, y así dos peleas iguales tienen los mismos hijos aunque una
## ejecute varios ticks en el mismo frame.
static func purge_dead(cm: CombatManager) -> void:
	for p in cm.projectiles_root.get_children():
		if not (p as Projectile).alive:
			cm.projectiles_root.remove_child(p)
			p.free()

## Toma la foto del estado actual.
static func capture(cm: CombatManager) -> Dictionary:
	purge_dead(cm)
	var rm := cm.round_manager
	var fighters_state: Array = []
	for f in cm.fighters:
		fighters_state.append({
			"vars": _grab(f, SKIP_FIGHTER),
			"position": f.position,
			"hurt_pos": f.hurtbox_shape.position,
			"hit_pos": f.hitbox_shape.position,
			"hurt_size": f._hurt_shape.size,
			"hit_size": f._hit_shape.size,
			"input": {
				"held": f.input.virtual_held.duplicate(),
				"pressed": f.input.virtual_pressed.duplicate(),
				"applied": f.input._applied_mask,
			},
		})
	var entities: Array = []
	for p in cm.projectiles_root.get_children():
		var pr := p as Projectile
		entities.append({"vars": _grab(pr, SKIP_PROJECTILE), "position": pr.position, "visible": pr.visible})
	return {
		"tick": cm.tick_count,
		"fighters": fighters_state,
		"entities": entities,
		"cinematic_frames": cm.cinematic_frames,
		"cinematic_fighter": cm.cinematic_fighter,
		"cinematic_text": cm.cinematic_text,
		"nexo_phase": cm._nexo_phase,
		"round": {"phase": rm.phase, "number": rm.round_number, "wins": rm.wins.duplicate(),
			"time_left": rm.time_left, "ko_pending": rm._ko_pending,
			"step": rm._step, "wait_until": rm._wait_until, "winner": rm._winner},
	}

## Vuelve al estado de la foto. Solo es válido dentro de la misma ronda y el mismo escenario
## (las transiciones de ronda no se deshacen: el rollback no retrocede más allá de ellas).
static func restore(cm: CombatManager, s: Dictionary) -> void:
	cm.tick_count = s["tick"]
	for i in cm.fighters.size():
		var f := cm.fighters[i]
		var fs: Dictionary = s["fighters"][i]
		_put(f, fs["vars"])
		f.position = fs["position"]
		f.hurtbox_shape.position = fs["hurt_pos"]
		f.hitbox_shape.position = fs["hit_pos"]
		f._hurt_shape.size = fs["hurt_size"]
		f._hit_shape.size = fs["hit_size"]
		f.input.virtual_held = fs["input"]["held"].duplicate()
		f.input.virtual_pressed = fs["input"]["pressed"].duplicate()
		f.input._applied_mask = fs["input"]["applied"]
	# Entidades: se vuelven a crear tal como estaban, en el mismo orden.
	for p in cm.projectiles_root.get_children():
		cm.projectiles_root.remove_child(p)
		p.free()
	for e in s["entities"]:
		var pr := Projectile.new()
		_put(pr, e["vars"])
		pr.position = e["position"]
		pr.visible = e["visible"]
		pr.shake_requested.connect(cm.shake)
		pr.sound_requested.connect(cm.sfx)
		cm.projectiles_root.add_child(pr)
	cm.cinematic_frames = s["cinematic_frames"]
	cm.cinematic_fighter = s["cinematic_fighter"]
	cm.cinematic_text = s["cinematic_text"]
	if cm._nexo_base != Vector2.ZERO and cm._nexo_phase != s["nexo_phase"]:
		cm._set_nexo_phase(s["nexo_phase"], false)
	cm._nexo_phase = s["nexo_phase"]
	var rm := cm.round_manager
	var r: Dictionary = s["round"]
	rm.phase = r["phase"]
	rm.round_number = r["number"]
	# El escenario de la ronda de la foto (si se retrocedió a otra ronda, el cargado puede ser otro).
	cm.swap_stage(rm.round_number)
	rm.wins = r["wins"].duplicate()
	rm.time_left = r["time_left"]
	rm._ko_pending = r["ko_pending"]
	rm._step = r["step"]
	rm._wait_until = r["wait_until"]
	rm._winner = r["winner"]
