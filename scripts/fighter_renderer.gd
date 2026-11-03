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

func _compute_pose() -> Dictionary:
	var base: Dictionary = _base_pose()
	var p: Dictionary = base.duplicate()
	_prop = ""
	match pose_name:
		&"idle", &"crouch", &"jump":
			if pose_name == &"idle" and data.idle_style == &"hand_in_coat":
				p["fa_u"] = 8.0
				p["fa_l"] = 112.0
		&"walk":
			var s := sin(anim_time * 11.0)
			p["fl_t"] = 16.0 + s * 22.0
			p["fl_s"] = 4.0 + minf(s, 0.0) * 25.0
			p["bl_t"] = -16.0 - s * 22.0
			p["bl_s"] = -8.0 + minf(-s, 0.0) * 25.0
			if data.idle_style == &"hand_in_coat":
				p["fa_u"] = 8.0
				p["fa_l"] = 112.0
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
			# Puño en alto que se agita
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
		bob = sin(anim_time * 4.0) * 0.8
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
	_fist(fhand, data.skin_color)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _seg(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	draw_line(a, b, _c(OUTLINE), w + 2.0, true)
	draw_circle(a, (w + 2.0) * 0.5, _c(OUTLINE))
	draw_circle(b, (w + 2.0) * 0.5, _c(OUTLINE))
	draw_line(a, b, _c(col), w, true)
	draw_circle(a, w * 0.5, _c(col))
	draw_circle(b, w * 0.5, _c(col))

func _limb(a: Vector2, b: Vector2, c: Vector2, col: Color, w: float) -> void:
	_seg(a, b, col, w)
	_seg(b, c, col, w - 1.0)

func _fist(at: Vector2, col: Color) -> void:
	var r := Rect2((at - Vector2(2.5, 2.5)).round(), Vector2(5, 5))
	draw_rect(r.grow(1), _c(OUTLINE))
	draw_rect(r, _c(col))
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(2, 1)), _c(col.lightened(0.25)))

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
		draw_rect(body.grow(1), _c(OUTLINE))
		draw_rect(body, _c(data.coat_color))
		# Sombreado lateral trasero
		draw_rect(Rect2(body.position, Vector2(3, body.size.y)), _c(data.coat_color.darkened(0.25)))
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

func _head() -> void:
	var hw := data.head_width
	var hh := data.head_height
	# Cuello
	draw_rect(Rect2(-3, -2, 6, 3), _c(data.skin_color.darkened(0.15)))
	var head := Rect2(roundf(-hw / 2.0), -hh, hw, hh)
	draw_rect(head.grow(1), _c(OUTLINE))
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
	draw_rect(r.grow(1), _c(OUTLINE))
	draw_rect(r, col)

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
	draw_polyline(closed, _c(OUTLINE), 2.0)
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
	draw_polyline(closed, _c(OUTLINE), 2.0)
	draw_colored_polygon(pts, _c(col))
	# Pliegues y dobladillo.
	draw_line(Vector2(-top_w * 0.1, -2), Vector2(-bot_w * 0.12 + sway * 0.6, length - 1), _c(col.darkened(0.22)), 1.0)
	draw_line(Vector2(top_w * 0.25, -2), Vector2(bot_w * 0.25 + sway * 0.5, length - 1), _c(col.darkened(0.15)), 1.0)
	draw_line(Vector2(-top_w * 0.5, -2), Vector2(-bot_w * 0.5 + sway, length - 1), _c(col.darkened(0.3)), 2.0)
	draw_line(pts[3] + Vector2(0, -1), pts[2] + Vector2(0, -1), _c(data.coat_trim_color), 2.0)

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
	draw_polyline(closed, _c(OUTLINE), 2.0)
	draw_colored_polygon(pts, _c(col))
	draw_line(pts[0], pts[3], _c(col.darkened(0.3)), 2.0)
	draw_line(pts[3], pts[2], _c(data.coat_trim_color), 2.0)
