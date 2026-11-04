## Renderizador PROVISIONAL de luchadores en pixel art procedural.
##
## Dibuja un muñeco articulado (piernas, torso, brazos, cabeza, sombrero)
## a partir de los colores y proporciones de FighterData. Como el juego se
## dibuja a 426x240 sin filtrado, cada línea y rectángulo sale como píxeles
## nítidos. Así cada personaje tiene silueta propia sin usar imágenes
## externas.
##
## Cuando existan sprites definitivos basta con rellenar
## FighterData.sprite_frames: fighter.gd ocultará este nodo y usará un
## AnimatedSprite2D con los mismos nombres de pose.
##
## Sistema de poses: cada pose es un diccionario de ángulos (grados) medidos
## desde la vertical hacia abajo; positivo = hacia delante (hacia el rival).
##   fa_u/fa_l  brazo delantero (superior / antebrazo)
##   ba_u/ba_l  brazo trasero
##   fl_t/fl_s  pierna delantera (muslo / espinilla)
##   bl_t/bl_s  pierna trasera
##   lean       inclinación del torso, head inclinación de cabeza
##   tl         escala de longitud del torso, hx desplazamiento de cadera
class_name FighterRenderer
extends Node2D

const OUTLINE := Color("120a14")

const BASE_STAND := {
	"fa_u": 35.0, "fa_l": 150.0, "ba_u": 20.0, "ba_l": 140.0,
	"fl_t": 16.0, "fl_s": 4.0, "bl_t": -16.0, "bl_s": -8.0,
	"lean": 4.0, "head": 0.0, "tl": 1.0, "hx": 0.0,
}
const BASE_CROUCH := {
	"fa_u": 55.0, "fa_l": 165.0, "ba_u": 40.0, "ba_l": 155.0,
	"fl_t": 95.0, "fl_s": -5.0, "bl_t": 55.0, "bl_s": -70.0,
	"lean": 22.0, "head": -6.0, "tl": 0.86, "hx": 0.0,
}
const BASE_AIR := {
	"fa_u": 45.0, "fa_l": 160.0, "ba_u": 30.0, "ba_l": 150.0,
	"fl_t": 80.0, "fl_s": -15.0, "bl_t": 35.0, "bl_s": -55.0,
	"lean": 8.0, "head": 0.0, "tl": 1.0, "hx": 0.0,
}
const POSE_BLOCK := {"fa_u": 70.0, "fa_l": 175.0, "ba_u": 62.0, "ba_l": 170.0, "lean": -6.0, "head": -8.0}
const POSE_HIT := {
	"fa_u": -35.0, "fa_l": -5.0, "ba_u": -45.0, "ba_l": -20.0,
	"lean": -22.0, "head": -18.0, "fl_t": 25.0, "fl_s": 10.0, "bl_t": -25.0, "bl_s": -5.0,
}
const POSE_VICTORY := {"fa_u": 30.0, "fa_l": 160.0, "ba_u": 172.0, "ba_l": 178.0, "lean": -4.0, "head": -6.0}

## Estilos de REPOSO y de VICTORIA (FighterData.idle_style): cómo se para y cómo celebra cada luchador.
## Es solo apariencia: no afecta a la simulación ni a las cajas de golpe.
##   pose     ángulos que sustituyen a la postura base mientras está quieto
##   walk     true: también los conserva al caminar (los brazos no se mueven al andar)
##   bob      [amplitud en px, velocidad] de la respiración; por defecto [0.8, 4.0]
##   victory  ángulos que sustituyen a la pose de victoria; wave=false: no agita el brazo
const IDLE_STYLES := {
	# Mano metida en la casaca (Napoleón).
	&"hand_in_coat": {"pose": {"fa_u": 8.0, "fa_l": 112.0}, "walk": true},
	# Brazos cruzados sobre el pecho: dureza y distancia (líderes de mano firme).
	&"arms_crossed": {"pose": {"fa_u": 8.0, "fa_l": 96.0, "ba_u": 4.0, "ba_l": 92.0, "lean": 2.0, "head": -3.0},
		"victory": {"fa_u": 8.0, "fa_l": 96.0, "ba_u": 4.0, "ba_l": 92.0, "lean": -6.0, "head": -9.0}, "wave": false},
	# Pecho afuera y manos en la cintura: orgullo (emperadores, reyes, oradores).
	&"proud": {"pose": {"fa_u": -12.0, "fa_l": 62.0, "ba_u": -18.0, "ba_l": 70.0, "lean": -3.0, "head": -4.0},
		"victory": {"fa_u": -12.0, "fa_l": 62.0, "ba_u": -18.0, "ba_l": 70.0, "lean": -8.0, "head": -9.0}, "wave": false},
	# Manos juntas frente al pecho: calma y fe (maestros espirituales).
	&"prayer": {"pose": {"fa_u": 14.0, "fa_l": 128.0, "ba_u": 12.0, "ba_l": 124.0, "lean": 3.0, "head": 12.0},
		"bob": [0.5, 2.5], "victory": {"fa_u": 150.0, "fa_l": 172.0, "ba_u": 160.0, "ba_l": 176.0, "lean": -4.0, "head": -10.0}},
	# Mano al mentón mientras piensa (filósofos y científicos).
	&"scholar": {"pose": {"fa_u": 52.0, "fa_l": 172.0, "ba_u": 8.0, "ba_l": 92.0, "head": 5.0},
		"bob": [0.6, 3.0], "victory": {"fa_u": 52.0, "fa_l": 172.0, "ba_u": 150.0, "ba_l": 176.0, "head": -6.0}},
	# Guardia alta y rodillas flexionadas: listo para el golpe (guerreros y soldados).
	&"boxer": {"pose": {"fa_u": 55.0, "fa_l": 160.0, "ba_u": 45.0, "ba_l": 165.0, "lean": 8.0,
			"fl_t": 22.0, "fl_s": 10.0, "bl_t": -20.0, "bl_s": -12.0},
		"bob": [1.1, 6.0], "victory": {"fa_u": 150.0, "fa_l": 170.0, "ba_u": 165.0, "ba_l": 175.0, "lean": -6.0}},
	# Brazos caídos, cuerpo suelto: tranquilidad (humildes y cercanos).
	&"relaxed": {"pose": {"fa_u": 6.0, "fa_l": 14.0, "ba_u": -4.0, "ba_l": 8.0, "lean": 0.0},
		"bob": [0.6, 3.0]},
	# Rebote constante: energía y espectáculo.
	&"bouncy": {"pose": {"fa_u": 40.0, "fa_l": 140.0, "ba_u": 25.0, "ba_l": 135.0}, "bob": [2.2, 8.0]},
	# Balanceo lento y digno (realeza y presencia inquietante).
	&"sway": {"pose": {"fa_u": 18.0, "fa_l": 135.0, "ba_u": 10.0, "ba_l": 130.0, "lean": -1.0},
		"bob": [1.4, 2.2]},
	# Encorvado y de brazos largos hacia delante: acecho.
	&"stalk": {"pose": {"fa_u": 28.0, "fa_l": 62.0, "ba_u": 22.0, "ba_l": 56.0, "lean": 11.0, "head": 6.0},
		"bob": [1.0, 3.5]},
}

## Animaciones de ataque: pose de preparación ("windup") y de impacto ("strike").
## "prop" dibuja un objeto en la mano delantera durante el ataque.
const POSES := {
	"jab": {
		"windup": {"fa_u": 25.0, "fa_l": 120.0},
		"strike": {"fa_u": 88.0, "fa_l": 90.0, "lean": 10.0, "hx": 2.0},
	},
	"straight": {
		"windup": {"fa_u": -25.0, "fa_l": 70.0, "lean": -6.0, "ba_u": 60.0, "ba_l": 160.0},
		"strike": {"fa_u": 92.0, "fa_l": 92.0, "lean": 20.0, "hx": 5.0, "ba_u": -20.0, "ba_l": 40.0},
	},
	"kick_low": {
		"windup": {"fl_t": 60.0, "fl_s": -20.0, "lean": -4.0},
		"strike": {"fl_t": 85.0, "fl_s": 82.0, "lean": -10.0, "bl_t": -8.0, "bl_s": -4.0},
	},
	"kick_high": {
		"windup": {"fl_t": 100.0, "fl_s": 15.0, "lean": -10.0},
		"strike": {"fl_t": 125.0, "fl_s": 118.0, "lean": -22.0, "bl_t": -5.0, "bl_s": -3.0, "fa_u": -10.0, "fa_l": 60.0},
	},
	"sweep": {
		"windup": {"fl_t": 70.0, "fl_s": 20.0},
		"strike": {"fl_t": 92.0, "fl_s": 94.0, "lean": 28.0},
	},
	"air_kick": {
		"windup": {"fl_t": 70.0, "fl_s": 10.0},
		"strike": {"fl_t": 55.0, "fl_s": 55.0, "bl_t": 20.0, "bl_s": -60.0, "lean": -12.0},
	},
	"air_punch": {
		"windup": {"fa_u": 60.0, "fa_l": 150.0},
		"strike": {"fa_u": 70.0, "fa_l": 60.0, "lean": 14.0},
	},
	"megaphone": {
		"prop": "megaphone",
		"windup": {"fa_u": 15.0, "fa_l": 160.0, "ba_u": 10.0, "ba_l": 150.0, "lean": -8.0},
		"strike": {"fa_u": 85.0, "fa_l": 92.0, "ba_u": 75.0, "ba_l": 100.0, "lean": 14.0, "hx": 3.0},
	},
	"golf": {
		"prop": "golf_club",
		"windup": {"fa_u": -55.0, "fa_l": -80.0, "ba_u": -45.0, "ba_l": -70.0, "lean": 14.0},
		"strike": {"fa_u": 150.0, "fa_l": 168.0, "ba_u": 140.0, "ba_l": 160.0, "lean": -12.0, "head": -10.0},
	},
	"cannon": {
		"windup": {"fa_u": 150.0, "fa_l": 170.0, "lean": -6.0},
		"strike": {"fa_u": 92.0, "fa_l": 88.0, "lean": 12.0, "hx": 2.0},
	},
	"charge": {
		"prop": "sword",
		"windup": {"fa_u": -30.0, "fa_l": 30.0, "lean": -8.0},
		"strike": {"fa_u": 88.0, "fa_l": 90.0, "lean": 32.0, "hx": 6.0,
			"fl_t": 45.0, "fl_s": 10.0, "bl_t": -45.0, "bl_s": -30.0},
	},
	# Variantes con otros objetos (o sin objeto) para los demás luchadores.
	"staff": {
		"prop": "staff",
		"windup": {"fa_u": -55.0, "fa_l": -80.0, "ba_u": -45.0, "ba_l": -70.0, "lean": 14.0},
		"strike": {"fa_u": 150.0, "fa_l": 168.0, "ba_u": 140.0, "ba_l": 160.0, "lean": -12.0, "head": -10.0},
	},
	"axe": {
		"prop": "axe",
		"windup": {"fa_u": -55.0, "fa_l": -80.0, "ba_u": -45.0, "ba_l": -70.0, "lean": 14.0},
		"strike": {"fa_u": 150.0, "fa_l": 168.0, "ba_u": 140.0, "ba_l": 160.0, "lean": -12.0, "head": -10.0},
	},
	"book": {
		"prop": "book",
		"windup": {"fa_u": 15.0, "fa_l": 160.0, "ba_u": 10.0, "ba_l": 150.0, "lean": -8.0},
		"strike": {"fa_u": 85.0, "fa_l": 92.0, "ba_u": 75.0, "ba_l": 100.0, "lean": 14.0, "hx": 3.0},
	},
	"flask": {
		"prop": "flask",
		"windup": {"fa_u": 150.0, "fa_l": 170.0, "lean": -6.0},
		"strike": {"fa_u": 92.0, "fa_l": 88.0, "lean": 12.0, "hx": 2.0},
	},
	"scroll": {
		"prop": "scroll",
		"windup": {"fa_u": 15.0, "fa_l": 160.0, "ba_u": 10.0, "ba_l": 150.0, "lean": -8.0},
		"strike": {"fa_u": 85.0, "fa_l": 92.0, "ba_u": 75.0, "ba_l": 100.0, "lean": 14.0, "hx": 3.0},
	},
	"dagger": {
		"prop": "dagger",
		"windup": {"fa_u": 25.0, "fa_l": 120.0, "lean": -4.0},
		"strike": {"fa_u": 92.0, "fa_l": 90.0, "lean": 16.0, "hx": 4.0},
	},
	"rifle": {
		"prop": "rifle",
		"windup": {"fa_u": 70.0, "fa_l": 95.0, "ba_u": 60.0, "ba_l": 100.0, "lean": -4.0},
		"strike": {"fa_u": 90.0, "fa_l": 90.0, "ba_u": 80.0, "ba_l": 95.0, "lean": 8.0, "hx": 2.0},
	},
	"pistol": {
		"prop": "pistol",
		"windup": {"fa_u": 60.0, "fa_l": 110.0, "lean": -4.0},
		"strike": {"fa_u": 90.0, "fa_l": 90.0, "lean": 6.0, "hx": 1.0},
	},
	"macana": {
		"prop": "macana",
		"windup": {"fa_u": -55.0, "fa_l": -80.0, "ba_u": -45.0, "ba_l": -70.0, "lean": 14.0},
		"strike": {"fa_u": 150.0, "fa_l": 168.0, "ba_u": 140.0, "ba_l": 160.0, "lean": -12.0, "head": -10.0},
	},
	"cast": {
		"windup": {"fa_u": 15.0, "fa_l": 160.0, "ba_u": 10.0, "ba_l": 150.0, "lean": -8.0},
		"strike": {"fa_u": 85.0, "fa_l": 92.0, "ba_u": 75.0, "ba_l": 100.0, "lean": 14.0, "hx": 3.0},
	},
	"rush": {
		"windup": {"fa_u": -30.0, "fa_l": 30.0, "lean": -8.0},
		"strike": {"fa_u": 88.0, "fa_l": 90.0, "lean": 32.0, "hx": 6.0,
			"fl_t": 45.0, "fl_s": 10.0, "bl_t": -45.0, "bl_s": -30.0},
	},
	# Agarre: los dos brazos se abren y se cierran sobre el rival.
	"grab": {
		"windup": {"fa_u": 60.0, "fa_l": 150.0, "ba_u": 55.0, "ba_l": 150.0, "lean": -4.0},
		"strike": {"fa_u": 85.0, "fa_l": 100.0, "ba_u": 80.0, "ba_l": 105.0, "lean": 12.0, "hx": 3.0},
	},
}

var data: FighterData
## Nombre de pose: idle, walk, jump, crouch, block, hit, ko, victory o una clave de POSES.
var pose_name: StringName = &"idle"
## Fase del ataque: &"startup", &"active", &"recovery".
var phase: StringName = &""
var phase_t: float = 0.0
var crouched: bool = false
var airborne: bool = false
## Altura sobre el suelo (para la sombra).
var height_above_floor: float = 0.0
var walk_dir: int = 1
## true si se desplaza hacia atrás respecto a donde mira (pose de correr en retirada).
var moving_back: bool = false
var anim_time: float = 0.0
var ko_t: float = 0.0
var flash: float = 0.0
var block_flash: float = 0.0
var draw_shadow: bool = true

var _prop: String = ""

## Dibujo FINO (todos menos el Nexo): mismo tamaño y mismas cajas de golpe, pero con contorno de medio
## píxel, luces y sombras en miembros y torso, cara con ojo detallado y adornos. FINE_IDS son los que
## tienen adornos hechos a mano (_sig_*); el resto usa los de su estilo de ropa, sombrero y barba (_*_b).
## Es solo apariencia: no toca la simulación.
const FINE_IDS: Array[StringName] = [
	&"papa_francisco", &"albert_einstein", &"rasputin", &"nikola_tesla", &"abraham_lincoln", &"napoleon",
	&"leonardo_da_vinci", &"gengis_kan", &"lautaro", &"juana_de_arco", &"cleopatra", &"alejandro_magno",
]
var _fine_on: bool = false

## Medio píxel de contorno en los finos, un píxel en el resto.
func _o() -> float:
	return 0.5 if _fine_on else 1.0

## Rectángulo con precisión de medio píxel.
func _f(x: float, y: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(x, y, w, h), _c(col))

## Línea fina (medio píxel por defecto).
func _fl(a: Vector2, b: Vector2, col: Color, w: float = 0.5) -> void:
	draw_line(a, b, _c(col), w)

func setup(p_data: FighterData) -> void:
	data = p_data
	queue_redraw()

## Altura aproximada de pies a coronilla (para encuadrar retratos).
func approx_height() -> float:
	if data == null:
		return 70.0
	var extra := 4.0
	match data.hat_style:
		&"bicorne": extra = 11.0
		&"top_hat": extra = 15.0
		&"halo": extra = 13.0
		&"clockwork": extra = 15.0
		&"plumes": extra = 18.0
		&"helmet", &"morion": extra = 10.0
		&"guan": extra = 8.0
		&"turban", &"fur_hat", &"nemes", &"crown", &"cap", &"beret": extra = 7.0
		&"tiara", &"headband": extra = 6.0
	return crown_height() + extra

## Altura de pies a coronilla sin sombrero (para encuadrar la cara en retratos pequeños).
func crown_height() -> float:
	if data == null:
		return 66.0
	return data.thigh_len + data.shin_len + data.torso_len + 2.0 + data.head_height

func flash_hit() -> void:
	flash = 1.0

func flash_block() -> void:
	block_flash = 1.0

func _process(delta: float) -> void:
	anim_time += delta
	flash = maxf(flash - delta * 6.0, 0.0)
	block_flash = maxf(block_flash - delta * 5.0, 0.0)
	if pose_name == &"ko":
		ko_t = minf(ko_t + delta * 3.0, 1.0)
	else:
		ko_t = 0.0
	queue_redraw()

# --- Utilidades -----------------------------------------------------------
static func _dir(deg: float) -> Vector2:
	var r := deg_to_rad(deg)
	return Vector2(sin(r), cos(r))

func _c(col: Color) -> Color:
	var out := col
	if block_flash > 0.0:
		out = out.lerp(Color("80c0ff"), block_flash * 0.6)
	if flash > 0.0:
		out = out.lerp(Color.WHITE, flash * 0.85)
	return out

static func _apply(p: Dictionary, over: Dictionary, t: float) -> Dictionary:
	var out := p.duplicate()
	for k in over:
		if k == "prop":
			continue
		out[k] = lerpf(float(out.get(k, 0.0)), float(over[k]), t)
	return out

func _base_pose() -> Dictionary:
	if airborne:
		return BASE_AIR
	if crouched:
		return BASE_CROUCH
	return BASE_STAND

func _style() -> Dictionary:
	return IDLE_STYLES.get(data.idle_style, {})

func _compute_pose() -> Dictionary:
	var base: Dictionary = _base_pose()
	var p: Dictionary = base.duplicate()
	_prop = ""
	match pose_name:
		&"idle", &"crouch", &"jump":
			if pose_name == &"idle":
				p.merge(_style().get("pose", {}), true)
		&"walk":
			var s := sin(anim_time * 11.0)
			p["fl_t"] = 16.0 + s * 22.0
			p["fl_s"] = 4.0 + minf(s, 0.0) * 25.0
			p["bl_t"] = -16.0 - s * 22.0
			p["bl_s"] = -8.0 + minf(-s, 0.0) * 25.0
			var st := _style()
			if st.get("walk", false):
				p.merge(st["pose"], true)
		&"run":
			# Zancada amplia y brazos bombeando; hacia atrás: pasos invertidos,
			# cuerpo erguido y guardia arriba.
			var s := sin(anim_time * 18.0)
			if moving_back:
				s = -s
				p["lean"] = -2.0
				p["fa_u"] = 55.0
				p["fa_l"] = 150.0
				p["ba_u"] = 40.0
				p["ba_l"] = 140.0
			else:
				p["lean"] = 14.0
				p["fa_u"] = 20.0 + s * 35.0
				p["fa_l"] = 100.0
				p["ba_u"] = 20.0 - s * 35.0
				p["ba_l"] = 100.0
			p["fl_t"] = 30.0 + s * 40.0
			p["fl_s"] = 10.0 + minf(s, 0.0) * 45.0
			p["bl_t"] = 30.0 - s * 40.0
			p["bl_s"] = 10.0 + minf(-s, 0.0) * 45.0
		&"block":
			p = _apply(p, POSE_BLOCK, 1.0)
		&"hit", &"ko":
			p = _apply(p, POSE_HIT, 1.0)
		&"victory":
			p = _apply(BASE_STAND, POSE_VICTORY, 1.0)
			var vst := _style()
			if vst.has("victory"):
				p.merge(vst["victory"], true)
			# Puño en alto que se agita (salvo los estilos que celebran quietos)
			if vst.get("wave", true):
				var wave := sin(anim_time * 8.0) * 10.0
				p["ba_l"] += wave
				p["ba_u"] -= wave * 0.5
		_:
			var anim: Dictionary = POSES.get(String(pose_name), POSES["jab"])
			_prop = anim.get("prop", "")
			var wind := _apply(base, anim["windup"], 1.0)
			var strike := _apply(wind, anim["strike"], 1.0)
			match phase:
				&"startup":
					if phase_t < 0.5:
						p = _apply(base, anim["windup"], phase_t * 2.0)
					else:
						p = _apply(wind, anim["strike"], (phase_t - 0.5) * 2.0)
				&"active":
					p = strike
				_:
					p = _apply(strike, base, clampf(phase_t, 0.0, 1.0))
	return p

# --- Dibujo ---------------------------------------------------------------
func _draw() -> void:
	if data == null:
		return
	var p := _compute_pose()
	_fine_on = data.id != &"el_nexo"

	# Sombra en el suelo (no rota con el cuerpo).
	if draw_shadow:
		var sw := data.torso_width + 10.0 - minf(height_above_floor * 0.1, 8.0)
		draw_set_transform(Vector2(0, height_above_floor))
		draw_rect(Rect2(-sw / 2.0, -1, sw, 3), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(-sw / 2.0 + 3, -2, sw - 6, 5), Color(0, 0, 0, 0.25))

	# Transformación raíz: KO = caer de espaldas girando sobre los pies.
	var root := Transform2D.IDENTITY
	if pose_name == &"ko":
		var ang := -deg_to_rad(84.0) * ease(ko_t, 0.5)
		root = Transform2D(ang, Vector2(-6.0 * ko_t, -4.0 * ko_t))
	var bob := 0.0
	if pose_name == &"idle" or pose_name == &"crouch" or pose_name == &"block":
		var bob_cfg: Array = _style().get("bob", [0.8, 4.0]) if pose_name == &"idle" else [0.8, 4.0]
		bob = sin(anim_time * float(bob_cfg[1])) * float(bob_cfg[0])
	if pose_name == &"victory":
		bob = -absf(roundf(sin(anim_time * 5.0) * 3.0))

	# --- Esqueleto ---
	var thigh := data.thigh_len
	var shin := data.shin_len
	var vf := cos(deg_to_rad(p["fl_t"])) * thigh + cos(deg_to_rad(p["fl_s"])) * shin
	var vb := cos(deg_to_rad(p["bl_t"])) * thigh + cos(deg_to_rad(p["bl_s"])) * shin
	var hip := Vector2(p["hx"], -maxf(maxf(vf, vb), 4.0) + bob)
	var lean_rad := deg_to_rad(p["lean"])
	var up := Vector2(sin(lean_rad), -cos(lean_rad))
	var torso_len: float = data.torso_len * float(p["tl"])
	var shoulder := hip + up * torso_len
	var neck := shoulder + up * 2.0

	var fknee := hip + _dir(p["fl_t"]) * thigh
	var ffoot := fknee + _dir(p["fl_s"]) * shin
	var bknee := hip + _dir(p["bl_t"]) * thigh
	var bfoot := bknee + _dir(p["bl_s"]) * shin
	var fsh := shoulder + Vector2(2, 1)
	var bsh := shoulder + Vector2(-3, 1)
	var felb := fsh + _dir(p["fa_u"]) * data.upper_arm_len
	var fhand := felb + _dir(p["fa_l"]) * data.forearm_len
	var belb := bsh + _dir(p["ba_u"]) * data.upper_arm_len
	var bhand := belb + _dir(p["ba_l"]) * data.forearm_len

	draw_set_transform_matrix(root)
	var dark := 0.72
	if data.cape_color.a > 0.0:
		_cape(shoulder, hip)
	# Brazo trasero
	_limb(bsh, belb, bhand, data.coat_color.darkened(0.3), data.arm_width)
	if data.jewelry == &"gauntlet":
		_gauntlet(bhand, false)
	else:
		_fist(bhand, data.skin_color.darkened(0.2))
	# Pierna trasera
	_leg(hip, bknee, bfoot, p["bl_s"], dark)
	# Pierna delantera
	_leg(hip, fknee, ffoot, p["fl_s"], 1.0)
	if data.outfit != &"none":
		draw_set_transform_matrix(root * Transform2D(-deg_to_rad((float(p["fl_t"]) + float(p["bl_t"])) * 0.5), hip))
		_skirt()
	# Torso
	draw_set_transform_matrix(root * Transform2D(lean_rad, hip))
	_torso(torso_len)
	# Cabeza
	draw_set_transform_matrix(root * Transform2D(lean_rad + deg_to_rad(p["head"]), neck))
	_head()
	# Brazo delantero y objeto
	draw_set_transform_matrix(root)
	if _prop != "":
		_draw_prop(fhand, _dir(p["fa_l"]))
	_limb(fsh, felb, fhand, data.coat_color, data.arm_width)
	if data.jewelry == &"gauntlet":
		_gauntlet(fhand, true)
	else:
		_fist(fhand, data.skin_color)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var ow := 1.0 if _fine_on else 2.0
	draw_line(a, b, _c(OUTLINE), w + ow, true)
	draw_circle(a, (w + ow) * 0.5, _c(OUTLINE))
	draw_circle(b, (w + ow) * 0.5, _c(OUTLINE))
	draw_line(a, b, _c(col), w, true)
	draw_circle(a, w * 0.5, _c(col))
	draw_circle(b, w * 0.5, _c(col))
	if _fine_on and w >= 3.0 and a.distance_to(b) > 1.0:
		# Luz arriba/delante y sombra atrás/abajo, a lo largo del miembro.
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		if absf(n.y) < 0.35:
			if n.x < 0.0:
				n = -n
		elif n.y > 0.0:
			n = -n
		draw_line(a + n * w * 0.2, b + n * w * 0.2, _c(col.lightened(0.22)), maxf(w * 0.26, 1.0))
		draw_line(a - n * w * 0.3, b - n * w * 0.3, _c(col.darkened(0.25)), maxf(w * 0.24, 1.0))

func _limb(a: Vector2, b: Vector2, c: Vector2, col: Color, w: float) -> void:
	_seg(a, b, col, w)
	_seg(b, c, col, w - 1.0)

func _fist(at: Vector2, col: Color) -> void:
	var r := Rect2((at - Vector2(2.5, 2.5)).round(), Vector2(5, 5))
	draw_rect(r.grow(_o()), _c(OUTLINE))
	draw_rect(r, _c(col))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(2, 1)), _c(col.lightened(0.25)))
	if _fine_on:
		# Nudillos y sombra del pulgar.
		for i in 3:
			_f(r.end.x - 1.5, r.position.y + 0.5 + i * 1.5, 1.0, 0.5, col.darkened(0.3))
		_f(r.position.x, r.end.y - 1.0, r.size.x, 1.0, col.darkened(0.2))

## Guantelete mecánico: la mano delantera es de oro segmentado; la trasera, una bola de energía magenta.
func _gauntlet(at: Vector2, front: bool) -> void:
	if front:
		var gold := data.jewelry_color
		var r := Rect2((at - Vector2(3.5, 3.5)).round(), Vector2(7, 7))
		draw_rect(r.grow(1), _c(OUTLINE))
		draw_rect(r, _c(gold))
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(3, 1)), _c(gold.lightened(0.4)))
		for i in 3:
			draw_rect(Rect2(r.position + Vector2(4, 1 + i * 2), Vector2(3, 1)), _c(gold.darkened(0.4)))
	else:
		var fl := sin(anim_time * 14.0)
		draw_circle(at, 5.0 + fl * 0.6, _c(Color(0.75, 0.2, 1.0, 0.3)))
		var r := Rect2((at - Vector2(2.5, 2.5)).round(), Vector2(5, 5))
		draw_rect(r.grow(1), _c(OUTLINE))
		draw_rect(r, _c(Color("7a2ad0")))
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(2, 2)), _c(Color("ff3cf0")))
		for i in 4:
			var sp := at + Vector2(cos(anim_time * 5.0 + i * 1.6), sin(anim_time * 7.0 + i * 2.1)) * 6.0
			draw_rect(Rect2(sp.round(), Vector2(1, 1)), _c(Color("ff7cff")))

func _leg(hip: Vector2, knee: Vector2, foot: Vector2, shin_deg: float, shade: float) -> void:
	var pants := data.pants_color.darkened(1.0 - shade)
	var boots := data.boots_color.darkened((1.0 - shade) * 0.5)
	_seg(hip, knee, pants, data.leg_width)
	_seg(knee, foot, boots if data.tall_boots else pants, data.leg_width - 1.0)
	# Zapato: perpendicular a la espinilla, apuntando hacia delante.
	var r := deg_to_rad(shin_deg)
	var fwd := Vector2(cos(r), -sin(r))
	_seg(foot, foot + fwd * 5.0, boots, 4.0)

func _torso(length: float) -> void:
	var w := data.torso_width
	var tail := 7.0 if data.chest_style == &"lapels" else 5.0
	var body := Rect2(-w / 2.0, -length, w, length + tail).abs()
	body.position = body.position.round()
	var top := -length
	var sw := w * 0.66 if data.female else w
	if data.female:
		_female_body(w, length, tail)
	else:
		draw_rect(body.grow(_o()), _c(OUTLINE))
		draw_rect(body, _c(data.coat_color))
		# Sombreado lateral trasero
		draw_rect(Rect2(body.position, Vector2(3, body.size.y)), _c(data.coat_color.darkened(0.25)))
		if _fine_on:
			# Luz en el borde delantero y los hombros, y pliegues horizontales.
			_f(body.end.x - 1.0, body.position.y, 1.0, body.size.y, data.coat_color.lightened(0.16))
			_f(body.position.x + 3.0, body.position.y, body.size.x - 3.0, 0.5, data.coat_color.lightened(0.22))
			for i in 3:
				_f(body.position.x + 3.0, top + length * (0.3 + 0.22 * i), body.size.x - 5.0, 0.5, data.coat_color.darkened(0.22))
	if data.chest_style == &"tie":
		# Barriga de caricatura
		var belly := Rect2(roundf(w / 2.0) - 1, roundf(top + length * 0.45), 3, roundf(length * 0.42))
		draw_rect(belly.grow(1), _c(OUTLINE))
		draw_rect(belly, _c(data.coat_color))
		# Camisa, solapas y corbata larguísima
		draw_rect(Rect2(-1, top, 7, 7), _c(data.shirt_color))
		draw_rect(Rect2(-2, top, 2, 9), _c(data.coat_color.darkened(0.35)))
		draw_rect(Rect2(6, top, 1, 9), _c(data.coat_color.darkened(0.35)))
		draw_rect(Rect2(1, top + 1, 3, 2), _c(data.accent_color.darkened(0.15)))
		draw_rect(Rect2(1, top + 3, 3, length - 2), _c(data.accent_color))
		draw_rect(Rect2(2, top + 3, 1, length - 2), _c(data.accent_color.lightened(0.2)))
		draw_rect(Rect2(1, top + length, 3, 2), _c(data.accent_color.darkened(0.2)))
		# Botones
		draw_rect(Rect2(-1, top + length * 0.6, 1, 1), _c(OUTLINE))
		draw_rect(Rect2(-1, top + length * 0.8, 1, 1), _c(OUTLINE))
	elif data.chest_style == &"lapels":
		# Chaleco blanco, cuello rojo y botones dorados
		draw_rect(Rect2(-1, top + 3, 7, length - 1), _c(data.shirt_color))
		draw_rect(Rect2(-1, top + 3, 1, length - 1), _c(data.shirt_color.darkened(0.2)))
		draw_rect(Rect2(-w / 2.0, top - 2, w, 4).abs(), _c(data.accent_color))
		for i in 4:
			draw_rect(Rect2(6, top + 5 + i * 5, 1, 1), _c(data.coat_trim_color))
		# Cinturón
		draw_rect(Rect2(-w / 2.0, -3, w, 2).abs(), _c(data.shirt_color.darkened(0.1)))
	elif data.chest_style == &"robe":
		# Túnica: cuello y franja central dorados, cinto de color.
		draw_rect(Rect2(-w / 2.0, top, w, 2).abs(), _c(data.coat_trim_color))
		draw_rect(Rect2(1, top + 2, 2, length - 1), _c(data.coat_trim_color))
		draw_rect(Rect2(-sw / 2.0, -6, sw, 2).abs(), _c(data.accent_color))
	elif data.chest_style == &"clockwork":
		# Armadura del Nexo: cuello y franja dorados, vetas de energía y un ojo dorado dentro de un engranaje.
		var gold := data.coat_trim_color
		var glow := Color("ff3cf0")
		draw_rect(Rect2(-w / 2.0, top, w, 2).abs(), _c(gold))
		draw_rect(Rect2(-w / 2.0, top + 2, 3, 2).abs(), _c(glow))
		draw_rect(Rect2(w / 2.0 - 3, top + 2, 3, 2).abs(), _c(glow))
		draw_rect(Rect2(-w / 2.0 + 1, top + 4, 1, length * 0.5), _c(glow.darkened(0.4)))
		var ec := Vector2(1, top + length * 0.45)
		draw_circle(ec, 7.0, _c(OUTLINE))
		draw_circle(ec, 6.0, _c(gold.darkened(0.25)))
		for i in 8:
			var a := i * TAU / 8.0 + anim_time * 0.6
			var tp := ec + Vector2(cos(a), sin(a)) * 6.0
			draw_rect(Rect2((tp - Vector2(1, 1)).round(), Vector2(2, 2)), _c(gold))
		draw_circle(ec, 4.5, _c(gold))
		draw_circle(ec, 3.2, _c(Color("2a1248")))
		draw_circle(ec, 2.4, _c(Color("ff9a20")))
		draw_rect(Rect2(ec.x - 0.5, ec.y - 1.5, 1, 3), _c(OUTLINE))
		# Cinturón dorado con hebilla
		draw_rect(Rect2(-w / 2.0, -6, w, 2).abs(), _c(gold))
		draw_rect(Rect2(0, -7, 3, 4), _c(gold.lightened(0.25)))
	elif data.chest_style == &"polo":
		# Polo de rayas por fuera del pantalón, cuello abierto y barriga.
		var belly := Rect2(roundf(w / 2.0) - 1, roundf(top + length * 0.4), 4, roundf(length * 0.55))
		draw_rect(belly.grow(1), _c(OUTLINE))
		draw_rect(belly, _c(data.coat_color))
		var y := top + 4.0
		while y < tail - 1.0:
			draw_rect(Rect2(body.position.x + 3, y, body.size.x - 3, 1), _c(data.accent_color))
			draw_rect(Rect2(belly.position.x, y, belly.size.x, 1), _c(data.accent_color))
			y += 4.0
		draw_rect(Rect2(-w / 2.0, top - 1, w, 2).abs(), _c(data.shirt_color))
		draw_rect(Rect2(2, top - 1, 5, 2), _c(data.shirt_color.darkened(0.15)))
		draw_rect(Rect2(3, top + 1, 3, 4), _c(data.skin_color.darkened(0.1)))
		draw_rect(Rect2(4, top + 5, 1, 1), _c(OUTLINE))
	elif data.chest_style == &"mao":
		# Traje estilo Mao: cuello alto cerrado, botonadura central y cuatro bolsillos.
		draw_rect(Rect2(-w / 2.0 + 2, top - 2, w - 2, 3).abs(), _c(data.coat_color.lightened(0.12)))
		for i in 5:
			draw_rect(Rect2(3, top + 3 + i * 4.5, 1, 1), _c(data.coat_trim_color))
		for pocket in [Rect2(-5, top + 5, 6, 4), Rect2(5, top + 5, 4, 4), Rect2(-5, top + length - 9, 6, 5), Rect2(5, top + length - 9, 4, 5)]:
			draw_rect(pocket, _c(data.coat_color.darkened(0.2)))
			draw_rect(Rect2(pocket.position, Vector2(pocket.size.x, 1)), _c(data.coat_color.lightened(0.1)))
	elif data.chest_style == &"uniform":
		# Guerrera militar: cuello, botonadura, bolsillo y cinturón.
		draw_rect(Rect2(-w / 2.0, top - 1, w, 3).abs(), _c(data.accent_color))
		for i in 4:
			draw_rect(Rect2(5, top + 4 + i * 5, 1, 1), _c(data.coat_trim_color))
		draw_rect(Rect2(-5, top + 7, 4, 4), _c(data.coat_color.darkened(0.2)))
		draw_rect(Rect2(-w / 2.0, -3, w, 2).abs(), _c(OUTLINE))
	else:
		# Camisa o jersey sencillo con cuello.
		draw_rect(Rect2(-1, top, 7, 4), _c(data.shirt_color))
		draw_rect(Rect2(-w / 2.0, -3, w, 1).abs(), _c(data.coat_color.darkened(0.25)))
	match data.jewelry:
		&"necklace":
			var xs: Array[float] = [-3.0, -1.0, 1.0, 3.0, 5.0]
			var ys: Array[float] = [1.0, 2.0, 3.0, 2.0, 1.0]
			for i in 5:
				draw_rect(Rect2(xs[i], top + ys[i], 2, 2), _c(OUTLINE))
				draw_rect(Rect2(xs[i], top + ys[i], 1, 1), _c(data.jewelry_color))
		&"sash":
			# Banda presidencial cruzada del hombro delantero a la cadera trasera (azul, blanco y rojo).
			var a := Vector2(roundf(w / 2.0) - 1, top + 1)
			var b := Vector2(-roundf(w / 2.0) + 3, -9)
			draw_line(a + Vector2(0, 2), b + Vector2(0, 2), _c(OUTLINE), 7.0)
			var cols: Array[Color] = [Color("2a4ab0"), Color("f0f0f0"), Color("d02828")]
			for i in 3:
				draw_line(a + Vector2(0, i * 2.0), b + Vector2(0, i * 2.0), _c(cols[i]), 2.0)
		&"pin":
			# Insignia en la solapa (izquierda del pecho, visible por delante).
			draw_rect(Rect2(-5, top + 4, 5, 5), _c(OUTLINE))
			draw_rect(Rect2(-4, top + 5, 3, 3), _c(data.jewelry_color))
			draw_rect(Rect2(-3, top + 6, 1, 1), _c(Color("f0d040")))
		&"cross":
			draw_rect(Rect2(3, top + 2, 3, 9), _c(OUTLINE))
			draw_rect(Rect2(1, top + 4, 7, 3), _c(OUTLINE))
			draw_rect(Rect2(4, top + 3, 1, 7), _c(data.jewelry_color))
			draw_rect(Rect2(2, top + 5, 5, 1), _c(data.jewelry_color))
	if data.has_epaulettes:
		var ep := Rect2(roundf(w / 2.0) - 6, top - 3, 8, 3)
		draw_rect(ep.grow(1), _c(OUTLINE))
		draw_rect(ep, _c(data.coat_trim_color))
		for i in 4:
			draw_rect(Rect2(ep.position.x + i * 2, top, 1, 3), _c(data.coat_trim_color.darkened(0.2)))
		var ep2 := Rect2(-roundf(w / 2.0) - 2, top - 2, 6, 3)
		draw_rect(ep2, _c(data.coat_trim_color.darkened(0.3)))
	if _fine_on:
		_sig_torso(w, top, length)

func _head() -> void:
	var hw := data.head_width
	var hh := data.head_height
	# Cuello
	draw_rect(Rect2(-3, -2, 6, 3), _c(data.skin_color.darkened(0.15)))
	var head := Rect2(roundf(-hw / 2.0), -hh, hw, hh)
	draw_rect(head.grow(_o()), _c(OUTLINE))
	draw_rect(head, _c(data.skin_color))
	var fx := head.end.x
	# Mandíbula / mejilla
	draw_rect(Rect2(fx - 4, -4, 3, 3), _c(data.skin_color.darkened(0.08)))
	# Oreja
	draw_rect(Rect2(head.position.x + 2, -hh * 0.6, 2, 3), _c(data.skin_color.darkened(0.2)))
	# Ojo, ceja, nariz y boca
	if data.eye_shape == &"almond":
		# Ojo rasgado: más estrecho y alargado, con el párpado superior marcado.
		draw_rect(Rect2(fx - 5, roundf(-hh * 0.62) + 1, 3, 1), _c(Color.WHITE))
		draw_rect(Rect2(fx - 3, roundf(-hh * 0.62) + 1, 1, 1), _c(OUTLINE))
		draw_rect(Rect2(fx - 5, roundf(-hh * 0.62), 4, 1), _c(OUTLINE))
	else:
		draw_rect(Rect2(fx - 4, roundf(-hh * 0.62), 2, 2), _c(Color.WHITE))
		draw_rect(Rect2(fx - 3, roundf(-hh * 0.62), 1, 2), _c(OUTLINE))
	draw_rect(Rect2(fx - 5, roundf(-hh * 0.62) - 2, 4, 1), _c(data.hair_color.darkened(0.2)))
	draw_rect(Rect2(fx, roundf(-hh * 0.55), 2, 3), _c(data.skin_color.darkened(0.1)))
	var eye_y := roundf(-hh * 0.62)
	if data.chest_style == &"tie":
		draw_rect(Rect2(fx - 3, roundf(-hh * 0.27), 2, 2), _c(Color("a04040")))
	elif data.female:
		# Labios pintados, pestañas y rubor.
		draw_rect(Rect2(fx - 4, roundf(-hh * 0.27), 3, 2), _c(Color("c82850")))
		draw_rect(Rect2(fx - 4, roundf(-hh * 0.27), 3, 1), _c(Color("e8587a")))
		draw_rect(Rect2(fx - 5, eye_y - 1, 4, 1), _c(OUTLINE))
		draw_rect(Rect2(fx - 1, eye_y - 2, 1, 1), _c(OUTLINE))
		draw_rect(Rect2(fx - 6, roundf(-hh * 0.4), 3, 1), _c(Color("f08090").lerp(data.skin_color, 0.4)))
	else:
		draw_rect(Rect2(fx - 4, roundf(-hh * 0.27), 3, 1), _c(OUTLINE))
	if _fine_on:
		_fine_face(head, fx, hh, eye_y)
	match data.glasses:
		&"round":
			draw_rect(Rect2(fx - 6, eye_y - 2, 6, 5), _c(OUTLINE), false, 1.0)
			draw_line(Vector2(head.position.x + 3, eye_y), Vector2(fx - 6, eye_y), _c(OUTLINE), 1.0)
		&"thick":
			# Marco grueso y negro de pasta, con cristal claro y patilla hasta la oreja.
			draw_rect(Rect2(fx - 7, eye_y - 3, 8, 6), _c(OUTLINE))
			draw_rect(Rect2(fx - 6, eye_y - 1, 6, 3), _c(Color("d8e8f0")))
			draw_rect(Rect2(fx - 4, eye_y, 2, 2), _c(Color.WHITE))
			draw_rect(Rect2(fx - 3, eye_y, 1, 2), _c(OUTLINE))
			draw_rect(Rect2(head.position.x + 3, eye_y - 2, fx - 10 - head.position.x, 2), _c(OUTLINE))
		&"dark":
			draw_rect(Rect2(fx - 6, eye_y - 1, 7, 4), _c(OUTLINE))
			draw_rect(Rect2(fx - 5, eye_y, 2, 1), _c(Color("7090c0")))
			draw_line(Vector2(head.position.x + 3, eye_y), Vector2(fx - 6, eye_y), _c(OUTLINE), 1.0)
	if data.glasses == &"visor":
		# Casco liso y oscuro con ranura de ojo magenta brillante.
		var metal := Color("1c1226")
		draw_rect(head, _c(metal))
		draw_rect(Rect2(head.position.x, head.position.y, hw, 1), _c(Color("5a2a9a")))
		draw_rect(Rect2(head.position.x + 1, head.position.y + 1, 2, hh - 2), _c(Color("2e1a48")))
		draw_rect(Rect2(fx - 2, head.position.y + 2, 1, hh - 4), _c(Color("3a2260")))
		draw_rect(Rect2(fx - 8, eye_y - 1, 8, 4), _c(OUTLINE))
		draw_rect(Rect2(fx - 7, eye_y, 6, 2), _c(Color("ff3cf0")))
		draw_rect(Rect2(fx - 5, eye_y, 2, 1), _c(Color("ffd0ff")))
		draw_rect(Rect2(head.position.x + 2, head.position.y + 3, 2, 1), _c(data.accent_color))
	match data.jewelry:
		&"earplug":
			draw_circle(Vector2(head.position.x + 3, -hh * 0.45 + 2), 3.6, _c(OUTLINE))
			draw_circle(Vector2(head.position.x + 3, -hh * 0.45 + 2), 2.7, _c(data.jewelry_color))
			draw_circle(Vector2(head.position.x + 3, -hh * 0.45 + 2), 1.0, _c(data.jewelry_color.darkened(0.35)))
		&"necklace":
			if data.female:
				draw_rect(Rect2(head.position.x + 1, -hh * 0.5 + 3, 3, 3), _c(OUTLINE))
				draw_rect(Rect2(head.position.x + 2, -hh * 0.5 + 3, 2, 2), _c(data.jewelry_color))
	# Vello facial (se dibuja sobre la cara y bajo el pelo y el sombrero).
	var beard := _c(data.hair_color)
	var mouth_y := roundf(-hh * 0.4)
	match data.beard_style:
		&"mustache":
			draw_rect(Rect2(fx - 5, mouth_y, 6, 2), beard)
		&"brush":
			# Bigote tupido y recortado.
			draw_rect(Rect2(fx - 6, mouth_y - 1, 7, 3), beard)
			draw_rect(Rect2(fx - 5, mouth_y - 1, 5, 1), _c(data.hair_color.lightened(0.2)))
		&"stubble":
			# Barba de pocos días en mandíbula y mentón, y bigote grueso que baja por las comisuras.
			var shadow := _c(data.skin_color.lerp(data.hair_color, 0.22))
			draw_rect(Rect2(head.position.x + 3, mouth_y + 1, hw - 4, roundf(hh * 0.4) - 1), shadow)
			draw_rect(Rect2(fx - 7, mouth_y - 1, 8, 3), beard)
			draw_rect(Rect2(fx - 7, mouth_y + 2, 2, 2), beard)
			draw_rect(Rect2(fx - 6, mouth_y - 1, 6, 1), _c(data.hair_color.lightened(0.15)))
		&"toothbrush":
			draw_rect(Rect2(fx - 4, mouth_y, 3, 2), beard)
		&"goatee":
			draw_rect(Rect2(fx - 5, mouth_y, 6, 2), beard)
			draw_rect(Rect2(fx - 4, roundf(-hh * 0.2), 3, 4), beard)
		&"chin":
			draw_rect(Rect2(head.position.x + 3, -4, hw - 4, 4), beard)
			draw_rect(Rect2(fx - 3, -3, 4, 6), beard)
		&"full", &"long":
			draw_rect(Rect2(head.position.x + 2, mouth_y, hw - 1, roundf(hh * 0.4) + 3), beard)
			draw_rect(Rect2(fx - 5, mouth_y - 1, 6, 2), beard.lightened(0.15))
			if data.beard_style == &"long":
				draw_rect(Rect2(fx - 8, 0, 8, 10), beard)
				draw_rect(Rect2(fx - 6, 8, 4, 3), beard.darkened(0.2))
	match data.hair_style:
		&"swoop":
			var top := Rect2(head.position.x - 2, -hh - 4, hw + 6, 6)
			draw_rect(top.grow(1), _c(OUTLINE))
			draw_rect(top, _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 2, -hh + 2, 5, roundf(hh * 0.45)), _c(data.hair_color))
			draw_rect(Rect2(fx + 1, -hh - 2, 3, 3), _c(data.hair_color))
			draw_rect(Rect2(head.position.x, -hh - 3, hw + 2, 1), _c(data.hair_color.lightened(0.35)))
			draw_rect(Rect2(head.position.x + 3, -hh - 1, hw - 1, 1), _c(data.hair_color.darkened(0.15)))
		&"short":
			draw_rect(Rect2(head.position.x - 1, -hh - 2, hw + 1, 4), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 1, -hh, 3, roundf(hh * 0.4)), _c(data.hair_color))
			draw_rect(Rect2(fx - 4, -hh + 2, 2, 3), _c(data.hair_color))
		&"long":
			draw_rect(Rect2(head.position.x - 2, -hh - 2, hw + 1, 4), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 3, -hh, 6, hh + 7), _c(data.hair_color))
			draw_rect(Rect2(fx - 4, -hh + 2, 2, 3), _c(data.hair_color))
		&"wild":
			draw_rect(Rect2(head.position.x - 4, -hh - 4, hw + 7, 7), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 4, -hh, 6, 9), _c(data.hair_color))
			draw_rect(Rect2(fx - 3, -hh - 6, 4, 3), _c(data.hair_color.lightened(0.2)))
			draw_rect(Rect2(head.position.x + 1, -hh - 7, 4, 3), _c(data.hair_color.lightened(0.2)))
		&"bun":
			draw_rect(Rect2(head.position.x - 1, -hh - 2, hw + 1, 4), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 1, -hh, 3, roundf(hh * 0.4)), _c(data.hair_color))
			draw_circle(Vector2(head.position.x + 1, -hh - 4), 3.0, _c(data.hair_color))
		&"bob":
			# Media melena a la altura de la barbilla con flequillo.
			draw_rect(Rect2(head.position.x - 2, -hh - 2, hw + 3, 4), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 3, -hh, 6, hh + 1), _c(data.hair_color.darkened(0.1)))
			draw_rect(Rect2(fx - 4, -hh + 1, 4, 3), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 1, -hh - 2, hw, 1), _c(data.hair_color.lightened(0.3)))
		&"braids":
			# Trenzas largas que cuelgan por la espalda.
			draw_rect(Rect2(head.position.x - 2, -hh - 2, hw + 1, 4), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 3, -hh, 5, hh), _c(data.hair_color))
			for i in 5:
				var bx := head.position.x - 5.0 + (i % 2) * 2.0
				draw_rect(Rect2(bx, 1.0 + i * 3.0, 4, 3), _c(OUTLINE))
				draw_rect(Rect2(bx + 1, 1.0 + i * 3.0, 3, 2), _c(data.hair_color.lightened(0.15) if i % 2 == 0 else data.hair_color))
			draw_rect(Rect2(head.position.x - 5, 16, 4, 2), _c(data.coat_trim_color))
		&"updo":
			# Recogido alto con rizos sobre la frente.
			draw_rect(Rect2(head.position.x - 1, -hh - 2, hw + 1, 4), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 1, -hh, 3, roundf(hh * 0.4)), _c(data.hair_color))
			draw_circle(Vector2(head.position.x + hw * 0.4, -hh - 5), 5.0, _c(OUTLINE))
			draw_circle(Vector2(head.position.x + hw * 0.4, -hh - 5), 4.0, _c(data.hair_color))
			draw_rect(Rect2(fx - 4, -hh, 2, 3), _c(data.hair_color.lightened(0.2)))
			draw_rect(Rect2(fx - 2, -hh + 1, 2, 3), _c(data.hair_color))
		&"ponytail":
			draw_rect(Rect2(head.position.x - 1, -hh - 2, hw + 1, 4), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 1, -hh, 3, roundf(hh * 0.4)), _c(data.hair_color))
			for i in 4:
				draw_rect(Rect2(head.position.x - 6.0 - i * 0.5, -hh + 2.0 + i * 3.0, 5, 4), _c(data.hair_color))
		&"wig":
			# Peluca del siglo XVII: raya al medio y bucles que caen hasta los hombros.
			draw_rect(Rect2(head.position.x - 2, -hh - 3, hw + 3, 5), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 1, -hh - 3, hw + 1, 1), _c(data.hair_color.lightened(0.25)))
			for i in 4:
				var lx := head.position.x - 4.0 + (i % 2) * 2.0
				draw_rect(Rect2(lx, -hh + i * 4.0, 7, 5), _c(OUTLINE))
				draw_rect(Rect2(lx + 1, -hh + 1 + i * 4.0, 5, 3), _c(data.hair_color if i % 2 == 0 else data.hair_color.darkened(0.12)))
			draw_rect(Rect2(fx - 3, -hh + 1, 3, 5), _c(data.hair_color))
			draw_rect(Rect2(fx - 3, -hh + 6, 2, 3), _c(data.hair_color.darkened(0.12)))
		&"undercut":
			# Laterales rapados (sombra azulada) y copete alto y plano peinado hacia atrás.
			var shaved := _c(data.skin_color.lerp(data.hair_color, 0.22))
			draw_rect(Rect2(head.position.x, -hh + 1, 5, roundf(hh * 0.45)), shaved)
			draw_rect(Rect2(head.position.x + 1, -hh - 1, hw, 2), shaved)
			var top := Rect2(head.position.x + 1, -hh - 5, hw + 1, 5)
			draw_rect(top.grow(1), _c(OUTLINE))
			draw_rect(top, _c(data.hair_color))
			draw_rect(Rect2(top.position.x + 2, top.position.y, hw - 3, 1), _c(data.hair_color.lightened(0.3)))
			draw_rect(Rect2(fx - 3, -hh - 1, 3, 2), _c(data.hair_color))
		&"sidepart":
			# Pelo abundante con raya al lado, peinado hacia atrás y sienes cubiertas.
			var hc := _c(data.hair_color)
			var mass := Rect2(head.position.x - 2, -hh - 4, hw + 3, 6)
			draw_rect(mass.grow(1), _c(OUTLINE))
			draw_rect(mass, hc)
			draw_rect(Rect2(head.position.x - 2, -hh + 1, 5, roundf(hh * 0.45)), hc)
			draw_rect(Rect2(fx - 3, -hh + 1, 3, 2), hc)
			draw_rect(Rect2(head.position.x + 1, -hh - 3, hw - 6, 1), _c(data.hair_color.lightened(0.35)))
			draw_rect(Rect2(fx - 5, -hh - 4, 1, 2), _c(data.hair_color.lightened(0.6)))
		&"mop":
			# Melena de rizos abultada: bucles por arriba, la nuca y el flequillo.
			var hc := _c(data.hair_color)
			var hl := _c(data.hair_color.lightened(0.35))
			var top_curls: Array[Vector2] = []
			for i in 5:
				top_curls.append(Vector2(head.position.x - 1.0 + i * (hw + 2.0) / 4.0, -hh - 3.0 - (i % 2)))
			var back_curls: Array[Vector2] = []
			for i in 3:
				back_curls.append(Vector2(head.position.x - 2.0, -hh + 2.0 + i * 3.5))
			# Contorno de toda la masa de pelo y después el relleno, para que se lea como una melena.
			for c in top_curls:
				draw_circle(c, 3.6, _c(OUTLINE))
			for c in back_curls:
				draw_circle(c, 3.1, _c(OUTLINE))
			draw_rect(Rect2(head.position.x - 3, -hh - 3, hw + 5, 5), hc)
			draw_rect(Rect2(head.position.x - 4, -hh, 6, roundf(hh * 0.7)), hc)
			for c in top_curls:
				draw_circle(c, 2.8, hc)
				draw_arc(c, 1.6, PI, PI * 1.6, 4, hl, 1.0)
			for c in back_curls:
				draw_circle(c, 2.3, hc)
				draw_rect(Rect2(c.x - 1, c.y - 1, 1, 1), hl)
			draw_rect(Rect2(fx - 5, -hh, 4, 3), hc)
			draw_rect(Rect2(fx - 3, -hh + 2, 2, 2), hc)
		&"curls":
			draw_rect(Rect2(head.position.x - 2, -hh - 3, hw + 4, 5), _c(data.hair_color))
			draw_rect(Rect2(head.position.x - 2, -hh, 4, 8), _c(data.hair_color))
			for i in 4:
				draw_rect(Rect2(head.position.x - 2 + i * 4, -hh - 4, 3, 2), _c(data.hair_color.lightened(0.15)))
	if _fine_on:
		_sig_head(head, fx, hw, hh)
	var hat := _c(data.hat_color)
	var trim := _c(data.coat_trim_color)
	match data.hat_style:
		&"top_hat":
			_orect(Rect2(-hw / 2.0 - 4, -hh - 1, hw + 8, 3), hat)
			_orect(Rect2(-hw / 2.0, -hh - 15, hw, 15), hat)
			draw_rect(Rect2(-hw / 2.0, -hh - 4, hw, 2), _c(data.accent_color))
		&"crown":
			_orect(Rect2(-hw / 2.0 - 1, -hh - 3, hw + 2, 4), hat)
			for i in 3:
				_orect(Rect2(-hw / 2.0 + i * 5, -hh - 6, 3, 4), hat)
			draw_rect(Rect2(-hw / 2.0 + 5, -hh - 2, 2, 2), _c(Color("d02030")))
		&"nemes":
			_orect(Rect2(-hw / 2.0 - 3, -hh - 4, hw + 6, 6), hat)
			_orect(Rect2(-hw / 2.0 - 3, -hh, 5, hh + 5), hat)
			draw_rect(Rect2(-hw / 2.0 - 3, -hh - 1, hw + 6, 1), trim)
			draw_rect(Rect2(-hw / 2.0 - 2, -hh + 4, 3, 1), trim)
			draw_rect(Rect2(fx - 1, -hh - 5, 3, 4), trim)
		&"tiara":
			_orect(Rect2(-hw / 2.0, -hh - 2, hw, 3), hat)
			for i in 3:
				_orect(Rect2(-hw / 2.0 + 1 + i * 4, -hh - 4 - (1 if i == 1 else 0), 2, 3), hat)
			draw_rect(Rect2(-1, -hh - 2, 2, 2), _c(Color("d02030")))
		&"headband":
			# Cinta en la frente (trarilonko).
			draw_rect(Rect2(-hw / 2.0 - 2, -hh + 1, hw + 3, 4), _c(OUTLINE))
			draw_rect(Rect2(-hw / 2.0 - 1, -hh + 2, hw + 2, 2), hat)
			draw_rect(Rect2(-hw / 2.0 - 1, -hh + 2, hw + 2, 1), hat.lightened(0.3))
			for i in 4:
				draw_rect(Rect2(-hw / 2.0 + i * 3, -hh + 3, 1, 1), trim)
		&"cap":
			_orect(Rect2(-hw / 2.0 - 1, -hh - 5, hw + 3, 6), hat)
			draw_rect(Rect2(fx - 1, -hh, 7, 2), _c(OUTLINE))
			draw_rect(Rect2(-hw / 2.0 - 1, -hh - 1, hw + 3, 1), trim)
			draw_rect(Rect2(fx - 3, -hh - 3, 2, 2), _c(data.accent_color))
		&"beret":
			_orect(Rect2(-hw / 2.0 - 3, -hh - 4, hw + 6, 5), hat)
			draw_rect(Rect2(-1, -hh - 6, 2, 2), hat)
		&"turban":
			_orect(Rect2(-hw / 2.0 - 2, -hh - 7, hw + 5, 9), hat)
			for i in 3:
				draw_rect(Rect2(-hw / 2.0 - 2, -hh - 5 + i * 3, hw + 5, 1), hat.darkened(0.2))
		&"fur_hat":
			_orect(Rect2(-hw / 2.0 - 2, -hh - 5, hw + 5, 7), hat)
			_orect(Rect2(-hw / 2.0 - 2, -hh, 4, 7), hat)
			draw_rect(Rect2(-1, -hh - 8, 3, 4), hat)
			draw_rect(Rect2(-hw / 2.0 - 1, -hh - 4, hw + 3, 1), hat.lightened(0.25))
		&"laurel":
			draw_rect(Rect2(-hw / 2.0 - 1, -hh - 1, hw + 3, 2), hat)
			for i in 4:
				draw_rect(Rect2(-hw / 2.0 - 1 + i * 4, -hh - 3, 2, 2), hat.lightened(0.2))
		&"helmet":
			_orect(Rect2(-hw / 2.0 - 1, -hh - 5, hw + 3, 7), hat)
			_orect(Rect2(-hw / 2.0 - 1, -hh, 4, hh * 0.7), hat)
			_orect(Rect2(-hw / 2.0, -hh - 10, hw + 1, 5), _c(data.accent_color))
			draw_rect(Rect2(-hw / 2.0 - 1, -hh - 2, hw + 3, 1), trim)
		&"plumes":
			# Penacho mexica: abanico de plumas de quetzal sobre una diadema de oro.
			for i in 7:
				var ang := deg_to_rad(-150.0 + i * 20.0)
				var root := Vector2(0, -hh - 1)
				var tip := root + Vector2(cos(ang), sin(ang)) * (15.0 if i % 2 == 0 else 12.0)
				draw_line(root, tip, _c(OUTLINE), 5.0)
				draw_line(root, tip, hat if i % 2 == 0 else hat.lightened(0.2), 3.0)
				draw_rect(Rect2(tip - Vector2(1, 1), Vector2(2, 2)), _c(data.accent_color))
			_orect(Rect2(-hw / 2.0 - 1, -hh - 3, hw + 2, 4), trim)
			for i in 3:
				draw_rect(Rect2(-hw / 2.0 + 1 + i * 4, -hh - 2, 2, 2), _c(data.accent_color))
		&"guan":
			# Gorro de letrado chino: copa alta y estrecha sujeta con una aguja.
			_orect(Rect2(-hw / 2.0, -hh - 2, hw, 3), hat)
			_orect(Rect2(-3, -hh - 9, 7, 8), hat)
			draw_rect(Rect2(-hw / 2.0 - 3, -hh - 6, hw + 6, 1), _c(OUTLINE))
			draw_rect(Rect2(-hw / 2.0 - 2, -hh - 6, hw + 4, 1), trim)
		&"morion":
			# Morrión español: casco con cresta alta y ala curvada en punta.
			var crest := PackedVector2Array([Vector2(-5, -hh - 4), Vector2(0, -hh - 12), Vector2(5, -hh - 4)])
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -hh - 3), Vector2(0, -hh - 13), Vector2(6, -hh - 3)]), _c(OUTLINE))
			draw_colored_polygon(crest, hat)
			_orect(Rect2(-hw / 2.0, -hh - 5, hw, 5), hat)
			var brim := PackedVector2Array([Vector2(-hw / 2.0 - 6, -hh - 4), Vector2(hw / 2.0 + 6, -hh - 4),
				Vector2(hw / 2.0 + 2, -hh), Vector2(-hw / 2.0 - 2, -hh)])
			draw_colored_polygon(brim, hat.darkened(0.15))
			draw_line(brim[0], brim[1], _c(OUTLINE), 1.0)
			draw_rect(Rect2(-1, -hh - 9, 2, 5), hat.lightened(0.3))
			draw_rect(Rect2(-hw / 2.0 - 4, -hh - 5, 3, 2), _c(data.accent_color))
		&"zucchetto":
			_orect(Rect2(-hw / 2.0 + 1, -hh - 2, hw - 1, 4), hat)
		&"clockwork":
			# Corona de pinchos dorados, engranaje detrás de la cabeza y dos relojes de arena flotando.
			var cc := Vector2(0, -hh + 3.0)
			var gr := 11.0
			draw_arc(cc, gr, PI, TAU, 24, _c(OUTLINE), 5.0)
			draw_arc(cc, gr, PI, TAU, 24, hat, 3.0)
			for i in 7:
				var ga := PI + i * PI / 6.0 + sin(anim_time * 0.8) * 0.05
				var gp := cc + Vector2(cos(ga), sin(ga)) * (gr + 2.5)
				_orect(Rect2((gp - Vector2(1.5, 1.5)).round(), Vector2(3, 3)), hat)
			_orect(Rect2(-hw / 2.0 - 1, -hh - 2, hw + 2, 3), hat)
			var spike_h := [3.0, 5.0, 8.0, 5.0, 3.0]
			for i in 5:
				var sx := -hw / 2.0 + i * (hw - 1.0) / 4.0
				_orect(Rect2(roundf(sx) - 1, -hh - 2 - spike_h[i], 2, spike_h[i]), hat.lightened(0.1))
			draw_rect(Rect2(-1, -hh - 1, 2, 1), _c(Color("ff3cf0")))
			for side in [-1.0, 1.0]:
				var hc := Vector2(side * (gr + 7.0), -hh - 3.0 + sin(anim_time * 2.0 + side) * 1.5).round()
				draw_rect(Rect2(hc + Vector2(-4, -7), Vector2(8, 3)), _c(OUTLINE))
				draw_rect(Rect2(hc + Vector2(-4, 4), Vector2(8, 3)), _c(OUTLINE))
				draw_rect(Rect2(hc + Vector2(-3, -6), Vector2(6, 1)), hat)
				draw_rect(Rect2(hc + Vector2(-3, 5), Vector2(6, 1)), hat)
				draw_colored_polygon(PackedVector2Array([hc + Vector2(-3, -5), hc + Vector2(3, -5), hc]), _c(Color("bfe8ff")))
				draw_colored_polygon(PackedVector2Array([hc, hc + Vector2(-3, 5), hc + Vector2(3, 5)]), hat.lightened(0.15))
		&"halo":
			draw_arc(Vector2(0, -hh - 6), 6.0, 0.0, TAU, 20, _c(OUTLINE), 4.0)
			draw_arc(Vector2(0, -hh - 6), 6.0, 0.0, TAU, 20, hat, 2.0)
	if data.hat_style == &"bicorne":
		var pts := PackedVector2Array([
			Vector2(-hw / 2.0 - 8, -hh + 1), Vector2(hw / 2.0 + 8, -hh + 1),
			Vector2(hw / 2.0 + 5, -hh - 6), Vector2(1, -hh - 11), Vector2(-hw / 2.0 - 5, -hh - 6),
		])
		var outline := PackedVector2Array()
		for v in pts:
			outline.append(v + v.normalized() * 1.2 + Vector2(0, 0))
		draw_colored_polygon(outline, _c(OUTLINE))
		draw_colored_polygon(pts, _c(data.hat_color))
		draw_rect(Rect2(-hw / 2.0 - 7, -hh, hw + 14, 1), _c(data.coat_trim_color.darkened(0.2)))
		# Escarapela tricolor
		draw_circle(Vector2(2, -hh - 5), 3.0, _c(Color("d02030")))
		draw_circle(Vector2(2, -hh - 5), 2.0, _c(Color.WHITE))
		draw_circle(Vector2(2, -hh - 5), 1.0, _c(Color("2040a0")))
	if _fine_on:
		_sig_hat(hw, hh, fx)

func _draw_prop(hand: Vector2, along: Vector2) -> void:
	match _prop:
		"megaphone":
			var perp := Vector2(-along.y, along.x)
			var a := hand + along * 1.0
			var b := hand + along * 11.0
			var pts := PackedVector2Array([a + perp * 2, b + perp * 5, b - perp * 5, a - perp * 2])
			draw_colored_polygon(pts, _c(Color("e8e8e8")))
			draw_line(b + perp * 5, b - perp * 5, _c(Color("c02020")), 2.0)
		"golf_club":
			var tip := hand + along * 22.0
			draw_line(hand.round(), tip.round(), _c(Color("d0d0d8")), 2.0)
			draw_rect(Rect2((tip - Vector2(2, 2)).round(), Vector2(5, 3)), _c(Color("707080")))
		"sword":
			var tip := hand + along * 22.0
			draw_line(hand.round(), tip.round(), _c(Color("e0e8f0")), 2.0)
			var perp := Vector2(-along.y, along.x)
			draw_line((hand + perp * 3).round(), (hand - perp * 3).round(), _c(Color("e0b040")), 2.0)
		"staff":
			var tip := hand + along * 26.0
			var tail := hand - along * 8.0
			draw_line(tail.round(), tip.round(), _c(OUTLINE), 4.0)
			draw_line(tail.round(), tip.round(), _c(Color("8a5a2a")), 2.0)
			draw_rect(Rect2((tip - Vector2(2, 2)).round(), Vector2(5, 5)), _c(Color("e0b040")))
		"axe":
			var perp := Vector2(-along.y, along.x)
			var tip := hand + along * 24.0
			draw_line((hand - along * 4.0).round(), tip.round(), _c(OUTLINE), 4.0)
			draw_line((hand - along * 4.0).round(), tip.round(), _c(Color("8a5a2a")), 2.0)
			var blade := PackedVector2Array([tip - along * 8.0 + perp * 1.0, tip + perp * 10.0 + along * 2.0,
				tip + perp * 8.0 - along * 10.0, tip - along * 8.0 - perp * 1.0])
			draw_colored_polygon(blade, _c(Color("c8ccd8")))
			draw_polyline(PackedVector2Array([blade[1], blade[2]]), _c(Color.WHITE), 1.0)
		"book":
			var c := hand + along * 6.0
			draw_rect(Rect2((c - Vector2(5, 4)).round(), Vector2(10, 8)), _c(OUTLINE))
			draw_rect(Rect2((c - Vector2(4, 3)).round(), Vector2(8, 6)), _c(Color("a03030")))
			draw_rect(Rect2((c - Vector2(3, 2)).round(), Vector2(6, 1)), _c(Color("e8d8a0")))
		"flask":
			var c := hand + along * 5.0
			draw_circle(c.round(), 4.0, _c(OUTLINE))
			draw_circle(c.round(), 3.0, _c(Color("60e070")))
			draw_rect(Rect2((c + Vector2(-1, -7)).round(), Vector2(3, 4)), _c(Color("d0e0e8")))
		"scroll":
			# Pergamino desenrollado con sus dos rodillos.
			var perp := Vector2(-along.y, along.x)
			var a := hand + along * 2.0
			var b := hand + along * 12.0
			draw_colored_polygon(PackedVector2Array([a + perp * 5, b + perp * 5, b - perp * 5, a - perp * 5]), _c(Color("efe2b8")))
			draw_line((a + perp * 3).round(), (b + perp * 3).round(), _c(Color("8a7a50")), 1.0)
			draw_line((a - perp * 1).round(), (b - perp * 1).round(), _c(Color("8a7a50")), 1.0)
			for e in [a, b]:
				draw_line((e + perp * 6).round(), (e - perp * 6).round(), _c(OUTLINE), 4.0)
				draw_line((e + perp * 6).round(), (e - perp * 6).round(), _c(Color("8a5a2a")), 2.0)
		"dagger":
			var tip := hand + along * 13.0
			draw_line(hand.round(), tip.round(), _c(OUTLINE), 3.0)
			draw_line(hand.round(), tip.round(), _c(Color("e0e8f0")), 1.0)
			var perp := Vector2(-along.y, along.x)
			draw_line((hand + perp * 2.5).round(), (hand - perp * 2.5).round(), _c(Color("c09030")), 2.0)
		"rifle":
			# Fusil de francotirador con mira telescópica.
			var perp := Vector2(-along.y, along.x)
			var tip := hand + along * 26.0
			var butt := hand - along * 9.0
			draw_line(butt.round(), tip.round(), _c(OUTLINE), 4.0)
			draw_line(butt.round(), (hand + along * 8.0).round(), _c(Color("7a4a24")), 2.0)
			draw_line((hand + along * 8.0).round(), tip.round(), _c(Color("3a3a40")), 2.0)
			var s0 := hand + along * 2.0 - perp * 3.0
			draw_line(s0.round(), (s0 + along * 9.0).round(), _c(OUTLINE), 3.0)
			draw_line(s0.round(), (s0 + along * 9.0).round(), _c(Color("2a2a30")), 1.0)
		"pistol":
			var perp := Vector2(-along.y, along.x)
			var tip := hand + along * 8.0
			draw_line(hand.round(), tip.round(), _c(OUTLINE), 4.0)
			draw_line(hand.round(), tip.round(), _c(Color("4a4a54")), 2.0)
			draw_line(hand.round(), (hand + perp * 4.0).round(), _c(Color("5a3a22")), 2.0)
		"macana":
			# Macuahuitl: maza de madera con filos de obsidiana a los dos lados.
			var perp := Vector2(-along.y, along.x)
			var tip := hand + along * 22.0
			draw_line((hand - along * 3.0).round(), tip.round(), _c(OUTLINE), 6.0)
			draw_line((hand - along * 3.0).round(), tip.round(), _c(Color("8a5a2a")), 4.0)
			for i in 4:
				var p := hand + along * (8.0 + i * 4.0)
				for s in [-1.0, 1.0]:
					draw_rect(Rect2((p + perp * 3.0 * s - Vector2(1, 1)).round(), Vector2(2, 2)), _c(Color("2a2a3a")))

func _orect(r: Rect2, col: Color) -> void:
	draw_rect(r.grow(_o()), _c(OUTLINE))
	draw_rect(r, col)

# --- Dibujo fino (solo los luchadores de FINE_IDS) ----------------------------------
## Cara con precisión de medio píxel: ojo con párpado, iris y brillo, nariz con luz y sombra, boca y mejilla.
func _fine_face(head: Rect2, fx: float, hh: float, eye_y: float) -> void:
	var sk := data.skin_color
	# Borra el ojo grueso del dibujo clásico y lo rehace más fino.
	_f(fx - 5.0, eye_y - 0.5, 4.5, 2.5, sk)
	_f(fx - 4.5, eye_y, 3.0, 1.5, Color.WHITE)
	_f(fx - 3.0, eye_y, 1.5, 1.5, Color("3a2a22"))
	_f(fx - 2.5, eye_y, 0.5, 0.5, Color.WHITE)
	_f(fx - 4.5, eye_y - 0.5, 3.5, 0.5, OUTLINE)
	_f(fx - 4.5, eye_y + 1.5, 3.0, 0.5, sk.darkened(0.25))
	# Nariz: luz arriba y sombra debajo.
	var ny := roundf(-hh * 0.55)
	_f(fx, ny, 1.0, 0.5, sk.lightened(0.2))
	_f(fx, ny + 2.5, 2.0, 0.5, sk.darkened(0.3))
	# Boca: labio inferior y comisura.
	var my := roundf(-hh * 0.27)
	_f(fx - 3.5, my + 1.0, 2.0, 0.5, sk.darkened(0.12))
	_f(fx - 4.5, my - 0.5, 0.5, 0.5, sk.darkened(0.3))
	# Mejilla, pómulo y sombra bajo la frente.
	_f(fx - 5.0, roundf(-hh * 0.45) + 1.0, 2.5, 1.0, sk.lerp(Color("e08070"), 0.16))
	_f(fx - 6.0, roundf(-hh * 0.62) + 2.5, 1.5, 0.5, sk.lightened(0.15))
	_f(head.position.x, head.position.y, head.size.x, 1.0, sk.darkened(0.1))

## Adornos del torso propios de cada luchador fino. x: -w/2 (espalda) .. w/2 (frente); y: top (hombros) .. 0 (cadera).
func _sig_torso(w: float, top: float, length: float) -> void:
	if not FINE_IDS.has(data.id):
		_sig_torso_b(w, top, length)
		return
	var gold := data.coat_trim_color
	var coat := data.coat_color
	match data.id:
		&"papa_francisco":
			# Sotana: botones, pliegues, fajín blanco con flecos.
			for i in 6:
				_f(0.5, top + 3.0 + i * (length - 4.0) / 6.0, 1.0, 0.5, Color("c8c8d0"))
			_fl(Vector2(-4, top + 4), Vector2(-4.5, 4), coat.darkened(0.1))
			_fl(Vector2(4, top + 4), Vector2(4.5, 4), coat.darkened(0.1))
			_f(-w / 2.0, -6.0, w, 1.5, Color("ffffff"))
			_f(-w / 2.0, -4.5, w, 0.5, Color("c8c8d0"))
			_f(w / 2.0 - 2.5, -4.5, 1.0, 3.0, Color("e8e8f0"))
			_f(w / 2.0 - 1.0, -4.5, 0.5, 2.5, Color("c8c8d0"))
		&"albert_einstein":
			# Chaqueta de punto: escote en V, botones, bolsillo y puños acanalados.
			var sh := data.shirt_color
			draw_colored_polygon(PackedVector2Array([Vector2(-1, top), Vector2(5, top), Vector2(2, top + 8)]), _c(sh))
			_fl(Vector2(-1, top), Vector2(2, top + 8), coat.darkened(0.3))
			_fl(Vector2(5, top), Vector2(2, top + 8), coat.darkened(0.3))
			for i in 3:
				_f(2.0, top + 10.0 + i * 4.0, 1.0, 1.0, coat.darkened(0.4))
			_f(-6.0, top + 10.0, 4.0, 4.0, coat.darkened(0.15))
			_f(-6.0, top + 10.0, 4.0, 0.5, coat.lightened(0.2))
			_f(-5.0, top + 7.0, 0.5, 4.0, Color("3a5aa0"))
			for i in int(w / 2.0):
				_f(-w / 2.0 + 1.0 + i * 2.0, -2.0, 0.5, 3.0, coat.darkened(0.3))
		&"rasputin":
			# Túnica oscura: cinto rojo con borlas, bordado dorado y pliegues largos.
			_f(-w / 2.0, -7.0, w, 2.0, data.accent_color)
			_f(-w / 2.0, -7.0, w, 0.5, data.accent_color.lightened(0.3))
			_f(w / 2.0 - 3.0, -5.0, 1.0, 6.0, data.accent_color.darkened(0.1))
			_f(w / 2.0 - 3.5, 1.0, 2.0, 1.0, gold)
			_f(-w / 2.0, top, w, 0.5, gold)
			for i in 3:
				_fl(Vector2(-3.0 + i * 3.0, top + 5), Vector2(-3.5 + i * 3.0, -8), coat.lightened(0.1))
			_fl(Vector2(1, top + 1), Vector2(1, top + 8), gold.darkened(0.2), 1.0)
		&"nikola_tesla":
			# Chaleco con botones, corbatín azul, cadena de reloj y solapas con luz.
			draw_colored_polygon(PackedVector2Array([Vector2(-1, top), Vector2(5, top), Vector2(2, top + 9)]), _c(data.shirt_color))
			_fl(Vector2(-1, top + 1), Vector2(2, top + 9), coat.lightened(0.22))
			_fl(Vector2(5, top + 1), Vector2(2, top + 9), coat.lightened(0.22))
			_f(0.0, top + 1.0, 4.0, 1.5, data.accent_color)
			_f(1.5, top + 0.5, 1.0, 2.5, data.accent_color.darkened(0.3))
			for i in 3:
				_f(2.0, top + 10.0 + i * 3.5, 1.0, 1.0, gold)
			_fl(Vector2(-4, top + 11), Vector2(2, top + 12), Color("d8c060"))
			draw_circle(Vector2(-4, top + 11.5), 1.2, _c(Color("d8c060")))
		&"abraham_lincoln":
			# Levita: pajarita, cuello blanco, solapas y cadena.
			_f(1.0, top, 3.0, 6.0, Color("f4f4f4"))
			_f(0.5, top + 1.0, 4.0, 1.5, Color("141418"))
			_f(2.0, top + 0.5, 1.0, 2.5, Color("000000"))
			_fl(Vector2(-1, top + 2), Vector2(2, top + 14), coat.lightened(0.2))
			_fl(Vector2(5, top + 2), Vector2(2, top + 14), coat.lightened(0.2))
			for i in 3:
				_f(2.0, top + 8.0 + i * 3.5, 1.0, 1.0, Color("3a3a40"))
			_fl(Vector2(-4, top + 9), Vector2(1, top + 10), Color("b8a040"))
		&"napoleon":
			# Condecoraciones: banda roja cruzada, cruz con cinta y cordón dorado.
			_fl(Vector2(w / 2.0 - 2.0, top + 1.0), Vector2(-w / 2.0 + 3.0, -4.0), Color("a02030"), 2.0)
			_fl(Vector2(w / 2.0 - 2.0, top + 1.0), Vector2(-w / 2.0 + 3.0, -4.0), Color("d04050"), 0.5)
			_f(-5.0, top + 4.0, 1.5, 3.0, Color("c02030"))
			draw_circle(Vector2(-4.2, top + 8.0), 1.6, _c(gold))
			_f(-4.7, top + 7.5, 1.0, 1.0, gold.lightened(0.5))
			_fl(Vector2(-1, top + 2), Vector2(-5, top + 12), gold, 0.5)
		&"leonardo_da_vinci":
			# Túnica: cuello con cordones, cinto de cuero con bolsa y bordes.
			for i in 3:
				_fl(Vector2(-1, top + 2.0 + i * 2.0), Vector2(3, top + 3.0 + i * 2.0), Color("e8d8b0"))
				_fl(Vector2(3, top + 2.0 + i * 2.0), Vector2(-1, top + 3.0 + i * 2.0), Color("e8d8b0"))
			_f(-w / 2.0, -7.0, w, 1.5, Color("6a4a2a"))
			_f(0.0, -8.0, 3.0, 3.5, gold.darkened(0.1))
			_f(-5.0, -5.5, 4.0, 4.0, Color("5a3a22"))
			_f(-5.0, -5.5, 4.0, 0.5, Color("8a6a3a"))
			_f(-w / 2.0, top + 1.0, 0.5, length, coat.darkened(0.3))
			_f(-w / 2.0 + 1.0, top + 7.0, w - 2.0, 0.5, coat.lightened(0.15))
		&"gengis_kan":
			# Coraza de láminas, cuello de piel, cinto con placa y correas.
			for i in 5:
				_f(-w / 2.0 + 1.0, top + 3.0 + i * 3.5, w - 2.0, 0.5, coat.darkened(0.35))
				for j in int(w / 3.0):
					_f(-w / 2.0 + 2.0 + j * 3.0, top + 3.5 + i * 3.5, 0.5, 3.0, coat.darkened(0.2))
			_f(-w / 2.0 - 1.0, top - 1.0, w + 2.0, 2.5, data.hat_color.lightened(0.15))
			for i in int(w / 2.0):
				_f(-w / 2.0 - 0.5 + i * 2.0, top + 1.5, 1.0, 1.0, data.hat_color.lightened(0.3))
			_f(-w / 2.0, -6.0, w, 2.0, Color("3a2a1a"))
			_f(0.0, -6.5, 3.0, 3.0, gold)
			_f(1.0, -5.5, 1.0, 1.0, Color("a02020"))
			_fl(Vector2(w / 2.0 - 2.0, top + 1.0), Vector2(-w / 2.0 + 2.0, -6.0), Color("3a2a1a"), 1.5)
		&"lautaro":
			# Pintura de guerra, collar de cuentas y cinto tejido con grecas.
			for i in 2:
				_fl(Vector2(-4.0 + i * 3.0, top + 3.0), Vector2(-1.0 + i * 3.0, top + 9.0), Color("c02828"), 1.0)
			for i in 5:
				_f(-3.0 + i * 2.0, top + 1.0 + (1.0 if i % 2 == 0 else 0.0) + (1.0 if i == 2 else 0.0), 1.0, 1.0, Color("e8e0d0") if i % 2 == 0 else Color("c02828"))
			_f(-w / 2.0, -5.0, w, 3.0, Color("f0e8d8"))
			for i in int(w / 2.0):
				_f(-w / 2.0 + i * 2.0, -5.0 + (i % 2) * 1.5, 1.0, 1.5, Color("c02828"))
			_f(-w / 2.0, -5.5, w, 0.5, Color("141418"))
			_f(-w / 2.0, top + 1.0, 0.5, length - 2.0, coat.lightened(0.2))
		&"juana_de_arco":
			# Sobreveste azul con flor de lis dorada, gorjal y cinturón.
			var steel := data.coat_color
			_f(-w * 0.33, top - 1.0, w * 0.66, 2.5, steel.lightened(0.25))
			_f(-w * 0.33, top + 0.5, w * 0.66, 0.5, steel.darkened(0.3))
			_f(1.0, top + 5.0, 1.0, 6.0, gold)
			_f(-0.5, top + 7.0, 4.0, 1.0, gold)
			_f(0.0, top + 5.0, 0.5, 2.5, gold)
			_f(2.5, top + 5.0, 0.5, 2.5, gold)
			_f(-w * 0.33, -3.0, w * 0.66, 1.5, Color("3a2a1a"))
			_f(0.5, -3.5, 2.0, 2.5, gold)
			_fl(Vector2(-3, top + 2), Vector2(-3, -4), steel.lightened(0.3))
		&"cleopatra":
			# Collar usekh de cuentas (azul, oro, rojo), plisado del vestido y cinto dorado.
			var cols: Array[Color] = [Color("2a6ac0"), gold, Color("c02030")]
			for r in 3:
				for k in 7:
					var a := deg_to_rad(20.0 + k * 23.0)
					var q := Vector2(1.0 + cos(a) * (3.0 + r * 1.8), top + 0.5 + sin(a) * (2.5 + r * 1.5))
					_f(q.x, q.y, 1.0, 1.0, cols[(k + r) % 3])
			for i in int(w / 3.0):
				_f(-w / 2.0 + 2.0 + i * 3.0, top + 8.0, 0.5, length - 6.0, Color("d8d8c8"))
			_f(-w * 0.33, -6.0, w * 0.66, 1.5, gold)
			_f(0.5, -6.5, 2.0, 2.5, Color("2a6ac0"))
		&"alejandro_magno":
			# Coraza anatómica: pectorales y abdominales, medallón de Gorgona y pteryges de cuero.
			_fl(Vector2(-3, top + 3), Vector2(1, top + 5), gold.darkened(0.3))
			_fl(Vector2(1, top + 5), Vector2(5, top + 3), gold.darkened(0.3))
			for i in 3:
				_f(-2.0, top + 9.0 + i * 3.0, 6.0, 0.5, gold.darkened(0.3))
			_f(1.0, top + 6.0, 0.5, 11.0, gold.darkened(0.25))
			draw_circle(Vector2(1.0, top + 4.5), 2.2, _c(Color("e0c040")))
			draw_circle(Vector2(1.0, top + 4.5), 1.0, _c(Color("7a2a2a")))
			for i in int(w / 3.0) + 1:
				_f(-w / 2.0 + i * 3.0, -2.0, 2.5, 4.0, Color("b08a3a"))
				_f(-w / 2.0 + i * 3.0, 1.5, 2.5, 0.5, gold)

## Adornos de la cabeza (pelo, barba, marcas de la cara) de cada luchador fino. Se dibujan antes del sombrero.
func _sig_head(head: Rect2, fx: float, hw: float, hh: float) -> void:
	if not FINE_IDS.has(data.id):
		_sig_head_b(head, fx, hw, hh)
		return
	var hair := data.hair_color
	var mouth_y := roundf(-hh * 0.4)
	var eye_y := roundf(-hh * 0.62)
	match data.id:
		&"papa_francisco":
			_fl(Vector2(fx - 5.0, -hh + 2.5), Vector2(fx - 1.0, -hh + 2.5), data.skin_color.darkened(0.15))
			_f(head.position.x - 0.5, -hh * 0.4, 1.0, 2.5, hair)
			_f(head.position.x + 0.5, -hh * 0.55, 0.5, 2.0, hair.darkened(0.15))
		&"albert_einstein":
			# Pelo imposible: mechones que salen en todas direcciones y cejas pobladas.
			for i in 9:
				var ang := deg_to_rad(-175.0 + i * 19.0)
				var root_p := Vector2(0, -hh)
				var tip := root_p + Vector2(cos(ang), sin(ang)) * (7.0 + (i % 3) * 1.5)
				_fl(root_p, tip, hair.darkened(0.12) if i % 2 == 0 else hair, 1.0)
				_fl(root_p + Vector2(0, -1), tip + Vector2(0.5, -0.5), Color.WHITE, 0.5)
			_f(fx - 5.5, eye_y - 2.0, 4.5, 1.0, hair)
			_f(fx - 6.0, mouth_y - 0.5, 1.5, 2.5, hair)
		&"rasputin":
			# Barba larga en mechones y mirada hipnótica.
			for i in 6:
				_fl(Vector2(fx - 8.0 + i * 1.6, 1.0), Vector2(fx - 8.5 + i * 1.6 + (i % 2), 10.5), hair.lightened(0.28))
			_f(fx - 3.5, eye_y + 0.25, 1.0, 1.0, Color("a0c8ff"))
			_f(fx - 5.5, eye_y - 2.0, 4.0, 1.0, hair)
			_fl(Vector2(head.position.x - 2, -hh + 2), Vector2(head.position.x - 3, 8), hair.lightened(0.18))
		&"nikola_tesla":
			# Bigote con las puntas hacia arriba y brillo en el pelo.
			_f(fx + 0.5, mouth_y - 1.0, 1.0, 2.0, hair)
			_f(fx - 6.0, mouth_y - 1.0, 1.0, 2.0, hair)
			_fl(Vector2(head.position.x, -hh - 1.5), Vector2(fx - 2.0, -hh - 1.5), hair.lightened(0.35))
		&"abraham_lincoln":
			# Lunar en la mejilla y mechones de la barba.
			_f(fx - 3.5, -hh * 0.35, 1.0, 1.0, Color("6a4a30"))
			for i in 4:
				_fl(Vector2(fx - 6.0 + i * 1.8, -3.0), Vector2(fx - 6.0 + i * 1.8, 2.0 + (i % 2) * 2.0), hair.lightened(0.2))
			_f(fx - 5.5, eye_y - 2.0, 4.5, 1.0, hair)
		&"napoleon":
			# Mechón sobre la frente y patilla.
			_f(fx - 4.0, -hh + 0.5, 3.0, 1.5, hair)
			_f(head.position.x, -hh * 0.55, 1.5, 3.0, hair)
			_fl(Vector2(fx - 4.0, -hh + 2.0), Vector2(fx - 1.0, -hh + 2.5), hair.lightened(0.2))
		&"leonardo_da_vinci":
			# Barba y melena onduladas.
			for i in 6:
				_fl(Vector2(fx - 8.0 + i * 1.5, 0.0), Vector2(fx - 8.0 + i * 1.5 + (1.0 if i % 2 == 0 else -1.0), 8.0), hair.lightened(0.3))
			for i in 3:
				_fl(Vector2(head.position.x - 2.5 + (i % 2), -hh + 1.0 + i * 3.0), Vector2(head.position.x - 3.0, -hh + 4.0 + i * 3.0), hair.lightened(0.25))
			_f(fx - 5.5, eye_y - 2.0, 4.5, 1.0, hair.darkened(0.1))
		&"gengis_kan":
			# Trenza colgando por la espalda y bigote caído.
			for i in 7:
				_f(head.position.x - 3.0 + (i % 2) * 0.5, -hh + 3.0 + i * 1.8, 1.5, 1.0, hair.lightened(0.15) if i % 2 == 0 else hair)
			_f(fx - 6.0, mouth_y, 0.5, 3.0, hair)
			_f(fx - 1.0, mouth_y, 0.5, 3.0, hair)
		&"lautaro":
			# Pintura roja en la mejilla y mechones largos.
			_f(fx - 6.0, -hh * 0.3, 4.0, 0.5, Color("c02828"))
			_f(fx - 6.5, -hh * 0.3 + 1.5, 4.0, 0.5, Color("c02828"))
			for i in 4:
				_fl(Vector2(head.position.x - 2.0 + (i % 2), -hh + 1.0), Vector2(head.position.x - 3.0 - (i % 2), 6.0 + i), hair.lightened(0.25))
		&"juana_de_arco":
			# Reflejos del pelo corto y flequillo.
			_fl(Vector2(head.position.x - 1.0, -hh - 1.5), Vector2(fx - 1.0, -hh - 1.5), hair.lightened(0.4))
			_fl(Vector2(fx - 5.0, -hh + 2.0), Vector2(fx - 2.0, -hh + 3.5), hair.lightened(0.25))
			_f(fx - 6.0, -hh * 0.4 + 0.5, 3.0, 1.0, Color("f08090").lerp(data.skin_color, 0.5))
		&"cleopatra":
			# Delineado egipcio con ala, sombra azul y flequillo recto.
			_f(fx - 5.0, eye_y - 1.5, 3.5, 0.5, Color("2a6ac0"))
			_f(fx - 1.5, eye_y + 0.5, 2.5, 0.5, OUTLINE)
			_f(fx + 0.5, eye_y, 1.0, 0.5, OUTLINE)
			_fl(Vector2(head.position.x - 1.0, -hh + 1.0), Vector2(fx - 1.0, -hh + 1.0), hair.lightened(0.3))
		&"alejandro_magno":
			# Rizos con reflejos y barbilla firme.
			for i in 5:
				_f(head.position.x + i * 2.5, -hh - 1.5 + (i % 2) * 1.0, 1.5, 0.5, hair.lightened(0.4))
			_f(fx - 5.5, eye_y - 2.0, 4.5, 1.0, hair.darkened(0.1))
			_f(fx - 3.0, -2.0, 3.0, 0.5, data.skin_color.darkened(0.15))

## Detalles de los sombreros de los luchadores finos (luces, texturas, plumas).
func _sig_hat(hw: float, hh: float, fx: float) -> void:
	if not FINE_IDS.has(data.id):
		_sig_hat_b(hw, hh, fx)
		return
	var hat := data.hat_color
	var gold := data.coat_trim_color
	match data.id:
		&"papa_francisco":
			_f(-hw / 2.0 + 1.5, -hh - 1.5, hw - 3.0, 0.5, Color("ffffff"))
			_f(-hw / 2.0 + 1.0, -hh + 1.0, hw - 1.0, 0.5, Color("c8c8d0"))
		&"abraham_lincoln":
			_f(hw / 2.0 - 3.0, -hh - 14.0, 1.0, 11.0, hat.lightened(0.3))
			_f(-hw / 2.0 + 1.0, -hh - 14.0, 0.5, 9.0, hat.lightened(0.12))
			_f(-hw / 2.0 - 3.5, -hh + 1.5, hw + 7.0, 0.5, hat.lightened(0.25))
			_f(-hw / 2.0, -hh - 3.5, hw, 0.5, Color("000000"))
		&"napoleon":
			_fl(Vector2(-hw / 2.0 - 5.0, -hh - 5.5), Vector2(1.0, -hh - 10.5), gold, 0.5)
			_fl(Vector2(hw / 2.0 + 5.0, -hh - 5.5), Vector2(1.0, -hh - 10.5), gold, 0.5)
			_fl(Vector2(-hw / 2.0 - 4.0, -hh - 1.5), Vector2(hw / 2.0 + 4.0, -hh - 1.5), hat.lightened(0.25))
		&"leonardo_da_vinci":
			# Boina con pliegues y una pluma.
			_fl(Vector2(-hw / 2.0, -hh - 3.0), Vector2(0, -hh - 1.0), hat.darkened(0.3))
			_fl(Vector2(hw / 2.0 - 1.0, -hh - 3.0), Vector2(hw / 2.0 + 5.0, -hh - 8.5), Color("f0e8d0"), 1.0)
			for i in 4:
				_fl(Vector2(hw / 2.0 + 0.5 + i * 1.3, -hh - 4.0 - i * 1.3), Vector2(hw / 2.0 + 2.5 + i * 1.3, -hh - 3.0 - i * 1.3), Color("d8c8a0"))
			_f(-hw / 2.0 - 2.0, -hh - 3.5, hw + 3.0, 0.5, hat.lightened(0.25))
		&"gengis_kan":
			# Gorro de piel: mechones en el borde y adorno dorado.
			for i in 8:
				_f(-hw / 2.0 - 1.5 + i * 2.0, -hh - 6.5 + (i % 2) * 0.5, 1.0, 2.0, hat.lightened(0.28))
			_f(-hw / 2.0 - 1.0, -hh + 0.5, 0.5, 6.0, hat.lightened(0.2))
			_f(fx - 3.0, -hh - 3.0, 2.0, 2.0, gold)
			_f(fx - 2.5, -hh - 2.5, 1.0, 1.0, Color("c02020"))
		&"lautaro":
			# Nudo de la cinta con colas que cuelgan.
			_f(-hw / 2.0 - 2.5, -hh + 2.0, 1.5, 5.0, hat)
			_f(-hw / 2.0 - 3.0, -hh + 5.0, 1.0, 3.0, hat.darkened(0.2))
			_f(-hw / 2.0 - 1.5, -hh + 2.0, 0.5, 5.0, hat.lightened(0.25))
		&"cleopatra":
			# Rayas del nemes en azul y oro, y la cobra real al frente.
			for i in 5:
				_f(-hw / 2.0 - 3.0, -hh + 1.0 + i * 2.0, 5.0, 0.5, gold if i % 2 == 0 else Color("8ab0f0"))
			_f(fx - 1.0, -hh - 7.0, 2.0, 3.0, gold)
			_f(fx - 1.5, -hh - 8.0, 3.0, 1.5, gold.lightened(0.2))
			_f(fx - 0.5, -hh - 7.5, 0.5, 0.5, Color("c02030"))
		&"alejandro_magno":
			# Crin del casco cayendo hacia atrás y remaches del carrillo.
			for i in 6:
				_fl(Vector2(-hw / 2.0 + i * 2.0, -hh - 10.0), Vector2(-hw / 2.0 - 3.0 + i * 1.5, -hh - 4.0 + i * 0.8), Color("c02828") if i % 2 == 0 else Color("e05050"), 0.75)
			_f(-hw / 2.0, -hh + 3.0, 0.5, 0.5, gold.lightened(0.4))
			_f(-hw / 2.0, -hh + 5.0, 0.5, 0.5, gold.lightened(0.4))
			_fl(Vector2(-hw / 2.0 - 1.0, -hh - 1.5), Vector2(hw / 2.0 + 2.0, -hh - 1.5), gold.lightened(0.3))

## Torso de los demás luchadores: detalle de base según el estilo de ropa y rasgos propios por personaje.
func _sig_torso_b(w: float, top: float, length: float) -> void:
	var gold := data.coat_trim_color
	var coat := data.coat_color
	var acc := data.accent_color
	match data.chest_style:
		&"tie":
			_fl(Vector2(-1, top + 1), Vector2(2, top + 10), coat.lightened(0.2))
			_fl(Vector2(5, top + 1), Vector2(2, top + 10), coat.lightened(0.2))
			_f(2.0, top + 3.0, 0.5, length - 3.0, acc.lightened(0.35))
			_f(1.0, top + 2.0, 3.0, 1.0, acc.darkened(0.2))
			_f(-5.0, top + 9.0, 2.5, 1.0, Color("f4f4f4"))
			_f(0.0, top + length * 0.75, 1.0, 1.0, coat.darkened(0.4))
		&"uniform":
			_f(-5.0, top + 7.0, 4.0, 0.5, coat.lightened(0.25))
			_f(2.0, top + 7.0, 4.0, 0.5, coat.lightened(0.25))
			_f(-w / 2.0, -3.0, w, 0.5, gold)
			_f(0.0, -3.5, 2.5, 2.0, gold)
			_fl(Vector2(w / 2.0 - 2.0, top + 1.0), Vector2(-w / 2.0 + 2.0, -3.0), coat.darkened(0.35), 1.0)
			_f(-w / 2.0, top + 1.0, 0.5, length - 3.0, coat.lightened(0.1))
		&"robe":
			_fl(Vector2(-4, top + 3), Vector2(-4.5, -2), coat.darkened(0.15))
			_fl(Vector2(4, top + 3), Vector2(4.5, -2), coat.lightened(0.12))
			_f(-w / 2.0, -1.0, w, 0.5, gold)
			_fl(Vector2(w / 2.0 - 2.0, top + 1.0), Vector2(-w / 2.0 + 3.0, -4.0), coat.darkened(0.12))
		&"plain":
			_fl(Vector2(1, top + 4), Vector2(1, -3), coat.darkened(0.25))
			_f(-1.0, top, 7.0, 1.0, data.shirt_color)
			for i in 3:
				_f(1.5, top + 6.0 + i * 4.0, 1.0, 1.0, coat.darkened(0.4))
		&"lapels":
			_f(0.0, top + 1.0, 4.0, 3.0, Color("f4f4f4"))
			_fl(Vector2(0.5, top + 2), Vector2(3.5, top + 2), Color("c8c8d0"))
			_fl(Vector2(0.5, top + 3), Vector2(3.5, top + 3), Color("c8c8d0"))
			for i in 5:
				_f(5.5, top + 5.0 + i * 3.5, 1.0, 1.0, gold)
			_f(-w / 2.0, -2.0, w, 0.5, coat.lightened(0.2))
		&"mao":
			_fl(Vector2(3, top + 2), Vector2(3, -6), coat.darkened(0.3))
			_f(-5.0, top + 5.5, 6.0, 0.5, coat.lightened(0.2))
			_f(5.0, top + 5.5, 4.0, 0.5, coat.lightened(0.2))
		&"polo":
			_f(3.0, top + 1.0, 0.5, 4.0, data.shirt_color.darkened(0.3))
			_fl(Vector2(-3, top + 6), Vector2(-3, 1), coat.darkened(0.25))
	match data.id:
		&"donald_trump":
			# Corbata larga y roja con brillo, y pin de la bandera en la solapa.
			_f(2.0, top + length * 0.55, 1.0, 3.0, acc.lightened(0.3))
			_f(-5.0, top + 4.0, 2.0, 1.5, Color("c02030"))
			_f(-5.0, top + 5.5, 2.0, 0.5, Color("2a3a8a"))
		&"kim_jong_un":
			_f(-w / 2.0 + 2.0, top - 2.0, w - 2.0, 0.5, coat.lightened(0.35))
		&"vladimir_putin", &"xi_jinping", &"salvador_allende":
			_f(-w / 2.0, -3.0, w, 0.5, Color("141418"))
		&"nicolas_maduro":
			# Chándal tricolor: franjas amarilla, azul y roja, y cremallera.
			_f(-w / 2.0, top + 8.0, w, 1.0, Color("f0d020"))
			_f(-w / 2.0, top + 9.0, w, 1.0, Color("2a4ab0"))
			_f(-w / 2.0, top + 10.0, w, 1.0, Color("d02020"))
			_fl(Vector2(1, top), Vector2(1, -3), Color("c8c8d0"))
		&"adolf_hitler", &"joseph_stalin", &"benito_mussolini", &"saddam_hussein", &"augusto_pinochet", &"fidel_castro":
			for i in 3:
				_f(-5.0 + i * 2.0, top + 3.0, 1.5, 2.0, [Color("d02020"), gold, Color("2a4ab0")][i])
		&"osama_bin_laden":
			_f(-5.0, top + 6.0, 5.0, 5.0, acc.darkened(0.1))
			_f(-5.0, top + 6.0, 5.0, 0.5, acc.lightened(0.25))
			_f(2.0, top + 6.0, 4.0, 4.0, acc.darkened(0.1))
		&"julio_cesar":
			_fl(Vector2(w / 2.0 - 1.0, top), Vector2(-w / 2.0 + 2.0, -3.0), acc, 1.5)
			_fl(Vector2(w / 2.0 - 1.0, top + 2.0), Vector2(-w / 2.0 + 2.0, -1.0), coat.darkened(0.12), 1.0)
		&"isabel_ii":
			_fl(Vector2(w / 2.0 - 2.0, top + 1.0), Vector2(-w / 2.0 + 3.0, -4.0), Color("2a4ab0"), 1.5)
			_f(-4.0, top + 5.0, 2.0, 2.0, Color("c02040"))
			_f(-3.5, top + 5.0, 0.5, 0.5, Color.WHITE)
		&"jesus_de_nazaret":
			_fl(Vector2(w / 2.0 - 2.0, top), Vector2(-w / 2.0 + 2.0, -4.0), acc, 2.0)
			_f(-w / 2.0, -5.0, w, 1.0, Color("c8a870"))
		&"buda":
			_f(w / 2.0 - 4.0, top, 4.0, 5.0, data.skin_color)
			_fl(Vector2(w / 2.0 - 4.0, top + 5.0), Vector2(-w / 2.0 + 2.0, -3.0), coat.darkened(0.2), 1.0)
		&"marie_curie":
			_f(-3.0, top, 7.0, 2.0, Color.WHITE)
			_f(-1.0, top + 3.0, 2.0, 1.5, Color("c8c8d0"))
		&"galileo_galilei", &"nicolas_maquiavelo":
			_f(-w / 2.0, top, w, 2.0, gold)
			_fl(Vector2(-1, top + 2), Vector2(3, top + 8), acc, 1.0)
			_fl(Vector2(5, top + 2), Vector2(3, top + 8), acc, 1.0)
		&"charles_darwin":
			_f(0.0, top + 1.0, 4.0, 2.0, Color("f0e8d0"))
			_fl(Vector2(-4, top + 9), Vector2(2, top + 10), Color("b8a040"))
		&"cristobal_colon":
			for i in 4:
				_f(-3.0 + i * 2.5, top + 3.0, 1.0, 1.0, gold)
		&"janequeo":
			for i in int(w / 2.0):
				_f(-w / 2.0 + i * 2.0, -4.0 + (i % 2) * 1.5, 1.0, 1.5, Color("c0c4cc"))
		&"pachacutec":
			for i in 3:
				for j in 3:
					_f(-3.0 + i * 3.0, top + 4.0 + j * 3.0, 2.0, 2.0, gold if (i + j) % 2 == 0 else acc)
		&"moctezuma_ii":
			draw_circle(Vector2(1.0, top + 5.0), 3.0, _c(gold))
			draw_circle(Vector2(1.0, top + 5.0), 1.5, _c(acc))
			_f(-w / 2.0 - 1.0, top - 1.0, w + 2.0, 2.0, data.hat_color)
		&"ivan_el_terrible":
			for i in 5:
				_f(1.0, top + 3.0 + i * 3.0, 1.0, 1.0, gold)
			_f(-w / 2.0 - 1.0, top - 1.0, w + 2.0, 2.5, Color("e8e0d0"))
		&"boudica":
			for i in 4:
				_f(-w / 2.0, top + 3.0 + i * 3.5, w, 0.5, gold)
			for i in 4:
				_f(-w / 2.0 + 2.0 + i * 4.0, top + 1.0, 0.5, length - 2.0, data.shirt_color)
		&"socrates", &"platon", &"aristoteles":
			_fl(Vector2(w / 2.0 - 1.0, top), Vector2(-w / 2.0 + 2.0, -2.0), coat.darkened(0.2), 1.5)
			for i in 3:
				_fl(Vector2(-3.0 + i * 3.0, top + 4.0), Vector2(-3.5 + i * 3.0, -2.0), coat.darkened(0.12))
		&"sun_tzu":
			for i in 5:
				_f(-w / 2.0 + 1.0, top + 3.0 + i * 3.5, w - 2.0, 0.5, coat.darkened(0.35))
		&"confucio":
			_fl(Vector2(-w / 2.0 + 2.0, top), Vector2(2, top + 8), gold, 1.0)
			_fl(Vector2(w / 2.0 - 2.0, top), Vector2(2, top + 8), gold, 1.0)
			_f(-w / 2.0, -4.0, w, 1.0, gold)
		&"isaac_newton":
			_f(-w / 2.0, top + 1.0, 0.5, length - 2.0, gold)
		&"hernan_cortes":
			for i in 3:
				_f(-w / 2.0 + 1.0, top + 3.0 + i * 5.0, w - 2.0, 0.5, coat.darkened(0.3))
			_f(1.0, top + 2.0, 1.0, length - 4.0, coat.lightened(0.25))
			_f(-w / 2.0, top, w, 1.5, coat.lightened(0.2))
		&"arturo_prat":
			for i in 4:
				_f(5.0, top + 4.0 + i * 3.5, 1.0, 1.0, gold)
				_f(3.0, top + 4.0 + i * 3.5, 1.0, 1.0, gold)
		&"mariya_oktyabrskaya", &"liudmila_pavlichenko":
			draw_circle(Vector2(-3.5, top + 6.0), 1.5, _c(gold))
			_f(-4.0, top + 3.0, 1.0, 2.5, Color("c02020"))
		&"pablo_escobar":
			_f(-w / 2.0, top + 11.0, w, 0.5, coat.lightened(0.2))

## Cabeza de los demás luchadores: reflejos de pelo, mechones de barba, brillo del bigote y detalles propios.
func _sig_head_b(head: Rect2, fx: float, hw: float, hh: float) -> void:
	var hair := data.hair_color
	var mouth_y := roundf(-hh * 0.4)
	var eye_y := roundf(-hh * 0.62)
	if data.hair_style != &"bald":
		_fl(Vector2(head.position.x - 1.0, -hh - 1.5), Vector2(fx - 1.0, -hh - 1.5), hair.lightened(0.32))
		if data.hair_style in [&"long", &"bob", &"braids", &"ponytail", &"wig"]:
			for i in 3:
				_fl(Vector2(head.position.x - 2.0 + (i % 2), -hh + 1.0), Vector2(head.position.x - 3.0 - (i % 2), 5.0 + i * 1.5), hair.lightened(0.22))
	match data.beard_style:
		&"full", &"long", &"chin", &"goatee", &"stubble":
			var n := 5
			for i in n:
				var bx := fx - 8.0 + i * 1.6
				_fl(Vector2(bx, mouth_y + 1.0), Vector2(bx + (i % 2) - 0.5, mouth_y + 6.0 + (4.0 if data.beard_style == &"long" else 0.0)), hair.lightened(0.25))
		&"mustache", &"brush", &"toothbrush":
			_f(fx - 5.0, mouth_y, 3.0, 0.5, hair.lightened(0.3))
	if data.female:
		_f(fx - 1.5, eye_y, 1.5, 0.5, OUTLINE)
		_f(fx - 3.5, roundf(-hh * 0.27), 1.0, 0.5, Color("ffb0c0"))
		_f(fx - 5.0, eye_y - 1.5, 3.0, 0.5, data.accent_color.lerp(data.skin_color, 0.4))
	match data.id:
		&"donald_trump":
			# Copete dorado con mechones y bronceado marcado.
			for i in 4:
				_fl(Vector2(head.position.x + 1.0 + i * 2.5, -hh - 3.0), Vector2(fx + 1.0, -hh - 1.0 + i * 0.5), hair.lightened(0.25))
			_f(fx - 6.0, eye_y - 1.0, 5.5, 3.5, data.skin_color.lightened(0.1))
		&"vladimir_putin":
			_f(fx - 2.0, -hh * 0.3, 1.0, 1.0, data.skin_color.darkened(0.2))
		&"xi_jinping", &"kim_jong_un":
			_f(fx - 5.0, -hh * 0.35, 3.0, 1.0, data.skin_color.lightened(0.1))
		&"nicolas_maduro":
			_f(fx - 6.0, mouth_y - 0.5, 1.0, 3.0, hair)
		&"adolf_hitler":
			_fl(Vector2(fx - 5.0, -hh + 2.0), Vector2(fx - 1.0, -hh + 4.0), hair.lightened(0.15), 1.0)
		&"pablo_escobar":
			for i in 4:
				_f(head.position.x - 2.0 + i * 3.0, -hh - 4.0, 1.5, 0.5, hair.lightened(0.4))
		&"isabel_ii":
			_fl(Vector2(head.position.x, -hh - 1.0), Vector2(fx - 1.0, -hh - 1.0), Color.WHITE)
		&"jesus_de_nazaret", &"buda":
			_f(fx - 3.0, -hh * 0.55, 1.0, 1.0, Color("e08070"))
		&"julio_cesar", &"cristobal_colon", &"hernan_cortes":
			_f(fx - 5.0, eye_y - 2.0, 4.0, 1.0, hair)
		&"sun_tzu", &"confucio":
			_fl(Vector2(fx - 6.0, mouth_y + 2.0), Vector2(fx - 8.0, mouth_y + 10.0), hair.lightened(0.3), 0.5)
			_fl(Vector2(fx - 3.0, mouth_y + 2.0), Vector2(fx - 4.0, mouth_y + 9.0), hair.lightened(0.3), 0.5)
		&"moctezuma_ii":
			_f(fx - 6.0, -hh * 0.3, 3.0, 0.5, Color("e04030"))
			_f(fx - 6.0, -hh * 0.3 + 1.5, 3.0, 0.5, Color("2a8a7a"))
		&"pachacutec", &"janequeo", &"boudica":
			_f(fx - 6.0, -hh * 0.35, 3.0, 0.5, Color("c02828") if data.id != &"boudica" else Color("3a6ac0"))
		&"osama_bin_laden", &"charles_darwin", &"galileo_galilei", &"ivan_el_terrible":
			_f(fx - 5.5, eye_y - 2.0, 4.5, 1.0, hair.lightened(0.1))

## Sombreros de los demás luchadores: brillos, pliegues, plumas y adornos según el estilo.
func _sig_hat_b(hw: float, hh: float, fx: float) -> void:
	var hat := data.hat_color
	var gold := data.coat_trim_color
	match data.hat_style:
		&"cap":
			_f(fx - 1.0, -hh, 7.0, 0.5, hat.lightened(0.3))
			_fl(Vector2(-hw / 2.0, -hh - 3.0), Vector2(hw / 2.0, -hh - 3.0), hat.lightened(0.2))
			_f(fx - 3.0, -hh - 3.0, 2.0, 2.0, data.accent_color)
			_f(fx - 2.5, -hh - 2.5, 1.0, 1.0, gold)
		&"beret":
			_fl(Vector2(-hw / 2.0, -hh - 3.0), Vector2(0, -hh - 1.0), hat.darkened(0.3))
			_fl(Vector2(hw / 2.0 - 1.0, -hh - 3.0), Vector2(1, -hh - 1.0), hat.darkened(0.25))
			_f(-hw / 2.0 - 2.0, -hh - 3.5, hw + 3.0, 0.5, hat.lightened(0.25))
		&"turban":
			for i in 3:
				_fl(Vector2(-hw / 2.0 - 1.0, -hh - 6.0 + i * 3.0), Vector2(hw / 2.0 + 2.0, -hh - 4.0 + i * 3.0), hat.lightened(0.25))
			_f(fx - 1.0, -hh - 3.0, 2.0, 2.0, data.accent_color)
		&"crown", &"tiara":
			for i in 3:
				_f(-hw / 2.0 + 1.0 + i * 4.0, -hh - 3.0, 1.0, 1.0, hat.lightened(0.5))
			_f(-hw / 2.0, -hh - 1.0, hw, 0.5, hat.lightened(0.3))
			_f(-1.0, -hh - 1.5, 2.0, 1.5, Color("2a4ab0") if data.id == &"isabel_ii" else Color("c02030"))
		&"laurel":
			for i in 4:
				_f(-hw / 2.0 + i * 4.0, -hh - 3.5, 1.0, 1.0, hat.darkened(0.25))
			_f(-hw / 2.0 - 1.0, -hh - 1.5, hw + 3.0, 0.5, hat.lightened(0.35))
		&"halo":
			var c := Vector2(0, -hh - 6.0)
			draw_arc(c, 7.5, 0.0, TAU, 24, _c(Color(hat.r, hat.g, hat.b, 0.35)), 1.5)
			draw_arc(c, 6.0, 0.0, TAU, 24, _c(hat.lightened(0.45)), 0.5)
			for i in 6:
				var a := i * TAU / 6.0 + 0.3
				_fl(c + Vector2(cos(a), sin(a)) * 8.5, c + Vector2(cos(a), sin(a)) * 10.5, Color(hat.r, hat.g, hat.b, 0.6))
		&"fur_hat":
			for i in 8:
				_f(-hw / 2.0 - 1.5 + i * 2.0, -hh - 6.5 + (i % 2) * 0.5, 1.0, 2.0, hat.lightened(0.28))
			_f(fx - 2.0, -hh - 3.0, 2.0, 2.0, gold)
		&"helmet", &"morion":
			_f(-hw / 2.0 + 1.0, -hh - 4.0, 0.5, 4.0, hat.lightened(0.4))
			_fl(Vector2(-hw / 2.0, -hh - 4.5), Vector2(hw / 2.0, -hh - 4.5), hat.lightened(0.3))
			_f(-hw / 2.0, -hh - 1.0, hw, 0.5, gold)
			_f(-hw / 2.0, -hh + 3.0, 0.5, 0.5, gold.lightened(0.4))
		&"plumes":
			for i in 7:
				var ang := deg_to_rad(-150.0 + i * 20.0)
				var root_p := Vector2(0, -hh - 1.0)
				var tip := root_p + Vector2(cos(ang), sin(ang)) * (15.0 if i % 2 == 0 else 12.0)
				_fl(root_p.lerp(tip, 0.4), tip, Color("a0f0c0") if i % 2 == 0 else Color("50d0a0"), 0.5)
		&"guan":
			_fl(Vector2(hw / 2.0 - 1.0, -hh - 7.0), Vector2(hw / 2.0 + 3.0, -hh - 3.0), gold, 1.0)
			_f(-3.0, -hh - 9.0, 0.5, 7.0, hat.lightened(0.35))
		&"headband":
			_f(-hw / 2.0 - 2.5, -hh + 2.0, 1.5, 5.0, hat)
			_f(-hw / 2.0 - 3.0, -hh + 5.0, 1.0, 3.0, hat.darkened(0.2))
		&"nemes":
			for i in 5:
				_f(-hw / 2.0 - 3.0, -hh + 1.0 + i * 2.0, 5.0, 0.5, gold if i % 2 == 0 else Color("8ab0f0"))
		&"top_hat":
			_f(hw / 2.0 - 3.0, -hh - 14.0, 1.0, 11.0, hat.lightened(0.3))

# --- Rasgos: silueta femenina, falda o vestido y capa ---------------------------
func _outfit_color() -> Color:
	return data.outfit_color if data.outfit_color.a > 0.0 else data.coat_color

## Torso con hombros estrechos, pecho, cintura marcada y caderas.
func _female_body(w: float, length: float, tail: float) -> void:
	var top := -length
	var pts := PackedVector2Array([
		Vector2(-w * 0.42, top), Vector2(w * 0.42, top),
		Vector2(w * 0.52, top + length * 0.3), Vector2(w * 0.34, top + length * 0.68),
		Vector2(w * 0.48, tail), Vector2(-w * 0.48, tail),
		Vector2(-w * 0.34, top + length * 0.68), Vector2(-w * 0.52, top + length * 0.3)])
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, _c(OUTLINE), _o() * 2.0)
	draw_colored_polygon(pts, _c(data.coat_color))
	# Sombreado de la espalda y brillo del pecho.
	draw_line(pts[0], pts[7], _c(data.coat_color.darkened(0.25)), 2.0)
	draw_line(pts[7], pts[6], _c(data.coat_color.darkened(0.25)), 2.0)
	draw_rect(Rect2(w * 0.2, top + length * 0.22, 3, 2), _c(data.coat_color.lightened(0.28)))
	draw_rect(Rect2(w * 0.2, top + length * 0.22 + 3, 3, 1), _c(data.coat_color.darkened(0.18)))

## Falda, vestido o traje largo: se dibuja desde la cadera y gira con las piernas.
func _skirt() -> void:
	var col := _outfit_color()
	var thigh := data.thigh_len
	var shin := data.shin_len
	var length := thigh * 0.95
	var flare := 1.5
	match data.outfit:
		&"dress":
			length = thigh + shin * 0.55
			flare = 1.4
		&"gown":
			length = thigh + shin - 1.0
			flare = 1.75
	var sway := sin(anim_time * 3.0) * 0.8
	if pose_name == &"run":
		sway = -3.0
	elif pose_name == &"walk":
		sway = -1.0
	var top_w := data.torso_width * 0.66
	var bot_w := data.torso_width * flare
	var pts := PackedVector2Array([
		Vector2(-top_w * 0.5, -3), Vector2(top_w * 0.5, -3),
		Vector2(bot_w * 0.5 + sway * 0.4, length), Vector2(-bot_w * 0.5 + sway, length)])
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, _c(OUTLINE), _o() * 2.0)
	draw_colored_polygon(pts, _c(col))
	# Pliegues y dobladillo.
	draw_line(Vector2(-top_w * 0.1, -2), Vector2(-bot_w * 0.12 + sway * 0.6, length - 1), _c(col.darkened(0.22)), 1.0)
	draw_line(Vector2(top_w * 0.25, -2), Vector2(bot_w * 0.25 + sway * 0.5, length - 1), _c(col.darkened(0.15)), 1.0)
	draw_line(Vector2(-top_w * 0.5, -2), Vector2(-bot_w * 0.5 + sway, length - 1), _c(col.darkened(0.3)), 2.0)
	draw_line(pts[3] + Vector2(0, -1), pts[2] + Vector2(0, -1), _c(data.coat_trim_color), 2.0)
	if _fine_on and data.chest_style != &"clockwork":
		# Más pliegues y brillo en el dobladillo (dibujo fino).
		for i in 3:
			_fl(Vector2(-top_w * 0.4 + i * top_w * 0.4, -2), Vector2(-bot_w * 0.35 + i * bot_w * 0.35 + sway * 0.5, length - 2), col.darkened(0.12))
		_fl(pts[3] + Vector2(0, -2.5), pts[2] + Vector2(0, -2.5), col.lightened(0.18))
	if data.chest_style == &"clockwork":
		# Franja central dorada y un engranaje bordado en la túnica del Nexo.
		var gold := data.coat_trim_color
		draw_line(Vector2(0, -2), Vector2(bot_w * 0.04 + sway * 0.6, length - 1), _c(gold), 3.0)
		draw_line(Vector2(-1, -2), Vector2(bot_w * 0.04 + sway * 0.6 - 1, length - 1), _c(gold.lightened(0.3)), 1.0)
		var gc := Vector2(-bot_w * 0.22 + sway * 0.3, length * 0.62)
		draw_circle(gc, 3.5, _c(gold))
		draw_circle(gc, 1.6, _c(col.darkened(0.3)))
		for gx in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
			draw_rect(Rect2((gc + gx - Vector2(1, 1)).round(), Vector2(2, 2)), _c(gold))

## Capa a la espalda: ondea al correr.
func _cape(shoulder: Vector2, hip: Vector2) -> void:
	var col := data.cape_color
	var fly := 0.0
	if pose_name == &"run":
		fly = 9.0 if not moving_back else -3.0
	elif pose_name == &"walk":
		fly = 3.0
	fly += sin(anim_time * 7.0) * 1.2
	var pts := PackedVector2Array([
		shoulder + Vector2(-3, -1), shoulder + Vector2(2, 0),
		hip + Vector2(-2.0 - fly * 0.3, data.thigh_len * 0.9),
		hip + Vector2(-data.torso_width * 0.5 - 6.0 - fly, data.thigh_len * 1.05)])
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, _c(OUTLINE), _o() * 2.0)
	draw_colored_polygon(pts, _c(col))
	draw_line(pts[0], pts[3], _c(col.darkened(0.3)), 2.0)
	draw_line(pts[3], pts[2], _c(data.coat_trim_color), 2.0)
