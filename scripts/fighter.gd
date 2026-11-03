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
signal guard_broken(fighter: Fighter)
signal knocked_out(fighter: Fighter)
signal attack_started(fighter: Fighter, attack: AttackData)
signal projectile_requested(fighter: Fighter, attack: AttackData, spawn_position: Vector2)
signal power_requested(fighter: Fighter, attack: AttackData)
signal combo_performed(fighter: Fighter, combo: ComboData)
signal not_enough_energy(fighter: Fighter)
## Un escudo absorbió un golpe (el que atacaba, para devolverle la onda).
signal shield_absorbed(fighter: Fighter, attacker: Fighter)
## Al tocar el suelo tras una caída (solo aviso visual; no cambia el estado).
signal landed(fighter: Fighter)

## THROW: está ejecutando una llave · THROWN: la está sufriendo.
## PREJUMP: se agacha antes de saltar · LAND: recuperación al aterrizar tras un
## ataque aéreo · BACKDASH: salto hacia atrás con invulnerabilidad.
## KNOCKDOWN: tumbado en el suelo tras un lanzamiento, barrido o agarre (no se le
## puede golpear) · WAKEUP: levantándose, con unos frames de invulnerabilidad.
enum State { IDLE, WALK, JUMP, CROUCH, BLOCK, ATTACK, HIT, KO, VICTORY, THROW, THROWN, PREJUMP, LAND, BACKDASH, KNOCKDOWN, WAKEUP }

const GRAVITY := 1100.0
const GROUND_FRICTION := 900.0
const MAX_ENERGY := 100.0
## El bloqueo deja pasar solo este porcentaje del daño ("chip damage").
const BLOCK_DAMAGE_FACTOR := 0.15
## Guardia: cada golpe bloqueado gasta (daño sin reducir × GUARD_DRAIN). Se
## recupera GUARD_REGEN_PER_SECOND tras GUARD_REGEN_DELAY frames sin bloquear
## ningún golpe. Al llegar a 0 se rompe: GUARD_BREAK_STUN frames de aturdimiento
## (sin poder bloquear) y la guardia vuelve al GUARD_AFTER_BREAK %.
const MAX_GUARD := 100.0
const GUARD_DRAIN := 2.0
const GUARD_REGEN_DELAY := 60
const GUARD_REGEN_PER_SECOND := 30.0
const GUARD_BREAK_STUN := 50
const GUARD_AFTER_BREAK := 50.0
## Combos. Un golpe que conecta o es bloqueado se puede cancelar en otro de rango
## igual o mayor (débil → fuerte → especial), sin repetir golpe en la cadena.
## Cada golpe del combo hace COMBO_SCALE_STEP menos de daño (mínimo COMBO_SCALE_MIN)
## y acorta HITSTUN_DECAY frames el aturdimiento (mínimo HITSTUN_MIN). A un rival
## en el aire solo se le pueden dar JUGGLE_LIMIT golpes seguidos.
const COMBO_SCALE_STEP := 0.1
const COMBO_SCALE_MIN := 0.4
const HITSTUN_DECAY := 2
const HITSTUN_MIN := 8
const JUGGLE_LIMIT := 3
## Counter-hit: golpear a un rival que aún está en el startup de su ataque.
const COUNTER_DAMAGE := 1.2
const COUNTER_HITSTUN := 4
## Rango de cada ranura para las cancelaciones (las que no están no se cancelan).
const CANCEL_RANK := {&"punch_light": 1, &"kick_light": 1, &"punch_heavy": 2, &"kick_heavy": 2,
	&"special_1": 3, &"special_2": 3}
## Salto: solo salta al PULSAR la tecla (mantenerla no repite). PREJUMP_FRAMES de
## preparación en los que no se puede actuar, un búfer de JUMP_BUFFER_FRAMES para
## no perder la pulsación y AIR_LANDING_FRAMES de recuperación al aterrizar tras
## un ataque aéreo (solo se puede dar uno por salto).
const PREJUMP_FRAMES := 3
const JUMP_BUFFER_FRAMES := 4
const AIR_LANDING_FRAMES := 5
## Antiaéreo (puño fuerte agachado): caja alta que lanza al rival y, durante los
## primeros UPPERCUT_INVULN_FRAMES, no le alcanzan los ataques aéreos.
const UPPERCUT_INVULN_FRAMES := 4
const UPPERCUT_EXTRA_RECOVERY := 6
const UPPERCUT_LAUNCH := -260.0
## Backdash (doble toque hacia atrás): se desliza hacia atrás BACKDASH_MOVE_FRAMES
## frames, no se le puede golpear los primeros BACKDASH_INVULN_FRAMES y hasta
## BACKDASH_FRAMES no puede actuar.
const BACKDASH_FRAMES := 20
const BACKDASH_MOVE_FRAMES := 9
const BACKDASH_SPEED := 200.0
const BACKDASH_INVULN_FRAMES := 4
## Derribo. Un lanzamiento (launch < 0), un barrido (patada agachada) o un agarre
## tiran al rival: al aterrizar queda KNOCKDOWN_FRAMES frames tumbado sin poder ser
## golpeado. Al levantarse hay tres opciones: quedarse (se levanta WAKEUP_FRAMES
## frames, invulnerable los primeros WAKEUP_INVULN), rodar hacia atrás (manteniendo
## atrás al final del derribo: ROLL_FRAMES frames, invulnerable ROLL_INVULN y se
## desplaza a ROLL_SPEED durante ROLL_MOVE_FRAMES) o evitar el derribo pulsando
## bloqueo justo antes de caer (ventana TECH_FALL_WINDOW): se levanta al instante,
## TECH_FRAMES frames invulnerable.
const KNOCKDOWN_FRAMES := 30
const WAKEUP_FRAMES := 14
const WAKEUP_INVULN := 8
const ROLL_FRAMES := 26
const ROLL_INVULN := 16
const ROLL_MOVE_FRAMES := 14
const ROLL_SPEED := 260.0
const TECH_FALL_WINDOW := 8
const TECH_FRAMES := 10
## Un barrido que conecta levanta al rival del suelo con este impulso para derribarlo.
const SWEEP_LAUNCH := -170.0
## Frames que se recuerda una pulsación de ataque hecha antes de tiempo.
const INPUT_BUFFER_FRAMES := 6
## Energía con la que empieza cada ronda (no se arrastra de la anterior).
const ROUND_START_ENERGY := 30.0
## Bloqueo perfecto: si el bloqueo se pulsa PERFECT_BLOCK_FRAMES frames o menos antes
## de que llegue el golpe, no hay daño de rozadura ni gasto de guardia, da
## PERFECT_BLOCK_ENERGY de energía extra y el bloqueo dura PERFECT_BLOCKSTUN_CUT
## frames menos (ventaja para quien bloquea).
const PERFECT_BLOCK_FRAMES := 6
const PERFECT_BLOCK_ENERGY := 8.0
const PERFECT_BLOCKSTUN_CUT := 4
## Frames de aviso (el luchador se tiñe) antes de que los controles se inviertan de verdad.
const INVERT_WARNING := 24
## Ultimate = Especial 1 + Especial 2 a la vez (la segunda tecla puede llegar hasta
## ULT_INPUT_FRAMES frames tarde) con la energía llena. Solo en el suelo.
const ULT_INPUT_FRAMES := 2
const ENERGY_ON_HIT_DEALT := 6.0
const ENERGY_ON_HIT_TAKEN := 4.0
const ENERGY_ON_BLOCK := 3.0
const ENERGY_REGEN_PER_SECOND := 2.5
const HISTORY_SIZE := 8
## Correr: doble toque (pulsar, soltar, pulsar) en una dirección, hacia delante o atrás.
const DOUBLE_TAP_FRAMES := 15
const RUN_SPEED_MULT := 1.8
## Agarre = puño débil + patada débil. Si la segunda tecla llega tarde, el golpe
## débil se convierte en agarre durante sus primeros GRAB_INPUT_FRAMES frames.
const GRAB_INPUT_FRAMES := 2
## Frames que dura la llave antes de hacer daño, ventana de la víctima para
## zafarse (pulsando también puño débil + patada débil) y recuperación final.
const THROW_FRAMES := 24
const THROW_TECH_FRAMES := 10
const THROW_RECOVERY := 8
## Aturdimiento y empuje de ambos al zafarse de una llave.
const THROW_BREAK_STUN := 14
const THROW_BREAK_PUSH := 150.0

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
var guard: float = MAX_GUARD
## Frames desde el último golpe bloqueado (la guardia no se recupera antes de GUARD_REGEN_DELAY).
var guard_idle: int = 0
## true mientras dura el aturdimiento de una guardia rota (para el HUD).
var guard_is_broken: bool = false
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
## true cuando el ataque en curso ha golpeado o ha sido bloqueado (ya se puede cancelar).
var attack_connected: bool = false
## Pulsación de salto recordada (frames) y si la tecla estaba pulsada el frame anterior.
var jump_buffer: int = 0
var _prev_jump_held: bool = false
var _prev_block_held: bool = false
## Frames desde que se pulsó el bloqueo (grande si no se mantiene).
var block_age: int = 999
## true cuando ya se ha usado el ataque aéreo de este salto.
var air_attack_used: bool = false
## Variantes de antiaéreo por ataque base (se crean al usarse).
var _uppercut_cache: Dictionary = {}
## Ranuras ya usadas en la cadena de cancelaciones en curso.
var chain_slots: Array[StringName] = []
## Combo con nombre que completa el ataque en curso (da su bono si conecta).
var attack_combo: ComboData
## attack_instance cuyo bono de combo ya cobró un proyectil (solo cobra el primer golpe).
var combo_claimed: int = -1
## Golpes seguidos recibidos en el aire (límite JUGGLE_LIMIT).
var juggle_hits: int = 0
## true si, al aterrizar, el golpe recibido deja al luchador en KNOCKDOWN.
var knockdown_pending: bool = false
## Frames que quedan de la pulsación de bloqueo hecha al caer (para evitar el derribo).
var tech_fall_buffer: int = 0
## Levantarse: duración total, frames invulnerables y si es una voltereta.
var wake_frames: int = 0
var wake_invuln: int = 0
var wake_rolling: bool = false

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
## Aviso de los controles invertidos: no se invierten hasta pasados INVERT_WARNING frames.
var invert_grace: int = 0
var float_frames: int = 0
## Atrapado por una barrera: no puede caminar, saltar ni hacer backdash (sí atacar y bloquear).
var root_frames: int = 0
## Escudo de energía: absorbe el siguiente golpe y lo devuelve como onda.
var shield_frames: int = 0
## true mientras corre (subestado de WALK). Se activa con doble toque en la dirección.
var running: bool = false
# Llave en curso (agarre que conectó).
var throw_target: Fighter
var throw_attack: AttackData
var throw_timer: int = 0
## true el tick en que la llave debe hacer daño (lo consume CombatManager).
var throw_ready: bool = false
## Víctima: teclas de zafarse pulsadas durante la ventana y si lo ha conseguido.
var _tech_punch: bool = false
var _tech_kick: bool = false
var tech_requested: bool = false
var _prev_h: int = 0
var _tap_dir: int = 0
var _tap_timer: int = 0
var _hurt_shape: RectangleShape2D
var _hit_shape: RectangleShape2D

func _ready() -> void:
	# Las Area2D solo sirven para ver las cajas (Depurar → Formas de colisión
	# visibles). Los impactos se calculan con get_hurt_rect() / get_hit_rect()
	# en el mismo tick, sin esperar al motor de física.
	hitbox.monitoring = false
	hurtbox.monitorable = false
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

## Restablece vida, estado y posición al empezar una ronda.
func reset_for_round(x: float, p_facing: int) -> void:
	position = Vector2(x, floor_y)
	velocity = Vector2.ZERO
	facing = p_facing
	health = data.max_health
	energy = ROUND_START_ENERGY
	guard = MAX_GUARD
	guard_idle = 0
	guard_is_broken = false
	juggle_hits = 0
	knockdown_pending = false
	tech_fall_buffer = 0
	wake_frames = 0
	wake_invuln = 0
	wake_rolling = false
	jump_buffer = 0
	_prev_jump_held = false
	_prev_block_held = false
	block_age = 999
	air_attack_used = false
	_end_attack()
	stun_frames = 0
	hitstop_frames = 0
	combo_hits_taken = 0
	slow_frames = 0
	invert_frames = 0
	invert_grace = 0
	float_frames = 0
	root_frames = 0
	shield_frames = 0
	running = false
	_clear_throw()
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
	_read_jump_buffer()
	_read_tech_fall_buffer()
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
	_tick_guard(delta)

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
		State.THROW:
			_state_throw()
		State.THROWN:
			_state_thrown()
		State.PREJUMP:
			_state_prejump()
		State.LAND:
			_state_land()
		State.BACKDASH:
			_state_backdash()
		State.KNOCKDOWN:
			_state_knockdown()
		State.WAKEUP:
			_state_wakeup()
		State.KO, State.VICTORY:
			_apply_friction(delta)

	_apply_physics(delta)
	_update_facing()
	_update_boxes()
	_update_visual()
	input.end_frame()

## Recupera la guardia si hace GUARD_REGEN_DELAY frames que no se bloquea un golpe.
func _tick_guard(delta: float) -> void:
	if guard_idle < GUARD_REGEN_DELAY:
		guard_idle += 1
	elif guard < MAX_GUARD and state != State.KO:
		guard = minf(guard + GUARD_REGEN_PER_SECOND * delta, MAX_GUARD)

# =========================================================================
#  Estados
# =========================================================================
func _ground_control() -> void:
	if not is_on_ground():
		_set_state(State.JUMP)
		return
	var h := input.horizontal() if controls_enabled else 0
	if is_inverted():
		h = -h
	if root_frames > 0:
		h = 0
		jump_buffer = 0
	var backdash := _update_run(h)
	var want_block := controls_enabled and input.is_held(&"block")
	var want_crouch := controls_enabled and input.is_held(&"crouch")

	# Prioridad: bloqueo > backdash > ataque > salto > agacharse > caminar > reposo
	if want_block:
		crouch_blocking = want_crouch
		velocity.x = 0.0
		_set_state(State.BLOCK)
		return
	if backdash:
		velocity.x = -facing * BACKDASH_SPEED
		_set_state(State.BACKDASH)
		return
	if buffered_slot != &"" and _try_start_attack(buffered_slot):
		return
	if jump_buffer > 0:
		jump_buffer = 0
		velocity.x = 0.0
		_set_state(State.PREJUMP)
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

## Recuerda la pulsación de salto unos frames. Solo cuenta el flanco (tecla que
## pasa de suelta a pulsada), así mantener la tecla no encadena saltos. Se lee del
## estado de las teclas por frame, igual que el resto: vale para teclado, IA y tests.
## true si los controles están invertidos de verdad (pasado el aviso).
func is_inverted() -> bool:
	return invert_frames > 0 and invert_grace <= 0

func _read_jump_buffer() -> void:
	var held := controls_enabled and input != null and input.is_held(&"jump")
	if held and not _prev_jump_held:
		jump_buffer = JUMP_BUFFER_FRAMES
	elif jump_buffer > 0 and hitstop_frames == 0:
		jump_buffer -= 1
	_prev_jump_held = held

## Detecta el doble toque en una dirección. Hacia delante: se corre mientras se
## mantiene (soltar o cambiar de dirección lo corta). Hacia atrás: devuelve true
## y hay que hacer un backdash. Usa solo el estado de las teclas por frame, así
## funciona igual con teclado, IA, tests y repeticiones.
func _update_run(h: int) -> bool:
	var backdash := false
	if h != _prev_h:
		if h == 0:
			running = false
		elif h == _tap_dir and _tap_timer > 0:
			_tap_timer = 0
			if h == facing:
				running = true
			else:
				running = false
				backdash = true
		else:
			running = false
			_tap_dir = h
			_tap_timer = DOUBLE_TAP_FRAMES
	_prev_h = h
	return backdash

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

## Se agacha unos frames antes de despegar; no se puede actuar. Al despegar
## lee la dirección que se mantiene en ese momento.
func _state_prejump() -> void:
	velocity.x = 0.0
	if state_frames < PREJUMP_FRAMES:
		return
	var h := input.horizontal() if controls_enabled else 0
	if is_inverted():
		h = -h
	air_attack_used = false
	velocity.y = data.jump_velocity
	velocity.x = h * data.jump_forward_speed
	_set_state(State.JUMP)

## Recuperación al aterrizar tras un ataque aéreo.
func _state_land() -> void:
	_apply_friction(1.0 / 60.0)
	if state_frames >= AIR_LANDING_FRAMES:
		_set_state(State.IDLE)

## Backdash: se desliza hacia atrás y luego frena; hasta BACKDASH_FRAMES no actúa.
func _state_backdash() -> void:
	if state_frames <= BACKDASH_MOVE_FRAMES:
		velocity.x = -facing * BACKDASH_SPEED
	else:
		_apply_friction(1.0 / 60.0)
	if state_frames >= BACKDASH_FRAMES:
		_set_state(State.IDLE)

func _state_attack() -> void:
	# Segunda tecla del agarre pulsada un poco tarde: el golpe débil pasa a agarre.
	if attack_frame < GRAB_INPUT_FRAMES and _is_grab_pair(current_slot, buffered_slot) \
			and _try_start_attack(&"grab"):
		return
	# Lo mismo con el ultimate: el especial recién empezado se convierte en ultimate.
	if attack_frame < ULT_INPUT_FRAMES and _is_ult_pair(current_slot, buffered_slot) \
			and _upgrade_to_ultimate():
		return
	if _try_cancel():
		return
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
		_set_state(State.LAND if air_attack_used else State.IDLE)
		air_attack_used = false
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

## Recuerda unos frames la pulsación de bloqueo hecha mientras se cae derribado.
func _read_tech_fall_buffer() -> void:
	var held := controls_enabled and input != null and input.is_held(&"block")
	if held and not _prev_block_held:
		# +1: el contador baja al principio del tick, antes de aterrizar.
		tech_fall_buffer = TECH_FALL_WINDOW + 1
	elif tech_fall_buffer > 0 and hitstop_frames == 0:
		tech_fall_buffer -= 1
	if held and not _prev_block_held:
		block_age = 0
	elif held:
		block_age += 1
	else:
		block_age = 999
	_prev_block_held = held

## Aterriza derribado: o evita el derribo (bloqueo pulsado al caer) o queda tumbado.
func _land_knockdown() -> void:
	knockdown_pending = false
	stun_frames = 0
	if tech_fall_buffer > 0:
		combo_hits_taken = 0
		velocity.x = 0.0
		_start_wakeup(TECH_FRAMES, TECH_FRAMES, false)
	else:
		_set_state(State.KNOCKDOWN)

## Tumbado: no se le puede golpear. Al acabar elige cómo levantarse según lo que
## mantenga: atrás = voltereta hacia atrás; cualquier otra cosa = levantarse en el sitio.
func _state_knockdown() -> void:
	_apply_friction(1.0 / 60.0)
	if state_frames < KNOCKDOWN_FRAMES:
		return
	combo_hits_taken = 0
	var h := input.horizontal() if controls_enabled else 0
	if is_inverted():
		h = -h
	if h != 0 and h != facing:
		velocity.x = -facing * ROLL_SPEED
		_start_wakeup(ROLL_FRAMES, ROLL_INVULN, true)
	else:
		_start_wakeup(WAKEUP_FRAMES, WAKEUP_INVULN, false)

func _start_wakeup(total: int, invuln: int, rolling: bool) -> void:
	wake_frames = total
	wake_invuln = invuln
	wake_rolling = rolling
	_set_state(State.WAKEUP)

## Levantándose: invulnerable los primeros wake_invuln frames; luego ya se puede golpear.
func _state_wakeup() -> void:
	if wake_rolling:
		if state_frames > ROLL_MOVE_FRAMES:
			_apply_friction(1.0 / 60.0)
	else:
		velocity.x = 0.0
	if state_frames >= wake_frames:
		wake_rolling = false
		_set_state(State.IDLE)

## Llave: sujeta a la víctima delante y, al acabar THROW_FRAMES, avisa a
## CombatManager (throw_ready) para que aplique el golpe con sus efectos.
func _state_throw() -> void:
	throw_timer += 1
	velocity = Vector2.ZERO
	var target := throw_target
	if target and target.state == State.THROWN:
		var hold := (data.body_width + target.data.body_width) * 0.4 + 1.0
		target.position.x = clampf(position.x + facing * hold, target.bounds.x, target.bounds.y)
		if throw_timer == THROW_FRAMES:
			throw_ready = true
	if throw_timer >= THROW_FRAMES + THROW_RECOVERY:
		_clear_throw()
		_set_state(State.IDLE)

## Víctima de una llave: durante THROW_TECH_FRAMES puede zafarse pulsando
## puño débil y patada débil (a la vez o seguidas).
func _state_thrown() -> void:
	velocity = Vector2.ZERO
	if not controls_enabled or state_frames > THROW_TECH_FRAMES:
		return
	_tech_punch = _tech_punch or input.just_pressed(&"punch_light")
	_tech_kick = _tech_kick or input.just_pressed(&"kick_light")
	if _tech_punch and _tech_kick:
		tech_requested = true

# =========================================================================
#  Ataques
# =========================================================================
func _read_attack_buffer() -> void:
	# Durante el hitstop el tiempo del búfer no corre: así la pulsación que se
	# adelanta a un golpe que conecta sigue viva cuando se puede cancelar.
	if buffered_frames > 0 and hitstop_frames == 0:
		buffered_frames -= 1
		if buffered_frames == 0:
			buffered_slot = &""
	if not controls_enabled or input == null:
		return
	var slot := input.pressed_attack()
	if slot != &"":
		if input.just_pressed(&"punch_light") and input.just_pressed(&"kick_light"):
			slot = &"grab"
		elif input.just_pressed(&"special_1") and input.just_pressed(&"special_2") and can_use_ultimate():
			slot = &"ultimate"
		buffered_slot = slot
		buffered_frames = INPUT_BUFFER_FRAMES

## true si a y b son las dos teclas del agarre (en cualquier orden).
static func _is_grab_pair(a: StringName, b: StringName) -> bool:
	return (a == &"punch_light" and b == &"kick_light") or (a == &"kick_light" and b == &"punch_light")

## true si a y b son los dos especiales (en cualquier orden).
static func _is_ult_pair(a: StringName, b: StringName) -> bool:
	return (a == &"special_1" and b == &"special_2") or (a == &"special_2" and b == &"special_1")

## ¿Se puede lanzar el ultimate ahora? Tiene que existir, estar en el suelo y haber
## energía suficiente.
func can_use_ultimate() -> bool:
	return data != null and data.ultimate != null and is_on_ground() \
		and energy >= data.ultimate.energy_cost

## Segunda tecla del ultimate llegada un instante tarde: se devuelve la energía y el
## enfriamiento del especial recién empezado y se lanza el ultimate en su lugar. Si
## con ese reembolso no llega la energía, el especial sigue su curso.
func _upgrade_to_ultimate() -> bool:
	if data.ultimate == null or not is_on_ground() or current_attack == null:
		return false
	var spent := current_attack.energy_cost
	if energy + spent < data.ultimate.energy_cost:
		return false
	var slot := current_slot
	var old_cooldown: int = cooldowns.get(slot, 0)
	add_energy(spent)
	cooldowns[slot] = 0
	if _try_start_attack(&"ultimate"):
		return true
	add_energy(-spent)
	cooldowns[slot] = old_cooldown
	return false

## Cancela el ataque en curso en el que hay en el búfer, si las reglas lo permiten:
## el golpe tiene que haber conectado (o ser bloqueado), la ranura nueva no puede
## estar ya en la cadena y su rango no puede ser menor. Los especiales no se cancelan.
func _try_cancel() -> bool:
	if not attack_connected or buffered_slot == &"" or current_attack == null:
		return false
	var cur_rank: int = CANCEL_RANK.get(current_slot, 0)
	var new_rank: int = CANCEL_RANK.get(buffered_slot, 0)
	if cur_rank == 0 or cur_rank >= 3 or new_rank < cur_rank or chain_slots.has(buffered_slot):
		return false
	if attack_frame <= current_attack.startup:
		return false
	return _try_start_attack(buffered_slot, true)

## Intenta iniciar un ataque. Devuelve false si no es posible ahora.
## `chained`: viene de cancelar otro ataque (continúa la cadena y el combo).
func _try_start_attack(slot: StringName, chained: bool = false) -> bool:
	var atk := data.get_attack(slot)
	if atk == null:
		return false
	var airborne := not is_on_ground()
	if airborne and (not atk.usable_in_air or air_attack_used or slot == &"ultimate"):
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
	# Cuenta la tecla mantenida y no solo el estado: si ↓ y el ataque se pulsan
	# a la vez, el ataque sale antes de que el luchador llegue a agacharse.
	var crouch_held := not airborne and controls_enabled and input != null and input.is_held(&"crouch")
	var crouching := (state == State.CROUCH or crouch_held) and atk.usable_crouching
	# Puño fuerte agachado = antiaéreo.
	if crouching and not airborne and slot == &"punch_heavy" and atk.kind == AttackData.Kind.PUNCH:
		atk = _uppercut_for(atk)
	current_attack = atk
	current_slot = slot
	attack_frame = 0
	attack_instance += 1
	hit_targets.clear()
	projectile_spawned = false
	attack_connected = false
	attack_combo = null
	if not chained:
		chain_slots.clear()
	chain_slots.append(slot)
	attack_crouching = crouching
	attack_airborne = airborne
	if airborne:
		air_attack_used = true
	if not airborne and atk.dash_speed <= 0.0:
		velocity.x = 0.0
	_set_state(State.ATTACK)
	_record_history(slot, chained)
	attack_started.emit(self, atk)
	return true

func _end_attack() -> void:
	current_attack = null
	current_slot = &""
	attack_frame = 0
	attack_crouching = false
	attack_airborne = false
	attack_connected = false
	attack_combo = null
	chain_slots.clear()
	hit_targets.clear()

## Apunta el ataque en el historial. `chained` = viene de una cancelación: los
## combos con nombre solo cuentan si cada golpe (menos el primero) está enlazado.
func _record_history(slot: StringName, chained: bool = false) -> void:
	input_history.append({"slot": slot, "frame": frame_counter, "chained": chained})
	if input_history.size() > HISTORY_SIZE:
		input_history.pop_front()
	for combo in data.get_combos():
		if combo and combo.matches(input_history):
			# Si encajan varios, vale el de más bono.
			if attack_combo == null or combo.bonus_damage > attack_combo.bonus_damage:
				attack_combo = combo
			combo_performed.emit(self, combo)

## El ataque en curso ha golpeado o ha sido bloqueado (lo llama CombatManager).
func on_attack_connected() -> void:
	attack_connected = true

## Variante antiaérea de un puño fuerte: caja alta y estrecha delante del luchador,
## lanza al rival hacia arriba y deja más recuperación si falla. Mismos tiempos de
## preparación y daño que el golpe base.
func _uppercut_for(base: AttackData) -> AttackData:
	var u: AttackData = _uppercut_cache.get(base)
	if u == null:
		u = base.duplicate() as AttackData
		u.id = &"uppercut"
		u.display_name = "Antiaéreo"
		u.hit_level = AttackData.HitLevel.MID
		u.hitbox_offset = Vector2(base.hitbox_offset.x * 0.6, -50.0)
		u.hitbox_size = Vector2(base.hitbox_size.x, 44.0)
		u.crouch_offset = Vector2.ZERO
		u.launch = UPPERCUT_LAUNCH
		u.knockback = minf(base.knockback, 70.0)
		u.hitstun = base.hitstun + 8
		u.recovery = base.recovery + UPPERCUT_EXTRA_RECOVERY
		u.usable_in_air = false
		_uppercut_cache[base] = u
	return u

## true mientras el antiaéreo esquiva los ataques aéreos (sus primeros frames).
func is_anti_air_invulnerable() -> bool:
	return state == State.ATTACK and current_attack != null and current_attack.id == &"uppercut" \
		and attack_frame <= UPPERCUT_INVULN_FRAMES

## Nivel del ataque en curso: en el aire es alto (overhead), una patada
## agachada es baja y, si no, el que diga su AttackData.
func current_hit_level() -> AttackData.HitLevel:
	if attack_airborne:
		return AttackData.HitLevel.OVERHEAD
	if attack_crouching and current_attack.kind == AttackData.Kind.KICK:
		return AttackData.HitLevel.LOW
	return current_attack.hit_level

## ¿El ataque en curso es un barrido (patada agachada)? Derriba al conectar.
func is_sweep_attack() -> bool:
	return attack_crouching and current_attack != null and current_attack.kind == AttackData.Kind.KICK

## true si nuestra guardia actual (de pie o agachada) para un golpe de ese nivel.
func guards_against(level: AttackData.HitLevel) -> bool:
	match level:
		AttackData.HitLevel.LOW:
			return crouch_blocking
		AttackData.HitLevel.OVERHEAD:
			return not crouch_blocking
	return true

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
	var target := opponent
	if target and not hit_targets.has(target) and target.can_be_hit() \
			and not (attack_airborne and target.is_anti_air_invulnerable()) \
			and get_hit_rect().intersects(target.get_hurt_rect()):
		if current_attack.kind != AttackData.Kind.GRAB or target.can_be_grabbed():
			result.append(target)
	return result

## Caja del cuerpo en coordenadas globales, con la posición ACTUAL (tras el
## empuje entre cuerpos). Es la que reciben golpes y proyectiles.
func get_hurt_rect() -> Rect2:
	return Rect2(global_position + hurtbox_shape.position - _hurt_shape.size * 0.5, _hurt_shape.size)

## Caja del golpe en coordenadas globales (solo tiene sentido si is_hitbox_active()).
func get_hit_rect() -> Rect2:
	return Rect2(global_position + hitbox_shape.position - _hit_shape.size * 0.5, _hit_shape.size)

func register_hit(target: Fighter) -> void:
	hit_targets.append(target)

## Durante una llave ninguno de los dos puede recibir otros golpes, ni tumbado, ni
## durante los primeros frames de un backdash o de levantarse. Un rival que
## ya ha recibido JUGGLE_LIMIT golpes en el aire no puede recibir más hasta aterrizar.
func can_be_hit() -> bool:
	if state in [State.KO, State.VICTORY, State.THROW, State.THROWN, State.KNOCKDOWN]:
		return false
	if state == State.BACKDASH and state_frames <= BACKDASH_INVULN_FRAMES:
		return false
	if state == State.WAKEUP and state_frames <= wake_invuln:
		return false
	return juggle_hits < JUGGLE_LIMIT or is_on_ground()

## Un agarre solo atrapa a un rival en el suelo que no esté aturdido
## (ni golpeado ni en bloqueo forzado).
func can_be_grabbed() -> bool:
	if not can_be_hit() or not is_on_ground() or state == State.HIT:
		return false
	return not (state == State.BLOCK and stun_frames > 0)

## El agarre conectó: empieza la llave.
func start_throw(target: Fighter) -> void:
	throw_attack = current_attack
	_end_attack()
	throw_target = target
	throw_timer = 0
	throw_ready = false
	velocity = Vector2.ZERO
	_set_state(State.THROW)

## Nos han agarrado: quedamos sujetos hasta el golpe o hasta zafarnos.
func start_thrown() -> void:
	_end_attack()
	_clear_throw()
	stun_frames = 0
	buffered_slot = &""
	buffered_frames = 0
	velocity = Vector2.ZERO
	_set_state(State.THROWN)

## Los dos se separan tras zafarse de una llave.
func break_throw() -> void:
	_clear_throw()
	_end_attack()
	buffered_slot = &""
	stun_frames = THROW_BREAK_STUN
	velocity = Vector2(-facing * THROW_BREAK_PUSH, 0.0)
	_set_state(State.HIT)

func _clear_throw() -> void:
	throw_target = null
	throw_attack = null
	throw_timer = 0
	throw_ready = false
	_tech_punch = false
	_tech_kick = false
	tech_requested = false

# =========================================================================
#  Recibir daño
# =========================================================================
## Aplica un golpe. `direction` = hacia dónde sale despedido (+1 / -1).
## `level`: alto/medio/bajo (decide si la guardia actual lo para).
## Devuelve {blocked: bool, damage: float, ko: bool}.
## `bonus`: daño extra de un combo con nombre completado (solo si el golpe entra).
## `sweep_hint`: el golpe era un barrido al recoger los impactos; en un intercambio el golpe del otro
## puede haber terminado ya el ataque del atacante, así que no se lee de su estado actual.
func receive_hit(attacker: Fighter, atk: AttackData, direction: int,
		level: AttackData.HitLevel = AttackData.HitLevel.MID, bonus: float = 0.0, sweep_hint: bool = false) -> Dictionary:
	var result := {"blocked": false, "damage": 0.0, "ko": false, "guard_break": false, "counter": false, "perfect": false, "absorbed": false}
	if shield_frames > 0 and state != State.KO:
		shield_frames = 0
		result.blocked = true
		result.absorbed = true
		add_energy(ENERGY_ON_BLOCK)
		shield_absorbed.emit(self, attacker)
		return result
	var dmg := atk.damage * attacker.data.strength / maxf(data.resistance, 0.1)
	if state == State.BLOCK and is_on_ground() and guards_against(level):
		# BLOQUEO: daño muy reducido. Los golpes normales nunca noquean; los
		# especiales (proyectiles, poderes) sí pueden rematar con el daño de rozadura.
		var full := dmg
		var perfect := block_age <= PERFECT_BLOCK_FRAMES and stun_frames <= 0
		if perfect:
			full = 0.0
		dmg *= 0.0 if perfect else BLOCK_DAMAGE_FACTOR
		var lethal := atk.is_projectile() or atk.is_power() \
			or atk.kind == AttackData.Kind.SPECIAL or atk.kind == AttackData.Kind.ULTIMATE
		health = maxf(health - dmg, 0.0 if lethal else minf(health, 1.0))
		stun_frames = maxi(atk.blockstun - (PERFECT_BLOCKSTUN_CUT if perfect else 0), 1)
		velocity.x = direction * atk.knockback * 0.6
		add_energy(ENERGY_ON_BLOCK + (PERFECT_BLOCK_ENERGY if perfect else 0.0))
		result.perfect = perfect
		visual.flash_block()
		result.blocked = true
		guard_idle = 0
		guard = maxf(guard - full * GUARD_DRAIN, 0.0)
		if health <= 0.0:
			_knock_out(direction)
			result.ko = true
		elif guard <= 0.0:
			_break_guard()
			result.guard_break = true
	else:
		# Golpes que ya lleva el combo (si no estaba aturdido, empieza uno nuevo).
		var hits_before := combo_hits_taken if state == State.HIT else 0
		# Counter-hit: le pillamos en el startup de su ataque.
		var counter := state == State.ATTACK and current_attack != null \
			and attack_frame <= current_attack.startup
		if counter:
			dmg *= COUNTER_DAMAGE
			result.counter = true
		dmg *= maxf(COMBO_SCALE_MIN, 1.0 - COMBO_SCALE_STEP * hits_before)
		dmg += bonus * attacker.data.strength / maxf(data.resistance, 0.1)
		health = maxf(health - dmg, 0.0)
		combo_hits_taken = hits_before + 1
		if not is_on_ground():
			juggle_hits += 1
		# ¿Este golpe derriba? Lanzamientos, agarres y barridos (patada agachada).
		var sweep := sweep_hint or (attacker.attack_crouching and attacker.current_attack == atk \
			and atk.kind == AttackData.Kind.KICK)
		if atk.launch != 0.0 or atk.kind == AttackData.Kind.GRAB or sweep:
			knockdown_pending = true
		_end_attack()
		air_attack_used = false
		velocity.x = direction * atk.knockback
		if atk.launch < 0.0:
			velocity.y = atk.launch
		elif atk.launch > 0.0 and not is_on_ground():
			# Lo estrella contra el suelo.
			velocity.y = atk.launch
		elif sweep and is_on_ground():
			velocity.y = SWEEP_LAUNCH
		elif not is_on_ground():
			velocity.y = minf(velocity.y, -140.0)
		var stun := atk.hitstun + (COUNTER_HITSTUN if counter else 0) - HITSTUN_DECAY * hits_before
		stun_frames = maxi(stun, mini(HITSTUN_MIN, atk.hitstun))
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

## La guardia llega a 0: aturdimiento sin poder bloquear y la guardia vuelve a medias.
func _break_guard() -> void:
	guard = GUARD_AFTER_BREAK
	guard_is_broken = true
	combo_hits_taken = 0
	stun_frames = GUARD_BREAK_STUN
	_set_state(State.HIT)
	guard_broken.emit(self)

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
	if root_frames > 0:
		root_frames -= 1
	if shield_frames > 0:
		shield_frames -= 1
	if invert_frames > 0:
		invert_frames -= 1
		if invert_grace > 0:
			invert_grace -= 1
	var tint := Color.WHITE
	if slow_frames > 0:
		tint = Color(0.6, 0.8, 1.0)
	elif invert_frames > 0:
		tint = Color(0.95, 0.6, 1.0)
	elif float_frames > 0:
		tint = Color(1.0, 1.0, 0.7)
	elif root_frames > 0:
		tint = Color(0.75, 0.85, 0.7)
	if modulate != tint:
		modulate = tint

## status: slow (tiempo lento) | invert (izquierda/derecha cambiadas) | float (flota y cae) | root (no puede caminar ni saltar)
func apply_status(status: StringName, frames: int) -> void:
	match status:
		&"slow": slow_frames = frames
		&"invert":
			invert_frames = frames
			invert_grace = INVERT_WARNING
		&"float": float_frames = frames
		&"root": root_frames = frames

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
			juggle_hits = 0
			landed.emit(self)
			if state == State.HIT and knockdown_pending and health > 0.0:
				_land_knockdown()
			elif state == State.JUMP:
				velocity.x = 0.0
				_set_state(State.LAND if air_attack_used else State.IDLE)
				air_attack_used = false
	position.x = clampf(position.x, bounds.x, bounds.y)

func _update_facing() -> void:
	if opponent == null:
		return
	var can_turn := state in [State.IDLE, State.WALK, State.CROUCH, State.BLOCK, State.PREJUMP, State.LAND] and is_on_ground()
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
	if state == State.KNOCKDOWN:
		h = minf(data.crouch_height, 22.0)
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
	# Solo afecta al dibujo de depuración; los impactos usan get_hit_rect().
	if hitbox_shape.disabled == active:
		hitbox_shape.set_deferred("disabled", not active)

func _set_state(new_state: State) -> void:
	if new_state != State.WALK:
		running = false
	if new_state != State.HIT:
		guard_is_broken = false
		juggle_hits = 0
		knockdown_pending = false
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
		State.THROW: return &"grab"
		State.PREJUMP, State.LAND: return &"crouch"
		State.BACKDASH: return &"run"
		State.THROWN: return &"hit"
		State.KNOCKDOWN: return &"ko"
		State.WAKEUP: return &"run" if wake_rolling else &"crouch"
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
	visual.moving_back = (state == State.WALK or state == State.BACKDASH) and velocity.x * facing < 0.0
	visual.crouched = is_crouching() or state == State.PREJUMP or state == State.LAND \
		or (state == State.WAKEUP and not wake_rolling)
	visual.airborne = not is_on_ground() and state != State.KO
	visual.height_above_floor = floor_y - position.y
	visual.phase = &""
	if state == State.THROW:
		visual.phase = &"active"
		visual.phase_t = 1.0
	elif state == State.ATTACK and current_attack:
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
