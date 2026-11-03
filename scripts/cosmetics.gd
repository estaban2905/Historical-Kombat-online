## Cosméticos del perfil: el marco del retrato y el título bajo el nombre. Se ganan al ver un final del modo
## Historia o al cumplir ciertos logros, se guardan como desbloqueos (Unlocks, tipo "cosmetic") y se ponen
## desde EDITAR PERFIL. El servidor solo deja ponerse los que se tienen.
class_name Cosmetics
extends RefCounted

const FRAMES := {
	&"frame_gold": {"name": "DORADO", "color": Color("f0c040")},
	&"frame_red": {"name": "ROJO", "color": Color("e83a3a")},
	&"frame_cyan": {"name": "CIAN", "color": Color("35e6ff")},
}

const TITLES := {
	&"title_guardian": "GUARDIÁN DEL TIEMPO",
	&"title_rewriter": "REESCRITOR DE LA HISTORIA",
	&"title_free": "SEÑOR DEL TIEMPO LIBRE",
	&"title_first_blood": "PRIMERA SANGRE",
	&"title_unstoppable": "IMPARABLE",
	&"title_legend": "LEYENDA",
}

## Qué se gana al ver cada final del modo Historia.
const ENDING_REWARDS := {
	&"repair": [&"frame_gold", &"title_guardian"],
	&"rewrite": [&"frame_red", &"title_rewriter"],
	&"free": [&"frame_cyan", &"title_free"],
}

## Qué se gana al cumplir un logro (las claves son las de Achievements).
const ACHIEVEMENT_REWARDS := {
	"first_win": &"title_first_blood",
	"streak_5": &"title_unstoppable",
	"wins_50": &"title_legend",
}

static func frame_color(key: String) -> Color:
	return FRAMES.get(StringName(key), {}).get("color", HKTheme.GOLD_DARK)

## Nombre de un marco ("" si no existe), para mostrarlo en el menú.
static func frame_name(key: String) -> String:
	return str(FRAMES.get(StringName(key), {}).get("name", ""))

## Texto de un título ("" si no existe: un título que esta versión del juego no conoce no se muestra).
static func title_name(key: String) -> String:
	return str(TITLES.get(StringName(key), ""))

static func owned_frames() -> Array[String]:
	return _owned(FRAMES)

static func owned_titles() -> Array[String]:
	return _owned(TITLES)

## Lo del catálogo que el jugador ya tiene, en el orden del catálogo.
static func _owned(catalog: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in catalog:
		if Unlocks.has("cosmetic", str(key)):
			out.append(str(key))
	return out

## Ver un final da su marco y su título.
static func grant_ending(ending: StringName) -> void:
	for key in ENDING_REWARDS.get(ending, []):
		Unlocks.add("cosmetic", str(key))

## Da el título de cada logro cumplido ({key, done} como los devuelve Backend.fetch_achievements).
static func grant_achievements(list: Array) -> void:
	for a in list:
		if bool(a.get("done", false)) and ACHIEVEMENT_REWARDS.has(str(a.get("key", ""))):
			Unlocks.add("cosmetic", str(ACHIEVEMENT_REWARDS[str(a["key"])]))
