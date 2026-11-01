## Capa de depuración del combate (F1 recorre: apagada, solo cajas, cajas y rótulos).
## Dibuja las MISMAS cajas que usa el motor para los impactos
## (Fighter.get_hurt_rect / get_hit_rect, Projectile.get_rect) y, sobre cada
## luchador, su estado, el frame del ataque en curso y el aturdimiento.
## Solo dibuja: no forma parte del estado del combate.
class_name DebugOverlay
extends Node2D

const HURT_COLOR := Color(0.3, 0.6, 1.0)
const HIT_COLOR := Color(1.0, 0.2, 0.2)
const PROJ_COLOR := Color(1.0, 0.6, 0.1)
## Color de la fase del ataque: preparación, activo, recuperación.
const PHASE_COLORS := {&"startup": Color(1.0, 0.9, 0.3), &"active": Color(1.0, 0.3, 0.3),
	&"recovery": Color(0.5, 0.7, 1.0)}
const FONT_SIZE := 8
const SLOT_SHORT := {&"punch_light": "PD", &"punch_heavy": "PF", &"kick_light": "KD",
	&"kick_heavy": "KF", &"special_1": "E1", &"special_2": "E2", &"ultimate": "ULT", &"grab": "AGA"}
## Nivel del golpe (indexado por AttackData.HitLevel): medio, bajo, alto.
const LEVEL_SHORT: Array[String] = ["MED", "BAJO", "ALTO"]

## 0 = apagada · 1 = solo cajas · 2 = cajas y rótulos de estado.
var mode: int = 0
var combat: CombatManager

func _init(p_combat: CombatManager) -> void:
	combat = p_combat
	name = "DebugOverlay"
	z_index = 50
	visible = false
	# Sigue respondiendo a F1 con el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode == KEY_F1:
		set_mode((mode + 1) % 3)
		get_viewport().set_input_as_handled()

func set_mode(m: int) -> void:
	mode = m
	visible = mode > 0

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	# Las cajas están en coordenadas globales.
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	for node in combat.projectiles_root.get_children():
		var p := node as Projectile
		if p and p.alive and not p.harmless:
			_box(p.get_rect(), PROJ_COLOR if p.is_armed() else PROJ_COLOR.darkened(0.5))
	for f in combat.fighters:
		if f.can_be_hit():
			_box(f.get_hurt_rect(), HURT_COLOR)
		if f.is_hitbox_active():
			_box(f.get_hit_rect(), HIT_COLOR)
		if mode >= 2:
			_label(f)

func _box(r: Rect2, color: Color) -> void:
	draw_rect(r, Color(color, 0.25))
	draw_rect(r, color, false, 1.0)

func _label(f: Fighter) -> void:
	var lines: Array = [[f.state_name(), Color.WHITE]]
	var atk := f.current_attack
	if f.state == Fighter.State.ATTACK and atk:
		var phase := &"recovery"
		if f.attack_frame <= atk.startup:
			phase = &"startup"
		elif f.attack_frame <= atk.startup + atk.active:
			phase = &"active"
		lines.append(["%s %s %d/%d" % [SLOT_SHORT.get(f.current_slot, "ATQ"), LEVEL_SHORT[f.current_hit_level()],
			f.attack_frame, atk.total_frames()],
			PHASE_COLORS[phase]])
	if f.stun_frames > 0:
		lines.append(["STUN %d" % f.stun_frames, PHASE_COLORS[&"active"]])
	if f.hitstop_frames > 0:
		lines.append(["STOP %d" % f.hitstop_frames, Color.GRAY])
	var top := f.get_hurt_rect().position.y - 4.0 - FONT_SIZE * (lines.size() - 1)
	var font := HKTheme.font()
	for i in lines.size():
		var text: String = lines[i][0]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var pos := Vector2(roundf(f.global_position.x - width * 0.5), roundf(top + i * FONT_SIZE))
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 2, Color.BLACK)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, lines[i][1])
