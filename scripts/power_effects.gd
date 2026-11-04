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
##   life     frames activo           · pierce: atraviesa y no se destruye
##   rehit / max_hits   golpes repetidos (frames entre golpes, nº máximo)
##   radial   empuja hacia fuera del centro
##   share    fracción del daño total  · knock / launch / stun   empuje, lanzamiento, aturdimiento
##   shake / sound   vibración de cámara y sonido al activarse
##   floor_y / boom  se destruye al llegar al suelo, explotando
##   clash    puede chocar con otros proyectiles
##   nostatus no aplica el estado alterado del ataque
##   pull     el golpe arrastra al rival hacia quien lo lanza (en vez de empujarlo)
##   follow   (solo visuales) acompaña a quien lo lanza hasta que acaba su escudo
##   dir      dirección de avance (1 = derecha, -1 = izquierda); por defecto, la de quien lo lanza
class_name PowerEffects
extends RefCounted

## Frames que dura el escudo de Allende.
const SHIELD_FRAMES := 120

static func cast(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	match atk.power:
		&"wall":
			# Trump: un muro gigante emerge bajo el rival y lo aplasta.
			_spawn(cm, f, atk, {"art": &"wall", "at_opp": true, "off": Vector2(0, -42), "box": Vector2(26, 84),
				"delay": 22, "show": true, "life": 27, "pierce": true, "knock": 140.0, "launch": -170.0,
				"stun": 32, "shake": 5.0, "sound": &"hit_heavy"})
			_stones_later(cm, f.opponent.position.x, 22)
		&"rockets":
			# Kim: ráfaga de cohetes caricaturescos.
			var ys: Array[float] = [-52.0, -38.0, -60.0, -44.0]
			for i in 4:
				_spawn(cm, f, atk, {"art": &"rocket", "off": Vector2(16, ys[i]), "box": Vector2(14, 8),
					"speed": 270.0, "delay": i * 8, "life": 78, "share": 0.25, "knock": 120.0, "stun": 18,
					"clash": true, "sound": &"cannon"})
		&"bear":
			# Putin: un oso gigante embiste.
			_spawn(cm, f, atk, {"art": &"bear", "off": Vector2(14, -13), "box": Vector2(38, 26), "speed": 200.0,
				"life": 102, "knock": 300.0, "launch": -120.0, "stun": 30, "sound": &"whoosh"})
		&"dragon":
			# Xi: un dragón imperial recorre la pantalla escupiendo fuego.
			_spawn(cm, f, atk, {"art": &"dragon", "off": Vector2(28, -54), "box": Vector2(62, 26), "speed": 140.0,
				"life": 120, "pierce": true, "knock": 200.0, "stun": 34, "sound": &"megaphone"})
		&"dance":
			# Maduro: baile sorpresa que expulsa una onda de energía.
			_spawn(cm, f, atk, {"art": &"dance", "color": Color("ff70c0"), "off": Vector2(0, -36),
				"box": Vector2(130, 56), "delay": 20, "life": 24, "pierce": true, "radial": true,
				"knock": 260.0, "stun": 28, "shake": 2.0, "sound": &"confirm"})
		&"chaos_march":
			# Hitler: marcha mecánica que genera ondas de choque en el suelo.
			for i in 2:
				_spawn(cm, f, atk, {"art": &"groundwave", "color": Color("d8c8a0"), "off": Vector2(16, -6),
					"box": Vector2(30, 12), "speed": 250.0, "delay": i * 14, "life": 60, "share": 0.5,
					"knock": 160.0, "stun": 24, "shake": 2.0, "sound": &"hit_heavy"})
		&"steel_fist":
			# Stalin: golpea el suelo y brota una explosión de hielo y metal.
			_spawn(cm, f, atk, {"art": &"ice_burst", "off": Vector2(54, -26), "box": Vector2(40, 52),
				"delay": 14, "show": true, "life": 24, "pierce": true, "knock": 220.0, "launch": -230.0,
				"stun": 34, "shake": 5.0, "sound": &"hit_heavy"})
			_stones_later(cm, f.position.x + 54.0 * f.facing, 14)
		&"big_speech":
			# Mussolini: un grito enorme crea una onda sonora gigante.
			_spawn(cm, f, atk, {"art": &"bigwave", "off": Vector2(30, -50), "box": Vector2(26, 38),
				"speed": 210.0, "life": 84, "knock": 260.0, "stun": 30, "sound": &"megaphone"})
		&"sandstorm":
			# Saddam: tormenta de arena que golpea varias veces.
			_spawn(cm, f, atk, {"art": &"sandstorm", "off": Vector2(24, -30), "box": Vector2(48, 58),
				"speed": 85.0, "life": 132, "pierce": true, "rehit": 16, "max_hits": 3, "share": 1.0 / 3.0,
				"knock": 40.0, "stun": 22, "sound": &"whoosh"})
		&"desert_ghost":
			# Bin Laden: desaparece entre humo y reaparece tras el rival.
			var o := f.opponent
			_visual(cm, f, f.position + Vector2(0, -30), {"art": &"smoke", "color": Color("c8c0d8"),
				"box": Vector2(30, 50), "life": 30})
			f.teleport_behind(o)
			_visual(cm, f, f.position + Vector2(0, -30), {"art": &"smoke", "color": Color("c8c0d8"),
				"box": Vector2(30, 50), "life": 30})
			_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -36), "box": Vector2(34, 52),
				"delay": 6, "life": 15, "pierce": true, "knock": 200.0, "stun": 24, "sound": &"hit_light"})
		&"artillery":
			# Napoleón: aparecen tres cañones y disparan una ráfaga de balas de energía.
			for i in 3:
				var x := -30.0 - i * 22.0
				_visual(cm, f, f.position + Vector2(x * f.facing, -8.0), {"art": &"cannon", "box": Vector2(28, 16),
					"life": 78})
				_spawn(cm, f, atk, {"style": &"ball", "off": Vector2(x + 22.0, -10.0), "box": Vector2(12, 12),
					"speed": 240.0, "delay": 12 + i * 10, "life": 84, "share": 1.0 / 3.0, "knock": 150.0,
					"stun": 20, "sound": &"cannon"})
		&"mongol_charge":
			# Gengis Kan: una manada de caballos atropella al rival.
			_spawn(cm, f, atk, {"art": &"horses", "off": Vector2(-14, -16), "box": Vector2(62, 32),
				"speed": 235.0, "life": 114, "pierce": true, "knock": 320.0, "launch": -140.0, "stun": 30,
				"sound": &"whoosh"})
		&"endless_speech":
			# Fidel: ondas de sonido sin parar que aturden.
			for i in 3:
				_spawn(cm, f, atk, {"style": &"soundwave", "off": Vector2(24, -52), "box": Vector2(16, 20),
					"speed": 205.0, "delay": i * 14, "life": 84, "share": 1.0 / 3.0, "knock": 90.0, "stun": 40,
					"sound": &"megaphone"})
		&"anubis":
			# Cleopatra: una enorme cabeza de chacal muerde al rival.
			_spawn(cm, f, atk, {"art": &"jackal", "at_opp": true, "off": Vector2(0, -28), "box": Vector2(36, 60),
				"delay": 20, "show": true, "life": 30, "pierce": true, "knock": 180.0, "launch": -150.0,
				"stun": 32, "shake": 3.0, "sound": &"hit_heavy"})
		&"legion":
			# César: soldados romanos avanzan en formación.
			_spawn(cm, f, atk, {"art": &"legion", "off": Vector2(8, -15), "box": Vector2(58, 34), "speed": 125.0,
				"life": 120, "pierce": true, "knock": 200.0, "stun": 26, "sound": &"whoosh"})
		&"bucephalus":
			# Alejandro: monta su caballo y atraviesa la pantalla embistiendo.
			_spawn(cm, f, atk, {"art": &"horse", "off": Vector2(10, -14), "box": Vector2(40, 30),
				"speed": maxf(atk.dash_speed, 300.0), "life": 21, "knock": 300.0, "launch": -120.0,
				"stun": 28, "sound": &"whoosh"})
		&"royal_guards":
			# Isabel: guardias reales disparan una ráfaga de energía.
			for i in 3:
				var x := 34.0 + i * 16.0
				_visual(cm, f, f.position + Vector2(x * f.facing, -15.0), {"art": &"guard", "box": Vector2(14, 34),
					"life": 78})
				_spawn(cm, f, atk, {"style": &"orb", "color": Color("f0c040"), "off": Vector2(x + 12.0, -22.0),
					"box": Vector2(14, 14), "speed": 250.0, "delay": 14 + i * 10, "life": 72,
					"share": 1.0 / 3.0, "knock": 140.0, "stun": 18, "sound": &"cannon"})
		&"divine_light":
			# Jesús: explosión de luz que empuja al rival y recarga energía.
			_spawn(cm, f, atk, {"art": &"lightburst", "off": Vector2(36, -38), "box": Vector2(62, 72),
				"delay": 10, "life": 21, "pierce": true, "knock": 330.0, "stun": 26, "shake": 2.0,
				"sound": &"confirm"})
		&"enlightenment":
			# Buda: se eleva y libera una onda de energía espiritual.
			f.hop(230.0)
			_spawn(cm, f, atk, {"art": &"ring", "color": Color("ffd040"), "off": Vector2(0, -56),
				"box": Vector2(130, 70), "delay": 16, "life": 24, "pierce": true, "radial": true,
				"knock": 280.0, "stun": 28, "shake": 2.0, "sound": &"confirm"})
		&"vatican_bells":
			# Papa Francisco: campanas enormes que generan ondas de choque.
			for i in 3:
				_spawn(cm, f, atk, {"art": &"bell_wave", "off": Vector2(22, -40), "box": Vector2(20, 52),
					"speed": 175.0, "delay": i * 16, "life": 78, "share": 1.0 / 3.0, "knock": 150.0,
					"stun": 26, "sound": &"confirm"})
		&"dark_hypnosis":
			# Rasputín: hipnotiza al rival; sus movimientos laterales se invierten.
			_spawn(cm, f, atk, {"style": &"orb", "color": Color("a050e0"), "off": Vector2(26, -48),
				"box": Vector2(16, 16), "speed": 165.0, "life": 108, "knock": 110.0, "stun": 22,
				"sound": &"megaphone"})
		&"bill_rain":
			# Escobar: montaña de fajos de billetes.
			for i in 7:
				_spawn(cm, f, atk, {"style": &"spin", "color": Color("50c060"),
					"off": Vector2(18.0, -58.0 + (i % 3) * 14.0), "box": Vector2(12, 10),
					"speed": 190.0 + (i % 3) * 25.0, "vy": -50.0 + (i % 3) * 25.0, "accel_y": 60.0,
					"delay": i * 5, "life": 78, "share": 1.0 / 7.0, "knock": 70.0, "stun": 16})
		&"relativity":
			# Einstein: ralentiza el tiempo alrededor del rival.
			_spawn(cm, f, atk, {"art": &"timefield", "at_opp": true, "off": Vector2(0, -36), "box": Vector2(60, 72),
				"delay": 12, "show": true, "life": 30, "pierce": true, "knock": 60.0, "stun": 20,
				"sound": &"confirm"})
		&"tesla_storm":
			# Tesla: rayos eléctricos desde las manos.
			var vys: Array[float] = [-30.0, 15.0, -55.0, 30.0]
			var oys: Array[float] = [-52.0, -46.0, -58.0, -42.0]
			for i in 4:
				_spawn(cm, f, atk, {"style": &"bolt", "color": Color("70e0ff"), "off": Vector2(20, oys[i]),
					"box": Vector2(22, 10), "speed": 300.0, "vy": vys[i], "delay": i * 6, "life": 60,
					"share": 0.25, "knock": 90.0, "stun": 18, "sound": &"hit_light"})
		&"flying_machine":
			# Da Vinci: su máquina voladora bombardea al rival.
			_visual(cm, f, f.position + Vector2(-30.0 * f.facing, -110.0), {"art": &"plane", "box": Vector2(50, 24),
				"speed": 175.0, "life": 132, "show": true})
			for i in 4:
				var ti := 0.3 + i * 0.22
				_spawn(cm, f, atk, {"art": &"bomb", "off": Vector2(-30.0 + 175.0 * ti, -104.0), "box": Vector2(10, 10),
					"speed": 0.0, "accel_y": 520.0, "floor_y": f.floor_y - 2.0, "boom": true, "color": Color("ffb030"),
					"delay": int(ti * 60.0), "life": 96, "share": 0.25, "knock": 150.0, "stun": 22})
		&"radiant_sphere":
			# Curie: esfera de energía brillante que explota al impactar.
			_spawn(cm, f, atk, {"art": &"sphere", "color": Color("60f070"), "off": Vector2(26, -48),
				"box": Vector2(24, 24), "speed": 175.0, "life": 96, "boom": true, "knock": 260.0, "stun": 26,
				"sound": &"megaphone"})
		&"gravity_flip":
			# Galileo: el rival flota y luego cae.
			_spawn(cm, f, atk, {"art": &"gravity", "at_opp": true, "off": Vector2(0, -36), "box": Vector2(46, 72),
				"delay": 16, "show": true, "life": 24, "pierce": true, "knock": 0.0, "stun": 95,
				"sound": &"confirm"})
		&"wild_evolution":
			# Darwin: una pandilla de monos salta sobre el rival.
			_spawn(cm, f, atk, {"art": &"monkeys", "at_opp": true, "off": Vector2(0, -18), "box": Vector2(46, 40),
				"delay": 12, "show": true, "life": 54, "pierce": true, "rehit": 14, "max_hits": 3,
				"share": 1.0 / 3.0, "knock": 50.0, "stun": 20, "sound": &"whoosh"})
		&"discovery":
			# Colón: una carabela atraviesa la pantalla y embiste al rival.
			_spawn(cm, f, atk, {"art": &"caravel", "off": Vector2(-26, -17), "box": Vector2(76, 42),
				"speed": 215.0, "life": 138, "pierce": true, "knock": 320.0, "launch": -120.0, "stun": 30,
				"sound": &"whoosh"})
		&"weichan_spirit":
			# Janequeo: carga con la lanza, da tres lanzadas seguidas y la última suelta una onda.
			f.lunge(150.0)
			for i in 3:
				_spawn(cm, f, atk, {"art": &"slash", "off": Vector2(34.0 + i * 8.0, -40.0 + (i % 2) * 8.0),
					"box": Vector2(34, 34), "delay": i * 9, "life": 11, "pierce": true, "share": 0.2,
					"knock": 70.0, "stun": 16, "sound": &"whoosh"})
			_spawn(cm, f, atk, {"art": &"bigwave", "off": Vector2(40, -42), "box": Vector2(22, 34),
				"speed": 230.0, "delay": 27, "life": 72, "share": 0.4, "knock": 220.0, "stun": 26,
				"sound": &"megaphone"})
		&"toqui_charge":
			# Lautaro: monta su caballo y atraviesa la pantalla con la lanza.
			_spawn(cm, f, atk, {"art": &"toqui", "off": Vector2(-14, -22), "box": Vector2(56, 34), "speed": 250.0,
				"life": 114, "pierce": true, "knock": 300.0, "launch": -130.0, "stun": 30, "sound": &"whoosh"})
		&"andean_quake":
			# Pachacútec: golpea el suelo con el cetro y la tierra se abre bajo el rival.
			_visual(cm, f, f.position + Vector2(30.0 * f.facing, -8.0), {"art": &"groundwave", "color": Color("b09060"),
				"box": Vector2(30, 12), "life": 24})
			_spawn(cm, f, atk, {"art": &"quake", "at_opp": true, "off": Vector2(0, -12), "box": Vector2(76, 24),
				"delay": 20, "show": true, "life": 30, "pierce": true, "knock": 120.0, "launch": -230.0,
				"stun": 36, "shake": 6.0, "sound": &"hit_heavy"})
			_stones_later(cm, f.opponent.position.x, 20)
		&"tsar_fury":
			# Iván: tormenta de rayos y hielo sobre el rival.
			for i in 3:
				_spawn(cm, f, atk, {"art": &"icebolt", "at_opp": true, "off": Vector2(-26.0 + i * 26.0, -45.0),
					"box": Vector2(18, 90), "delay": 14 + i * 10, "show": true, "life": 18, "pierce": true,
					"share": 1.0 / 3.0, "knock": 90.0, "stun": 20, "sound": &"hit_heavy",
					"color": Color("a0e0ff") if i != 1 else Color("fff080")})
		&"war_chariot":
			# Boudica: un carro de guerra tirado por caballos arrolla al rival.
			_spawn(cm, f, atk, {"art": &"chariot", "off": Vector2(-20, -18), "box": Vector2(74, 34), "speed": 255.0,
				"life": 114, "pierce": true, "knock": 330.0, "launch": -130.0, "stun": 30, "sound": &"whoosh"})
		&"orleans_blade":
			# Juana de Arco: levanta la espada y lanza un corte de luz.
			_visual(cm, f, f.position + Vector2(16.0 * f.facing, -52.0), {"art": &"lightburst", "box": Vector2(40, 40),
				"life": 18})
			_spawn(cm, f, atk, {"art": &"lightblade", "off": Vector2(30, -40), "box": Vector2(26, 56), "speed": 280.0,
				"life": 78, "knock": 240.0, "stun": 28, "clash": true, "sound": &"confirm"})
		&"state_siege":
			# Pinochet: una barrera militar inmoviliza al rival y lo deja a merced de un ataque.
			_spawn(cm, f, atk, {"art": &"barrier", "at_opp": true, "off": Vector2(0, -22), "box": Vector2(60, 44),
				"delay": 10, "show": true, "life": 36, "pierce": true, "share": 0.3, "knock": 0.0, "stun": 12,
				"sound": &"confirm"})
			_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -34), "box": Vector2(44, 56),
				"delay": 44, "life": 15, "pierce": true, "share": 0.7, "knock": 200.0, "stun": 26,
				"nostatus": true, "shake": 4.0, "sound": &"hit_heavy"})
		&"chilean_way":
			# Allende: escudo de energía roja que absorbe un golpe y lo devuelve como onda (ver reflect).
			f.grant_shield(SHIELD_FRAMES)
			_visual(cm, f, f.position + Vector2(0, -36), {"art": &"redshield", "box": Vector2(46, 74),
				"life": SHIELD_FRAMES, "follow": true, "show": true})
		&"esmeralda":
			# Prat: aparece la silueta de la Esmeralda y un ancla gigante arrastra al rival.
			_visual(cm, f, Vector2(213.0, f.floor_y - 66.0), {"art": &"ship", "box": Vector2(170, 100), "life": 72,
				"show": true})
			_spawn(cm, f, atk, {"art": &"anchor", "off": Vector2(28, -44), "box": Vector2(24, 26), "speed": 330.0,
				"life": 54, "pull": true, "knock": 300.0, "stun": 30, "sound": &"cannon"})
		&"socratic":
			# Sócrates: le llueven preguntas al rival, que queda confundido (controles invertidos)
			# y recibe una combinación de bastonazos.
			_spawn(cm, f, atk, {"art": &"questions", "at_opp": true, "off": Vector2(0, -44), "box": Vector2(54, 70),
				"delay": 12, "show": true, "life": 54, "pierce": true, "share": 0.25, "knock": 0.0, "stun": 46,
				"sound": &"confirm"})
			for i in 3:
				_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(-6.0 + i * 6.0, -36.0 + (i % 2) * 8.0),
					"box": Vector2(40, 52), "delay": 34 + i * 10, "life": 11, "pierce": true, "share": 0.25,
					"knock": 200.0 if i == 2 else 50.0, "stun": 22, "nostatus": true, "sound": &"hit_light"})
		&"ideas":
			# Platón: tres copias ilusorias atacan desde delante, desde detrás y desde arriba.
			var tint := Color("b0d0ff")
			_spawn(cm, f, atk, {"art": &"clone", "color": tint, "at_opp": true, "off": Vector2(_opp_dx(f, -110.0), -26),
				"box": Vector2(22, 44), "dir": f.facing, "speed": 260.0, "delay": 8, "show": true, "life": 60,
				"share": 1.0 / 3.0, "knock": 110.0, "stun": 24, "sound": &"whoosh"})
			_spawn(cm, f, atk, {"art": &"clone", "color": tint, "at_opp": true, "off": Vector2(_opp_dx(f, 110.0), -26),
				"box": Vector2(22, 44), "dir": -f.facing, "speed": 260.0, "delay": 18, "show": true, "life": 60,
				"share": 1.0 / 3.0, "knock": 110.0, "stun": 24, "sound": &"whoosh"})
			_spawn(cm, f, atk, {"art": &"clone", "color": tint, "at_opp": true, "off": Vector2(0, -150), "box": Vector2(22, 44),
				"vy": 300.0, "floor_y": f.floor_y - 4.0, "delay": 28, "show": true, "life": 60, "share": 1.0 / 3.0,
				"knock": 160.0, "stun": 26, "shake": 2.0, "sound": &"whoosh"})
		&"logic":
			# Aristóteles: analiza al rival y descarga tres golpes calculados al milímetro.
			_spawn(cm, f, atk, {"art": &"logic", "at_opp": true, "off": Vector2(0, -36), "box": Vector2(44, 66),
				"delay": 10, "show": true, "life": 48, "pierce": true, "share": 0.1, "knock": 0.0, "stun": 40,
				"sound": &"confirm"})
			var shares: Array[float] = [0.25, 0.25, 0.4]
			for i in 3:
				_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -50.0 + i * 14.0), "box": Vector2(42, 40),
					"delay": 30 + i * 10, "life": 11, "pierce": true, "share": shares[i], "knock": 260.0 if i == 2 else 40.0,
					"launch": -200.0 if i == 2 else 0.0, "stun": 24, "shake": 3.0 if i == 2 else 0.0,
					"sound": &"hit_heavy" if i == 2 else &"hit_light"})
		&"art_of_war":
			# Sun Tzu: deja una ilusión que carga de frente y reaparece detrás del rival.
			var o := f.opponent
			_visual(cm, f, f.position + Vector2(0, -26), {"art": &"clone", "color": Color("ffd890"), "box": Vector2(22, 44),
				"speed": 170.0, "life": 30})
			_visual(cm, f, f.position + Vector2(0, -30), {"art": &"smoke", "color": Color("c8c0b0"), "box": Vector2(30, 50),
				"life": 30})
			f.teleport_behind(o)
			_visual(cm, f, f.position + Vector2(0, -30), {"art": &"smoke", "color": Color("c8c0b0"), "box": Vector2(30, 50),
				"life": 30})
			_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -40), "box": Vector2(36, 52),
				"delay": 6, "life": 12, "pierce": true, "share": 0.4, "knock": 40.0, "stun": 22, "sound": &"hit_light"})
			_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -30), "box": Vector2(40, 52),
				"delay": 18, "life": 12, "pierce": true, "share": 0.6, "knock": 230.0, "stun": 26, "shake": 3.0,
				"sound": &"hit_heavy"})
		&"celestial_order":
			# Confucio: símbolos luminosos que golpean y empujan al rival.
			for i in 3:
				_spawn(cm, f, atk, {"art": &"glyph", "color": Color("ffd860"), "off": Vector2(22, -60.0 + i * 16.0),
					"box": Vector2(18, 18), "speed": 215.0, "delay": i * 8, "life": 84, "share": 1.0 / 3.0,
					"knock": 170.0, "stun": 20, "clash": true, "sound": &"confirm"})
		&"gravity_absolute":
			# Newton: levanta al rival, lo deja suspendido y lo estrella contra el suelo.
			_spawn(cm, f, atk, {"art": &"gravity", "at_opp": true, "off": Vector2(0, -36), "box": Vector2(46, 72),
				"delay": 14, "show": true, "life": 36, "pierce": true, "share": 0.35, "knock": 0.0, "stun": 75,
				"sound": &"confirm"})
			_spawn(cm, f, atk, {"art": &"gravslam", "at_opp": true, "off": Vector2(0, -50), "box": Vector2(46, 100),
				"delay": 60, "life": 18, "pierce": true, "share": 0.65, "knock": 140.0, "launch": 320.0, "stun": 34,
				"nostatus": true, "shake": 6.0, "sound": &"hit_heavy"})
			_stones_later(cm, f.opponent.position.x, 62)
		&"conquest":
			# Cortés: jinetes y soldados con pica atraviesan la pantalla.
			_spawn(cm, f, atk, {"art": &"conquistadors", "off": Vector2(-20, -18), "box": Vector2(58, 40), "speed": 250.0,
				"life": 114, "pierce": true, "share": 0.55, "knock": 120.0, "stun": 30, "sound": &"whoosh"})
			_spawn(cm, f, atk, {"art": &"tercio", "off": Vector2(-30, -15), "box": Vector2(58, 34), "speed": 200.0,
				"delay": 16, "life": 120, "pierce": true, "share": 0.45, "knock": 280.0, "launch": -130.0, "stun": 28,
				"sound": &"whoosh"})
		&"huitzilopochtli":
			# Moctezuma: aparece la figura del sol y suelta una explosión de energía.
			_visual(cm, f, f.position + Vector2(-10.0 * f.facing, -96.0), {"art": &"sungod", "box": Vector2(100, 100),
				"life": 66, "show": true})
			_spawn(cm, f, atk, {"art": &"sphere", "color": Color("ffc040"), "off": Vector2(30, -50), "box": Vector2(30, 30),
				"speed": 240.0, "delay": 24, "life": 90, "boom": true, "knock": 290.0, "launch": -120.0, "stun": 30,
				"shake": 3.0, "sound": &"megaphone"})
		&"the_prince":
			# Maquiavelo: deja una ilusión, reaparece tras el rival, lo atrapa en un cepo y lo apuñala.
			var o := f.opponent
			_visual(cm, f, f.position + Vector2(0, -26), {"art": &"clone", "color": Color("d0a0a0"), "box": Vector2(22, 44),
				"life": 42})
			f.teleport_behind(o)
			_visual(cm, f, f.position + Vector2(0, -30), {"art": &"smoke", "color": Color("8a7a8a"), "box": Vector2(30, 50),
				"life": 30})
			_spawn(cm, f, atk, {"art": &"jaws", "at_opp": true, "off": Vector2(0, -10), "box": Vector2(44, 20),
				"delay": 8, "show": true, "life": 36, "pierce": true, "share": 0.3, "knock": 0.0, "stun": 34,
				"sound": &"hit_light"})
			_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -38), "box": Vector2(40, 52),
				"delay": 34, "life": 13, "pierce": true, "share": 0.7, "knock": 220.0, "stun": 26, "nostatus": true,
				"shake": 4.0, "sound": &"hit_heavy"})
		&"t34":
			# Mariya: su T-34 cruza el escenario disparando y remata con una explosión.
			_spawn(cm, f, atk, {"art": &"tank", "off": Vector2(-34, -14), "box": Vector2(60, 28), "speed": 160.0,
				"life": 144, "pierce": true, "share": 0.35, "knock": 40.0, "stun": 30, "sound": &"hit_heavy"})
			for i in 3:
				_spawn(cm, f, atk, {"style": &"ball", "off": Vector2(14, -26), "box": Vector2(12, 12), "speed": 300.0,
					"delay": 10 + i * 12, "life": 72, "share": 0.1, "knock": 30.0, "stun": 24, "sound": &"cannon"})
			_spawn(cm, f, atk, {"art": &"lightburst", "at_opp": true, "off": Vector2(0, -32), "box": Vector2(66, 72),
				"delay": 58, "life": 21, "pierce": true, "share": 0.35, "knock": 200.0, "launch": -300.0, "stun": 36,
				"shake": 6.0, "sound": &"hit_heavy"})
		&"death_shot":
			# Liudmila: la mira se cierra sobre el rival (tiempo lento) y una bala de energía lo atraviesa.
			_spawn(cm, f, atk, {"art": &"scope", "color": Color("ff6060"), "at_opp": true, "off": Vector2(0, -40),
				"box": Vector2(44, 44), "delay": 14, "show": true, "life": 30, "pierce": true, "share": 0.15,
				"knock": 0.0, "stun": 40, "sound": &"confirm"})
			_spawn(cm, f, atk, {"art": &"tracer", "color": Color("ffe080"), "off": Vector2(26, -46), "box": Vector2(26, 10),
				"speed": 560.0, "delay": 34, "life": 48, "pierce": true, "share": 0.85, "knock": 270.0, "stun": 30,
				"nostatus": true, "shake": 4.0, "sound": &"cannon"})
		&"ult":
			_cast_ultimate(cm, f, atk)
		_:
			push_warning("PowerEffects: poder desconocido «%s»" % atk.power)

## Escudo de Allende: devuelve al que atacó una onda roja con el daño de su poder.
static func reflect(cm: CombatManager, f: Fighter, foe: Fighter) -> void:
	var atk := f.data.special_2
	if atk == null:
		return
	f.face_towards(foe)
	_spawn(cm, f, atk, {"art": &"bigwave", "color": Color("e03030"), "off": Vector2(26, -40), "box": Vector2(26, 44),
		"speed": 270.0, "life": 90, "knock": 260.0, "stun": 28, "shake": 3.0, "sound": &"hit_heavy"})

# =========================================================================
#  Ultimates: cada tipo es una escena a pantalla completa (golpes múltiples + ambiente)
# =========================================================================
## Caja (ancho, alto) y altura del centro respecto a los pies de los dibujos que se lanzan.
const ART_GEOM := {
	&"horses": [66.0, 34.0, -16.0], &"toqui": [58.0, 36.0, -22.0], &"chariot": [76.0, 36.0, -18.0],
	&"legion": [62.0, 44.0, -22.0], &"caravel": [78.0, 44.0, -18.0], &"shipfull": [130.0, 90.0, -42.0],
	&"bear": [40.0, 28.0, -13.0], &"dragon": [64.0, 30.0, -50.0], &"jackal": [50.0, 30.0, -14.0],
	&"guard": [44.0, 40.0, -20.0], &"monkeys": [48.0, 42.0, -20.0], &"corgis": [70.0, 24.0, -12.0],
	&"bell_wave": [24.0, 54.0, -30.0], &"ghost_army": [50.0, 40.0, -20.0], &"galleon": [88.0, 52.0, -26.0],
}

## Programa un evento de pantalla dentro de `delay` frames de combate (si el efecto existe).
static func _ufx(cm: CombatManager, delay: int, type: StringName, args: Dictionary = {}) -> void:
	cm.ult_fx_at(delay, type, args)

static func _cast_ultimate(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	if not cm.has_ult_fx():
		cm.start_ult_fx(atk)
	match atk.ult_kind:
		&"barrage": _ult_barrage(cm, f, atk)
		&"charge": _ult_charge(cm, f, atk)
		&"quake": _ult_quake(cm, f, atk)
		&"storm": _ult_storm(cm, f, atk)
		&"light": _ult_light(cm, f, atk)
		&"wave": _ult_wave(cm, f, atk)
		&"summon": _ult_summon(cm, f, atk)
		&"meteor": _ult_meteor(cm, f, atk)
		&"slash": _ult_slash(cm, f, atk)
		&"trap": _ult_trap(cm, f, atk)
		&"snipe": _ult_snipe(cm, f, atk)
		&"chains": _ult_chains(cm, f, atk)
		&"oprichnina": _ult_oprichnina(cm, f, atk)
		&"codex": _ult_codex(cm, f, atk)
		&"army": _ult_army(cm, f, atk)
		&"nuke": _ult_nuke(cm, f, atk)
		&"bribe": _ult_bribe(cm, f, atk)
		&"plagues": _ult_plagues(cm, f, atk)
		&"ides": _ult_ides(cm, f, atk)
		&"inferno": _ult_inferno(cm, f, atk)
		&"tidal": _ult_tidal(cm, f, atk)
		&"judo": _ult_judo(cm, f, atk)
		&"censor": _ult_censor(cm, f, atk)
		&"arc": _ult_arc(cm, f, atk)
		&"spacetime": _ult_spacetime(cm, f, atk)
		&"nirvana": _ult_nirvana(cm, f, atk)
		&"presser": _ult_presser(cm, f, atk)
		&"guerrilla": _ult_guerrilla(cm, f, atk)
		&"bombing": _ult_bombing(cm, f, atk)
		&"defense": _ult_defense(cm, f, atk)
		&"miracle": _ult_miracle(cm, f, atk)
		&"pyre": _ult_pyre(cm, f, atk)
		&"stonewalls": _ult_stonewalls(cm, f, atk)
		&"mass": _ult_mass(cm, f, atk)
		_: push_warning("PowerEffects: tipo de ultimate desconocido «%s»" % atk.ult_kind)

## Lluvia de bombas sobre toda la zona del rival; cada impacto abre una grieta.
static func _ult_barrage(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	# Las bombas centrales caen sobre el rival (casi todo el daño); las de los lados abren el suelo.
	var order: Array[float] = [0.0, -15.0, 15.0, -30.0, 30.0, -50.0, 50.0, -75.0, 75.0, -100.0, 100.0, -130.0, 130.0]
	var weight: Array[float] = []
	var total := 0.0
	for off in order:
		var w := 1.0 if absf(off) <= 30.0 else 0.12
		weight.append(w)
		total += w
	var fall := 51
	var art := atk.ult_art if atk.ult_art != &"" else &"bomb"
	for i in order.size():
		var d := {"off": Vector2(order[i], -f.floor_y + 10.0), "at_opp": true, "box": Vector2(20, 20), "speed": 0.0,
			"accel_y": 520.0, "floor_y": f.floor_y - 2.0, "boom": true, "color": atk.ult_color, "delay": 4 + i * 6,
			"life": 108, "share": weight[i] / total, "knock": 40.0, "stun": 26}
		if art == &"bill":
			d["style"] = &"spin"
			d["box"] = Vector2(18, 14)
			d["boom"] = false
		else:
			d["art"] = art
		_spawn(cm, f, atk, d)
		var t := 4 + i * 6 + fall
		_ufx(cm, t, &"crack", {"x": o + order[i] * f.facing, "len": 60.0, "shake": 2.5})
	_ufx(cm, 24, &"flash", {"amount": 0.3})

## Estampida: tres oleadas cruzan la pantalla rompiendo el suelo a su paso.
static func _ult_charge(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var g: Array = ART_GEOM.get(atk.ult_art, [60.0, 34.0, -18.0])
	for i in 3:
		_spawn(cm, f, atk, {"art": atk.ult_art, "off": Vector2(-24.0 - i * 16.0, g[2]), "box": Vector2(g[0], g[1]),
			"speed": 320.0, "delay": i * 18, "life": 126, "pierce": true, "share": 1.0 / 3.0, "knock": 300.0,
			"launch": -150.0 if i == 2 else 0.0, "stun": 28, "shake": 3.0, "sound": &"whoosh"})
	for k in 9:
		var x := f.position.x + f.facing * (30.0 + k * 38.0)
		_ufx(cm, 6 + k * 6, &"crack", {"x": x, "len": 50.0, "shake": 2.0})
		_ufx(cm, 6 + k * 6, &"dust", {"x": x})

## Terremoto: el suelo se parte, suben rocas y cae polvo del techo.
static func _ult_quake(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	var offs: Array[float] = [0.0, -70.0, 70.0, -140.0, 140.0]
	for i in offs.size():
		_spawn(cm, f, atk, {"art": &"quake", "at_opp": true, "off": Vector2(offs[i], -12.0), "box": Vector2(84, 26),
			"delay": 8 + i * 12, "show": true, "life": 30, "pierce": true, "share": 1.0 / float(offs.size()), "knock": 120.0,
			"launch": -230.0 if i == 0 else 0.0, "stun": 40, "shake": 6.0, "sound": &"hit_heavy"})
		var t := 8 + i * 12
		_ufx(cm, t, &"crack", {"x": o + offs[i] * f.facing, "len": 130.0, "shake": 5.0})
		_ufx(cm, t, &"debris", {"x": o + offs[i] * f.facing})
	_ufx(cm, 0, &"flash", {"amount": 0.5})

## Tormenta: rayos que caen sobre el rival, con relámpagos que iluminan toda la pantalla.
static func _ult_storm(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	var offs: Array[float] = [0.0, -70.0, 60.0, -30.0, 90.0, -95.0, 30.0]
	for i in offs.size():
		var delay := 10 + i * 9
		_spawn(cm, f, atk, {"art": &"icebolt", "at_opp": true, "off": Vector2(offs[i], -105.0), "box": Vector2(20, 210),
			"delay": delay, "show": true, "life": 18, "pierce": true, "share": 1.0 / float(offs.size()), "knock": 90.0,
			"stun": 22, "sound": &"hit_heavy", "color": atk.ult_color if i % 2 == 0 else Color.WHITE})
		var t := delay
		_ufx(cm, t, &"bolt")
		_ufx(cm, t, &"crack", {"x": o + offs[i] * f.facing, "len": 40.0, "shake": 1.0})

## Luz: tres pilares sagrados y una explosión final que lanza al rival.
static func _ult_light(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	var offs: Array[float] = [0.0, -55.0, 55.0]
	for i in offs.size():
		_spawn(cm, f, atk, {"art": &"lightpillar", "at_opp": true, "off": Vector2(offs[i], -105.0), "box": Vector2(40, 210),
			"delay": 12 + i * 12, "show": true, "life": 36, "pierce": true, "share": 0.22, "knock": 60.0, "stun": 26,
			"color": atk.ult_color, "sound": &"confirm"})
		_ufx(cm, 12 + i * 12, &"crack", {"x": o + offs[i] * f.facing, "len": 70.0, "shake": 2.0})
	_spawn(cm, f, atk, {"art": &"ring", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -36), "box": Vector2(190, 90),
		"delay": 52, "show": true, "life": 30, "pierce": true, "radial": true, "share": 0.34, "knock": 320.0,
		"launch": -260.0, "stun": 40, "shake": 7.0, "sound": &"hit_heavy"})
	_ufx(cm, 52, &"ring", {"x": o})
	_ufx(cm, 52, &"flash", {"amount": 0.7})

## Ondas de choque concéntricas que recorren el suelo.
static func _ult_wave(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	var art := atk.ult_art if atk.ult_art != &"" else &"ring"
	for i in 4:
		_spawn(cm, f, atk, {"art": art, "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -36), "box": Vector2(230, 96),
			"delay": 10 + i * 16, "show": true, "life": 24, "pierce": true, "radial": true, "share": 0.25, "knock": 240.0,
			"launch": -230.0 if i == 3 else 0.0, "stun": 30, "shake": 4.0, "sound": &"confirm"})
		_ufx(cm, 10 + i * 16, &"ring", {"x": o})
		_ufx(cm, 10 + i * 16, &"crack", {"x": o, "len": 40.0 + i * 25.0, "shake": 3.0})

## Invocación: aliados que llegan desde los dos lados y aplastan al rival.
static func _ult_summon(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	var g: Array = ART_GEOM.get(atk.ult_art, [50.0, 34.0, -18.0])
	var n := 0
	for wave in 2:
		for side in [-1, 1]:
			_spawn(cm, f, atk, {"art": atk.ult_art, "at_opp": true, "off": Vector2(side * 190.0 * f.facing, g[2]),
				"dir": -side, "box": Vector2(g[0], g[1]), "speed": 230.0, "delay": wave * 26 + (0 if side < 0 else 6),
				"life": 114, "pierce": true, "share": 0.25, "knock": 220.0, "launch": -120.0 if wave == 1 else 0.0,
				"stun": 26, "shake": 3.0, "sound": &"whoosh"})
			n += 1
	for k in 6:
		_ufx(cm, 18 + roundi(k * 10.8), &"crack", {"x": o + (-1.0 if k % 2 == 0 else 1.0) * (20.0 + k * 22.0), "len": 60.0, "shake": 2.5})
		_ufx(cm, 18 + roundi(k * 10.8), &"dust", {"x": o + (-1.0 if k % 2 == 0 else 1.0) * (30.0 + k * 20.0)})

## Meteoritos que arrasan la pantalla: unos golpean al rival y otros hunden el suelo.
static func _ult_meteor(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	var art := atk.ult_art if atk.ult_art != &"" else &"meteor"
	var hits: Array[float] = [0.0, -45.0, 45.0, -90.0, 90.0]
	var fall := 57
	for i in hits.size():
		_spawn(cm, f, atk, {"art": art, "color": atk.ult_color, "at_opp": true, "off": Vector2(hits[i], -f.floor_y + 4.0),
			"box": Vector2(24, 24), "speed": 0.0, "accel_y": 520.0, "floor_y": f.floor_y - 2.0, "boom": true,
			"delay": 6 + i * 9, "life": 120, "share": 0.2, "knock": 200.0, "stun": 28})
		_ufx(cm, 6 + i * 9 + fall, &"crack", {"x": o + hits[i] * f.facing, "len": 90.0, "shake": 4.0})
	# Meteoritos de adorno por toda la pantalla.
	var decor: Array[float] = [-170.0, -130.0, 130.0, 170.0, -110.0, 110.0]
	for i in decor.size():
		_visual(cm, f, Vector2(o + decor[i] * f.facing, 0.0), {"art": art, "color": atk.ult_color, "box": Vector2(24, 24),
			"vy": 280.0, "delay": 14 + i * 8, "life": 78})
		_ufx(cm, 14 + i * 8 + 60, &"crack", {"x": o + decor[i] * f.facing, "len": 60.0, "shake": 2.0})

## Lluvia de cortes: el rival recibe una ráfaga y un tajo final que lo lanza.
static func _ult_slash(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var offs: Array[float] = [-30.0, 25.0, -10.0, 35.0, -35.0, 15.0, 0.0, 30.0, -20.0]
	for i in offs.size():
		_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(offs[i], -36.0 + (i % 3) * 8.0),
			"box": Vector2(46, 60), "delay": 6 + i * 6, "life": 12, "pierce": true, "share": 0.07,
			"knock": 60.0, "stun": 18, "sound": &"hit_light"})
		_ufx(cm, 6 + i * 6, &"cut")
	_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -40), "box": Vector2(90, 100), "delay": 66,
		"show": true, "life": 18, "pierce": true, "share": 0.37, "knock": 320.0, "launch": -260.0, "stun": 40,
		"shake": 7.0, "sound": &"hit_heavy"})
	_ufx(cm, 66, &"crack", {"x": f.opponent.position.x, "len": 120.0, "shake": 6.0})
	_ufx(cm, 66, &"flash", {"amount": 0.7})

## Trampa: un objeto gigante (copa, caverna, pizarra, estatua, libro, manzana, disco solar)
## cae o se cierra sobre el rival, lo golpea varias veces y lo despide con un estallido final.
static func _ult_trap(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	var drop := 40
	_spawn(cm, f, atk, {"art": atk.ult_art, "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -50),
		"box": Vector2(66, 100), "delay": drop, "show": true, "life": 84, "pierce": true, "rehit": 16, "max_hits": 4,
		"share": 0.15, "knock": 0.0, "stun": 30, "shake": 6.0, "sound": &"hit_heavy"})
	_ufx(cm, drop, &"crack", {"x": o, "len": 110.0, "shake": 5.0})
	_ufx(cm, drop, &"debris", {"x": o})
	_ufx(cm, drop, &"flash", {"amount": 0.4})
	_spawn(cm, f, atk, {"art": &"ring", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -36), "box": Vector2(190, 90),
		"delay": drop + 80, "show": true, "life": 27, "pierce": true, "radial": true, "share": 0.4, "knock": 330.0,
		"launch": -280.0, "stun": 40, "shake": 7.0, "sound": &"hit_heavy"})
	_ufx(cm, drop + 80, &"ring", {"x": o})
	_ufx(cm, drop + 80, &"flash", {"amount": 0.8})

## Disparo: la pantalla se oscurece, se apunta al rival (mira o cañón del tanque) y un
## único disparo lo derriba dentro de una nube de humo.
static func _ult_snipe(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	var shot := 70
	if atk.ult_art == &"tank":
		# El tanque entra en primer plano por detrás de quien lo lanza.
		_visual(cm, f, f.position + Vector2(-70.0 * f.facing, -16.0), {"art": &"tank", "box": Vector2(70, 34),
			"speed": 60.0, "life": 96, "show": true})
	else:
		_visual(cm, f, f.opponent.position + Vector2(0, -40), {"art": &"scope", "color": atk.ult_color,
			"box": Vector2(70, 70), "life": shot, "show": true})
	_spawn(cm, f, atk, {"art": &"lightburst", "at_opp": true, "off": Vector2(0, -40), "box": Vector2(60, 76),
		"delay": shot, "life": 21, "pierce": true, "share": 0.7, "knock": 340.0, "launch": -240.0, "stun": 44,
		"shake": 8.0, "sound": &"cannon"})
	_spawn(cm, f, atk, {"art": &"smoke", "color": Color("4a4440"), "at_opp": true, "off": Vector2(0, -30),
		"box": Vector2(80, 70), "delay": shot + 4, "show": false, "life": 60, "pierce": true, "rehit": 12,
		"max_hits": 3, "share": 0.1, "knock": 40.0, "stun": 20})
	_ufx(cm, shot, &"flash", {"amount": 1.0})
	_ufx(cm, shot, &"crack", {"x": o, "len": 120.0, "shake": 6.0})
	_ufx(cm, shot, &"debris", {"x": o})

## Lincoln: unas cadenas inmovilizan al rival, el hacha las rompe a golpes y la onda final lo libera... lejos.
static func _ult_chains(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	_spawn(cm, f, atk, {"art": &"chains", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -36),
		"box": Vector2(54, 76), "delay": 14, "show": true, "life": 24, "pierce": true, "share": 0.12, "knock": 0.0,
		"stun": 40, "status": &"root", "status_frames": 120, "shake": 3.0, "sound": &"hit_heavy"})
	_ufx(cm, 14, &"crack", {"x": o, "len": 60.0, "shake": 3.0})
	for i in 4:
		_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(-8.0 + i * 5.0, -40.0 + (i % 2) * 10.0),
			"box": Vector2(44, 56), "delay": 46 + i * 12, "life": 11, "pierce": true, "share": 0.12, "knock": 40.0,
			"stun": 26, "sound": &"hit_light"})
		_ufx(cm, 46 + i * 12, &"cut")
	_spawn(cm, f, atk, {"art": &"ring", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -36),
		"box": Vector2(190, 90), "delay": 108, "show": true, "life": 27, "pierce": true, "radial": true, "share": 0.4,
		"knock": 330.0, "launch": -270.0, "stun": 40, "shake": 7.0, "sound": &"hit_heavy"})
	_ufx(cm, 108, &"ring", {"x": o})
	_ufx(cm, 108, &"flash", {"amount": 0.7})

## Iván: la Oprichnina. Jinetes del zar cabalgan desde los dos lados, el rival queda lento y una columna
## de hielo cierra la purga.
static func _ult_oprichnina(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	for i in 4:
		var side := -1 if i % 2 == 0 else 1
		var d := {"art": &"horse", "at_opp": true, "off": Vector2(side * 190.0 * f.facing, -16.0), "dir": -side,
			"box": Vector2(40, 30), "speed": 250.0, "delay": 8 + i * 14, "life": 114, "pierce": true, "share": 0.15,
			"knock": 140.0, "stun": 26, "shake": 2.0, "sound": &"whoosh"}
		if i == 0:
			d["status"] = &"slow"
			d["status_frames"] = 150
		_spawn(cm, f, atk, d)
	for k in 6:
		_ufx(cm, 16 + k * 10, &"dust", {"x": o + (-1.0 if k % 2 == 0 else 1.0) * (30.0 + k * 20.0)})
	_spawn(cm, f, atk, {"art": &"icebolt", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -105),
		"box": Vector2(36, 210), "delay": 96, "show": true, "life": 24, "pierce": true, "share": 0.4,
		"knock": 320.0, "launch": -260.0, "stun": 40, "shake": 7.0, "sound": &"hit_heavy"})
	_ufx(cm, 96, &"bolt")
	_ufx(cm, 96, &"crack", {"x": o, "len": 110.0, "shake": 6.0})
	_ufx(cm, 96, &"flash", {"amount": 0.7})

## Da Vinci: el Códice de inventos. Un carro blindado arrolla, una ballesta gigante dispara y el
## Hombre de Vitruvio estalla como remate.
static func _ult_codex(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	_spawn(cm, f, atk, {"art": &"tank", "off": Vector2(-34, -14), "box": Vector2(60, 28), "speed": 210.0,
		"delay": 6, "life": 130, "pierce": true, "share": 0.25, "knock": 200.0, "stun": 28, "shake": 2.0,
		"sound": &"hit_heavy"})
	for i in 3:
		_spawn(cm, f, atk, {"art": &"tracer", "color": atk.ult_color, "off": Vector2(26, -56.0 + i * 12.0),
			"box": Vector2(26, 10), "speed": 520.0, "delay": 40 + i * 12, "life": 48, "pierce": true, "share": 0.12,
			"knock": 60.0, "stun": 22, "sound": &"cannon"})
	_spawn(cm, f, atk, {"art": &"ring", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -36),
		"box": Vector2(190, 90), "delay": 96, "show": true, "life": 27, "pierce": true, "radial": true, "share": 0.39,
		"knock": 330.0, "launch": -270.0, "stun": 40, "shake": 7.0, "sound": &"hit_heavy"})
	_ufx(cm, 96, &"ring", {"x": o})
	_ufx(cm, 96, &"flash", {"amount": 0.7})

## Remate común: anillo que lanza al rival (`share` del daño), con su grieta y destello.
static func _finisher(cm: CombatManager, f: Fighter, atk: AttackData, delay: int, share: float) -> void:
	var o := f.opponent.position.x
	_spawn(cm, f, atk, {"art": &"ring", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -36),
		"box": Vector2(190, 90), "delay": delay, "show": true, "life": 27, "pierce": true, "radial": true, "share": share,
		"knock": 330.0, "launch": -270.0, "stun": 40, "shake": 7.0, "sound": &"hit_heavy"})
	_ufx(cm, delay, &"ring", {"x": o})
	_ufx(cm, delay, &"crack", {"x": o, "len": 110.0, "shake": 6.0})
	_ufx(cm, delay, &"flash", {"amount": 0.7})

## Napoleón: la Grande Armée avanza en columnas (infantería y caballería) y remata la Guardia Imperial.
static func _ult_army(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	for i in 3:
		_spawn(cm, f, atk, {"art": &"legion", "off": Vector2(-40.0 - i * 30.0, -15.0), "box": Vector2(58, 34),
			"speed": 170.0, "delay": i * 16, "life": 130, "pierce": true, "share": 0.2, "knock": 120.0, "stun": 26,
			"sound": &"whoosh"})
	_spawn(cm, f, atk, {"art": &"horse", "off": Vector2(-30, -16), "box": Vector2(40, 30), "speed": 300.0,
		"delay": 60, "life": 100, "pierce": true, "share": 0.15, "knock": 260.0, "launch": -120.0, "stun": 28,
		"sound": &"whoosh"})
	for k in 8:
		_ufx(cm, 10 + k * 8, &"dust", {"x": f.position.x + f.facing * (20.0 + k * 40.0)})
	_finisher(cm, f, atk, 104, 0.25)

## Kim: cuenta atrás y un único misil gigante que cae sobre el rival.
static func _ult_nuke(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	_spawn(cm, f, atk, {"art": &"bomb", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -f.floor_y + 4.0),
		"box": Vector2(40, 40), "speed": 0.0, "accel_y": 420.0, "floor_y": f.floor_y - 2.0, "boom": true,
		"delay": 30, "life": 120, "share": 0.3, "knock": 100.0, "stun": 30})
	_ufx(cm, 30 + 62, &"crack", {"x": o, "len": 140.0, "shake": 8.0})
	_ufx(cm, 30 + 62, &"flash", {"amount": 1.0})
	_finisher(cm, f, atk, 96, 0.7)

## Escobar: plata o plomo. Los billetes ciegan de codicia (controles cambiados) y el plomo remata.
static func _ult_bribe(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	for i in 10:
		var d := {"style": &"spin", "color": Color("50c060"), "at_opp": true,
			"off": Vector2(-60.0 + (i % 5) * 30.0, -f.floor_y + 10.0), "box": Vector2(18, 14), "speed": 0.0,
			"accel_y": 380.0, "floor_y": f.floor_y - 2.0, "delay": 6 + i * 6, "life": 110, "share": 0.05,
			"knock": 30.0, "stun": 24}
		if i == 0:
			d["status"] = &"invert"
			d["status_frames"] = 150
		_spawn(cm, f, atk, d)
	for i in 4:
		_spawn(cm, f, atk, {"art": &"tracer", "color": atk.ult_color, "at_opp": true,
			"off": Vector2(_opp_dx(f, -150.0), -50.0 + i * 8.0), "box": Vector2(26, 10), "dir": f.facing,
			"speed": 520.0, "delay": 76 + i * 8, "life": 40, "pierce": true, "share": 0.1, "knock": 60.0,
			"stun": 24, "sound": &"cannon"})
	_finisher(cm, f, atk, 116, 0.1)
	_ufx(cm, 116, &"flash", {"amount": 0.3})

## Cleopatra: las plagas de Egipto. Langostas, granizo y la última plaga.
static func _ult_plagues(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	_spawn(cm, f, atk, {"art": &"sandstorm", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -30),
		"box": Vector2(70, 70), "delay": 10, "show": true, "life": 70, "pierce": true, "rehit": 14, "max_hits": 4,
		"share": 0.08, "knock": 20.0, "stun": 22, "status": &"slow", "status_frames": 120})
	var offs: Array[float] = [-60.0, 40.0, -20.0, 70.0, 0.0]
	for i in offs.size():
		_spawn(cm, f, atk, {"art": &"meteor", "color": Color("a0e0ff"), "at_opp": true,
			"off": Vector2(offs[i], -f.floor_y + 4.0), "box": Vector2(20, 20), "speed": 0.0, "accel_y": 520.0,
			"floor_y": f.floor_y - 2.0, "boom": true, "delay": 40 + i * 10, "life": 110, "share": 0.08,
			"knock": 80.0, "stun": 26})
		_ufx(cm, 40 + i * 10 + 55, &"crack", {"x": o + offs[i] * f.facing, "len": 50.0, "shake": 2.0})
	_finisher(cm, f, atk, 110, 0.28)

## César: los idus de marzo. La legión rodea al rival y llegan las puñaladas de todos lados.
static func _ult_ides(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	for side in [-1, 1]:
		_spawn(cm, f, atk, {"art": &"legion", "at_opp": true, "off": Vector2(side * 190.0 * f.facing, -15.0),
			"dir": -side, "box": Vector2(58, 34), "speed": 200.0, "delay": 0 if side < 0 else 6, "life": 110,
			"pierce": true, "share": 0.1, "knock": 80.0, "stun": 24, "sound": &"whoosh"})
	for i in 6:
		_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(-30.0 + (i % 3) * 30.0, -30.0 - (i % 2) * 14.0),
			"box": Vector2(40, 52), "delay": 44 + i * 9, "life": 11, "pierce": true, "share": 0.08, "knock": 40.0,
			"stun": 22, "sound": &"hit_light"})
		_ufx(cm, 44 + i * 9, &"cut")
	_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -40), "box": Vector2(90, 100), "delay": 110,
		"show": true, "life": 18, "pierce": true, "share": 0.32, "knock": 320.0, "launch": -260.0, "stun": 40,
		"shake": 7.0, "sound": &"hit_heavy"})
	_ufx(cm, 110, &"crack", {"x": o, "len": 120.0, "shake": 6.0})
	_ufx(cm, 110, &"flash", {"amount": 0.7})

## Boudica: Londinium en llamas. Columnas de fuego avanzan hasta el rival y el grito de guerra remata.
static func _ult_inferno(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	for i in 5:
		var x := lerpf(40.0, absf(o - f.position.x), float(i) / 4.0)
		_spawn(cm, f, atk, {"art": &"lightpillar", "color": Color("ff6030"), "off": Vector2(x, -105.0),
			"box": Vector2(40, 210), "delay": 10 + i * 12, "show": true, "life": 36, "pierce": true, "share": 0.15,
			"knock": 80.0, "stun": 24, "sound": &"hit_heavy"})
		_ufx(cm, 10 + i * 12, &"crack", {"x": f.position.x + f.facing * x, "len": 60.0, "shake": 2.0})
	_finisher(cm, f, atk, 84, 0.25)

## Colón: tormenta en el Atlántico. Una ola gigante embiste y la flota bombardea.
static func _ult_tidal(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	_spawn(cm, f, atk, {"art": &"bigwave", "off": Vector2(20, -50), "box": Vector2(50, 100), "speed": 220.0,
		"delay": 8, "life": 120, "pierce": true, "share": 0.45, "knock": 300.0, "launch": -120.0, "stun": 34,
		"shake": 4.0, "sound": &"megaphone"})
	var offs: Array[float] = [-50.0, 30.0, -10.0, 60.0]
	for i in offs.size():
		_spawn(cm, f, atk, {"art": &"bomb", "color": atk.ult_color, "at_opp": true,
			"off": Vector2(offs[i], -f.floor_y + 4.0), "box": Vector2(20, 20), "speed": 0.0, "accel_y": 520.0,
			"floor_y": f.floor_y - 2.0, "boom": true, "delay": 50 + i * 10, "life": 110, "share": 0.1,
			"knock": 100.0, "stun": 26})
		_ufx(cm, 50 + i * 10 + 55, &"crack", {"x": o + offs[i] * f.facing, "len": 60.0, "shake": 3.0})
	_finisher(cm, f, atk, 120, 0.15)

## Putin: llave de judo. Agarra, golpea de cerca y lo estrella contra el tatami.
static func _ult_judo(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(0, -36), "box": Vector2(46, 60), "delay": 12,
		"life": 14, "pierce": true, "share": 0.1, "knock": 0.0, "stun": 40, "status": &"root", "status_frames": 80,
		"sound": &"hit_light"})
	for i in 3:
		_spawn(cm, f, atk, {"art": &"slash", "at_opp": true, "off": Vector2(-6.0 + i * 6.0, -36.0),
			"box": Vector2(40, 52), "delay": 28 + i * 10, "life": 11, "pierce": true, "share": 0.1, "knock": 30.0,
			"stun": 24, "sound": &"hit_light"})
	_spawn(cm, f, atk, {"art": &"gravslam", "at_opp": true, "off": Vector2(0, -50), "box": Vector2(46, 100),
		"delay": 66, "life": 18, "pierce": true, "share": 0.6, "knock": 140.0, "launch": 320.0, "stun": 34,
		"shake": 8.0, "sound": &"hit_heavy"})
	_stones_later(cm, o, 68)
	_ufx(cm, 66, &"crack", {"x": o, "len": 120.0, "shake": 7.0})
	_ufx(cm, 66, &"flash", {"amount": 0.6})

## Xi: gran cortafuegos. Los caracteres censuran al rival (controles cambiados) y la Gran Muralla lo aplasta.
static func _ult_censor(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	for i in 6:
		var d := {"art": &"glyph", "color": Color("ff4040"), "at_opp": true,
			"off": Vector2(-50.0 + (i % 3) * 50.0, -f.floor_y + 10.0), "box": Vector2(18, 18), "speed": 0.0,
			"accel_y": 380.0, "floor_y": f.floor_y - 2.0, "delay": 8 + i * 8, "life": 110, "share": 0.07,
			"knock": 30.0, "stun": 24}
		if i == 0:
			d["status"] = &"invert"
			d["status_frames"] = 160
		_spawn(cm, f, atk, d)
	_spawn(cm, f, atk, {"art": &"wall", "at_opp": true, "off": Vector2(0, -42), "box": Vector2(40, 84),
		"delay": 78, "show": true, "life": 27, "pierce": true, "share": 0.58, "knock": 160.0, "launch": -200.0,
		"stun": 36, "shake": 7.0, "sound": &"hit_heavy"})
	_stones_later(cm, o, 78)
	_ufx(cm, 78, &"crack", {"x": o, "len": 110.0, "shake": 6.0})
	_ufx(cm, 78, &"flash", {"amount": 0.6})

## Tesla: Wardenclyffe. Dos arcos eléctricos recorren el suelo hacia el rival y caen los rayos.
static func _ult_arc(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	for side in [-1, 1]:
		var d := {"art": &"groundwave", "color": atk.ult_color, "at_opp": true,
			"off": Vector2(side * 190.0 * f.facing, -6.0), "dir": -side, "box": Vector2(40, 16), "speed": 260.0,
			"delay": 0, "life": 100, "pierce": true, "share": 0.15, "knock": 60.0, "stun": 26, "shake": 2.0,
			"sound": &"hit_heavy"}
		if side < 0:
			d["status"] = &"root"
			d["status_frames"] = 70
		_spawn(cm, f, atk, d)
	var offs: Array[float] = [0.0, -45.0, 45.0, -20.0, 20.0]
	for i in offs.size():
		var delay := 48 + i * 10
		_spawn(cm, f, atk, {"art": &"icebolt", "color": atk.ult_color, "at_opp": true, "off": Vector2(offs[i], -105.0),
			"box": Vector2(20, 210), "delay": delay, "show": true, "life": 18, "pierce": true, "share": 0.12,
			"knock": 90.0, "stun": 22, "sound": &"hit_heavy"})
		_ufx(cm, delay, &"bolt")
		_ufx(cm, delay, &"crack", {"x": o + offs[i] * f.facing, "len": 40.0, "shake": 1.0})
	_finisher(cm, f, atk, 108, 0.1)

## Cura a quien lanza el ultimate (sin pasar de su vida máxima).
static func _heal(f: Fighter, amount: float) -> void:
	f.health = minf(f.health + amount, f.data.max_health)

## Einstein: frena el tiempo del rival y detona una esfera de energía (E = mc²).
static func _ult_spacetime(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	_spawn(cm, f, atk, {"art": &"timefield", "at_opp": true, "off": Vector2(0, -36), "box": Vector2(70, 80),
		"delay": 10, "show": true, "life": 40, "pierce": true, "share": 0.15, "knock": 0.0, "stun": 30,
		"status": &"slow", "status_frames": 170, "sound": &"confirm"})
	_spawn(cm, f, atk, {"art": &"sphere", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -40),
		"box": Vector2(70, 70), "delay": 64, "show": true, "life": 20, "pierce": true, "radial": true, "boom": true,
		"share": 0.45, "knock": 260.0, "stun": 34, "shake": 5.0, "sound": &"hit_heavy"})
	_ufx(cm, 64, &"flash", {"amount": 0.9})
	_finisher(cm, f, atk, 100, 0.4)

## Buda: se eleva, el rival queda en calma (inmóvil) entre ondas doradas y él recupera vida.
static func _ult_nirvana(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	f.hop(230.0)
	_heal(f, 12.0)
	for i in 3:
		var d := {"art": &"ring", "color": atk.ult_color, "at_opp": true, "off": Vector2(0, -40), "box": Vector2(150, 80),
			"delay": 12 + i * 22, "show": true, "life": 26, "pierce": true, "radial": true, "share": 0.2,
			"knock": 90.0, "stun": 32, "sound": &"confirm"}
		if i == 0:
			d["status"] = &"root"
			d["status_frames"] = 120
		_spawn(cm, f, atk, d)
		_ufx(cm, 12 + i * 22, &"ring", {"x": f.opponent.position.x})
	_finisher(cm, f, atk, 92, 0.4)

## Trump: rueda de prensa. Ráfagas de megáfono (fake news: controles cambiados) y lluvia de aranceles.
static func _ult_presser(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	for i in 6:
		var d := {"art": &"bigwave", "off": Vector2(30, -50), "box": Vector2(26, 38), "speed": 230.0,
			"delay": i * 9, "life": 84, "share": 0.08, "knock": 70.0, "stun": 26, "sound": &"megaphone"}
		if i == 0:
			d["status"] = &"invert"
			d["status_frames"] = 150
		_spawn(cm, f, atk, d)
	for i in 4:
		_spawn(cm, f, atk, {"style": &"spin", "color": Color("ffd040"), "at_opp": true,
			"off": Vector2(-45.0 + i * 30.0, -f.floor_y + 10.0), "box": Vector2(18, 14), "speed": 0.0,
			"accel_y": 380.0, "floor_y": f.floor_y - 2.0, "delay": 40 + i * 8, "life": 110, "share": 0.08,
			"knock": 30.0, "stun": 24})
	_finisher(cm, f, atk, 100, 0.2)

## Fidel: los barbudos disparan desde los dos lados y el discurso final remata.
static func _ult_guerrilla(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	for i in 8:
		var side := -1 if i % 2 == 0 else 1
		_spawn(cm, f, atk, {"art": &"tracer", "color": atk.ult_color, "at_opp": true,
			"off": Vector2(side * 170.0 * f.facing, -40.0 - (i % 3) * 8.0), "dir": -side, "box": Vector2(26, 10),
			"speed": 520.0, "delay": 8 + i * 8, "life": 44, "pierce": true, "share": 0.06, "knock": 40.0,
			"stun": 24, "sound": &"cannon"})
	_finisher(cm, f, atk, 96, 0.52)

## Pinochet: los cazas de la Fuerza Aérea bombardean La Moneda y la onda final cierra.
static func _ult_bombing(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	for k in 2:
		_visual(cm, f, f.position + Vector2(-30.0 * f.facing, -110.0 - k * 14.0), {"art": &"jet",
			"box": Vector2(50, 24), "speed": 240.0 + k * 30.0, "life": 132, "delay": k * 10, "show": true})
	var offs: Array[float] = [-60.0, 20.0, -20.0, 60.0, 0.0, -40.0]
	for i in offs.size():
		_spawn(cm, f, atk, {"art": &"bomb", "color": atk.ult_color, "at_opp": true,
			"off": Vector2(offs[i], -f.floor_y + 4.0), "box": Vector2(20, 20), "speed": 0.0, "accel_y": 520.0,
			"floor_y": f.floor_y - 2.0, "boom": true, "delay": 14 + i * 9, "life": 110, "share": 0.1,
			"knock": 90.0, "stun": 26})
		_ufx(cm, 14 + i * 9 + 55, &"crack", {"x": o + offs[i] * f.facing, "len": 60.0, "shake": 3.0})
	_finisher(cm, f, atk, 112, 0.4)

## Allende: se defiende en La Moneda con el fusil que le regaló Fidel: ráfaga larga y un último disparo.
static func _ult_defense(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	for i in 14:
		_spawn(cm, f, atk, {"art": &"tracer", "color": atk.ult_color, "off": Vector2(26, -46.0 + (i % 3) * 5.0),
			"box": Vector2(22, 8), "speed": 480.0, "delay": 8 + i * 4, "life": 46, "pierce": true, "share": 0.045,
			"knock": 30.0, "stun": 20, "sound": &"cannon"})
		if i % 3 == 0:
			_ufx(cm, 8 + i * 4, &"flash", {"amount": 0.15})
	_spawn(cm, f, atk, {"art": &"tracer", "color": Color("ffe080"), "off": Vector2(26, -46), "box": Vector2(34, 12),
		"speed": 560.0, "delay": 80, "life": 46, "pierce": true, "share": 0.37, "knock": 320.0, "launch": -200.0,
		"stun": 40, "shake": 6.0, "sound": &"cannon"})
	_ufx(cm, 90, &"crack", {"x": o, "len": 90.0, "shake": 5.0})
	_ufx(cm, 90, &"flash", {"amount": 0.6})

## Jesús: el milagro. El rival flota entre pilares de luz y Jesús recupera vida.
static func _ult_miracle(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	_heal(f, 15.0)
	for i in 3:
		var d := {"art": &"lightpillar", "color": atk.ult_color, "at_opp": true, "off": Vector2(-24.0 + i * 24.0, -105.0),
			"box": Vector2(40, 210), "delay": 12 + i * 12, "show": true, "life": 36, "pierce": true, "share": 0.15,
			"knock": 0.0, "stun": 30, "sound": &"confirm"}
		if i == 1:
			d["status"] = &"float"
			d["status_frames"] = 45
		_spawn(cm, f, atk, d)
		_ufx(cm, 12 + i * 12, &"crack", {"x": o + (-24.0 + i * 24.0) * f.facing, "len": 70.0, "shake": 2.0})
	_finisher(cm, f, atk, 80, 0.55)

## Juana: la hoguera. Una columna de llamas envuelve al rival y quema varias veces.
static func _ult_pyre(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	_spawn(cm, f, atk, {"art": &"lightpillar", "color": Color("ff7030"), "at_opp": true, "off": Vector2(0, -105),
		"box": Vector2(64, 210), "delay": 14, "show": true, "life": 76, "pierce": true, "rehit": 12, "max_hits": 5,
		"share": 0.12, "knock": 0.0, "stun": 26, "shake": 3.0, "sound": &"hit_heavy"})
	_ufx(cm, 14, &"crack", {"x": o, "len": 90.0, "shake": 4.0})
	_finisher(cm, f, atk, 96, 0.4)

## Pachacútec: muros incas se cierran sobre el rival y la tierra se abre.
static func _ult_stonewalls(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	var o := f.opponent.position.x
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		_spawn(cm, f, atk, {"art": &"wall", "at_opp": true, "off": Vector2(side * 22.0, -42), "box": Vector2(26, 84),
			"delay": 10 + i * 6, "show": true, "life": 27, "pierce": true, "share": 0.2, "knock": 60.0, "stun": 28,
			"shake": 4.0, "sound": &"hit_heavy"})
	_spawn(cm, f, atk, {"art": &"wall", "at_opp": true, "off": Vector2(0, -42), "box": Vector2(40, 84),
		"delay": 46, "show": true, "life": 27, "pierce": true, "share": 0.2, "knock": 60.0, "launch": 0.0,
		"stun": 34, "shake": 6.0, "sound": &"hit_heavy"})
	_stones_later(cm, o, 46)
	_spawn(cm, f, atk, {"art": &"quake", "at_opp": true, "off": Vector2(0, -12), "box": Vector2(120, 26),
		"delay": 84, "show": true, "life": 30, "pierce": true, "share": 0.4, "knock": 120.0, "launch": -260.0,
		"stun": 40, "shake": 7.0, "sound": &"hit_heavy"})
	_ufx(cm, 84, &"crack", {"x": o, "len": 130.0, "shake": 6.0})
	_ufx(cm, 84, &"debris", {"x": o})

## Papa Francisco: la misa. La Guardia Suiza llega por los dos lados, repican campanas y él recupera vida.
static func _ult_mass(cm: CombatManager, f: Fighter, atk: AttackData) -> void:
	_heal(f, 15.0)
	for i in 4:
		var side := -1 if i % 2 == 0 else 1
		_spawn(cm, f, atk, {"art": &"guard", "at_opp": true, "off": Vector2(side * 190.0 * f.facing, -20.0),
			"dir": -side, "box": Vector2(30, 40), "speed": 210.0, "delay": i * 8, "life": 110, "pierce": true,
			"share": 0.1, "knock": 90.0, "stun": 24, "sound": &"whoosh"})
	for i in 3:
		_spawn(cm, f, atk, {"art": &"bell_wave", "off": Vector2(22, -40), "box": Vector2(20, 52), "speed": 175.0,
			"delay": 40 + i * 14, "life": 78, "share": 0.1, "knock": 120.0, "stun": 26, "sound": &"confirm"})
	_finisher(cm, f, atk, 100, 0.3)

## Desplazamiento (hacia delante) desde el rival que no saca la entidad de la pantalla.
static func _opp_dx(f: Fighter, dx: float) -> float:
	var x := clampf(f.opponent.position.x + dx * f.facing, -40.0, 466.0)
	return (x - f.opponent.position.x) * f.facing

## Fragmentos de piedra en el suelo tras `frames` (cuando el poder golpea).
static func _stones_later(cm: CombatManager, x: float, frames: int) -> void:
	cm.spawn_stones(x, frames)

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
	if d.has("status"):
		a.status = d["status"]
		a.status_frames = int(d.get("status_frames", 60))
	var base: Vector2 = f.opponent.position if d.get("at_opp", false) else f.position
	var off: Vector2 = d.get("off", Vector2.ZERO)
	var p := Projectile.new()
	p.setup(f, a, base + Vector2(off.x * f.facing, off.y))
	p.configure(d)
	cm.add_entity(p)
	if p.is_armed():
		if p.shake_on_arm > 0.0:
			cm.shake(p.shake_on_arm)
		if p.sound_on_arm != &"":
			cm.sfx(p.sound_on_arm)
	return p

## Crea una entidad solo de decorado (cañón, guardia, humo, avión...).
static func _visual(cm: CombatManager, f: Fighter, pos: Vector2, d: Dictionary) -> Projectile:
	var p := Projectile.make_visual(f, pos, d)
	cm.add_entity(p)
	return p
