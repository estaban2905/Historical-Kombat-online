## Modo ENTRENAMIENTO (Game.Mode.TRAINING). Lo crea CombatManager y se dibuja en
## la capa del HUD.
##   - P2 es un muñeco con varias conductas (F2): quieto, agachado, salta,
##     bloquea de pie o agachado, la CPU o manejado por el jugador 2.
##   - Vida y energía infinitas, sin reloj ni rondas.
##   - Panel de frame data del último ataque (de cualquiera de los dos): preparación,
##     activos, recuperación, daño real y ventaja medida al golpear y al bloquear.
##   - Pausa de frames (F5) y avance de un frame (F6).
## Teclas: F1 cajas (apagadas / cajas / cajas y rótulos) · F2 muñeco · F3 reiniciar posiciones · F4 panel · F5 pausa de
## frames · F6 avanzar un frame.
class_name TrainingMode
extends Control

enum Dummy { STAND, CROUCH, JUMP, BLOCK, BLOCK_LOW, CPU, MANUAL }
const DUMMY_NAMES: Array[String] = ["QUIETO", "AGACHADO", "SALTA", "BLOQUEA", "BLOQUEA AGACHADO", "CPU", "MANUAL (J2)"]
## Si la vida baja de esta fracción se rellena (así nadie llega a caer K.O.).
const REFILL_BELOW := 0.35
const KO_RESET_TICKS := 45
## Cada cuántos ticks salta el muñeco que salta.
const JUMP_EVERY := 75
## Ticks máximos para medir una ventaja antes de descartarla.
const MEASURE_TIMEOUT := 300
const SLOT_SHORT := {&"punch_light": "PD", &"punch_heavy": "PF", &"kick_light": "KD",
	&"kick_heavy": "KF", &"special_1": "E1", &"special_2": "E2", &"ultimate": "ULT", &"grab": "AGA"}

const BAR_Y := 206.0
const P1_COLOR := Color("ff8a7a")
const P2_COLOR := Color("7ab4ff")

var combat: CombatManager
var dummy: Dummy = Dummy.STAND
var frozen: bool = false
var panel_visible: bool = true

var _step: bool = false
var _ai: AIController
var _ko_ticks: int = 0
# Último ataque visto.
var _last_player: int = 0
var _last_atk: AttackData
var _last_slot: StringName = &""
var _last_damage: float = -1.0
var _last_blocked: bool = false
var _last_counter: bool = false
# Combo en curso (daño y golpes recibidos por quien lo sufre).
var _combo_damage: float = 0.0
var _combo_hits: int = 0
## Ventajas ya medidas: "jugador_ataque" -> {hit: int, block: int}.
var _memory: Dictionary = {}
## Mediciones en curso: {att, def, key, blocked, att_free, def_free, t0}.
var _measures: Array = []

func _init(p_combat: CombatManager) -> void:
	combat = p_combat
	name = "TrainingMode"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

## Se llama cuando el combate ya tiene a los dos luchadores.
func start() -> void:
	combat.hit_landed.connect(_on_hit_landed)
	combat.ticked.connect(_on_tick)
	for f in combat.fighters:
		f.attack_started.connect(_on_attack_started)
	# Las cajas se ven de entrada; los rótulos de estado se piden con F1 (el panel ya da lo importante).
	var overlay := combat.get_node_or_null("DebugOverlay") as DebugOverlay
	if overlay:
		overlay.set_mode(1)
	_apply_dummy()

# =========================================================================
#  Teclas
# =========================================================================
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F2:
			set_dummy(((int(dummy) + 1) % DUMMY_NAMES.size()) as Dummy)
		KEY_F3:
			reset_positions()
		KEY_F4:
			panel_visible = not panel_visible
		KEY_F5:
			frozen = not frozen
		KEY_F6:
			step_one()
		_:
			return
	get_viewport().set_input_as_handled()

## Con la pausa de frames activa, deja pasar el siguiente tick de combate.
func step_one() -> void:
	if frozen:
		_step = true

func set_dummy(mode: Dummy) -> void:
	dummy = mode
	_apply_dummy()

func _apply_dummy() -> void:
	var inp := combat.p2.input
	inp.use_keyboard = dummy == Dummy.MANUAL
	inp.release_all()
	_ai = AIController.new(combat.p2, combat.p1, Game.ai_level()) if dummy == Dummy.CPU else null

## Vuelve a colocar a los dos luchadores con todo restablecido.
func reset_positions() -> void:
	combat.reset_round()
	combat.set_controls(true)
	_measures.clear()
	_combo_hits = 0
	_combo_damage = 0.0

# =========================================================================
#  Enganches con CombatManager
# =========================================================================
## true si este tick de combate no debe ejecutarse (pausa de frames).
func should_skip_tick() -> bool:
	if not frozen:
		return false
	if _step:
		_step = false
		return false
	return true

## Se llama antes de cada tick: decide qué hace el muñeco.
func pre_tick() -> void:
	var inp := combat.p2.input
	match dummy:
		Dummy.MANUAL:
			return
		Dummy.CPU:
			_ai.think()
			return
	inp.release_all()
	match dummy:
		Dummy.CROUCH:
			inp.hold(&"crouch")
		Dummy.JUMP:
			if combat.tick_count % JUMP_EVERY < 3:
				inp.hold(&"jump")
		Dummy.BLOCK:
			inp.hold(&"block")
		Dummy.BLOCK_LOW:
			inp.hold(&"block")
			inp.hold(&"crouch")

func _on_attack_started(f: Fighter, atk: AttackData) -> void:
	_last_player = f.player_id
	_last_atk = atk
	_last_slot = f.current_slot
	_last_damage = -1.0
	_last_blocked = false
	_last_counter = false

func _on_hit_landed(attacker: Fighter, defender: Fighter, atk: AttackData, result: HitResult) -> void:
	if _last_atk != atk or _last_player != attacker.player_id:
		_last_player = attacker.player_id
		_last_atk = atk
		_last_slot = attacker.current_slot
	_last_damage = result.damage
	_last_blocked = result.blocked
	_last_counter = result.counter
	if not result.blocked:
		if defender.combo_hits_taken <= 1:
			_combo_damage = 0.0
		_combo_damage += result.damage
		_combo_hits = defender.combo_hits_taken
	# Los proyectiles y poderes no tienen ventaja que medir (el atacante ya está libre).
	if atk.is_projectile() or atk.is_power():
		return
	_measures.append({"att": attacker, "def": defender, "key": _key(attacker.player_id, atk),
		"blocked": result.blocked, "att_free": -1, "def_free": -1, "t0": combat.tick_count})

func _on_tick() -> void:
	# Recursos infinitos: la vida se rellena antes de poder caer K.O.
	var any_ko := false
	for f in combat.fighters:
		f.add_energy(Fighter.MAX_ENERGY)
		if f.state == Fighter.State.KO:
			any_ko = true
		elif f.health < REFILL_BELOW * f.data.max_health:
			f.health = f.data.max_health
			f.health_changed.emit(f)
	if any_ko:
		_ko_ticks += 1
		if _ko_ticks >= KO_RESET_TICKS:
			_ko_ticks = 0
			reset_positions()
	else:
		_ko_ticks = 0
	_update_measures()

# =========================================================================
#  Medición de la ventaja
# =========================================================================
static func _key(player: int, atk: AttackData) -> String:
	return "%d_%s" % [player, atk.id]

## ¿Puede el luchador actuar ya? (en bloqueo, solo cuando termina el bloqueo forzado)
static func _is_free(f: Fighter) -> bool:
	if f.state == Fighter.State.BLOCK:
		return f.stun_frames <= 0
	return f.state in [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.CROUCH, Fighter.State.JUMP]

## Ventaja = ticks que el atacante actúa antes que el defensor (negativa = actúa
## después). Mismo criterio que tests/frame_data_test.gd: el atacante actúa en el
## tick en que termina su ataque y el defensor en el siguiente a salir del aturdimiento.
func _update_measures() -> void:
	var t := combat.tick_count
	for m in _measures.duplicate():
		if m.att_free < 0 and _is_free(m.att):
			m.att_free = t
		if m.def_free < 0 and _is_free(m.def):
			m.def_free = t
		if m.att_free >= 0 and m.def_free >= 0:
			var entry: Dictionary = _memory.get(m.key, {})
			entry["block" if m.blocked else "hit"] = m.def_free + 1 - m.att_free
			_memory[m.key] = entry
			_measures.erase(m)
		elif t - m.t0 > MEASURE_TIMEOUT:
			_measures.erase(m)

## Ventaja medida del ataque dado ("hit" o "block"), o null si aún no se ha medido.
func advantage(player: int, atk: AttackData, kind: String) -> Variant:
	var entry: Dictionary = _memory.get(_key(player, atk), {})
	return entry.get(kind)

# =========================================================================
#  Dibujo
# =========================================================================
func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Ayuda y estado del muñeco, bajo el "ENTRENAMIENTO" del HUD.
	HKTheme.draw_text(self, Vector2(0, 58), "F1 CAJAS · F2 MUÑECO · F3 REINICIO · F4 PANEL",
		8, HKTheme.MUTED.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
	HKTheme.draw_text(self, Vector2(0, 68), "F5 PAUSA DE FRAMES · F6 UN FRAME",
		8, HKTheme.MUTED.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
	HKTheme.draw_text(self, Vector2(0, 80), "MUÑECO: %s" % DUMMY_NAMES[dummy], 8, HKTheme.GOLD,
		HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
	if frozen:
		var col := HKTheme.BLOOD if int(Time.get_ticks_msec() / 400) % 2 == 0 else HKTheme.PAPER
		HKTheme.draw_text(self, Vector2(0, 92), "PAUSA DE FRAMES", 8, col, HORIZONTAL_ALIGNMENT_CENTER, 426, 2)
	if panel_visible:
		_draw_panel()

func _draw_panel() -> void:
	draw_rect(Rect2(0, BAR_Y, 426, 240.0 - BAR_Y), Color(0.03, 0.02, 0.05, 0.78))
	draw_rect(Rect2(0, BAR_Y, 426, 1), HKTheme.GOLD_DARK)
	var atk := _last_atk
	if atk == null:
		HKTheme.draw_text(self, Vector2(0, 224), "ATACA PARA VER EL FRAME DATA", 8, HKTheme.MUTED,
			HORIZONTAL_ALIGNMENT_CENTER, 426, 1)
		return
	var col := P1_COLOR if _last_player == 1 else P2_COLOR
	# Línea 1: quién, qué ataque y su nivel
	var slot: String = SLOT_SHORT.get(_last_slot, "")
	var title := "P%d %s" % [_last_player, atk.display_name.to_upper().left(30)]
	if slot != "":
		title += " [%s]" % slot
	HKTheme.draw_text(self, Vector2(4, 216), title, 8, col, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	if _last_counter:
		HKTheme.draw_text(self, Vector2(0, 216), "COUNTER", 8, Color("60d0ff"), HORIZONTAL_ALIGNMENT_RIGHT, 422, 1)
	# Línea 2: tiempos y daño
	var line2 := "INI %d  ACT %d  REC %d  TOT %d" % [atk.startup, atk.active, atk.recovery, atk.total_frames()]
	if atk.is_projectile() or atk.is_power():
		line2 = "INI %d  ENERGÍA %d" % [atk.startup, int(atk.energy_cost)]
	if _last_damage >= 0.0:
		line2 += "  %s %.1f" % ["BLOQ" if _last_blocked else "DAÑO", _last_damage]
	HKTheme.draw_text(self, Vector2(4, 226), line2, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	# Línea 3: ventaja medida y combo
	var line3 := "VENT GOLPE %s  BLOQ %s" % [_fmt_adv(advantage(_last_player, atk, "hit")),
		_fmt_adv(advantage(_last_player, atk, "block"))]
	if _combo_hits >= 2:
		line3 += "  COMBO %d: %.1f" % [_combo_hits, _combo_damage]
	HKTheme.draw_text(self, Vector2(4, 236), line3, 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

static func _fmt_adv(v: Variant) -> String:
	if v == null:
		return "?"
	return "%+d" % int(v)
