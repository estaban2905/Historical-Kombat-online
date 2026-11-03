## Director del combate (raíz de Fight.tscn).
##   1. Carga el escenario y crea los dos luchadores a partir de sus datos.
##   2. Cada frame de física actualiza a ambos en orden fijo (tick).
##   3. Separa los cuerpos (nadie atraviesa al rival ni se queda trabado).
##   4. Resuelve impactos cuerpo a cuerpo y de proyectiles, aplicando daño,
##      hitstop, efectos, sonido y vibración de cámara.
## Las reglas de rondas y tiempo están en round_manager.gd.
class_name CombatManager
extends Node2D

signal hit_landed(attacker: Fighter, defender: Fighter, attack: AttackData, result: HitResult)
signal fighter_knocked_out(fighter: Fighter)
## Al final de cada tick de combate (tras incrementar tick_count).
signal ticked
## Punto de control de la sincronía online: cada SYNC_EVERY ticks, con el resumen del estado (ver state_checksum).
signal sync_point(tick: int, checksum: int, version: int)

const FIGHTER_SCENE := preload("res://scenes/fighters/Fighter.tscn")
## Cinemática del ultimate: todo se congela estos frames (zoom sobre quien lo lanza y
## su nombre en pantalla) antes de que empiece el ataque.
## Cada cuántos ticks se comprueba que las dos peleas online siguen iguales (1 s).
const SYNC_EVERY := 60
## Versión del contenido de state_snapshot: súbela si cambias qué recoge, para que el servidor no
## compare el resumen de un juego antiguo con el de uno nuevo.
const SNAPSHOT_VERSION := 1
const ULT_CINEMATIC_FRAMES := 48
const ULT_ZOOM := 1.45

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
## true en el duelo online: emite sync_point cada SYNC_EVERY ticks.
var sync_enabled: bool = false
var _input_source: Callable
## Frames que quedan de la cinemática de un ultimate (0 = no hay). Mientras dura no
## avanza nada del combate ni del reloj de la ronda.
var cinematic_frames: int = 0
var cinematic_fighter: Fighter
var cinematic_text: String = ""
## Efectos de pantalla del ultimate en curso (ambiente, grietas, rayos...).
var ult_fx: UltimateFX
## Fases del Nexo (jefe final): [fracción de vida, rótulo, fuerza x, velocidad x].
const NEXO_PHASES := [[0.66, "FASE II", 1.15, 1.15], [0.33, "FASE III", 1.3, 1.3]]
var _nexo_phase: int = 0
## (fuerza, velocidad) de la ficha del Nexo sin fases; Vector2.ZERO = no es el combate final.
var _nexo_base := Vector2.ZERO

func _ready() -> void:
	_load_stage()
	fx = ParticleFX.new()
	fx.use_flash = true
	fx.floor_y = stage.floor_y
	fx.z_index = 19
	effects_root.add_child(fx)
	p1 = _spawn_fighter(Game.p1_data(), 1)
	# Las fases del Nexo cambian su ficha durante el combate: se usa una copia para que
	# la ficha guardada en Game no arrastre el refuerzo a la revancha.
	var p2_data := Game.p2_data()
	if Game.is_story_nexo_fight():
		p2_data = p2_data.duplicate() as FighterData
	p2 = _spawn_fighter(p2_data, 2)
	p1.opponent = p2
	p2.opponent = p1
	fighters = [p1, p2]
	if Game.is_story_nexo_fight():
		_nexo_base = Vector2(p2.data.strength, p2.data.walk_speed)
	if Game.is_vs_cpu():
		p2.input.use_keyboard = false
		ai = AIController.new(p2, p1, Game.ai_level())
	add_child(DebugOverlay.new(self))
	hud.bind(self)
	if Game.is_online():
		_start_online()
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
	if is_instance_valid(ult_fx):
		ult_fx.queue_free()
	ult_fx = null
	cinematic_frames = 0
	_update_cinematic()
	for p in projectiles_root.get_children():
		p.queue_free()
	fx.clear()
	p1.reset_for_round(stage.p1_spawn_x, 1)
	p2.reset_for_round(stage.p2_spawn_x, -1)
	if _nexo_base != Vector2.ZERO:
		_set_nexo_phase(0, false)

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
	if cinematic_frames > 0:
		cinematic_frames -= 1
		_update_cinematic()
		return
	if _input_source.is_valid():
		var masks: Array = _input_source.call(tick_count)
		# Vacío = aún faltan los botones del rival (online): el combate espera este tick.
		_set_waiting(masks.is_empty())
		if masks.is_empty():
			return
		p1.input.apply_mask(masks[0])
		p2.input.apply_mask(masks[1])
	if ai:
		ai.think()
	if training:
		training.pre_tick()
	for f in fighters:
		f.tick(delta)
	if _nexo_base != Vector2.ZERO:
		_update_nexo_phase()
	for p in projectiles_root.get_children():
		(p as Projectile).tick(delta)
	_resolve_bodies()
	_resolve_melee_hits()
	_resolve_throws()
	_resolve_projectiles()
	_update_shake(delta)
	_update_fx()
	tick_count += 1
	if sync_enabled and tick_count % SYNC_EVERY == 0:
		sync_point.emit(tick_count, state_checksum(), SNAPSHOT_VERSION)
	ticked.emit()

## El Nexo se endurece al perder vida: más fuerza y velocidad en cada fase (se reinicia cada ronda).
func _update_nexo_phase() -> void:
	var frac := p2.health / maxf(p2.data.max_health, 1.0)
	var phase := 0
	for i in NEXO_PHASES.size():
		if frac <= NEXO_PHASES[i][0]:
			phase = i + 1
	if phase > _nexo_phase:
		_set_nexo_phase(phase, true)

func _set_nexo_phase(phase: int, announce: bool) -> void:
	_nexo_phase = phase
	var mult_s := 1.0
	var mult_v := 1.0
	if phase > 0:
		mult_s = NEXO_PHASES[phase - 1][2]
		mult_v = NEXO_PHASES[phase - 1][3]
	p2.data.strength = _nexo_base.x * mult_s
	p2.data.walk_speed = _nexo_base.y * mult_v
	if announce:
		hud.show_message("EL NEXO · %s" % NEXO_PHASES[phase - 1][1], 1.6, Color("ffd24a"))
		shake(6.0)
		Sfx.play(&"hit_heavy")

## Sustituye el teclado por una fuente externa de entradas (partida online,
## repeticiones, pruebas). `source` recibe el número de tick y devuelve
## [máscara_P1, máscara_P2] (ver InputManager.apply_mask). Mientras esté
## activa, el combate depende SOLO de esas máscaras: mismas máscaras = misma pelea.
func set_input_source(source: Callable) -> void:
	_input_source = source
	for f in fighters:
		f.input.use_keyboard = false

# =========================================================================
#  Duelo online
# =========================================================================
## Aviso mientras faltan los botones del rival (solo presentación).
var _waiting_label: Label

func _start_online() -> void:
	set_input_source(Online.input_source)
	Online.begin_fight()
	sync_enabled = true
	sync_point.connect(Online.send_sync)
	Online.opponent_left.connect(_on_online_opponent_left, CONNECT_ONE_SHOT)
	Online.timed_out.connect(_on_online_timed_out, CONNECT_ONE_SHOT)
	Online.desynced.connect(_on_online_desynced, CONNECT_ONE_SHOT)
	Online.failed.connect(_on_online_failed, CONNECT_ONE_SHOT)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_waiting_label = Label.new()
	_waiting_label.theme = HKTheme.theme()
	_waiting_label.text = "ESPERANDO AL RIVAL..."
	_waiting_label.position = Vector2(0, 222)
	_waiting_label.size = Vector2(426, 12)
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.visible = false
	layer.add_child(_waiting_label)

## Muestra el aviso solo si la espera ya se nota (más de ~6 frames seguidos), con los segundos
## que quedan antes de que el servidor cierre el duelo.
func _set_waiting(waiting: bool) -> void:
	if _waiting_label == null:
		return
	_waiting_label.visible = waiting and Online.stalled_ticks > 6
	if _waiting_label.visible:
		_waiting_label.text = "ESPERANDO AL RIVAL... %d" % Online.stall_seconds_left()

## El rival se desconectó en plena pelea: la partida se da por ganada.
func _on_online_opponent_left() -> void:
	_stop_listening_online()
	hud.show_message("RIVAL DESCONECTADO", 2.0, HKTheme.GOLD)
	round_manager.abort()
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	Game.set_match_result(Online.side, round_manager.wins[1], round_manager.wins[2])
	Game.goto(Game.SCENE_RESULTS)

## Los resúmenes de las dos peleas no coinciden: cada uno estaría viendo una pelea distinta.
## No se sabe quién tiene razón, así que el duelo se anula y se vuelve al menú.
func _on_online_desynced() -> void:
	_stop_listening_online()
	sync_enabled = false
	hud.show_message("SIN SINCRONÍA · DUELO ANULADO", 2.0, HKTheme.BLOOD)
	round_manager.abort()
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		Game.goto(Game.SCENE_MENU)

## Deja de escuchar los avisos de la red: ya se decidió cómo termina el duelo.
func _stop_listening_online() -> void:
	for pair in [[Online.opponent_left, _on_online_opponent_left], [Online.timed_out, _on_online_timed_out],
			[Online.desynced, _on_online_desynced], [Online.failed, _on_online_failed]]:
		var sig: Signal = pair[0]
		var handler: Callable = pair[1]
		if sig.is_connected(handler):
			sig.disconnect(handler)

## El servidor cerró el duelo porque nadie respondía: pierde quien iba por detrás.
## Si no se sabe quién fue (loser = 0), el duelo se anula y se vuelve al menú.
func _on_online_timed_out(loser: int) -> void:
	_stop_listening_online()
	if loser == 0:
		hud.show_message("SIN RESPUESTA · DUELO ANULADO", 2.0, HKTheme.BLOOD)
	elif loser == Online.side:
		hud.show_message("TE QUEDASTE SIN RESPONDER", 2.0, HKTheme.BLOOD)
	else:
		hud.show_message("EL RIVAL NO RESPONDE", 2.0, HKTheme.GOLD)
	round_manager.abort()
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree():
		return
	if loser == 0:
		Game.goto(Game.SCENE_MENU)
		return
	Game.set_match_result(3 - loser, round_manager.wins[1], round_manager.wins[2])
	Game.goto(Game.SCENE_RESULTS)

## Se perdió MI conexión: no hay ganador, se vuelve al menú.
func _on_online_failed(message: String) -> void:
	_stop_listening_online()
	hud.show_message(message, 2.0, HKTheme.BLOOD)
	round_manager.abort()
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		Game.goto(Game.SCENE_MENU)

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
			f.guard, f.guard_idle, f.attack_connected, f.chain_slots.size(), f.juggle_hits, f.root_frames, f.shield_frames,
				f.knockdown_pending, f.tech_fall_buffer, f.wake_frames, f.wake_rolling,
				f.jump_buffer, f.air_attack_used, f.running, f.crouch_blocking, f.block_age, f.input_history,
				f.attack_crouching, f.attack_airborne, f.guard_is_broken, f.wake_invuln, f.invert_grace,
				f._prev_jump_held, f._prev_block_held, f._prev_h, f._tap_dir, f._tap_timer, f.throw_ready,
				f.current_slot, f.projectile_spawned, f.combo_claimed, f.frame_counter])
	for p in projectiles_root.get_children():
		var pr := p as Projectile
		parts.append([pr.position, pr.life, pr.alive, pr.vy, pr._t, pr.delay, pr._armed, pr._hit_log.values()])
	parts.append(cinematic_frames)
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
	# El nivel y si es un barrido se guardan ya: si hay intercambio, el primer impacto
	# termina el ataque del otro antes de aplicar el suyo.
	for f in fighters:
		for target in f.get_hit_candidates():
			hits.append([f, target, f.current_attack, f.current_hit_level(), f.attack_combo, f.is_sweep_attack()])
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
		_apply_hit(attacker, target, atk, attacker.facing, point, false, h[3], h[4], h[5])
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
				var owner_f := p.owner_fighter
				var combo: ComboData = null
				if p.combo != null and owner_f.combo_claimed != p.combo_instance:
					combo = p.combo
					owner_f.combo_claimed = p.combo_instance
				_apply_hit(owner_f, target, p.attack, p.hit_direction(target),
					_contact_point(p.global_position, target), true, p.attack.hit_level, combo)
				p.register_hit(target)
				if not p.alive:
					break

func _contact_point(from: Vector2, target: Fighter) -> Vector2:
	var center := target.hurtbox_shape.global_position
	return Vector2(lerpf(from.x, center.x, 0.4), from.y)

func _apply_hit(attacker: Fighter, target: Fighter, atk: AttackData, direction: int,
		point: Vector2, from_projectile: bool, level: AttackData.HitLevel = AttackData.HitLevel.MID,
		combo: ComboData = null, sweep: bool = false) -> void:
	var result := target.receive_hit(attacker, atk, direction, level, combo.bonus_damage if combo else 0.0, sweep)
	if result.absorbed:
		HitEffect.spawn(effects_root, point, HitEffect.Type.CLASH, 1.6)
		Sfx.play(&"block")
		fx.flash(0.3)
		PowerEffects.reflect(self, target, attacker)
		hit_landed.emit(attacker, target, atk, result)
		return
	# Nombre del combo completado: solo si el golpe final entra (el HUD lo muestra).
	result.combo_name = combo.display_name if combo and not result.blocked else ""
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

func _on_attack_started(fighter: Fighter, atk: AttackData) -> void:
	if fighter.current_slot == &"special_2" and fighter.data.power_quote != "":
		hud.show_shout(fighter, fighter.data.power_quote)
	if atk.kind == AttackData.Kind.ULTIMATE:
		_start_cinematic(fighter, atk)
	elif not atk.is_projectile():
		Sfx.play(&"whoosh", 0.15)

# =========================================================================
#  Cinemática del ultimate
# =========================================================================
func _start_cinematic(f: Fighter, atk: AttackData) -> void:
	cinematic_frames = ULT_CINEMATIC_FRAMES
	cinematic_fighter = f
	start_ult_fx(atk)
	cinematic_text = atk.display_name.to_upper()
	Sfx.play(&"confirm")
	Sfx.play(&"megaphone")
	fx.flash(0.7)
	shake(3.0)
	_update_cinematic()

# --- Interfaz para los poderes (PowerEffects): no tocan los nodos internos del combate ---
## Añade al combate una entidad de poder (proyectil, decorado...). Si pide sacudir la cámara al armarse, se conecta.
func add_entity(entity: Projectile) -> void:
	entity.shake_requested.connect(shake)
	projectiles_root.add_child(entity)

## ¿Hay efectos de pantalla de un ultimate en marcha?
func has_ult_fx() -> bool:
	return is_instance_valid(ult_fx)

## Programa un evento de los efectos de pantalla del ultimate (si existen).
func ult_fx_at(delay: float, type: StringName, args: Dictionary = {}) -> void:
	if is_instance_valid(ult_fx):
		ult_fx.at(delay, type, args)

## Fragmentos de piedra en el suelo, en la posición x.
func spawn_stones(x: float) -> void:
	fx.stones(Vector2(x, stage.floor_y))

## Crea los efectos de pantalla del ultimate (el ambiente ya se oscurece durante el zoom).
func start_ult_fx(atk: AttackData) -> void:
	if is_instance_valid(ult_fx):
		ult_fx.queue_free()
	ult_fx = null
	if atk.ult_kind == &"":
		return
	ult_fx = UltimateFX.new()
	ult_fx.setup(self, atk)
	effects_root.add_child(ult_fx)

## Cámara de la cinemática: se acerca a quien lanza el ultimate, aguanta y vuelve.
## Es solo presentación: no entra en el estado del combate.
func _update_cinematic() -> void:
	if cinematic_frames <= 0 or cinematic_fighter == null:
		camera.zoom = Vector2.ONE
		camera.position = Vector2.ZERO
		return
	var elapsed := ULT_CINEMATIC_FRAMES - cinematic_frames
	var t_in := clampf(float(elapsed) / 10.0, 0.0, 1.0)
	var t_out := clampf(float(cinematic_frames) / 8.0, 0.0, 1.0)
	var t := ease(minf(t_in, t_out), 0.4)
	var zoom := lerpf(1.0, ULT_ZOOM, t)
	camera.zoom = Vector2(zoom, zoom)
	var view := Vector2(426, 240) / zoom
	var target := cinematic_fighter.global_position + Vector2(0, -40)
	var top_left := (target - view * 0.5).clamp(Vector2.ZERO, Vector2(426, 240) - view)
	camera.position = Vector2.ZERO.lerp(top_left, t)

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
