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
## Modo entrenamiento (null en el resto de modos).
var training: TrainingMode
var _shake: float = 0.0
## Partículas decorativas (polvo, chispas, sangre...). No forman parte del estado.
var fx: ParticleFX
## Ticks de combate transcurridos (un tick = un frame de física a 60 Hz).
var tick_count: int = 0
var _input_source: Callable

func _ready() -> void:
	_load_stage()
	fx = ParticleFX.new()
	fx.use_flash = true
	fx.floor_y = stage.floor_y
	fx.z_index = 19
	effects_root.add_child(fx)
	p1 = _spawn_fighter(Game.p1_data(), 1)
	p2 = _spawn_fighter(Game.p2_data(), 2)
	p1.opponent = p2
	p2.opponent = p1
	fighters = [p1, p2]
	if Game.is_vs_cpu():
		p2.input.use_keyboard = false
		ai = AIController.new(p2, p1, Game.ai_level())
	add_child(DebugOverlay.new(self))
	hud.bind(self)
	if Game.mode == Game.Mode.TRAINING:
		training = TrainingMode.new(self)
		hud.get_parent().add_child(training)
		training.start()
		round_manager.start_training()
	else:
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
	fx.floor_y = stage.floor_y
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
	f.landed.connect(_on_fighter_landed)
	f.not_enough_energy.connect(func(_who: Fighter): Sfx.play(&"denied"))
	return f

## Coloca a los luchadores para una nueva ronda (vida al máximo).
func reset_round() -> void:
	for p in projectiles_root.get_children():
		p.queue_free()
	fx.clear()
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
	# Pausa de frames del modo entrenamiento.
	if training and training.should_skip_tick():
		return
	if _input_source.is_valid():
		var masks: Array = _input_source.call(tick_count)
		p1.input.apply_mask(masks[0])
		p2.input.apply_mask(masks[1])
	if ai:
		ai.think()
	if training:
		training.pre_tick()
	for f in fighters:
		f.tick(delta)
	for p in projectiles_root.get_children():
		(p as Projectile).tick(delta)
	_resolve_bodies()
	_resolve_melee_hits()
	_resolve_throws()
	_resolve_projectiles()
	_update_shake(delta)
	_update_fx()
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
			f.buffered_slot, f.buffered_frames, f.cooldowns, f.throw_timer, f.tech_requested,
			f.guard, f.guard_idle, f.attack_connected, f.chain_slots.size(), f.juggle_hits])
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
	# El nivel se guarda ya: si hay intercambio, el primer impacto termina el
	# ataque del otro antes de aplicar el suyo.
	for f in fighters:
		for target in f.get_hit_candidates():
			hits.append([f, target, f.current_attack, f.current_hit_level(), f.attack_combo])
	for h in hits:
		(h[0] as Fighter).register_hit(h[1])
	var grabs: Array = []
	for h in hits:
		var attacker: Fighter = h[0]
		var target: Fighter = h[1]
		var atk: AttackData = h[2]
		if atk.kind == AttackData.Kind.GRAB:
			grabs.append(h)
			continue
		var point := _contact_point(attacker.hitbox_shape.global_position, target)
		_apply_hit(attacker, target, atk, attacker.facing, point, false, h[3], h[4])
		# Golpe dado o bloqueado: ya se puede cancelar en otro.
		if attacker.state == Fighter.State.ATTACK and attacker.current_attack == atk:
			attacker.on_attack_connected()
	# Los agarres se resuelven después: si en el mismo frame el agarrador recibe
	# un golpe, gana el golpe. Si los dos se agarran a la vez, se zafan.
	if grabs.size() == 2:
		_break_throw(grabs[0][0], grabs[0][1])
		return
	for h in grabs:
		var attacker: Fighter = h[0]
		var target: Fighter = h[1]
		if attacker.state == Fighter.State.ATTACK and target.can_be_grabbed():
			attacker.start_throw(target)
			target.start_thrown()
			Sfx.play(&"whoosh")

## Llaves en curso: la víctima se zafa o, al acabar la llave, recibe el golpe.
func _resolve_throws() -> void:
	for f in fighters:
		if f.state != Fighter.State.THROW or f.throw_target == null:
			continue
		var target := f.throw_target
		if target.state != Fighter.State.THROWN:
			continue
		if target.tech_requested:
			_break_throw(f, target)
		elif f.throw_ready:
			f.throw_ready = false
			var atk := f.throw_attack
			# No se puede bloquear: la víctima está en THROWN, no en BLOCK.
			_apply_hit(f, target, atk, f.facing, (f.position + target.position) * 0.5 + Vector2(0, -40), false)

func _break_throw(a: Fighter, b: Fighter) -> void:
	a.break_throw()
	b.break_throw()
	HitEffect.spawn(effects_root, (a.position + b.position) * 0.5 + Vector2(0, -40), HitEffect.Type.CLASH, 1.0)
	Sfx.play(&"block")

func _resolve_projectiles() -> void:
	var nodes := projectiles_root.get_children()
	for node in nodes:
		var p := node as Projectile
		if p == null or not p.alive or p.harmless or not p.is_armed():
			continue
		var rect := p.get_rect()
		if p.clashable:
			for other_node in nodes:
				var other := other_node as Projectile
				if other and other != p and other.clashable and other.alive and not other.harmless \
						and other.is_armed() and other.owner_fighter != p.owner_fighter \
						and rect.intersects(other.get_rect()):
					# Choque de proyectiles: se anulan.
					HitEffect.spawn(effects_root, (p.position + other.position) * 0.5, HitEffect.Type.CLASH, 1.4)
					Sfx.play(&"block")
					p.destroy()
					other.destroy()
					break
			if not p.alive:
				continue
		# Orden fijo [P1, P2]: mismo resultado en todos los PCs.
		for target in fighters:
			if target != p.owner_fighter and target.can_be_hit() and p.can_hit(target) \
					and rect.intersects(target.get_hurt_rect()):
				_apply_hit(p.owner_fighter, target, p.attack, p.hit_direction(target),
					_contact_point(p.global_position, target), true, p.attack.hit_level)
				p.register_hit(target)
				if not p.alive:
					break

func _contact_point(from: Vector2, target: Fighter) -> Vector2:
	var center := target.hurtbox_shape.global_position
	return Vector2(lerpf(from.x, center.x, 0.4), from.y)

func _apply_hit(attacker: Fighter, target: Fighter, atk: AttackData, direction: int,
		point: Vector2, from_projectile: bool, level: AttackData.HitLevel = AttackData.HitLevel.MID,
		combo: ComboData = null) -> void:
	var result := target.receive_hit(attacker, atk, direction, level, combo.bonus_damage if combo else 0.0)
	# Nombre del combo completado: solo si el golpe final entra (el HUD lo muestra).
	result["combo_name"] = combo.display_name if combo and not result.blocked else ""
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
	if result.guard_break:
		fx_type = HitEffect.Type.HIT
	if result.ko:
		fx_type = HitEffect.Type.KO
	var fx_scale := atk.effect_scale * (1.5 if result.guard_break else 1.0) * (1.3 if result.counter else 1.0)
	HitEffect.spawn(effects_root, point, fx_type, fx_scale)
	if result.guard_break:
		# Guardia rota: sonido y sacudida de golpe pesado.
		Sfx.play(&"hit_heavy")
		shake(3.0)
		fx.sparks(point, -direction)
		fx.hit_burst(point, direction, 1)
		fx.flash(0.35)
	elif result.blocked and not result.ko:
		Sfx.play(&"block", 0.08)
		fx.sparks(point, -direction)
	elif result.ko:
		Sfx.play(&"ko")
		shake(5.0)
		fx.hit_burst(point, direction, 2)
		fx.ko_stain(target.position.x)
		fx.flash(0.6)
	else:
		var heavy: bool = atk.damage >= 10.0 or result.counter
		Sfx.play(&"hit_heavy" if heavy else &"hit_light", 0.1)
		shake(3.0 if heavy else 1.0)
		stage.excite(0.25 if heavy else 0.1)
		if heavy:
			fx.hit_burst(point, direction, 2 if atk.launch < 0.0 else 1)
		if atk.damage >= 15.0:
			fx.flash(0.35)
	if result.ko:
		stage.excite(1.0)
	hit_landed.emit(attacker, target, atk, result)

func _on_projectile_requested(fighter: Fighter, atk: AttackData, spawn_position: Vector2) -> void:
	var p := Projectile.new()
	p.setup(fighter, atk, spawn_position)
	projectiles_root.add_child(p)
	Sfx.play(&"cannon" if atk.projectile_style == &"ball" else &"megaphone")

func _on_power_requested(fighter: Fighter, atk: AttackData) -> void:
	fx.flash(0.3)
	PowerEffects.cast(self, fighter, atk)

func _on_attack_started(_fighter: Fighter, atk: AttackData) -> void:
	if not atk.is_projectile():
		Sfx.play(&"whoosh", 0.15)

# =========================================================================
#  Partículas (solo decorado)
# =========================================================================
func _on_fighter_landed(f: Fighter) -> void:
	var feet := Vector2(f.position.x, f.floor_y)
	if f.state == Fighter.State.HIT or f.state == Fighter.State.KO:
		fx.dust_wave(feet)
	elif f.state == Fighter.State.JUMP or f.state == Fighter.State.ATTACK:
		fx.dust_land(feet)

func _update_fx() -> void:
	for i in fighters.size():
		var f := fighters[i]
		if f.hitstop_frames > 0:
			continue
		var phase := tick_count + i * 3
		var atk := f.current_attack
		# Estela mientras la hitbox de patadas y especiales está activa.
		if atk != null and f.is_hitbox_active() and atk.kind != AttackData.Kind.PUNCH and phase % 2 == 0:
			fx.trail(f.hitbox_shape.global_position, Color("ffd040") if atk.kind == AttackData.Kind.KICK else Color("ff7020"))
		if not f.is_on_ground():
			continue
		var feet := Vector2(f.position.x, f.floor_y)
		var moving := int(signf(f.velocity.x))
		match f.state:
			Fighter.State.WALK:
				if phase % (5 if f.running else 13) == 0:
					fx.dust_step(feet, -moving if moving != 0 else -f.facing, f.running)
				if f.running and phase % 6 == 0 and moving != 0:
					fx.speed_lines(feet, moving)
			Fighter.State.HIT:
				if absf(f.velocity.x) > 110.0 and phase % 4 == 0:
					fx.dust_slide(feet, moving)
			Fighter.State.ATTACK:
				if atk == null:
					continue
				if f.attack_crouching and f.is_hitbox_active() and phase % 3 == 0:
					fx.dust_sweep(feet, f.facing)
				if atk.dash_speed > 0.0 and f.attack_frame <= atk.startup + atk.active:
					if phase % 4 == 0:
						fx.dust_step(feet, -f.facing, true)
					if phase % 6 == 0:
						fx.speed_lines(feet, f.facing)

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
