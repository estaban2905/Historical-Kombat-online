## Director del combate (raíz de Fight.tscn).
##   1. Carga el escenario y crea los dos luchadores a partir de sus datos.
##   2. Cada frame de física actualiza a ambos en orden fijo (tick).
##   3. Separa los cuerpos (nadie atraviesa al rival ni se queda trabado).
##   4. Resuelve impactos cuerpo a cuerpo y de proyectiles, aplicando daño,
##      hitstop, efectos, sonido y vibración de cámara.
## Las reglas de rondas y tiempo están en round_manager.gd.
class_name CombatManager
extends Node2D

signal hit_landed(attacker: Fighter, defender: Fighter, attack: AttackData, result: Dictionary)
signal fighter_knocked_out(fighter: Fighter)
## Al final de cada tick de combate (tras incrementar tick_count).
signal ticked

const FIGHTER_SCENE := preload("res://scenes/fighters/Fighter.tscn")

@onready var stage_holder: Node2D = $StageHolder
@onready var fighters_root: Node2D = $Fighters
@onready var projectiles_root: Node2D = $Projectiles
@onready var effects_root: Node2D = $Effects
@onready var camera: Camera2D = $Camera
@onready var round_manager: RoundManager = $RoundManager
@onready var hud: HUD = $HUDLayer/HUD

var stage: Stage
var _stage_owner: StringName = &""
var p1: Fighter
var p2: Fighter
var fighters: Array[Fighter] = []
## Cerebro de P2 en el modo contra la CPU (null en versus local).
var ai: AIController
var _shake: float = 0.0
## Ticks de combate transcurridos (un tick = un frame de física a 60 Hz).
var tick_count: int = 0
var _input_source: Callable

func _ready() -> void:
	_load_stage()
	p1 = _spawn_fighter(Game.p1_data(), 1)
	p2 = _spawn_fighter(Game.p2_data(), 2)
	p1.opponent = p2
	p2.opponent = p1
	fighters = [p1, p2]
	if Game.is_vs_cpu():
		p2.input.use_keyboard = false
		ai = AIController.new(p2, p1, Game.ai_level())
	hud.bind(self)
	round_manager.start_match()

func _load_stage(round_number: int = 1) -> void:
	_stage_owner = Game.stage_owner(round_number)
	var path := StageRegistry.scene_for(_stage_owner)
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("No se pudo cargar el escenario " + path)
		packed = load(StageRegistry.COLOSSEUM)
	stage = packed.instantiate() as Stage
	if stage is ThemedStage:
		(stage as ThemedStage).fighter_id = _stage_owner
	stage_holder.add_child(stage)

## ¿Hay que cambiar de escenario al empezar esta ronda?
func stage_changes_for(round_number: int) -> bool:
	return Game.stage_owner(round_number) != _stage_owner

## Sustituye el escenario por el que toca en la ronda dada.
func swap_stage(round_number: int) -> void:
	var old := stage
	stage_holder.remove_child(old)
	old.queue_free()
	_load_stage(round_number)
	for f in fighters:
		f.floor_y = stage.floor_y
		f.bounds = Vector2(stage.left_bound, stage.right_bound)

func stage_name() -> String:
	return StageRegistry.name_for(_stage_owner)

func _spawn_fighter(data: FighterData, player_id: int) -> Fighter:
	var f := FIGHTER_SCENE.instantiate() as Fighter
	fighters_root.add_child(f)
	f.floor_y = stage.floor_y
	f.bounds = Vector2(stage.left_bound, stage.right_bound)
	f.position = Vector2(stage.p1_spawn_x if player_id == 1 else stage.p2_spawn_x, stage.floor_y)
	f.setup(data, player_id, InputManager.new(player_id))
	f.projectile_requested.connect(_on_projectile_requested)
	f.power_requested.connect(_on_power_requested)
	f.knocked_out.connect(func(who: Fighter): fighter_knocked_out.emit(who))
	f.attack_started.connect(_on_attack_started)
	f.not_enough_energy.connect(func(_who: Fighter): Sfx.play(&"denied"))
	return f

## Coloca a los luchadores para una nueva ronda (vida al máximo).
func reset_round() -> void:
	for p in projectiles_root.get_children():
		p.queue_free()
	p1.reset_for_round(stage.p1_spawn_x, 1)
	p2.reset_for_round(stage.p2_spawn_x, -1)

func set_controls(enabled: bool) -> void:
	for f in fighters:
		f.controls_enabled = enabled
		if not enabled:
			f.input.release_all()

# =========================================================================
#  Bucle de combate
# =========================================================================
func _physics_process(delta: float) -> void:
	if _input_source.is_valid():
		var masks: Array = _input_source.call(tick_count)
		p1.input.apply_mask(masks[0])
		p2.input.apply_mask(masks[1])
	if ai:
		ai.think()
	for f in fighters:
		f.tick(delta)
	for p in projectiles_root.get_children():
		(p as Projectile).tick(delta)
	_resolve_bodies()
	_resolve_melee_hits()
	_resolve_projectiles()
	_update_shake(delta)
	tick_count += 1
	ticked.emit()

## Sustituye el teclado por una fuente externa de entradas (partida online,
## repeticiones, pruebas). `source` recibe el número de tick y devuelve
## [máscara_P1, máscara_P2] (ver InputManager.apply_mask). Mientras esté
## activa, el combate depende SOLO de esas máscaras: mismas máscaras = misma pelea.
func set_input_source(source: Callable) -> void:
	_input_source = source
	for f in fighters:
		f.input.use_keyboard = false

## Resumen numérico del estado del combate. Dos máquinas que van sincronizadas
## devuelven el mismo valor en el mismo tick; si difiere, hay desincronización.
func state_checksum() -> int:
	return hash(state_snapshot())

## Estado relevante del combate como datos legibles (para depurar desincronizaciones).
func state_snapshot() -> Array:
	var parts: Array = [tick_count, round_manager.phase, round_manager.round_number,
		round_manager.wins, round_manager.time_left]
	for f in fighters:
		parts.append([f.position, f.velocity, f.health, f.energy, f.state, f.state_frames,
			f.facing, f.attack_frame, f.attack_instance, f.stun_frames, f.hitstop_frames,
			f.combo_hits_taken, f.slow_frames, f.invert_frames, f.float_frames,
			f.buffered_slot, f.buffered_frames, f.cooldowns])
	for p in projectiles_root.get_children():
		var pr := p as Projectile
		parts.append([pr.position, pr.life, pr.alive])
	return parts

## Empuje entre cuerpos: impide que se superpongan y que alguien quede
## atrapado. Si uno está claramente por encima del otro (salto), puede
## cruzar al otro lado.
func _resolve_bodies() -> void:
	if p1.state == Fighter.State.KO or p2.state == Fighter.State.KO:
		return
	var min_dist := (p1.data.body_width + p2.data.body_width) * 0.5 * 0.8
	var dx := p2.position.x - p1.position.x
	if absf(dx) >= min_dist:
		return
	# ¿Alguno pasa por encima de la cabeza del otro?
	if p1.position.y < p2.position.y - p2.data.stand_height * 0.7:
		return
	if p2.position.y < p1.position.y - p1.data.stand_height * 0.7:
		return
	var dir := signf(dx)
	if dir == 0.0:
		dir = float(p1.facing)
	var overlap := min_dist - absf(dx)
	p1.position.x -= dir * overlap * 0.5
	p2.position.x += dir * overlap * 0.5
	p1.position.x = clampf(p1.position.x, p1.bounds.x, p1.bounds.y)
	p2.position.x = clampf(p2.position.x, p2.bounds.x, p2.bounds.y)
	# Si uno chocó con la pared, el otro absorbe el resto del empuje.
	var still := min_dist - absf(p2.position.x - p1.position.x)
	if still > 0.01:
		if p1.is_at_wall():
			p2.position.x = clampf(p2.position.x + dir * still, p2.bounds.x, p2.bounds.y)
		else:
			p1.position.x = clampf(p1.position.x - dir * still, p1.bounds.x, p1.bounds.y)

func _resolve_melee_hits() -> void:
	# Primero se recogen TODOS los impactos y luego se aplican: así un
	# intercambio simultáneo de golpes afecta a los dos luchadores.
	var hits: Array = []
	for f in fighters:
		for target in f.get_hit_candidates():
			hits.append([f, target, f.current_attack])
	for h in hits:
		(h[0] as Fighter).register_hit(h[1])
	for h in hits:
		var attacker: Fighter = h[0]
		var target: Fighter = h[1]
		var atk: AttackData = h[2]
		var point := _contact_point(attacker.hitbox_shape.global_position, target)
		_apply_hit(attacker, target, atk, attacker.facing, point, false)

func _resolve_projectiles() -> void:
	for node in projectiles_root.get_children():
		var p := node as Projectile
		if p == null or not p.alive or p.harmless or not p.is_armed():
			continue
		for area in p.get_overlapping_areas():
			if area is Projectile:
				var other := area as Projectile
				if p.clashable and other.clashable and other.alive and not other.harmless \
						and other.is_armed() and other.owner_fighter != p.owner_fighter:
					# Choque de proyectiles: se anulan.
					HitEffect.spawn(effects_root, (p.position + other.position) * 0.5, HitEffect.Type.CLASH, 1.4)
					Sfx.play(&"block")
					p.destroy()
					other.destroy()
					break
				continue
			var target := area.get_parent() as Fighter
			if target and target != p.owner_fighter and target.can_be_hit() and p.can_hit(target):
				_apply_hit(p.owner_fighter, target, p.attack, p.hit_direction(target),
					_contact_point(p.global_position, target), true)
				p.register_hit(target)
				if not p.alive:
					break

func _contact_point(from: Vector2, target: Fighter) -> Vector2:
	var center := target.hurtbox_shape.global_position
	return Vector2(lerpf(from.x, center.x, 0.4), from.y)

func _apply_hit(attacker: Fighter, target: Fighter, atk: AttackData, direction: int,
		point: Vector2, from_projectile: bool) -> void:
	var result := target.receive_hit(attacker, atk, direction)
	if not result.blocked:
		# Efectos de los poderes: estados alterados y energía recuperada.
		if atk.status != &"" and atk.status_frames > 0:
			target.apply_status(atk.status, atk.status_frames)
		if atk.energy_on_hit > 0.0:
			attacker.add_energy(atk.energy_on_hit)
	var stop := atk.hitstop if not result.blocked else maxi(atk.hitstop - 2, 2)
	if result.ko:
		stop = 22
	target.hitstop_frames = stop
	if not from_projectile:
		attacker.hitstop_frames = stop
		# En la esquina, el atacante sale rebotado para no encadenar sin fin.
		if target.is_at_wall():
			attacker.velocity.x = -direction * atk.knockback * 0.5
	var fx_type := HitEffect.Type.BLOCK if result.blocked else HitEffect.Type.HIT
	if result.ko:
		fx_type = HitEffect.Type.KO
	HitEffect.spawn(effects_root, point, fx_type, atk.effect_scale)
	if result.blocked:
		Sfx.play(&"block", 0.08)
	elif result.ko:
		Sfx.play(&"ko")
		shake(5.0)
	else:
		var heavy := atk.damage >= 10.0
		Sfx.play(&"hit_heavy" if heavy else &"hit_light", 0.1)
		shake(3.0 if heavy else 1.0)
		stage.excite(0.25 if heavy else 0.1)
	if result.ko:
		stage.excite(1.0)
	hit_landed.emit(attacker, target, atk, result)

func _on_projectile_requested(fighter: Fighter, atk: AttackData, spawn_position: Vector2) -> void:
	var p := Projectile.new()
	p.setup(fighter, atk, spawn_position)
	projectiles_root.add_child(p)
	Sfx.play(&"cannon" if atk.projectile_style == &"ball" else &"megaphone")

func _on_power_requested(fighter: Fighter, atk: AttackData) -> void:
	PowerEffects.cast(self, fighter, atk)

func _on_attack_started(_fighter: Fighter, atk: AttackData) -> void:
	if not atk.is_projectile():
		Sfx.play(&"whoosh", 0.15)

# =========================================================================
#  Cámara fija con vibración
# =========================================================================
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func _update_shake(delta: float) -> void:
	if _shake > 0.05:
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
		_shake = move_toward(_shake, 0.0, delta * 20.0)
	else:
		_shake = 0.0
		camera.offset = Vector2.ZERO
