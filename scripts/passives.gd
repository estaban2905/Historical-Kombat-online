## Catálogo de PASIVAS: una regla propia por luchador que actúa sola, sin botones ni energía.
##
## Cada luchador declara `FighterData.passive` (un id de este catálogo; vacío = sin pasiva).
## Cada pasiva = un nombre y una descripción (INFO) + un EFECTO de la biblioteca con sus números (CFG).
## Los efectos se reutilizan: así hay ~25 comportamientos que probar y balancear, y cada luchador
## tiene su propio nombre, tema y cifras.
##
## El motor avisa con "hooks" cuando pasa algo y el efecto decide si reacciona.
##
## REGLAS (el online es lockstep: los dos PC simulan la pelea completa):
##   - Nada de azar (randf/randi) ni de reloj real: solo ticks y números del estado.
##   - Todo lo que la pasiva recuerda va en `Fighter.passive_state` (enteros). Las ranuras 0..ROUND_SLOTS-1
##     se reinician cada ronda; las demás duran todo el combate. CombatManager.state_snapshot lo
##     incluye para detectar desincronizaciones.
##   - Una pasiva solo modifica cosas que ya existen (velocidad, daño, energía, guardia, vida).
##   - Ninguna pasiva puede dar el K.O. por sí sola: lo que quita vida deja al menos 1.
##
## CÓMO AÑADIR UNA: poner su id en INFO y en CFG (con un efecto existente), y asignarla en el .tres:
##   passive = &"mi_pasiva". Un efecto nuevo se añade en los hooks que necesite.
class_name Passives
extends RefCounted

## Ranuras enteras de `Fighter.passive_state` (contadores, "ya usada", temporizadores...).
const STATE_SIZE := 4
## Las ranuras 0 y 1 se reinician en cada ronda; la 2 y la 3 duran todo el combate.
const ROUND_SLOTS := 2

# Ranuras (cada efecto usa las suyas; un luchador solo tiene un efecto).
const SLOT_A := 0        # temporizador / "ya usada esta ronda" / ticks de radiación
const SLOT_B := 1        # contador de ticks / bandera de "primer golpe" / ticks hasta el próximo daño
const SLOT_SURVIVED := 2 # Rasputín: ya se levantó (dura todo el combate)
const SLOT_BLESSED := 3  # La Doncella: ganó la ronda anterior (dura hasta empezar la siguiente)

# Efectos de la biblioteca.
const SPEED_LOW_HP := &"speed_low_hp"          # (umbral de vida, multiplicador de velocidad)
const REDUCE_LOW_HP := &"reduce_low_hp"        # (umbral, fracción de daño que ignora)
const DAMAGE_LOW_HP := &"damage_low_hp"        # (umbral, bono de daño)
const GUARD_ON_BLOCK := &"guard_on_block"      # (guardia que recupera)
const ENERGY_ON_BLOCK := &"energy_on_block"    # (energía)
const PERFECT_BLOCK_ENERGY := &"perfect_block_energy"  # (energía)
const ENERGY_ON_HIT := &"energy_on_hit"        # (energía por golpe conectado)
const PAIN_ENERGY := &"pain_energy"            # (energía por golpe recibido)
const LIFESTEAL := &"lifesteal"                # (fracción del daño que cura)
const REGEN := &"regen"                        # (vida por segundo, fuera de bloqueo y aturdimiento)
const ENERGY_REGEN := &"energy_regen"          # (energía extra por segundo)
const GUARD_REGEN := &"guard_regen"            # (guardia extra por segundo)
const ROUND_ENERGY := &"round_energy"          # (energía al empezar cada ronda)
const WIN_ENERGY := &"win_energy"              # (energía en la ronda siguiente a ganar)
const PROJECTILE_DAMAGE := &"projectile_damage"  # (bono de daño de proyectiles y poderes)
const PROJECTILE_RESIST := &"projectile_resist"  # (fracción que ignora de proyectiles y poderes)
const OPENING := &"opening"                    # (bono del primer golpe limpio de cada ronda)
const MOMENTUM := &"momentum"                  # (ticks, multiplicador de velocidad tras conectar)
const HEAL_ONCE := &"heal_once"                # (umbral de vida, vida que recupera una vez por ronda)
const RANGE_FAR := &"range_far"                # (distancia mínima en px, bono de daño)
const RANGE_NEAR := &"range_near"              # (distancia máxima en px, bono de daño)
const FULL_ENERGY_DAMAGE := &"full_energy_damage"  # (bono con la energía al máximo)
const THORNS := &"thorns"                      # (vida que pierde quien lo golpea)
const SURVIVE := &"survive"                    # (una vez por combate evita un K.O.)
const IRRADIATE := &"irradiate"                # (Curie: marca al rival con daño en el tiempo)

# Cifras que no son parámetros de un solo efecto.
const REGEN_EVERY := 30          # la vida se regenera en pasos de medio segundo (en enteros)
const CURIE_TICKS := 180
const CURIE_EVERY := 30
const CURIE_DAMAGE := 1.0
const NO_KO_FLOOR := 1.0         # lo que quita vida por sí solo nunca deja menos que esto
const TICKS_PER_SECOND := 60.0

## id → [nombre corto (máx. ~23 caracteres), descripción (máx. ~62: dos líneas en la pantalla)]
const INFO := {
	# --- Piloto ---
	&"waterloo": ["WATERLOO AL REVÉS", "Con menos del 40% de vida camina un 25% más rápido."],
	&"dificil_de_matar": ["DIFÍCIL DE MATAR", "Una vez por combate, sobrevive a un K.O. con 1 de vida."],
	&"la_doncella": ["LA DONCELLA", "Ganar una ronda da +40 de energía en la siguiente."],
	&"radiactividad": ["RADIACTIVIDAD", "Irradia al rival: pierde 1 de vida cada 0,5 s durante 3 s."],
	&"mente_tranquila": ["MENTE TRANQUILA", "Cada golpe que bloquea le devuelve 15 de guardia."],
	&"hombre_de_acero": ["HOMBRE DE ACERO", "Con menos de la mitad de vida, recibe un 20% menos de daño."],
	# --- Estrategas ---
	&"ganar_sin_luchar": ["GANAR SIN LUCHAR", "Cada golpe que bloquea le da 8 de energía."],
	&"el_fin_justifica": ["EL FIN JUSTIFICA", "Se cura un 12% del daño que causa con sus golpes."],
	&"jinete_implacable": ["JINETE IMPLACABLE", "Tras conectar, camina un 20% más rápido durante 1,5 s."],
	&"sin_retroceso": ["SIN RETROCESO", "Tras conectar un golpe, camina un 20% más rápido durante 1 s."],
	&"gloria_de_roma": ["GLORIA DE ROMA", "Cada golpe que conecta le da 3 de energía extra."],
	&"tierra_a_la_vista": ["TIERRA A LA VISTA", "Empieza cada ronda con 25 de energía extra."],
	&"quemar_las_naves": ["QUEMAR LAS NAVES", "Su primer golpe limpio de cada ronda pega un 25% más."],
	&"estrategia_del_toqui": ["ESTRATEGIA DEL TOQUI", "Tras conectar un golpe, camina un 25% más rápido durante 1 s."],
	# --- Resistentes y defensores ---
	&"casa_en_pie": ["CASA EN PIE", "Con menos de la mitad de vida, recibe un 15% menos de daño."],
	&"al_abordaje": ["AL ABORDAJE", "Una vez por ronda, bajo el 30% de vida recupera 15."],
	&"blindaje": ["BLINDAJE T-34", "Ignora el 30% del daño de proyectiles y poderes."],
	&"mano_dura": ["MANO DURA", "A corta distancia pega un 20% más fuerte."],
	&"aguante": ["AGUANTE", "Con menos de la mitad de vida, recibe un 15% menos de daño."],
	&"muralla_andina": ["MURALLA ANDINA", "Su guardia se recupera 15 puntos más rápido por segundo."],
	&"imperturbable": ["IMPERTURBABLE", "Su guardia se recupera 20 puntos más rápido por segundo."],
	&"paciencia_infinita": ["PACIENCIA INFINITA", "Su guardia se recupera 20 puntos más rápido por segundo."],
	&"milagro": ["MILAGRO", "Una vez por ronda, bajo el 25% de vida recupera 20."],
	&"bendicion": ["BENDICIÓN CONSTANTE", "Recupera 0,6 de vida por segundo si no está en peligro."],
	&"seleccion_natural": ["SELECCIÓN NATURAL", "Recupera 0,5 de vida por segundo si no está en peligro."],
	&"sostiene_el_tiempo": ["SOSTIENE EL TIEMPO", "Recupera 0,6 de vida por segundo si no está en peligro."],
	# --- Científicos y filósofos ---
	&"energia_es_masa": ["ENERGÍA ES MASA", "Su energía se recupera 1,5 puntos más rápido por segundo."],
	&"observacion": ["OBSERVACIÓN", "Su energía se recupera 1,5 puntos más rápido por segundo."],
	&"solo_se_que_no_se": ["SÓLO SÉ QUE NO SÉ", "Un bloqueo perfecto le da 25 de energía."],
	&"disciplina": ["DISCIPLINA", "Un bloqueo perfecto le da 25 de energía."],
	&"mundo_de_ideas": ["MUNDO DE LAS IDEAS", "Cada golpe que bloquea le da 6 de energía."],
	&"telescopio": ["TELESCOPIO", "Desde lejos (más de 110 px) pega un 20% más fuerte."],
	&"tercera_ley": ["TERCERA LEY", "Quien lo golpea pierde 1 de vida (nunca lo deja K.O.)."],
	&"corriente_alterna": ["CORRIENTE ALTERNA", "Cada golpe que conecta le da 4 de energía extra."],
	&"genio_creativo": ["GENIO CREATIVO", "Cada golpe que conecta le da 2 de energía extra."],
	# --- Líderes y guerreros ---
	&"furia_icena": ["FURIA ICENA", "Con menos de la mitad de vida pega un 25% más fuerte."],
	&"tierra_ancestral": ["TIERRA ANCESTRAL", "Con menos de la mitad de vida camina un 20% más rápido."],
	&"terror_del_zar": ["TERROR DEL ZAR", "Quien lo golpea pierde 1,5 de vida (nunca lo deja K.O.)."],
	&"berrinche_final": ["BERRINCHE FINAL", "Con menos del 35% de vida pega un 30% más fuerte."],
	&"hasta_el_final": ["HASTA EL ÚLTIMO DÍA", "Con menos del 40% de vida pega un 30% más fuerte."],
	&"fugitivo": ["FUGITIVO", "Con menos de la mitad de vida camina un 25% más rápido."],
	# --- Carismáticos y poderosos ---
	&"el_mejor": ["EL MEJOR", "Sus poderes y proyectiles hacen un 25% más de daño."],
	&"programa_de_misiles": ["PROGRAMA DE MISILES", "Sus poderes y proyectiles hacen un 20% más de daño."],
	&"arsenal_dorado": ["ARSENAL DORADO", "Sus poderes y proyectiles hacen un 20% más de daño."],
	&"balcon": ["DESDE EL BALCÓN", "Con la energía llena pega un 20% más fuerte."],
	&"poder_del_sol": ["PODER DEL SOL", "Con la energía llena pega un 25% más fuerte."],
	&"resistencia": ["RESISTENCIA", "Al recibir un golpe gana 8 de energía extra."],
	&"encanto_fatal": ["ASTUCIA REAL", "Al recibir un golpe gana 6 de energía extra."],
	&"plata_o_plomo": ["PLATA O PLOMO", "Cada golpe que conecta le da 5 de energía extra."],
	&"judoca": ["JUDOCA", "A corta distancia pega un 20% más fuerte."],
	&"francotiradora": ["FRANCOTIRADORA", "Desde lejos (más de 120 px) pega un 25% más fuerte."],
}

## id → [efecto, parámetro a, parámetro b]. Ver el comentario de cada efecto arriba.
const CFG := {
	# --- Piloto ---
	&"waterloo": [SPEED_LOW_HP, 0.4, 1.25],
	&"dificil_de_matar": [SURVIVE, 0.0, 0.0],
	&"la_doncella": [WIN_ENERGY, 40.0, 0.0],
	&"radiactividad": [IRRADIATE, 0.0, 0.0],
	&"mente_tranquila": [GUARD_ON_BLOCK, 15.0, 0.0],
	&"hombre_de_acero": [REDUCE_LOW_HP, 0.5, 0.2],
	# --- Estrategas ---
	&"ganar_sin_luchar": [ENERGY_ON_BLOCK, 8.0, 0.0],
	&"el_fin_justifica": [LIFESTEAL, 0.12, 0.0],
	&"jinete_implacable": [MOMENTUM, 90.0, 1.2],
	&"sin_retroceso": [MOMENTUM, 60.0, 1.2],
	&"gloria_de_roma": [ENERGY_ON_HIT, 3.0, 0.0],
	&"tierra_a_la_vista": [ROUND_ENERGY, 25.0, 0.0],
	&"quemar_las_naves": [OPENING, 0.25, 0.0],
	&"estrategia_del_toqui": [MOMENTUM, 60.0, 1.25],
	# --- Resistentes y defensores ---
	&"casa_en_pie": [REDUCE_LOW_HP, 0.5, 0.15],
	&"al_abordaje": [HEAL_ONCE, 0.3, 15.0],
	&"blindaje": [PROJECTILE_RESIST, 0.3, 0.0],
	&"mano_dura": [RANGE_NEAR, 45.0, 0.2],
	&"aguante": [REDUCE_LOW_HP, 0.5, 0.15],
	&"muralla_andina": [GUARD_REGEN, 15.0, 0.0],
	&"imperturbable": [GUARD_REGEN, 20.0, 0.0],
	&"paciencia_infinita": [GUARD_REGEN, 20.0, 0.0],
	&"milagro": [HEAL_ONCE, 0.25, 20.0],
	&"bendicion": [REGEN, 0.6, 0.0],
	&"seleccion_natural": [REGEN, 0.5, 0.0],
	&"sostiene_el_tiempo": [REGEN, 0.6, 0.0],
	# --- Científicos y filósofos ---
	&"energia_es_masa": [ENERGY_REGEN, 1.5, 0.0],
	&"observacion": [ENERGY_REGEN, 1.5, 0.0],
	&"solo_se_que_no_se": [PERFECT_BLOCK_ENERGY, 25.0, 0.0],
	&"disciplina": [PERFECT_BLOCK_ENERGY, 25.0, 0.0],
	&"mundo_de_ideas": [ENERGY_ON_BLOCK, 6.0, 0.0],
	&"telescopio": [RANGE_FAR, 110.0, 0.2],
	&"tercera_ley": [THORNS, 1.0, 0.0],
	&"corriente_alterna": [ENERGY_ON_HIT, 4.0, 0.0],
	&"genio_creativo": [ENERGY_ON_HIT, 2.0, 0.0],
	# --- Líderes y guerreros ---
	&"furia_icena": [DAMAGE_LOW_HP, 0.5, 0.25],
	&"tierra_ancestral": [SPEED_LOW_HP, 0.5, 1.2],
	&"terror_del_zar": [THORNS, 1.5, 0.0],
	&"berrinche_final": [DAMAGE_LOW_HP, 0.35, 0.3],
	&"hasta_el_final": [DAMAGE_LOW_HP, 0.4, 0.3],
	&"fugitivo": [SPEED_LOW_HP, 0.5, 1.25],
	# --- Carismáticos y poderosos ---
	&"el_mejor": [PROJECTILE_DAMAGE, 0.25, 0.0],
	&"programa_de_misiles": [PROJECTILE_DAMAGE, 0.2, 0.0],
	&"arsenal_dorado": [PROJECTILE_DAMAGE, 0.2, 0.0],
	&"balcon": [FULL_ENERGY_DAMAGE, 0.2, 0.0],
	&"poder_del_sol": [FULL_ENERGY_DAMAGE, 0.25, 0.0],
	&"resistencia": [PAIN_ENERGY, 8.0, 0.0],
	&"encanto_fatal": [PAIN_ENERGY, 6.0, 0.0],
	&"plata_o_plomo": [ENERGY_ON_HIT, 5.0, 0.0],
	&"judoca": [RANGE_NEAR, 40.0, 0.2],
	&"francotiradora": [RANGE_FAR, 120.0, 0.25],
}

# --- Consultas ------------------------------------------------------------------

static func has(f: Fighter) -> bool:
	return f != null and f.data != null and f.data.passive != &""

static func has_data(d: FighterData) -> bool:
	return d != null and d.passive != &""

static func display_name(id: StringName) -> String:
	return INFO[id][0] if INFO.has(id) else ""

static func description(id: StringName) -> String:
	return INFO[id][1] if INFO.has(id) else ""

## Errores de datos de una pasiva (vacío = bien). Lo usa FighterData.validate.
static func validate(id: StringName) -> PackedStringArray:
	var errors := PackedStringArray()
	if id == &"":
		return errors
	if not INFO.has(id):
		errors.append("pasiva «%s»: falta su nombre y descripción en Passives.INFO" % id)
	if not CFG.has(id):
		errors.append("pasiva «%s»: falta su efecto en Passives.CFG" % id)
	return errors

## Estado inicial (todo a cero). Se usa al crear al luchador; cada ronda solo se reinician ROUND_SLOTS.
static func fresh_state() -> Array[int]:
	var s: Array[int] = []
	s.resize(STATE_SIZE)
	s.fill(0)
	return s

static func _effect(f: Fighter) -> StringName:
	return CFG[f.data.passive][0] if has(f) and CFG.has(f.data.passive) else &""

static func _a(f: Fighter) -> float:
	return CFG[f.data.passive][1]

static func _b(f: Fighter) -> float:
	return CFG[f.data.passive][2]

static func _hp_ratio(f: Fighter) -> float:
	return f.health / maxf(f.data.max_health, 1.0)

static func _alive(f: Fighter) -> bool:
	return f.state != Fighter.State.KO

## Cura `amount` sin pasar de la vida máxima, avisando al HUD.
static func _heal(f: Fighter, amount: float) -> void:
	if amount <= 0.0 or not _alive(f):
		return
	f.health = minf(f.health + amount, f.data.max_health)
	f.health_changed.emit(f)

## Quita `amount` sin llegar nunca a K.O. (mínimo NO_KO_FLOOR).
static func _drain(f: Fighter, amount: float) -> void:
	if not _alive(f) or f.health <= NO_KO_FLOOR:
		return
	f.health = maxf(f.health - amount, NO_KO_FLOOR)
	f.health_changed.emit(f)

## Aviso visual: la pasiva acaba de actuar (el HUD hace brillar la estrella). No se simula ni entra en el
## checksum: solo lo lee la interfaz.
static func _pulse(f: Fighter) -> void:
	f.passive_pulses += 1

# Estado de la pasiva para el icono del HUD.
const STATUS_OFF := 0      # gastada (ya usada esta ronda/combate)
const STATUS_READY := 1    # en espera: siempre activa o aún sin condición
const STATUS_ACTIVE := 2   # su condición se cumple ahora mismo

## Estado de la pasiva de `f` para dibujar su icono (solo lectura; no cambia nada).
static func status(f: Fighter) -> int:
	if not has(f) or not CFG.has(f.data.passive):
		return STATUS_OFF
	var foe := f.opponent
	var near_far := 0.0 if foe == null else absf(f.position.x - foe.position.x)
	match _effect(f):
		SPEED_LOW_HP, REDUCE_LOW_HP, DAMAGE_LOW_HP:
			return STATUS_ACTIVE if _hp_ratio(f) < _a(f) else STATUS_READY
		MOMENTUM, IRRADIATE:
			return STATUS_ACTIVE if f.passive_state[SLOT_A] > 0 else STATUS_READY
		OPENING:
			return STATUS_ACTIVE if f.passive_state[SLOT_B] == 0 else STATUS_OFF
		HEAL_ONCE:
			return STATUS_READY if f.passive_state[SLOT_A] == 0 else STATUS_OFF
		SURVIVE:
			return STATUS_READY if f.passive_state[SLOT_SURVIVED] == 0 else STATUS_OFF
		FULL_ENERGY_DAMAGE:
			return STATUS_ACTIVE if f.energy >= Fighter.MAX_ENERGY - 0.01 else STATUS_READY
		RANGE_FAR:
			return STATUS_ACTIVE if foe != null and near_far > _a(f) else STATUS_READY
		RANGE_NEAR:
			return STATUS_ACTIVE if foe != null and near_far < _a(f) else STATUS_READY
	return STATUS_READY

# --- Multiplicadores (los lee el motor al calcular daño y velocidad) -------------------

## Multiplicador del daño que INFLIGE `f` con `atk` sobre `target` (1.0 = normal).
static func outgoing_mult(f: Fighter, target: Fighter, atk: AttackData) -> float:
	match _effect(f):
		DAMAGE_LOW_HP:
			if _hp_ratio(f) < _a(f):
				return 1.0 + _b(f)
		OPENING:
			if f.passive_state[SLOT_B] == 0:
				return 1.0 + _a(f)
		PROJECTILE_DAMAGE:
			if atk.is_projectile() or atk.is_power():
				return 1.0 + _a(f)
		RANGE_FAR:
			if absf(f.position.x - target.position.x) > _a(f):
				return 1.0 + _b(f)
		RANGE_NEAR:
			if absf(f.position.x - target.position.x) < _a(f):
				return 1.0 + _b(f)
		FULL_ENERGY_DAMAGE:
			if f.energy >= Fighter.MAX_ENERGY - 0.01:
				return 1.0 + _a(f)
	return 1.0

## Multiplicador del daño que RECIBE `f` de `attacker` con `atk` (1.0 = normal).
static func incoming_mult(f: Fighter, _attacker: Fighter, atk: AttackData) -> float:
	match _effect(f):
		REDUCE_LOW_HP:
			if _hp_ratio(f) < _a(f):
				return 1.0 - _b(f)
		PROJECTILE_RESIST:
			if atk.is_projectile() or atk.is_power():
				return 1.0 - _a(f)
	return 1.0

## Multiplicador de la velocidad al caminar (1.0 = normal).
static func speed_mult(f: Fighter) -> float:
	match _effect(f):
		SPEED_LOW_HP:
			if _hp_ratio(f) < _a(f):
				return _b(f)
		MOMENTUM:
			if f.passive_state[SLOT_A] > 0:
				return _b(f)
	return 1.0

# --- Hooks (los llama el motor; sin pasiva no hacen nada) ---------------------------

## Al empezar una ronda, ya con la vida y la energía restablecidas.
static func on_round_start(f: Fighter) -> void:
	match _effect(f):
		ROUND_ENERGY:
			f.add_energy(_a(f))
			_pulse(f)
		WIN_ENERGY:
			if f.passive_state[SLOT_BLESSED] > 0:
				f.passive_state[SLOT_BLESSED] = 0
				f.add_energy(_a(f))
				_pulse(f)

## Una vez por tick de simulación (fuera del congelado por golpe).
static func on_tick(f: Fighter) -> void:
	var effect := _effect(f)
	if effect == &"":
		return
	var live: bool = f.controls_enabled and _alive(f)
	match effect:
		IRRADIATE:
			var foe := f.opponent
			if f.passive_state[SLOT_A] <= 0 or foe == null:
				return
			f.passive_state[SLOT_A] -= 1
			f.passive_state[SLOT_B] -= 1
			if f.passive_state[SLOT_B] <= 0:
				f.passive_state[SLOT_B] = CURIE_EVERY
				_drain(foe, CURIE_DAMAGE)
		MOMENTUM:
			if f.passive_state[SLOT_A] > 0:
				f.passive_state[SLOT_A] -= 1
		REGEN:
			# Solo de pie, agachado o bloqueando. Cuenta ticks enteros y cura cada medio segundo.
			if live and f.state in [Fighter.State.IDLE, Fighter.State.WALK, Fighter.State.CROUCH, Fighter.State.BLOCK]:
				f.passive_state[SLOT_B] += 1
				if f.passive_state[SLOT_B] >= REGEN_EVERY:
					f.passive_state[SLOT_B] = 0
					_heal(f, _a(f) * REGEN_EVERY / TICKS_PER_SECOND)
		ENERGY_REGEN:
			if live:
				f.add_energy(_a(f) / TICKS_PER_SECOND)
		GUARD_REGEN:
			if _alive(f) and f.state != Fighter.State.BLOCK and f.guard < Fighter.MAX_GUARD and not f.guard_is_broken:
				f.guard = minf(f.guard + _a(f) / TICKS_PER_SECOND, Fighter.MAX_GUARD)

## `f` conectó un golpe (no bloqueado) sobre `target`.
static func on_hit_dealt(f: Fighter, _target: Fighter, _atk: AttackData, result: HitResult) -> void:
	match _effect(f):
		IRRADIATE:
			if f.passive_state[SLOT_A] <= 0:
				f.passive_state[SLOT_B] = CURIE_EVERY
			f.passive_state[SLOT_A] = CURIE_TICKS
			_pulse(f)
		LIFESTEAL:
			_heal(f, result.damage * _a(f))
			_pulse(f)
		ENERGY_ON_HIT:
			f.add_energy(_a(f))
			_pulse(f)
		MOMENTUM:
			f.passive_state[SLOT_A] = int(_a(f))
			_pulse(f)
		OPENING:
			f.passive_state[SLOT_B] = 1
			_pulse(f)

## `f` recibió un golpe (no bloqueado) de `attacker`.
static func on_hit_taken(f: Fighter, attacker: Fighter, _atk: AttackData, result: HitResult) -> void:
	if result.ko or not _alive(f):
		return
	match _effect(f):
		PAIN_ENERGY:
			f.add_energy(_a(f))
			_pulse(f)
		THORNS:
			_drain(attacker, _a(f))
			_pulse(f)
		HEAL_ONCE:
			if f.passive_state[SLOT_A] == 0 and _hp_ratio(f) < _a(f):
				f.passive_state[SLOT_A] = 1
				_heal(f, _b(f))
				_pulse(f)

## `f` bloqueó un golpe de `attacker`.
static func on_block(f: Fighter, _attacker: Fighter, _atk: AttackData, result: HitResult) -> void:
	match _effect(f):
		GUARD_ON_BLOCK:
			if not result.guard_break and not result.ko:
				f.guard = minf(f.guard + _a(f), Fighter.MAX_GUARD)
				_pulse(f)
		ENERGY_ON_BLOCK:
			f.add_energy(_a(f))
			_pulse(f)
		PERFECT_BLOCK_ENERGY:
			if result.perfect:
				f.add_energy(_a(f))
				_pulse(f)

## `f` iba a quedar K.O. Devuelve true para evitarlo (la pasiva debe dejarle vida: p. ej. 1).
static func prevents_ko(f: Fighter) -> bool:
	if _effect(f) != SURVIVE or f.passive_state[SLOT_SURVIVED] > 0:
		return false
	f.passive_state[SLOT_SURVIVED] = 1
	f.health = 1.0
	_pulse(f)
	return true

## `f` empezó un especial o un ultimate (`atk`). Reservado: ningún efecto lo usa todavía.
static func on_special_cast(_f: Fighter, _atk: AttackData) -> void:
	pass

## `f` ganó la ronda (se llama antes de empezar la siguiente).
static func on_round_won(f: Fighter) -> void:
	if _effect(f) == WIN_ENERGY:
		f.passive_state[SLOT_BLESSED] = 1

## Resumen del estado para el checksum del combate. Vacío si no tiene pasiva, para que los
## luchadores sin pasiva den exactamente el mismo resumen que antes de existir este sistema.
static func snapshot(f: Fighter) -> Array:
	return f.passive_state if has(f) else []
