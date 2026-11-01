## Cerebro de la CPU: maneja el InputManager de un luchador con entradas
## virtuales, igual que lo haría una persona con el teclado.
##   - Cada pocos frames (tiempo de reacción) decide si acercarse, retroceder
##     o atacar según la distancia, la energía y el estado del rival.
##   - Cuando el rival empieza un ataque que la alcanza, tira un dado para
##     bloquearlo (y reacciona con retraso, así que a veces llega tarde) o para
##     escapar con un backdash.
##   - Encadena cancelaciones, castiga ataques con recuperación larga, usa el
##     antiaéreo contra saltos, mezcla golpes altos y bajos contra el bloqueo,
##     lanza el ultimate con la energía llena y se levanta con voltereta o evita
##     el derribo.
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
## true: el bloqueo planeado es agachado (contra golpes bajos).
var _block_low: bool = false
## Frames que mantiene agachada para un golpe bajo / antiaéreo.
var _crouch_left: int = 0
## Pasos de un doble toque (backdash): dirección por frame.
var _dash_steps: Array[int] = []
## Un ataque (attack_instance) ya decidió si se cancela o no.
var _cancel_instance: int = -1
var _tech_decided: bool = false
var _tech_left: int = 0
var _roll_back: bool = false

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
	if me.state == Fighter.State.KNOCKDOWN:
		_hold_while_down()
		return
	_try_tech()
	_try_cancel_chain()
	if _block_wait > 0:
		_block_wait -= 1
		if _block_wait == 0:
			_block_left = _block_hold
	elif _block_left > 0:
		_block_left -= 1
	var blocking := _block_left > 0
	if _jump_left > 0:
		_jump_left -= 1
	if _crouch_left > 0:
		_crouch_left -= 1
	if _tech_left > 0:
		_tech_left -= 1
	inp.hold(&"block", blocking or _tech_left > 0)
	inp.hold(&"jump", _jump_left > 0)
	if not _dash_steps.is_empty():
		_move_dir = _dash_steps.pop_front()
	elif blocking:
		_move_dir = 0
	else:
		_think_in -= 1
		if _think_in <= 0:
			_think_in = _reaction() + _rng.randi_range(0, 6)
			_decide()
	inp.hold(&"left", _move_dir < 0)
	inp.hold(&"right", _move_dir > 0)
	# Después de decidir: un golpe bajo o un antiaéreo necesitan el agachado en este mismo frame.
	inp.hold(&"crouch", (blocking and _block_low) or _crouch_left > 0)

func _reset_plan() -> void:
	_think_in = 0
	_move_dir = 0
	_jump_left = 0
	_block_wait = 0
	_block_left = 0
	_crouch_left = 0
	_dash_steps.clear()
	_tech_left = 0

# --- Parámetros según el nivel ------------------------------------------
func _reaction() -> int:
	return int(lerpf(26.0, 8.0, level))

func _aggression() -> float:
	return lerpf(0.35, 0.85, level)

func _block_chance() -> float:
	return lerpf(0.10, 0.75, level)

## Probabilidad de elegir bien entre guardia alta y baja.
func _read_level_chance() -> float:
	return lerpf(0.5, 0.95, level)

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
	if me.is_on_ground():
		# Ultimate con la energía llena y el rival a tiro.
		var ult := me.data.ultimate
		if ult != null and me.can_use_ultimate() and dist <= (210.0 if ult.is_power() else _reach(ult, foe.data.body_width)) \
				and _rng.randf() < 0.5 + 0.4 * level:
			me.input.press(&"special_1")
			me.input.press(&"special_2")
			return
		# Rival en el aire cerca: antiaéreo (abajo + puño fuerte).
		if not foe.is_on_ground() and dist < 80.0 and _rng.randf() < 0.25 + 0.65 * level \
				and me.data.punch_heavy != null:
			_crouch_left = 2
			me.input.press(&"punch_heavy")
			return
		# Castigo: ataque rival en recuperación y un golpe nuestro que llega antes de que acabe.
		var punish := _punish_slot(dist)
		if punish != &"" and _rng.randf() < 0.35 + 0.6 * level:
			me.input.press(punish)
			return
		# Rival bloqueando agachado: su golpe alto propio (overhead) le sorprende.
		if foe.state == Fighter.State.BLOCK and foe.crouch_blocking and _rng.randf() < 0.3 + 0.3 * level:
			for slot in [&"punch_heavy", &"kick_heavy", &"punch_light", &"kick_light"]:
				var oh := me.data.get_attack(slot)
				if oh != null and oh.hit_level == AttackData.HitLevel.OVERHEAD and me.cooldowns.get(slot, 0) <= 0 						and dist <= _reach(oh, foe.data.body_width):
					me.input.press(slot)
					return
		# Rival bloqueando de pie: mezcla golpes bajos (hay que agacharse para bloquearlos).
		if foe.state == Fighter.State.BLOCK and not foe.crouch_blocking and me.data.kick_light != null \
				and dist <= _reach(me.data.kick_light, foe.data.body_width) \
				and _rng.randf() < 0.3 + 0.3 * level:
			_crouch_left = 2
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

## Frames que le quedan de recuperación al ataque del rival (0 si no está en recuperación).
func _foe_recovery_left() -> int:
	var atk := foe.current_attack
	if foe.state != Fighter.State.ATTACK or atk == null or atk.is_projectile() or atk.is_power():
		return 0
	if foe.attack_frame <= atk.startup + atk.active:
		return 0
	return atk.total_frames() - foe.attack_frame

## El golpe normal de más daño que llega al rival y acierta antes de que se recupere.
func _punish_slot(dist: float) -> StringName:
	var left := _foe_recovery_left()
	if left <= 0:
		return &""
	var best := &""
	var best_damage := 0.0
	for slot in [&"punch_light", &"kick_light", &"punch_heavy", &"kick_heavy"]:
		var atk := me.data.get_attack(slot)
		if atk == null or me.cooldowns.get(slot, 0) > 0:
			continue
		# Hay que andar un poco hasta el golpe: se deja margen de 2 frames.
		if atk.startup + 2 > left or dist > _reach(atk, foe.data.body_width):
			continue
		if atk.damage > best_damage:
			best_damage = atk.damage
			best = slot
	return best

## Cancela el golpe que acaba de conectar o ser bloqueado en otro mayor (una decisión por golpe).
func _try_cancel_chain() -> void:
	if me.state != Fighter.State.ATTACK or not me.attack_connected or _cancel_instance == me.attack_instance:
		return
	_cancel_instance = me.attack_instance
	var cur: int = Fighter.CANCEL_RANK.get(me.current_slot, 0)
	if cur == 0 or cur >= 3 or _rng.randf() > 0.2 + 0.7 * level:
		return
	var dist := absf(foe.position.x - me.position.x)
	var slots: Array[StringName] = []
	var weights: Array[float] = []
	var total := 0.0
	for slot in Fighter.CANCEL_RANK:
		if Fighter.CANCEL_RANK[slot] < cur or me.chain_slots.has(slot):
			continue
		var w := _weight(slot, dist, true)
		if w > 0.0:
			slots.append(slot)
			weights.append(w)
			total += w
	if total <= 0.0:
		return
	var roll := _rng.randf() * total
	for i in slots.size():
		roll -= weights[i]
		if roll <= 0.0:
			me.input.press(slots[i])
			return
	me.input.press(slots.back())

## Al caer derribada, a veces pulsa bloqueo justo antes de tocar el suelo para evitar el derribo.
func _try_tech() -> void:
	if not me.knockdown_pending:
		_tech_decided = false
		return
	if _tech_decided or me.is_on_ground() or me.velocity.y <= 0.0 or me.floor_y - me.position.y > 12.0:
		return
	_tech_decided = true
	if _rng.randf() < 0.1 + 0.7 * level:
		_tech_left = 2

## Tumbada: suelta todo y, según el dado, mantiene atrás al final para levantarse rodando.
func _hold_while_down() -> void:
	var inp := me.input
	if me.state_frames <= 1:
		_roll_back = _rng.randf() < 0.6 * level
	var away := -1 if foe.position.x > me.position.x else 1
	var go := _roll_back and me.state_frames >= Fighter.KNOCKDOWN_FRAMES - 3
	inp.hold(&"block", false)
	inp.hold(&"crouch", false)
	inp.hold(&"jump", false)
	inp.hold(&"left", go and away < 0)
	inp.hold(&"right", go and away > 0)
	_move_dir = 0

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
	var roll := _rng.randf()
	if threat and roll >= _block_chance() and _dash_steps.is_empty() \
			and dist < 70.0 and me.state in [Fighter.State.IDLE, Fighter.State.WALK] \
			and _rng.randf() < 0.15 + 0.35 * level:
		# No bloquea: se escapa con un backdash (doble toque hacia atrás).
		var back := -1 if foe.position.x > me.position.x else 1
		_dash_steps = [back, 0, back, back, back, back, back]
		return
	if threat and roll < _block_chance():
		_block_wait = maxi(int(_reaction() * 0.5), 2)
		_block_hold = hold
		# Proyectiles y poderes usan el nivel de su ataque; los golpes, el contexto.
		var low := (atk.hit_level if atk.is_projectile() or atk.is_power() else foe.current_hit_level()) \
			== AttackData.HitLevel.LOW
		_block_low = low if _rng.randf() < _read_level_chance() else not low
