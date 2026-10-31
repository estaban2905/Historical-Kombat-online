## Motor de un luchador: máquina de estados, física, ataques, bloqueo,
## energía y cajas de colisión. No contiene datos de ningún personaje
## concreto: todo sale de FighterData / AttackData.
##
## El CombatManager llama a tick() una vez por frame de física (60 Hz) para
## ambos luchadores en orden fijo y luego resuelve los impactos. Así los dos
## jugadores pueden atacar a la vez e incluso intercambiar golpes en el
## mismo frame.
class_name Fighter
extends Node2D

signal health_changed(fighter: Fighter)
signal energy_changed(fighter: Fighter)
signal knocked_out(fighter: Fighter)
signal attack_started(fighter: Fighter, attack: AttackData)
signal projectile_requested(fighter: Fighter, attack: AttackData, spawn_position: Vector2)
signal power_requested(fighter: Fighter, attack: AttackData)
signal combo_performed(fighter: Fighter, combo: ComboData)
signal not_enough_energy(fighter: Fighter)

enum State { IDLE, WALK, JUMP, CROUCH, BLOCK, ATTACK, HIT, KO, VICTORY }

const GRAVITY := 1100.0
const GROUND_FRICTION := 900.0
const MAX_ENERGY := 100.0
## El bloqueo deja pasar solo este porcentaje del daño ("chip damage").
const BLOCK_DAMAGE_FACTOR := 0.15
## Frames que se recuerda una pulsación de ataque hecha antes de tiempo.
const INPUT_BUFFER_FRAMES := 6
const ENERGY_ON_HIT_DEALT := 6.0
const ENERGY_ON_HIT_TAKEN := 4.0
const ENERGY_ON_BLOCK := 3.0
const ENERGY_REGEN_PER_SECOND := 2.5
const HISTORY_SIZE := 8
## Correr: doble toque (pulsar, soltar, pulsar) en una dirección, hacia delante o atrás.
const DOUBLE_TAP_FRAMES := 15
const RUN_SPEED_MULT := 1.8

@export var player_id: int = 1

@onready var visual: FighterRenderer = $Visual
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/Shape
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape

var data: FighterData
var input: InputManager
var opponent: Fighter

var state: State = State.IDLE
var state_frames: int = 0
var facing: int = 1
var velocity: Vector2 = Vector2.ZERO
var health: float = 100.0
var energy: float = 0.0
## Si es false el luchador ignora los controles (presentación / fin de ronda).
var controls_enabled: bool = false
var floor_y: float = 200.0
## Límites horizontales de la arena (x mínima, x máxima).
var bounds: Vector2 = Vector2(16, 410)

# Ataque en curso
var current_attack: AttackData
var current_slot: StringName = &""
var attack_frame: int = 0
var attack_crouching: bool = false
var attack_airborne: bool = false
## Aumenta con cada ataque nuevo. Sirve para que un golpe impacte una sola vez.
var attack_instance: int = 0
var hit_targets: Array[Fighter] = []
var projectile_spawned: bool = false

var stun_frames: int = 0
var hitstop_frames: int = 0
var cooldowns: Dictionary = {}
var buffered_slot: StringName = &""
var buffered_frames: int = 0
## Golpes seguidos recibidos sin recuperarse (para el contador de combo del HUD).
var combo_hits_taken: int = 0
## Historial de ataques para los combos de comando: [{slot, frame}, ...]
var input_history: Array = []
var frame_counter: int = 0
var crouch_blocking: bool = false
## Estados alterados provocados por poderes del rival (frames restantes).
var slow_frames: int = 0
var invert_frames: int = 0
var float_frames: int = 0
## true mientras corre (subestado de WALK). Se activa con doble toque en la dirección.
var running: bool = false
var _prev_h: int = 0
var _tap_dir: int = 0
var _tap_timer: int = 0
var _hurt_shape: RectangleShape2D
var _hit_shape: RectangleShape2D

func _ready() -> void:
	# Cada luchador necesita sus propias formas (no compartir el recurso de la escena).
	_hurt_shape = RectangleShape2D.new()
	hurtbox_shape.shape = _hurt_shape
	_hit_shape = RectangleShape2D.new()
	hitbox_shape.shape = _hit_shape
	hitbox_shape.disabled = true

## Prepara el luchador con su ficha y su jugador.
func setup(p_data: FighterData, p_player_id: int, p_input: InputManager) -> void:
	data = p_data
	player_id = p_player_id
	input = p_input
	name = "Fighter%d" % player_id
	if data.sprite_frames:
		sprite.sprite_frames = data.sprite_frames
		sprite.position = data.sprite_offset
		sprite.visible = true
		visual.visible = false
	else:
		sprite.visible = false
		visual.visible = true
		visual.setup(data)
	reset_for_round(position.x, 1)
	energy = 30.0

## Restablece vida, estado y posición al empezar una ronda.
func reset_for_round(x: float, p_facing: int) -> void:
	position = Vector2(x, floor_y)
	velocity = Vector2.ZERO
	facing = p_facing
	health = data.max_health
	_end_attack()
	stun_frames = 0
	hitstop_frames = 0
	combo_hits_taken = 0
	slow_frames = 0
	invert_frames = 0
	float_frames = 0
	running = false
	_prev_h = 0
	_tap_dir = 0
	_tap_timer = 0
	modulate = Color.WHITE
	cooldowns.clear()
	buffered_slot = &""
	input_history.clear()
	if input:
		input.release_all()
	_set_state(State.IDLE)
	hurtbox_shape.set_deferred("disabled", false)
	_update_boxes()
	_update_visual()
	health_changed.emit(self)
	energy_changed.emit(self)

# =========================================================================
#  Bucle principal (lo llama CombatManager)
# =========================================================================
func tick(delta: float) -> void:
	frame_counter += 1
	_read_attack_buffer()
	_tick_status()
	if hitstop_frames > 0:
		hitstop_frames -= 1
		input.end_frame()
		return
	# Tiempo ralentizado: solo se actualiza uno de cada dos frames.
	if slow_frames > 0 and frame_counter % 2 == 0:
		input.end_frame()
		return
	state_frames += 1
	if _tap_timer > 0:
		_tap_timer -= 1
	for slot in cooldowns.keys():
		cooldowns[slot] = maxi(cooldowns[slot] - 1, 0)
	if controls_enabled and state != State.KO:
		add_energy(ENERGY_REGEN_PER_SECOND * delta)

	match state:
		State.IDLE, State.WALK, State.CROUCH:
			_ground_control()
		State.BLOCK:
			_state_block()
		State.JUMP:
			_state_jump()
		State.ATTACK:
			_state_attack()
		State.HIT:
			_state_hit()
		State.KO, State.VICTORY:
			_apply_friction(delta)

	_apply_physics(delta)
	_update_facing()
	_update_boxes()
	_update_visual()
	input.end_frame()

# =========================================================================
#  Estados
# =========================================================================
func _ground_control() -> void:
	if not is_on_ground():
		_set_state(State.JUMP)
		return
	var h := input.horizontal() if controls_enabled else 0
	if invert_frames > 0:
		h = -h
	_update_run(h)
	var want_block := controls_enabled and input.is_held(&"block")
	var want_crouch := controls_enabled and input.is_held(&"crouch")
	var want_jump := controls_enabled and input.is_held(&"jump")

	# Prioridad: bloqueo > ataque > salto > agacharse > caminar > reposo
	if want_block:
		crouch_blocking = want_crouch
		velocity.x = 0.0
		_set_state(State.BLOCK)
		return
	if buffered_slot != &"" and _try_start_attack(buffered_slot):
		return
	if want_jump:
		velocity.y = data.jump_velocity
		velocity.x = h * data.jump_forward_speed
		_set_state(State.JUMP)
		return
	if want_crouch:
		velocity.x = 0.0
		if state != State.CROUCH:
			_set_state(State.CROUCH)
		return
	if h != 0:
		# Retroceder es algo más lento que avanzar.
		var backwards := h != facing
		velocity.x = h * data.walk_speed * (0.8 if backwards else 1.0) * (RUN_SPEED_MULT if running else 1.0)
		if state != State.WALK:
			_set_state(State.WALK)
		return
	velocity.x = 0.0
	if state != State.IDLE:
		_set_state(State.IDLE)

## Detecta el doble toque en una dirección (adelante o atrás). Se corre mientras
## se mantiene; soltar o cambiar de dirección lo corta. Usa solo el estado de las
## teclas por frame, así funciona igual con teclado, IA, tests y repeticiones.
func _update_run(h: int) -> void:
	if h != _prev_h:
		if h == 0:
			running = false
		elif h == _tap_dir and _tap_timer > 0:
			running = true
			_tap_timer = 0
		else:
			running = false
			_tap_dir = h
			_tap_timer = DOUBLE_TAP_FRAMES
	_prev_h = h

func _state_block() -> void:
	_apply_friction(1.0 / 60.0)
	if stun_frames > 0:
		# Bloqueo forzado mientras dura el blockstun.
		stun_frames -= 1
		return
	if not (controls_enabled and input.is_held(&"block")):
		_set_state(State.IDLE)
		_ground_control()
	else:
		crouch_blocking = input.is_held(&"crouch")

func _state_jump() -> void:
	if controls_enabled and buffered_slot != &"":
		_try_start_attack(buffered_slot)

func _state_attack() -> void:
	attack_frame += 1
	var atk := current_attack
	var in_motion := attack_frame <= atk.startup + atk.active
	if atk.dash_speed > 0.0 and in_motion and not attack_airborne:
		velocity.x = facing * atk.dash_speed
	elif not attack_airborne:
		_apply_friction(1.0 / 60.0)
	# Proyectil: se dispara justo al acabar el startup.
	if atk.is_projectile() and not projectile_spawned and attack_frame >= atk.startup:
		projectile_spawned = true
		var spawn := position + Vector2(atk.hitbox_offset.x * facing, atk.hitbox_offset.y)
		projectile_requested.emit(self, atk, spawn)
	# Poder especial: se invoca justo al acabar el startup.
	if atk.is_power() and not projectile_spawned and attack_frame >= atk.startup:
		projectile_spawned = true
		power_requested.emit(self, atk)
	# Un ataque aéreo termina al tocar el suelo.
	if attack_airborne and is_on_ground() and attack_frame > 2:
		_end_attack()
		_set_state(State.IDLE)
		return
	if attack_frame >= atk.total_frames():
		var was_crouching := attack_crouching
		var was_air := attack_airborne
		_end_attack()
		if was_air and not is_on_ground():
			_set_state(State.JUMP)
		elif was_crouching and controls_enabled and input.is_held(&"crouch"):
			_set_state(State.CROUCH)
		else:
			_set_state(State.IDLE)
		if is_on_ground() and state != State.CROUCH:
			_ground_control()

func _state_hit() -> void:
	if is_on_ground():
		_apply_friction(1.0 / 60.0)
	if stun_frames > 0:
		stun_frames -= 1
	if stun_frames <= 0 and is_on_ground():
		combo_hits_taken = 0
		_set_state(State.IDLE)

# =========================================================================
#  Ataques
# =========================================================================
func _read_attack_buffer() -> void:
	if buffered_frames > 0:
		buffered_frames -= 1
		if buffered_frames == 0:
			buffered_slot = &""
	if not controls_enabled or input == null:
		return
	var slot := input.pressed_attack()
	if slot != &"":
		buffered_slot = slot
		buffered_frames = INPUT_BUFFER_FRAMES

## Intenta iniciar un ataque. Devuelve false si no es posible ahora.
func _try_start_attack(slot: StringName) -> bool:
	var atk := data.get_attack(slot)
	if atk == null:
		return false
	var airborne := not is_on_ground()
	if airborne and not atk.usable_in_air:
		return false
	if cooldowns.get(slot, 0) > 0:
		return false
	if atk.energy_cost > energy:
		buffered_slot = &""
		not_enough_energy.emit(self)
		return false
	buffered_slot = &""
	buffered_frames = 0
	add_energy(-atk.energy_cost)
	if atk.cooldown > 0:
		cooldowns[slot] = atk.cooldown
	current_attack = atk
	current_slot = slot
	attack_frame = 0
	attack_instance += 1
	hit_targets.clear()
	projectile_spawned = false
	# Cuenta la tecla mantenida y no solo el estado: si ↓ y el ataque se pulsan
	# a la vez, el ataque sale antes de que el luchador llegue a agacharse.
	var crouch_held := not airborne and controls_enabled and input != null and input.is_held(&"crouch")
	attack_crouching = (state == State.CROUCH or crouch_held) and atk.usable_crouching
	attack_airborne = airborne
	if not airborne and atk.dash_speed <= 0.0:
		velocity.x = 0.0
	_set_state(State.ATTACK)
	_record_history(slot)
	attack_started.emit(self, atk)
	return true

func _end_attack() -> void:
	current_attack = null
	current_slot = &""
	attack_frame = 0
	attack_crouching = false
	attack_airborne = false
	hit_targets.clear()

func _record_history(slot: StringName) -> void:
	input_history.append({"slot": slot, "frame": frame_counter})
	if input_history.size() > HISTORY_SIZE:
		input_history.pop_front()
	for combo in data.combos:
		if combo and combo.matches(input_history):
			combo_performed.emit(self, combo)

## true si la hitbox cuerpo a cuerpo está activa en este frame.
func is_hitbox_active() -> bool:
	if state != State.ATTACK or current_attack == null or current_attack.is_projectile() or current_attack.is_power():
		return false
	return attack_frame > current_attack.startup and attack_frame <= current_attack.startup + current_attack.active

## Rivales cuya hurtbox toca nuestra hitbox y que este ataque aún no golpeó.
func get_hit_candidates() -> Array[Fighter]:
	var result: Array[Fighter] = []
	if not is_hitbox_active():
		return result
	for area in hitbox.get_overlapping_areas():
		var target := area.get_parent() as Fighter
		if target and target != self and not hit_targets.has(target) and target.can_be_hit():
			result.append(target)
	return result

func register_hit(target: Fighter) -> void:
	hit_targets.append(target)

func can_be_hit() -> bool:
	return state != State.KO and state != State.VICTORY

# =========================================================================
#  Recibir daño
# =========================================================================
## Aplica un golpe. `direction` = hacia dónde sale despedido (+1 / -1).
## Devuelve {blocked: bool, damage: float, ko: bool}.
func receive_hit(attacker: Fighter, atk: AttackData, direction: int) -> Dictionary:
	var result := {"blocked": false, "damage": 0.0, "ko": false}
	var dmg := atk.damage * attacker.data.strength / maxf(data.resistance, 0.1)
	if state == State.BLOCK and is_on_ground():
		# BLOQUEO: daño muy reducido que nunca llega a noquear.
		dmg *= BLOCK_DAMAGE_FACTOR
		health = maxf(health - dmg, minf(health, 1.0))
		stun_frames = atk.blockstun
		velocity.x = direction * atk.knockback * 0.6
		add_energy(ENERGY_ON_BLOCK)
		visual.flash_block()
		result.blocked = true
	else:
		health = maxf(health - dmg, 0.0)
		combo_hits_taken = combo_hits_taken + 1 if state == State.HIT else 1
		_end_attack()
		velocity.x = direction * atk.knockback
		if atk.launch < 0.0:
			velocity.y = atk.launch
		elif not is_on_ground():
			velocity.y = minf(velocity.y, -140.0)
		stun_frames = atk.hitstun
		_set_state(State.HIT)
		add_energy(ENERGY_ON_HIT_TAKEN)
		attacker.add_energy(ENERGY_ON_HIT_DEALT)
		visual.flash_hit()
		if health <= 0.0:
			_knock_out(direction)
			result.ko = true
	result.damage = dmg
	health_changed.emit(self)
	return result

func _knock_out(direction: int) -> void:
	health = 0.0
	velocity = Vector2(direction * 150.0, -230.0)
	_end_attack()
	_set_state(State.KO)
	hurtbox_shape.set_deferred("disabled", true)
	knocked_out.emit(self)

func set_victory() -> void:
	if state == State.KO:
		return
	_end_attack()
	velocity.x = 0.0
	_set_state(State.VICTORY)

func add_energy(amount: float) -> void:
	var before := energy
	energy = clampf(energy + amount, 0.0, MAX_ENERGY)
	if not is_equal_approx(before, energy):
		energy_changed.emit(self)

# =========================================================================
#  Física
# =========================================================================
func is_on_ground() -> bool:
	return position.y >= floor_y - 0.01 and velocity.y >= 0.0

func _apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, GROUND_FRICTION * delta)

## Cuenta atrás de los estados alterados y color que los delata.
func _tick_status() -> void:
	if slow_frames > 0:
		slow_frames -= 1
	if invert_frames > 0:
		invert_frames -= 1
	var tint := Color.WHITE
	if slow_frames > 0:
		tint = Color(0.6, 0.8, 1.0)
	elif invert_frames > 0:
		tint = Color(0.95, 0.6, 1.0)
	elif float_frames > 0:
		tint = Color(1.0, 1.0, 0.7)
	if modulate != tint:
		modulate = tint

## status: slow (tiempo lento) | invert (izquierda/derecha cambiadas) | float (flota y cae)
func apply_status(status: StringName, frames: int) -> void:
	match status:
		&"slow": slow_frames = frames
		&"invert": invert_frames = frames
		&"float": float_frames = frames

func _apply_physics(delta: float) -> void:
	if float_frames > 0:
		float_frames -= 1
		velocity.y = -38.0
	elif position.y < floor_y or velocity.y < 0.0:
		velocity.y += GRAVITY * delta
	position += velocity * delta
	if position.y >= floor_y:
		position.y = floor_y
		if velocity.y > 0.0:
			velocity.y = 0.0
			if state == State.JUMP:
				velocity.x = 0.0
				_set_state(State.IDLE)
	position.x = clampf(position.x, bounds.x, bounds.y)

func _update_facing() -> void:
	if opponent == null:
		return
	var can_turn := state in [State.IDLE, State.WALK, State.CROUCH, State.BLOCK] and is_on_ground()
	var dx := opponent.position.x - position.x
	if can_turn and absf(dx) > 2.0:
		facing = 1 if dx > 0.0 else -1

## true si está pegado a un límite de la arena (para el empuje en esquina).
func is_at_wall() -> bool:
	return position.x <= bounds.x + 0.5 or position.x >= bounds.y - 0.5

# =========================================================================
#  Cajas de colisión y visual
# =========================================================================
func is_crouching() -> bool:
	return state == State.CROUCH or attack_crouching or (state == State.BLOCK and crouch_blocking)

func _update_boxes() -> void:
	var h := data.crouch_height if is_crouching() else data.stand_height
	var y_center := -h / 2.0
	if state == State.JUMP or (state == State.ATTACK and attack_airborne):
		h = data.stand_height * 0.8
		y_center = -data.stand_height * 0.55
	_hurt_shape.size = Vector2(data.body_width, h)
	hurtbox_shape.position = Vector2(0, y_center)

	var active := is_hitbox_active()
	if active:
		var atk := current_attack
		var off := atk.hitbox_offset
		if attack_crouching:
			off += atk.crouch_offset
		elif attack_airborne:
			off += atk.air_offset
		_hit_shape.size = atk.hitbox_size
		hitbox_shape.position = Vector2(off.x * facing, off.y)
	if hitbox_shape.disabled == active:
		hitbox_shape.set_deferred("disabled", not active)

func _set_state(new_state: State) -> void:
	if new_state != State.WALK:
		running = false
	state = new_state
	state_frames = 0

## Nombre de pose/animación que corresponde al estado actual.
func get_pose_name() -> StringName:
	match state:
		State.IDLE: return &"idle"
		State.WALK: return &"run" if running else &"walk"
		State.JUMP: return &"jump"
		State.CROUCH: return &"crouch"
		State.BLOCK: return &"block"
		State.HIT: return &"hit"
		State.KO: return &"ko"
		State.VICTORY: return &"victory"
		State.ATTACK:
			var atk := current_attack
			if atk.kind == AttackData.Kind.KICK:
				if attack_airborne:
					return &"air_kick"
				if attack_crouching:
					return &"sweep"
			elif atk.kind == AttackData.Kind.PUNCH and attack_airborne:
				return &"air_punch"
			return atk.anim
	return &"idle"

func _update_visual() -> void:
	var pose := get_pose_name()
	if sprite.visible:
		sprite.flip_h = facing < 0
		if sprite.sprite_frames.has_animation(pose) and sprite.animation != pose:
			sprite.play(pose)
		return
	visual.scale.x = facing
	visual.pose_name = pose
	visual.moving_back = state == State.WALK and velocity.x * facing < 0.0
	visual.crouched = is_crouching()
	visual.airborne = not is_on_ground() and state != State.KO
	visual.height_above_floor = floor_y - position.y
	visual.phase = &""
	if state == State.ATTACK and current_attack:
		var atk := current_attack
		if attack_frame <= atk.startup:
			visual.phase = &"startup"
			visual.phase_t = float(attack_frame) / maxf(atk.startup, 1)
		elif attack_frame <= atk.startup + atk.active:
			visual.phase = &"active"
			visual.phase_t = 1.0
		else:
			visual.phase = &"recovery"
			visual.phase_t = float(attack_frame - atk.startup - atk.active) / maxf(atk.recovery, 1)

## Nombre legible del estado (depuración y pruebas).
func state_name() -> String:
	return State.keys()[state]
