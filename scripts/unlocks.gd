## Lo que el jugador ha desbloqueado: luchadores (al vencerlos en el modo Historia), finales vistos y cosméticos.
## Se guarda en el equipo (user://unlocks.cfg, una lista por cuenta y otra para el que juega sin cuenta) y,
## con sesión, se sincroniza con la cuenta (Backend.sync_unlocks). Desbloquear es para siempre: solo se añade.
##
## Los desbloqueos de luchadores valen para el modo Historia y el versus local. El online con ranking
## tiene los 50 abiertos (para que el plantel no desnivele el ranking): ver CharacterSelect.
class_name Unlocks
extends RefCounted

## Los 12 luchadores con los que se empieza. El resto se desbloquea venciéndolo en el modo Historia.
const STARTERS: Array[StringName] = [
	&"papa_francisco", &"albert_einstein", &"rasputin", &"nikola_tesla", &"abraham_lincoln", &"napoleon",
	&"leonardo_da_vinci", &"gengis_kan", &"lautaro", &"juana_de_arco", &"cleopatra", &"alejandro_magno",
]

## Los finales del modo Historia, en el orden en que se muestran, y cuál es el oculto (sale como "???" hasta verlo).
const ENDINGS: Array[StringName] = [&"repair", &"rewrite", &"free"]
const ENDING_NAMES := {&"repair": "REPARAR", &"rewrite": "REESCRIBIR", &"free": "LIBERAR"}
const HIDDEN_ENDING := &"free"

## Para pruebas: otro archivo para no tocar los desbloqueos reales.
static var path: String = "user://unlocks.cfg"

## Lo que hay en el equipo para el dueño actual: "tipo:clave" ("fighter:napoleon", "ending:repair").
static func items() -> PackedStringArray:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return PackedStringArray()
	return PackedStringArray(cfg.get_value(_owner(), "items", PackedStringArray()))

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

## ¿Puede usarse este luchador en el modo Historia o el versus local?
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
static func _owner() -> String:
	return Backend.user_id if Backend.user_id != "" else "guest"

static func _save(list: PackedStringArray) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)   # conserva las listas de los demás dueños
	cfg.set_value(_owner(), "items", list)
	cfg.save(path)
