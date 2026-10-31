## Ficha completa de un luchador. Cada personaje del juego es UN archivo
## .tres con este script (p. ej. fighters/napoleon/napoleon.tres).
## Para añadir un personaje nuevo no hay que tocar el motor: se crea un
## .tres nuevo y se registra en scripts/fighter_registry.gd.
class_name FighterData
extends Resource

## Ranuras de ataque que entiende el motor. El orden coincide con los botones.
const ATTACK_SLOTS: Array[StringName] = [
	&"punch_light", &"punch_heavy", &"special_1",
	&"kick_light", &"kick_heavy", &"special_2",
]

@export_group("Identidad")
@export var id: StringName = &"fighter"
@export var display_name: String = "LUCHADOR"
## Nombre corto para el HUD (máx. ~10 caracteres).
@export var short_name: String = "LUCHADOR"
@export var country: String = ""
@export var era: String = ""
@export_multiline var intro_quote: String = ""
@export_multiline var victory_quote: String = ""
@export_multiline var bio: String = ""

@export_group("Estadísticas")
@export var max_health: float = 100.0
## Velocidad al caminar (px/s).
@export var walk_speed: float = 70.0
## Impulso de salto (px/s, negativo = hacia arriba).
@export var jump_velocity: float = -360.0
## Velocidad horizontal durante un salto con dirección.
@export var jump_forward_speed: float = 110.0
## Multiplicador del daño que inflige (1.0 = normal).
@export var strength: float = 1.0
## Divisor del daño que recibe (1.2 = recibe un 17% menos).
@export var resistance: float = 1.0

@export_group("Ataques")
@export var punch_light: AttackData
@export var punch_heavy: AttackData
@export var kick_light: AttackData
@export var kick_heavy: AttackData
## Poder especial 1 (botón O / Numpad 3).
@export var special_1: AttackData
## Poder especial 2 (botón L / Numpad 6).
@export var special_2: AttackData
## Ataque definitivo: definido en los datos, se activará en versiones futuras.
@export var ultimate: AttackData
## Combos de comando (estructura preparada, ver combo_data.gd).
@export var combos: Array[ComboData] = []

@export_group("Cuerpo (hurtbox)")
@export var body_width: float = 26.0
@export var stand_height: float = 76.0
@export var crouch_height: float = 48.0

@export_group("Gráficos finales (opcional)")
## Retrato para menús. Si está vacío se dibuja el busto provisional.
@export var portrait: Texture2D
## Cuando existan sprites reales: un SpriteFrames con animaciones llamadas
## idle, walk, jump, crouch, block, hit, ko, victory y una por cada `anim`
## de AttackData. Si está vacío se usa el renderizador provisional.
@export var sprite_frames: SpriteFrames
@export var sprite_offset: Vector2 = Vector2(0, 0)

@export_group("Aspecto provisional (pixel art procedural)")
@export var skin_color: Color = Color("f0c090")
@export var hair_color: Color = Color("3a2a1a")
@export var coat_color: Color = Color("2a3a6a")
@export var coat_trim_color: Color = Color("e0c060")
@export var shirt_color: Color = Color("eeeeee")
@export var accent_color: Color = Color("c02020")
@export var pants_color: Color = Color("2a2a3a")
@export var boots_color: Color = Color("1a1a1a")
@export var hat_color: Color = Color("111111")
## Peinado: swoop | short | bald | long | wild | bun | curls
@export var hair_style: StringName = &"short"
## Sombrero: none | bicorne | top_hat | crown | nemes | cap | beret | turban |
## fur_hat | laurel | helmet | zucchetto | halo
@export var hat_style: StringName = &"none"
## Vello facial: none | mustache | toothbrush | goatee | chin | full | long
@export var beard_style: StringName = &"none"
## Decoración del pecho: tie | lapels | plain | robe | uniform
@export var chest_style: StringName = &"tie"
@export var has_epaulettes: bool = false
@export var tall_boots: bool = false
## Proporciones en píxeles.
@export var thigh_len: float = 13.0
@export var shin_len: float = 13.0
@export var leg_width: float = 6.0
@export var torso_len: float = 26.0
@export var torso_width: float = 18.0
@export var upper_arm_len: float = 11.0
@export var forearm_len: float = 11.0
@export var arm_width: float = 5.0
@export var head_width: float = 12.0
@export var head_height: float = 13.0
## Pose de reposo especial: normal | hand_in_coat
@export var idle_style: StringName = &"normal"

## Devuelve el AttackData de una ranura (&"punch_light", ...).
func get_attack(slot: StringName) -> AttackData:
	match slot:
		&"punch_light": return punch_light
		&"punch_heavy": return punch_heavy
		&"kick_light": return kick_light
		&"kick_heavy": return kick_heavy
		&"special_1": return special_1
		&"special_2": return special_2
		&"ultimate": return ultimate
	return null

## Comprobación básica para detectar fichas incompletas al cargarlas.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).is_empty():
		errors.append("id vacío")
	for slot in ATTACK_SLOTS:
		if get_attack(slot) == null:
			errors.append("%s: falta el ataque %s" % [id, slot])
	if max_health <= 0:
		errors.append("%s: max_health debe ser > 0" % id)
	return errors
