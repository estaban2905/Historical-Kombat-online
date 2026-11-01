## Datos de UN ataque. Es un Resource: se edita en el Inspector de Godot
## o dentro del .tres de cada personaje. El motor (fighter.gd) solo lee
## estos valores; nunca hay números de daño "a fuego" en el código.
##
## Todos los tiempos están en FRAMES a 60 fps (1 frame = 1/60 s).
class_name AttackData
extends Resource

## GRAB: agarre. Ignora el bloqueo; ver Fighter.can_be_grabbed().
enum Kind { PUNCH, KICK, SPECIAL, ULTIMATE, GRAB }
## Cómo se bloquea: MID de pie o agachado, LOW solo agachado, OVERHEAD solo de pie.
enum HitLevel { MID, LOW, OVERHEAD }

@export_group("Identidad")
## Identificador interno (p. ej. "punch_light", "cannonball").
@export var id: StringName = &"attack"
## Nombre que se muestra al jugador.
@export var display_name: String = "Ataque"
@export var kind: Kind = Kind.PUNCH
## Pose del renderizador provisional (ver fighter_renderer.gd -> POSES).
## Cuando existan sprites, es el nombre de la animación en SpriteFrames.
@export var anim: StringName = &"jab"

@export_group("Daño y efecto")
@export var damage: float = 5.0
## Frames que el rival queda aturdido al recibir el golpe.
@export var hitstun: int = 14
## Frames que el rival queda inmovilizado si BLOQUEA.
@export var blockstun: int = 8
## Velocidad horizontal (px/s) con la que se empuja al rival.
@export var knockback: float = 90.0
## Velocidad vertical (px/s, negativa = hacia arriba). Lanza al rival por los aires.
@export var launch: float = 0.0
## Frames de "congelado" de ambos luchadores al impactar (sensación de golpe).
@export var hitstop: int = 4
## Tamaño del efecto visual de impacto (1 = normal).
@export var effect_scale: float = 1.0
## Nivel del golpe lanzado de pie. Da igual lo que ponga aquí: lanzado en el
## aire es siempre OVERHEAD y una patada agachada siempre LOW
## (ver Fighter.current_hit_level).
@export var hit_level: HitLevel = HitLevel.MID

@export_group("Tiempos (frames)")
@export var startup: int = 4
@export var active: int = 3
@export var recovery: int = 8

@export_group("Hitbox (relativa a los pies, mirando a la derecha)")
## Centro de la caja de impacto. x positiva = hacia delante, y negativa = hacia arriba.
@export var hitbox_offset: Vector2 = Vector2(24, -50)
@export var hitbox_size: Vector2 = Vector2(20, 10)
## Desplazamiento extra de la hitbox si se lanza agachado.
@export var crouch_offset: Vector2 = Vector2(0, 22)
## Desplazamiento extra si se lanza en el aire.
@export var air_offset: Vector2 = Vector2(0, 10)
@export var usable_in_air: bool = true
@export var usable_crouching: bool = true

@export_group("Recursos (especiales)")
## Energía que consume (0 = gratis).
@export var energy_cost: float = 0.0
## Frames antes de poder repetir el ataque.
@export var cooldown: int = 0

@export_group("Movimiento y proyectil")
## Velocidad de avance (px/s) durante startup + active (embestidas).
@export var dash_speed: float = 0.0
## Si > 0, el ataque no usa hitbox propia: dispara un proyectil al
## terminar el startup con esta velocidad (px/s).
@export var projectile_speed: float = 0.0
## Estilo visual del proyectil (ver projectile.gd).
## Estilos: ball | soundwave | orb | bolt | spin
@export var projectile_style: StringName = &"ball"
@export var projectile_lifetime: float = 2.0
## Color principal del proyectil (orb, bolt y spin).
@export var projectile_color: Color = Color("ffe060")

@export_group("Poder especial (efectos)")
## Si no está vacío, el ataque no usa hitbox propia: al acabar el startup se
## invoca PowerEffects.cast() con este identificador (ver power_effects.gd).
@export var power: StringName = &""
## Estado que se aplica al rival al impactar: slow | invert | float
@export var status: StringName = &""
@export var status_frames: int = 0
## Energía que recupera el atacante cuando el golpe conecta (sin bloqueo).
@export var energy_on_hit: float = 0.0

## Duración total en frames.
func total_frames() -> int:
	return startup + active + recovery

func is_projectile() -> bool:
	return projectile_speed > 0.0

func is_power() -> bool:
	return power != &""
