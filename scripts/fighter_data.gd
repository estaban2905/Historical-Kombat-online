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
## Año de referencia (nacimiento; negativo = a.C.). Ordena la línea de tiempo del modo Historia.
@export var year: int = 0
@export_multiline var intro_quote: String = ""
@export_multiline var victory_quote: String = ""
## Frase que grita al lanzar su poder especial (vacía = no dice nada).
@export var power_quote: String = ""
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
## Agarre (puño débil + patada débil a la vez). Vacío = agarre común (default_grab).
@export var grab: AttackData
## Combos con nombre propios (ver combo_data.gd). Vacío = los comunes.
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
## Peinado: swoop | short | bald | long | wild | bun | curls | bob | braids | updo | ponytail
@export var hair_style: StringName = &"short"
## Sombrero: none | bicorne | top_hat | crown | nemes | cap | beret | turban |
## fur_hat | laurel | helmet | zucchetto | halo | tiara | headband
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

@export_group("Rasgos (aspecto provisional)")
## Silueta femenina: hombros estrechos, cintura marcada, pestañas, labios y rubor.
@export var female: bool = false
## Falda o vestido: none | skirt (hasta la rodilla) | dress (hasta la pantorrilla) | gown (hasta el suelo).
@export var outfit: StringName = &"none"
## Color de la falda o el vestido (transparente = el del abrigo).
@export var outfit_color: Color = Color(0, 0, 0, 0)
## Gafas: none | round | dark
@export var glasses: StringName = &"none"
## Capa que cuelga a la espalda (transparente = sin capa).
@export var cape_color: Color = Color(0, 0, 0, 0)
## Joyas: none | necklace (collar y pendiente) | cross (cruz al cuello) | earplug (disco en la oreja)
@export var jewelry: StringName = &"none"
@export var jewelry_color: Color = Color("e8c040")

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
		&"grab": return grab if grab else default_grab()
	return null

static var _default_combos: Array[ComboData] = []

## Combos de este personaje: los suyos o, si no tiene, los comunes.
func get_combos() -> Array[ComboData]:
	return combos if not combos.is_empty() else default_combos()

## Dos combos comunes a todos los luchadores, que se hacen cancelando golpes.
static func default_combos() -> Array[ComboData]:
	if _default_combos.is_empty():
		_default_combos = [
			_make_combo(&"trio", "TRÍO", [&"punch_light", &"punch_heavy", &"kick_heavy"], 3.0),
			_make_combo(&"cuarteto", "CUARTETO", [&"punch_light", &"kick_light", &"punch_heavy", &"kick_heavy"], 5.0),
		]
	return _default_combos

static func _make_combo(p_id: StringName, p_name: String, slots: Array[StringName], bonus: float) -> ComboData:
	var c := ComboData.new()
	c.id = p_id
	c.display_name = p_name
	c.sequence = slots
	c.bonus_damage = bonus
	return c

static var _default_grab: AttackData

## Agarre común a todos los luchadores: rápido y de poco alcance, pero con
## mucha recuperación si falla.
static func default_grab() -> AttackData:
	if _default_grab == null:
		var g := AttackData.new()
		g.id = &"grab"
		g.display_name = "Agarre"
		g.kind = AttackData.Kind.GRAB
		g.anim = &"grab"
		g.damage = 12.0
		g.hitstun = 30
		g.knockback = 170.0
		g.launch = -220.0
		g.hitstop = 8
		g.effect_scale = 1.3
		g.startup = 5
		g.active = 2
		g.recovery = 22
		g.hitbox_offset = Vector2(22, -40)
		g.hitbox_size = Vector2(14, 30)
		g.crouch_offset = Vector2.ZERO
		g.air_offset = Vector2.ZERO
		g.usable_in_air = false
		g.usable_crouching = false
		_default_grab = g
	return _default_grab

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
