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
	"cast": {
		"windup": {"fa_u": 15.0, "fa_l": 160.0, "ba_u": 10.0, "ba_l": 150.0, "lean": -8.0},
		"strike": {"fa_u": 85.0, "fa_l": 92.0, "ba_u": 75.0, "ba_l": 100.0, "lean": 14.0, "hx": 3.0},
	},
	"rush": {
		"windup": {"fa_u": -30.0, "fa_l": 30.0, "lean": -8.0},
		"strike": {"fa_u": 88.0, "fa_l": 90.0, "lean": 32.0, "hx": 6.0,
			"fl_t": 45.0, "fl_s": 10.0, "bl_t": -45.0, "bl_s": -30.0},
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
		&"helmet": extra = 10.0
		&"turban", &"fur_hat", &"nemes", &"crown", &"cap", &"beret": extra = 7.0
	return data.thigh_len + data.shin_len + data.torso_len + 2.0 + data.head_height + extra

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
	# Brazo trasero
	_limb(bsh, belb, bhand, data.coat_color.darkened(0.3), data.arm_width)
	_fist(bhand, data.skin_color.darkened(0.2))
	# Pierna trasera
	_leg(hip, bknee, bfoot, p["bl_s"], dark)
	# Pierna delantera
	_leg(hip, fknee, ffoot, p["fl_s"], 1.0)
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
	draw_rect(body.grow(1), _c(OUTLINE))
	draw_rect(body, _c(data.coat_color))
	# Sombreado lateral trasero
	draw_rect(Rect2(body.position, Vector2(3, body.size.y)), _c(data.coat_color.darkened(0.25)))
	var top := -length
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
		draw_rect(Rect2(-w / 2.0, -6, w, 2).abs(), _c(data.accent_color))
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
	draw_rect(Rect2(fx - 4, roundf(-hh * 0.62), 2, 2), _c(Color.WHITE))
	draw_rect(Rect2(fx - 3, roundf(-hh * 0.62), 1, 2), _c(OUTLINE))
	draw_rect(Rect2(fx - 5, roundf(-hh * 0.62) - 2, 4, 1), _c(data.hair_color.darkened(0.2)))
	draw_rect(Rect2(fx, roundf(-hh * 0.55), 2, 3), _c(data.skin_color.darkened(0.1)))
	if data.chest_style == &"tie":
		draw_rect(Rect2(fx - 3, roundf(-hh * 0.27), 2, 2), _c(Color("a04040")))
	else:
		draw_rect(Rect2(fx - 4, roundf(-hh * 0.27), 3, 1), _c(OUTLINE))
	# Vello facial (se dibuja sobre la cara y bajo el pelo y el sombrero).
	var beard := _c(data.hair_color)
	var mouth_y := roundf(-hh * 0.4)
	match data.beard_style:
		&"mustache":
			draw_rect(Rect2(fx - 5, mouth_y, 6, 2), beard)
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

func _orect(r: Rect2, col: Color) -> void:
	draw_rect(r.grow(1), _c(OUTLINE))
	draw_rect(r, col)
