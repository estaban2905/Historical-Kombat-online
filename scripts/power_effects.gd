## Catálogo de poderes especiales con efectos propios (AttackData.power).
##
## Cuando un luchador termina el startup de un ataque con `power`, el
## CombatManager llama a cast(). Cada poder crea una o varias entidades
## (Projectile) con su propio aspecto (PowerArt), retardo, alcance y golpes,
## o modifica al luchador (teletransporte, salto...). El daño total del
## ataque (AttackData.damage) se reparte entre las entidades con `share`.
##
## Claves de las opciones de _spawn:
##   art      estilo de PowerArt ("" = proyectil clásico, ver style)
##   style    estilo clásico: ball | soundwave | orb | bolt | spin
##   color    color del proyectil / efecto
##   off      posición del CENTRO relativa a los pies (x hacia delante, y arriba < 0)
##   at_opp   true: la posición se mide desde el rival, no desde el lanzador
##   box      tamaño de la caja de impacto
##   speed / vy / accel_y   movimiento (px/s) hacia delante, vertical y gravedad
##   delay    frames hasta activarse   · show: se ve durante el retardo
##   life     segundos activo          · pierce: atraviesa y no se destruye
##   rehit / max_hits   golpes repetidos (frames entre golpes, nº máximo)
##   radial   empuja hacia fuera del centro
##   share    fracción del daño total  · knock / launch / stun   empuje, lanzamiento, aturdimiento
##   shake / sound   vibración de cámara y sonido al activarse
##   floor_y / boom  se destruye al llegar al suelo, explotando
##   clash    puede chocar con otros proyectiles
##   nostatus no aplica el estado alterado del ataque
##   pull     el golpe arrastra al rival hacia quien lo lanza (en vez de empujarlo)
##   follow   (solo visuales) acompaña a quien lo lanza hasta que acaba su escudo
class_name PowerEffects
extends RefCounted

## Frames que dura el escudo de Allende.
const SHIELD_FRAMES := 120

static func cast(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	match atk.power:
		&"wall":
			# Trump: un muro gigante emerge bajo el rival y lo aplasta.
			_spawn(cm, f, atk, {"art": &"wall", "at_opp": true, "off": Vector2(0, -42), "box": Vector2(26, 84),
				"delay": 22, "show": true, "life": 0.45, "pierce": true, "knock": 140.0, "launch": -170.0,
				"stun": 32, "shake": 5.0, "sound": &"hit_heavy"})
			_stones_later(cm, f.opponent.position.x, 22)
		&"rockets":
			# Kim: ráfaga de cohetes caricaturescos.
			var ys: Array[float] = [-52.0, -38.0, -60.0, -44.0]
			for i in 4:
				_spawn(cm, f, atk, {"art": &"rocket", "off": Vector2(16, ys[i]), "box": Vector2(14, 8),
					"speed": 270.0, "delay": i * 8, "life": 1.3, "share": 0.25, "knock": 120.0, "stun": 18,
					"clash": true, "sound": &"cannon"})
		&"bear":
			# Putin: un oso gigante embiste.
			_spawn(cm, f, atk, {"art": &"bear", "off": Vector2(14, -13), "box": Vector2(38, 26), "speed": 200.0,
				"life": 1.7, "knock": 300.0, "launch": -120.0, "stun": 30, "sound": &"whoosh"})
		&"dragon":
			# Xi: un dragón imperial recorre la pantalla escupiendo fuego.
			_spawn(cm, f, atk, {"art": &"dragon", "off": Vector2(28, -54), "box": Vector2(62, 26), "speed": 140.0,
				"life": 2.0, "pierce": true, "knock": 200.0, "stun": 34, "sound": &"megaphone"})
		&"dance":
			# Maduro: baile sorpresa que expulsa una onda de energía.
			_spawn(cm, f, atk, {"art": &"dance", "color": Color("ff70c0"), "off": Vector2(0, -36),
				"box": Vector2(130, 56), "delay": 20, "life": 0.4, "pierce": true, "radial": true,
				"knock": 260.0, "stun": 28, "shake": 2.0, "sound": &"confirm"})
		&"chaos_march":
			# Hitler: marcha mecánica que genera ondas de choque en el suelo.
			for i in 2:
				_spawn(cm, f, atk, {"art": &"groundwave", "color": Color("d8c8a0"), "off": Vector2(16, -6),
					"box": Vector2(30, 12), "speed": 250.0, "delay": i * 14, "life": 1.0, "share": 0.5,
					"knock": 160.0, "stun": 24, "shake": 2.0, "sound": &"hit_heavy"})
		&"steel_fist":
			# Stalin: golpea el suelo y brota una explosión de hielo y metal.
			_spawn(cm, f, atk, {"art": &"ice_burst", "off": Vector2(54, -26), "box": Vector2(40, 52),
				"delay": 14, "show": true, "life": 0.4, "pierce": true, "knock": 220.0, "launch": -230.0,
				"stun": 34, "shake": 5.0, "sound": &"hit_heavy"})
			_stones_later(cm, f.position.x + 54.0 * f.facing, 14)
		&"big_speech":
			# Mussolini: un grito enorme crea una onda sonora gigante.
			_spawn(cm, f, atk, {"art": &"bigwave", "off": Vector2(30, -50), "box": Vector2(26, 38),
				"speed": 210.0, "life": 1.4, "knock": 260.0, "stun": 30, "sound": &"megaphone"})
		&"sandstorm":
			# Saddam: tormenta de arena que golpea varias veces.
			_spawn(cm, f, atk, {"art": &"sandstorm", "off": Vector2(24, -30), "box": Vector2(48, 58),
				"speed": 85.0, "life": 2.2, "pierce": true, "rehit": 16, "max_hits": 3, "share": 1.0 / 3.0,
				"knock": 40.0, "stun": 22, "sound": &"whoosh"})
		&"desert_ghost":
			# Bin Laden: desaparece entre humo y reaparece tras el rival.
			var o := f.opponent
			var sgn := signf(o.position.x - f.position.x)
			if sgn == 0.0:
				sgn = float(f.facing)
			_visual(cm, f, f.position + Vector2(0, -30), {"art": &"smoke", "color": Color("c8c0d8"),
				"box": Vector2(30, 50), "life": 0.5})
			f.position.x = clampf(o.position.x + sgn * 30.0, f.bounds.x, f.bounds.y)
			f.facing = -int(sgn)
			f.velocity.x = 0.0
			_visual(cm, f, f.position + Vector2(0, -30), {"art": &"smoke", "color": Color("c8c0d8"),
				"box": Vector2(30, 50), "life": 0.5})
			_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -36), "box": Vector2(34, 52),
				"delay": 6, "life": 0.25, "pierce": true, "knock": 200.0, "stun": 24, "sound": &"hit_light"})
		&"artillery":
			# Napoleón: aparecen tres cañones y disparan una ráfaga de balas de energía.
			for i in 3:
				var x := -30.0 - i * 22.0
				_visual(cm, f, f.position + Vector2(x * f.facing, -8.0), {"art": &"cannon", "box": Vector2(28, 16),
					"life": 1.3})
				_spawn(cm, f, atk, {"style": &"ball", "off": Vector2(x + 22.0, -10.0), "box": Vector2(12, 12),
					"speed": 240.0, "delay": 12 + i * 10, "life": 1.4, "share": 1.0 / 3.0, "knock": 150.0,
					"stun": 20, "sound": &"cannon"})
		&"mongol_charge":
			# Gengis Kan: una manada de caballos atropella al rival.
			_spawn(cm, f, atk, {"art": &"horses", "off": Vector2(-14, -16), "box": Vector2(62, 32),
				"speed": 235.0, "life": 1.9, "pierce": true, "knock": 320.0, "launch": -140.0, "stun": 30,
				"sound": &"whoosh"})
		&"endless_speech":
			# Fidel: ondas de sonido sin parar que aturden.
			for i in 3:
				_spawn(cm, f, atk, {"style": &"soundwave", "off": Vector2(24, -52), "box": Vector2(16, 20),
					"speed": 205.0, "delay": i * 14, "life": 1.4, "share": 1.0 / 3.0, "knock": 90.0, "stun": 40,
					"sound": &"megaphone"})
		&"anubis":
			# Cleopatra: una enorme cabeza de chacal muerde al rival.
			_spawn(cm, f, atk, {"art": &"jackal", "at_opp": true, "off": Vector2(0, -28), "box": Vector2(36, 60),
				"delay": 20, "show": true, "life": 0.5, "pierce": true, "knock": 180.0, "launch": -150.0,
				"stun": 32, "shake": 3.0, "sound": &"hit_heavy"})
		&"legion":
			# César: soldados romanos avanzan en formación.
			_spawn(cm, f, atk, {"art": &"legion", "off": Vector2(8, -15), "box": Vector2(58, 34), "speed": 125.0,
				"life": 2.0, "pierce": true, "knock": 200.0, "stun": 26, "sound": &"whoosh"})
		&"bucephalus":
			# Alejandro: monta su caballo y atraviesa la pantalla embistiendo.
			_spawn(cm, f, atk, {"art": &"horse", "off": Vector2(10, -14), "box": Vector2(40, 30),
				"speed": maxf(atk.dash_speed, 300.0), "life": 0.35, "knock": 300.0, "launch": -120.0,
				"stun": 28, "sound": &"whoosh"})
		&"royal_guards":
			# Isabel: guardias reales disparan una ráfaga de energía.
			for i in 3:
				var x := 34.0 + i * 16.0
				_visual(cm, f, f.position + Vector2(x * f.facing, -15.0), {"art": &"guard", "box": Vector2(14, 34),
					"life": 1.3})
				_spawn(cm, f, atk, {"style": &"orb", "color": Color("f0c040"), "off": Vector2(x + 12.0, -22.0),
					"box": Vector2(14, 14), "speed": 250.0, "delay": 14 + i * 10, "life": 1.2,
					"share": 1.0 / 3.0, "knock": 140.0, "stun": 18, "sound": &"cannon"})
		&"divine_light":
			# Jesús: explosión de luz que empuja al rival y recarga energía.
			_spawn(cm, f, atk, {"art": &"lightburst", "off": Vector2(36, -38), "box": Vector2(62, 72),
				"delay": 10, "life": 0.35, "pierce": true, "knock": 330.0, "stun": 26, "shake": 2.0,
				"sound": &"confirm"})
		&"enlightenment":
			# Buda: se eleva y libera una onda de energía espiritual.
			f.velocity.y = -230.0
			_spawn(cm, f, atk, {"art": &"ring", "color": Color("ffd040"), "off": Vector2(0, -56),
				"box": Vector2(130, 70), "delay": 16, "life": 0.4, "pierce": true, "radial": true,
				"knock": 280.0, "stun": 28, "shake": 2.0, "sound": &"confirm"})
		&"vatican_bells":
			# Papa Francisco: campanas enormes que generan ondas de choque.
			for i in 3:
				_spawn(cm, f, atk, {"art": &"bell_wave", "off": Vector2(22, -40), "box": Vector2(20, 52),
					"speed": 175.0, "delay": i * 16, "life": 1.3, "share": 1.0 / 3.0, "knock": 150.0,
					"stun": 26, "sound": &"confirm"})
		&"dark_hypnosis":
			# Rasputín: hipnotiza al rival; sus movimientos laterales se invierten.
			_spawn(cm, f, atk, {"style": &"orb", "color": Color("a050e0"), "off": Vector2(26, -48),
				"box": Vector2(16, 16), "speed": 165.0, "life": 1.8, "knock": 110.0, "stun": 22,
				"sound": &"megaphone"})
		&"bill_rain":
			# Escobar: montaña de fajos de billetes.
			for i in 7:
				_spawn(cm, f, atk, {"style": &"spin", "color": Color("50c060"),
					"off": Vector2(18.0, -58.0 + (i % 3) * 14.0), "box": Vector2(12, 10),
					"speed": 190.0 + (i % 3) * 25.0, "vy": -50.0 + (i % 3) * 25.0, "accel_y": 60.0,
					"delay": i * 5, "life": 1.3, "share": 1.0 / 7.0, "knock": 70.0, "stun": 16})
		&"relativity":
			# Einstein: ralentiza el tiempo alrededor del rival.
			_spawn(cm, f, atk, {"art": &"timefield", "at_opp": true, "off": Vector2(0, -36), "box": Vector2(60, 72),
				"delay": 12, "show": true, "life": 0.5, "pierce": true, "knock": 60.0, "stun": 20,
				"sound": &"confirm"})
		&"tesla_storm":
			# Tesla: rayos eléctricos desde las manos.
			var vys: Array[float] = [-30.0, 15.0, -55.0, 30.0]
			var oys: Array[float] = [-52.0, -46.0, -58.0, -42.0]
			for i in 4:
				_spawn(cm, f, atk, {"style": &"bolt", "color": Color("70e0ff"), "off": Vector2(20, oys[i]),
					"box": Vector2(22, 10), "speed": 300.0, "vy": vys[i], "delay": i * 6, "life": 1.0,
					"share": 0.25, "knock": 90.0, "stun": 18, "sound": &"hit_light"})
		&"flying_machine":
			# Da Vinci: su máquina voladora bombardea al rival.
			_visual(cm, f, f.position + Vector2(-30.0 * f.facing, -110.0), {"art": &"plane", "box": Vector2(50, 24),
				"speed": 175.0, "life": 2.2, "show": true})
			for i in 4:
				var ti := 0.3 + i * 0.22
				_spawn(cm, f, atk, {"art": &"bomb", "off": Vector2(-30.0 + 175.0 * ti, -104.0), "box": Vector2(10, 10),
					"speed": 0.0, "accel_y": 520.0, "floor_y": f.floor_y - 2.0, "boom": true, "color": Color("ffb030"),
					"delay": int(ti * 60.0), "life": 1.6, "share": 0.25, "knock": 150.0, "stun": 22})
		&"radiant_sphere":
			# Curie: esfera de energía brillante que explota al impactar.
			_spawn(cm, f, atk, {"art": &"sphere", "color": Color("60f070"), "off": Vector2(26, -48),
				"box": Vector2(24, 24), "speed": 175.0, "life": 1.6, "boom": true, "knock": 260.0, "stun": 26,
				"sound": &"megaphone"})
		&"gravity_flip":
			# Galileo: el rival flota y luego cae.
			_spawn(cm, f, atk, {"art": &"gravity", "at_opp": true, "off": Vector2(0, -36), "box": Vector2(46, 72),
				"delay": 16, "show": true, "life": 0.4, "pierce": true, "knock": 0.0, "stun": 95,
				"sound": &"confirm"})
		&"wild_evolution":
			# Darwin: una pandilla de monos salta sobre el rival.
			_spawn(cm, f, atk, {"art": &"monkeys", "at_opp": true, "off": Vector2(0, -18), "box": Vector2(46, 40),
				"delay": 12, "show": true, "life": 0.9, "pierce": true, "rehit": 14, "max_hits": 3,
				"share": 1.0 / 3.0, "knock": 50.0, "stun": 20, "sound": &"whoosh"})
		&"discovery":
			# Colón: una carabela atraviesa la pantalla y embiste al rival.
			_spawn(cm, f, atk, {"art": &"caravel", "off": Vector2(-26, -17), "box": Vector2(76, 42),
				"speed": 215.0, "life": 2.3, "pierce": true, "knock": 320.0, "launch": -120.0, "stun": 30,
				"sound": &"whoosh"})
		&"weichan_spirit":
			# Janequeo: carga con la lanza, da tres lanzadas seguidas y la última suelta una onda.
			f.velocity.x = f.facing * 150.0
			for i in 3:
				_spawn(cm, f, atk, {"art": &"slash", "off": Vector2(34.0 + i * 8.0, -40.0 + (i % 2) * 8.0),
					"box": Vector2(34, 34), "delay": i * 9, "life": 0.18, "pierce": true, "share": 0.2,
					"knock": 70.0, "stun": 16, "sound": &"whoosh"})
			_spawn(cm, f, atk, {"art": &"bigwave", "off": Vector2(40, -42), "box": Vector2(22, 34),
				"speed": 230.0, "delay": 27, "life": 1.2, "share": 0.4, "knock": 220.0, "stun": 26,
				"sound": &"megaphone"})
		&"toqui_charge":
			# Lautaro: monta su caballo y atraviesa la pantalla con la lanza.
			_spawn(cm, f, atk, {"art": &"toqui", "off": Vector2(-14, -22), "box": Vector2(56, 34), "speed": 250.0,
				"life": 1.9, "pierce": true, "knock": 300.0, "launch": -130.0, "stun": 30, "sound": &"whoosh"})
		&"andean_quake":
			# Pachacútec: golpea el suelo con el cetro y la tierra se abre bajo el rival.
			_visual(cm, f, f.position + Vector2(30.0 * f.facing, -8.0), {"art": &"groundwave", "color": Color("b09060"),
				"box": Vector2(30, 12), "life": 0.4})
			_spawn(cm, f, atk, {"art": &"quake", "at_opp": true, "off": Vector2(0, -12), "box": Vector2(76, 24),
				"delay": 20, "show": true, "life": 0.5, "pierce": true, "knock": 120.0, "launch": -230.0,
				"stun": 36, "shake": 6.0, "sound": &"hit_heavy"})
			_stones_later(cm, f.opponent.position.x, 20)
		&"tsar_fury":
			# Iván: tormenta de rayos y hielo sobre el rival.
			for i in 3:
				_spawn(cm, f, atk, {"art": &"icebolt", "at_opp": true, "off": Vector2(-26.0 + i * 26.0, -45.0),
					"box": Vector2(18, 90), "delay": 14 + i * 10, "show": true, "life": 0.3, "pierce": true,
					"share": 1.0 / 3.0, "knock": 90.0, "stun": 20, "sound": &"hit_heavy",
					"color": Color("a0e0ff") if i != 1 else Color("fff080")})
		&"war_chariot":
			# Boudica: un carro de guerra tirado por caballos arrolla al rival.
			_spawn(cm, f, atk, {"art": &"chariot", "off": Vector2(-20, -18), "box": Vector2(74, 34), "speed": 255.0,
				"life": 1.9, "pierce": true, "knock": 330.0, "launch": -130.0, "stun": 30, "sound": &"whoosh"})
		&"orleans_blade":
			# Juana de Arco: levanta la espada y lanza un corte de luz.
			_visual(cm, f, f.position + Vector2(16.0 * f.facing, -52.0), {"art": &"lightburst", "box": Vector2(40, 40),
				"life": 0.3})
			_spawn(cm, f, atk, {"art": &"lightblade", "off": Vector2(30, -40), "box": Vector2(26, 56), "speed": 280.0,
				"life": 1.3, "knock": 240.0, "stun": 28, "clash": true, "sound": &"confirm"})
		&"state_siege":
			# Pinochet: una barrera militar inmoviliza al rival y lo deja a merced de un ataque.
			_spawn(cm, f, atk, {"art": &"barrier", "at_opp": true, "off": Vector2(0, -22), "box": Vector2(60, 44),
				"delay": 10, "show": true, "life": 0.6, "pierce": true, "share": 0.3, "knock": 0.0, "stun": 12,
				"sound": &"confirm"})
			_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -34), "box": Vector2(44, 56),
				"delay": 44, "life": 0.25, "pierce": true, "share": 0.7, "knock": 200.0, "stun": 26,
				"nostatus": true, "shake": 4.0, "sound": &"hit_heavy"})
		&"chilean_way":
			# Allende: escudo de energía roja que absorbe un golpe y lo devuelve como onda (ver reflect).
			f.shield_frames = SHIELD_FRAMES
			_visual(cm, f, f.position + Vector2(0, -36), {"art": &"redshield", "box": Vector2(46, 74),
				"life": float(SHIELD_FRAMES) / 60.0, "follow": true, "show": true})
		&"esmeralda":
			# Prat: aparece la silueta de la Esmeralda y un ancla gigante arrastra al rival.
			_visual(cm, f, Vector2(213.0, f.floor_y - 66.0), {"art": &"ship", "box": Vector2(170, 100), "life": 1.2,
				"show": true})
			_spawn(cm, f, atk, {"art": &"anchor", "off": Vector2(28, -44), "box": Vector2(24, 26), "speed": 330.0,
				"life": 0.9, "pull": true, "knock": 300.0, "stun": 30, "sound": &"cannon"})
		_:
			push_warning("PowerEffects: poder desconocido «%s»" % atk.power)

## Escudo de Allende: devuelve al que atacó una onda roja con el daño de su poder.
static func reflect(cm: CombatManager, f: Fighter, foe: Fighter) -> void:
	var atk := f.data.special_2
	if atk == null:
		return
	f.facing = 1 if foe.position.x >= f.position.x else -1
	_spawn(cm, f, atk, {"art": &"bigwave", "color": Color("e03030"), "off": Vector2(26, -40), "box": Vector2(26, 44),
		"speed": 270.0, "life": 1.5, "knock": 260.0, "stun": 28, "shake": 3.0, "sound": &"hit_heavy"})

## Fragmentos de piedra en el suelo tras `frames` (cuando el poder golpea).
static func _stones_later(cm: CombatManager, x: float, frames: int) -> void:
	await cm.get_tree().create_timer(frames / 60.0).timeout
	if is_instance_valid(cm):
		cm.fx.stones(Vector2(x, cm.stage.floor_y))

## Crea una entidad que golpea (ver claves en la cabecera).
static func _spawn(cm: CombatManager, f: Fighter, atk: AttackData, d: Dictionary) -> Projectile:
	var a := atk.duplicate() as AttackData
	a.damage = atk.damage * float(d.get("share", 1.0))
	a.knockback = float(d.get("knock", atk.knockback))
	a.launch = float(d.get("launch", 0.0))
	a.hitstun = int(d.get("stun", atk.hitstun))
	a.projectile_style = d.get("style", &"ball")
	a.projectile_color = d.get("color", atk.projectile_color)
	a.hitbox_size = d.get("box", Vector2(12, 12))
	a.projectile_speed = float(d.get("speed", 0.0))
	if d.get("nostatus", false):
		a.status = &""
		a.energy_on_hit = 0.0
	var base: Vector2 = f.opponent.position if d.get("at_opp", false) else f.position
	var off: Vector2 = d.get("off", Vector2.ZERO)
	var p := Projectile.new()
	p.setup(f, a, base + Vector2(off.x * f.facing, off.y))
	p.configure(d)
	cm.projectiles_root.add_child(p)
	if p.is_armed():
		if p.shake_on_arm > 0.0:
			cm.shake(p.shake_on_arm)
		if p.sound_on_arm != &"":
			Sfx.play(p.sound_on_arm)
	return p

## Crea una entidad solo de decorado (cañón, guardia, humo, avión...).
static func _visual(cm: CombatManager, f: Fighter, pos: Vector2, d: Dictionary) -> Projectile:
	var p := Projectile.make_visual(f, pos, d)
	cm.projectiles_root.add_child(p)
	return p
