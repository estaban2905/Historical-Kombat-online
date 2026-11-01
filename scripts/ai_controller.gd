## Cerebro de la CPU: maneja el InputManager de un luchador con entradas
## virtuales, igual que lo haría una persona con el teclado.
##   - Cada pocos frames (tiempo de reacción) decide si acercarse, retroceder
##     o atacar según la distancia, la energía y el estado del rival.
##   - Cuando el rival empieza un ataque que la alcanza, tira un dado para
##     bloquearlo (y reacciona con retraso, así que a veces llega tarde).
## `level` (0..1) lo controla todo: reacción, agresividad y bloqueo.
## CombatManager llama a think() una vez por frame de física, antes del tick.
class_name AIController
extends RefCounted

var me: Fighter
var foe: Fighter
var level: float = 0.5

var _rng := RandomNumberGenerator.new()
var _think_in: int = 0
var _move_dir: int = 0
var _jump_left: int = 0
var _block_wait: int = 0
var _block_left: int = 0
var _block_hold: int = 0
var _seen_instance: int = -1
## Frame de la llave en que intentará zafarse (-1 = no lo intentará).
var _break_at: int = -1

func _init(p_me: Fighter, p_foe: Fighter, p_level: float) -> void:
	me = p_me
	foe = p_foe
	level = clampf(p_level, 0.0, 1.0)
	_rng.randomize()

func think() -> void:
	var inp := me.input
	if not me.controls_enabled or me.state == Fighter.State.KO or me.state == Fighter.State.VICTORY:
		inp.release_all()
		_reset_plan()
		return
	_watch_foe_attack()
	if me.state == Fighter.State.THROWN:
		_try_throw_break()
		return
	if _block_wait > 0:
		_block_wait -= 1
		if _block_wait == 0:
			_block_left = _block_hold
	elif _block_left > 0:
		_block_left -= 1
	var blocking := _block_left > 0
	if _jump_left > 0:
		_jump_left -= 1
	inp.hold(&"block", blocking)
	inp.hold(&"jump", _jump_left > 0)
	if blocking:
		_move_dir = 0
	else:
		_think_in -= 1
		if _think_in <= 0:
			_think_in = _reaction() + _rng.randi_range(0, 6)
			_decide()
	inp.hold(&"left", _move_dir < 0)
	inp.hold(&"right", _move_dir > 0)

func _reset_plan() -> void:
	_think_in = 0
	_move_dir = 0
	_jump_left = 0
	_block_wait = 0
	_block_left = 0

# --- Parámetros según el nivel ------------------------------------------
func _reaction() -> int:
	return int(lerpf(26.0, 8.0, level))

func _aggression() -> float:
	return lerpf(0.35, 0.85, level)

func _block_chance() -> float:
	return lerpf(0.10, 0.75, level)

func _grab_chance() -> float:
	return lerpf(0.15, 0.7, level)

## Probabilidad de zafarse de una llave (se decide una vez por llave).
func _break_chance() -> float:
	return lerpf(0.05, 0.6, level)

## Al ser agarrada, tira un dado y, si sale, pulsa las dos teclas de zafarse
## con un retraso de reacción dentro de la ventana.
func _try_throw_break() -> void:
	me.input.release_all()
	if me.state_frames == 0:
		_break_at = int(lerpf(9.0, 3.0, level)) if _rng.randf() < _break_chance() else -1
	if me.state_frames == _break_at:
		me.input.press(&"punch_light")
		me.input.press(&"kick_light")

# --- Decisiones -----------------------------------------------------------
func _decide() -> void:
	var dx := foe.position.x - me.position.x
	var dist := absf(dx)
	var toward := 1 if dx > 0.0 else -1
	_move_dir = 0
	var can_act := me.hitstop_frames == 0 and me.state in [
		Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.CROUCH, Fighter.State.JUMP]
	if not can_act:
		return
	# Rival que se queda bloqueando a tiro: agarre.
	if foe.state == Fighter.State.BLOCK and me.is_on_ground() \
			and dist <= _reach(me.data.get_attack(&"grab"), foe.data.body_width) \
			and _rng.randf() < _grab_chance():
		me.input.press(&"punch_light")
		me.input.press(&"kick_light")
		return
	var slot := _pick_attack(dist)
	if slot != &"" and _rng.randf() < _aggression():
		me.input.press(slot)
		return
	var spacing := _spacing()
	if dist > spacing:
		_move_dir = toward
		if dist > 140.0 and me.is_on_ground() and _rng.randf() < 0.04 + 0.08 * level:
			_jump_left = 3
	elif dist < spacing * 0.45 and _rng.randf() < 0.35:
		_move_dir = -toward

## Distancia a la que le gusta pelear: justo al alcance de su golpe ligero.
func _spacing() -> float:
	var a := me.data.punch_light
	return _reach(a, foe.data.body_width) * 0.9 if a else 40.0

## Distancia entre centros a la que un golpe cuerpo a cuerpo alcanza al objetivo.
func _reach(atk: AttackData, target_width: float) -> float:
	return atk.hitbox_offset.x + atk.hitbox_size.x * 0.5 + target_width * 0.5

func _foe_is_vulnerable() -> bool:
	if foe.state == Fighter.State.HIT:
		return true
	var atk := foe.current_attack
	return foe.state == Fighter.State.ATTACK and atk != null \
		and foe.attack_frame > atk.startup + atk.active

func _pick_attack(dist: float) -> StringName:
	var vulnerable := _foe_is_vulnerable()
	var slots: Array[StringName] = []
	var weights: Array[float] = []
	var total := 0.0
	for slot in InputManager.ATTACK_ACTIONS:
		var w := _weight(slot, dist, vulnerable)
		if w <= 0.0:
			continue
		slots.append(slot)
		weights.append(w)
		total += w
	if total <= 0.0:
		return &""
	var roll := _rng.randf() * total
	for i in slots.size():
		roll -= weights[i]
		if roll <= 0.0:
			return slots[i]
	return slots.back()

## Peso de un ataque ahora mismo (0 = no se puede o no tiene sentido).
func _weight(slot: StringName, dist: float, vulnerable: bool) -> float:
	var atk := me.data.get_attack(slot)
	if atk == null or me.cooldowns.get(slot, 0) > 0 or atk.energy_cost > me.energy:
		return 0.0
	if not me.is_on_ground() and not atk.usable_in_air:
		return 0.0
	var heavy := slot == &"punch_heavy" or slot == &"kick_heavy"
	var special := slot == &"special_1" or slot == &"special_2"
	var w := 0.0
	if atk.is_projectile():
		if dist < 90.0 or dist > 280.0:
			return 0.0
		w = 2.0
	elif atk.is_power():
		if dist > 150.0:
			return 0.0
		w = 1.5
	else:
		if dist > _reach(atk, foe.data.body_width):
			return 0.0
		w = 1.0 if heavy else 3.0
	if special:
		w *= lerpf(0.4, 1.2, level)
	if vulnerable and heavy:
		w *= 1.0 + 2.0 * level
	return w

## Detecta un ataque nuevo del rival y decide si intentará bloquearlo.
func _watch_foe_attack() -> void:
	var atk := foe.current_attack
	if foe.state != Fighter.State.ATTACK or atk == null:
		return
	if foe.attack_instance == _seen_instance:
		return
	_seen_instance = foe.attack_instance
	if not me.is_on_ground():
		return
	var dist := absf(foe.position.x - me.position.x)
	var hold := atk.total_frames() + 8
	var threat := false
	if atk.is_projectile():
		threat = dist < 300.0
		hold += int(dist / atk.projectile_speed * 60.0)
	elif atk.is_power():
		threat = dist < 170.0
	else:
		threat = dist <= _reach(atk, me.data.body_width) + 30.0
	if threat and _rng.randf() < _block_chance():
		_block_wait = maxi(int(_reaction() * 0.5), 2)
		_block_hold = hold
