## Lo que el jugador ha desbloqueado: luchadores (al vencerlos en el modo Historia), finales vistos y cosméticos.
## Se guarda en el equipo (user://unlocks.cfg, una lista por cuenta y otra para el que juega sin cuenta) y,
## con sesión, se sincroniza con la cuenta (Backend.sync_unlocks). Desbloquear es para siempre: solo se añade.
##
## Los desbloqueos de luchadores valen para el modo Historia. El online con ranking tiene los 50 abiertos
## (para que el plantel no desnivele el ranking): ver CharacterSelect.
##
## Lo que se gana jugando sin cuenta pasa a la cuenta con la que se entre después (adopt_guest).
class_name Unlocks
extends RefCounted

## Los buenos y justos con los que se empieza (no son rivales en el modo Historia: ver StoryCampaign.PLAYABLE_ONLY).
## El resto (villanos, ambiciosos y los creadores del Reloj) se desbloquea venciéndolo en el modo Historia.
const STARTERS: Array[StringName] = StoryCampaign.PLAYABLE_ONLY

## Los finales del modo Historia, en el orden en que se muestran, y cuál es el oculto (sale como "???" hasta verlo).
const ENDINGS: Array[StringName] = [&"repair", &"rewrite", &"free"]
const ENDING_NAMES := {&"repair": "REPARAR", &"rewrite": "REESCRIBIR", &"free": "LIBERAR"}
const HIDDEN_ENDING := &"free"

## Para pruebas: otro archivo para no tocar los desbloqueos reales.
static var path: String = "user://unlocks.cfg"

## Última lista leída del archivo, con el archivo y el dueño a los que corresponde. La selección de
## personaje pregunta por cada casilla en cada redibujo: sin esto parseaba el archivo decenas de veces.
static var _cache := PackedStringArray()
static var _cache_key := ""
## Cuántas veces se ha leído el archivo (para las pruebas).
static var disk_reads: int = 0

## Lo que hay en el equipo para el dueño actual: "tipo:clave" ("fighter:napoleon", "ending:repair").
static func items() -> PackedStringArray:
	var key := "%s|%s" % [path, _owner()]
	if key != _cache_key:
		var cfg := ConfigFile.new()
		disk_reads += 1
		_cache = PackedStringArray()
		if cfg.load(path) == OK:
			_cache = PackedStringArray(cfg.get_value(_owner(), "items", PackedStringArray()))
		_cache_key = key
	return _cache

static func has(kind: String, key: String) -> bool:
	return items().has("%s:%s" % [kind, key])

## Desbloquea algo. true si era nuevo (para avisar al jugador); false si ya lo tenía.
## Con sesión, avisa también a la cuenta.
static func add(kind: String, key: String) -> bool:
	var list := items()
	var item := "%s:%s" % [kind, key]
	if list.has(item):
		return false
	list.append(item)
	_save(list)
	if Backend.is_logged_in():
		Backend.push_unlocks([{"kind": kind, "key": key}])
	return true

## Une lo que llega de la cuenta con lo del equipo. true si el equipo ha ganado algo nuevo.
static func merge(remote: Array) -> bool:
	var list := items()
	var changed := false
	for u in remote:
		var item := "%s:%s" % [str(u.get("kind", "")), str(u.get("key", ""))]
		if item != ":" and not list.has(item):
			list.append(item)
			changed = true
	if changed:
		_save(list)
	return changed

## Lo del equipo en el formato del servidor ([{kind, key}]).
static func as_dicts() -> Array:
	var out := []
	for item in items():
		var parts := item.split(":", true, 1)
		if parts.size() == 2:
			out.append({"kind": parts[0], "key": parts[1]})
	return out

## Con sesión, pasa a la cuenta lo ganado sin cuenta en este equipo y vacía la lista del invitado (así no
## se reparte entre varias cuentas). true si la cuenta ha ganado algo nuevo. Sin sesión no hace nada.
static func adopt_guest() -> bool:
	if _owner() == GUEST:
		return false
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK or not cfg.has_section(GUEST):
		return false
	var guest_items := PackedStringArray(cfg.get_value(GUEST, "items", PackedStringArray()))
	var list := PackedStringArray(cfg.get_value(_owner(), "items", PackedStringArray()))
	var changed := false
	for item in guest_items:
		if not list.has(item):
			list.append(item)
			changed = true
	cfg.set_value(_owner(), "items", list)
	cfg.erase_section(GUEST)
	cfg.save(path)
	_cache_key = ""
	return changed

## ¿Puede usarse este luchador en el modo Historia?
static func fighter_unlocked(id: StringName) -> bool:
	return STARTERS.has(id) or has("fighter", str(id))

## Cuántos de los luchadores del plantel están desbloqueados.
static func fighters_unlocked() -> int:
	var n := 0
	for d in FighterRegistry.all():
		if fighter_unlocked(d.id):
			n += 1
	return n

## Cuáles de los finales del modo Historia ya se han visto.
static func endings_seen() -> Array[StringName]:
	var out: Array[StringName] = []
	for e in ENDINGS:
		if has("ending", str(e)):
			out.append(e)
	return out

## Cada cuenta (y quien juega sin cuenta) tiene su propia lista.
const GUEST := "guest"

static func _owner() -> String:
	return Backend.user_id if Backend.user_id != "" else GUEST

static func _save(list: PackedStringArray) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)   # conserva las listas de los demás dueños
	cfg.set_value(_owner(), "items", list)
	cfg.save(path)
	_cache = list
	_cache_key = "%s|%s" % [path, _owner()]
