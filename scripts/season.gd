## Temporadas del ranking: cada mes (UTC) es una. Al terminar, el servidor guarda tu puesto y tu liga máxima,
## da un marco según esa liga y un título al top 3, y acerca los puntos de todos a 1000 a la mitad.
## Aquí solo están los textos y las fechas; los datos llegan de Backend.fetch_season y fetch_my_seasons.
class_name Season
extends RefCounted

const MONTHS: Array[String] = ["ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO", "JULIO", "AGOSTO",
	"SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE"]
## Liga del servidor ("silver") → la del juego (League.TIERS).
const LEAGUE_NAMES := {"bronze": "BRONCE", "silver": "PLATA", "gold": "ORO", "diamond": "DIAMANTE"}
const SEASON_FRAMES := {"silver": "frame_season_silver", "gold": "frame_season_gold", "diamond": "frame_season_diamond"}
## Para no repetir el aviso de fin de temporada: la última que vio cada cuenta.
static var seen_path: String = "user://seasons_seen.cfg"

## "2026-11" → "NOVIEMBRE 2026" ("" si no tiene ese formato).
static func name_of(id: String) -> String:
	var parts := id.split("-")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return ""
	var month := int(parts[1])
	if month < 1 or month > 12:
		return ""
	return "%s %s" % [MONTHS[month - 1], parts[0]]

## Días que faltan hasta `ends_at` (fecha ISO del servidor), redondeando hacia arriba; 0 si ya pasó.
static func days_left(ends_at: String, now_unix: float = Time.get_unix_time_from_system()) -> int:
	var end := Time.get_unix_time_from_datetime_string(ends_at.left(19))
	return maxi(ceili((end - now_unix) / 86400.0), 0)

## "QUEDAN 12 DÍAS" o, el último día, "ÚLTIMAS HORAS".
static func time_left_text(ends_at: String, now_unix: float = Time.get_unix_time_from_system()) -> String:
	var days := days_left(ends_at, now_unix)
	return "ÚLTIMAS HORAS" if days <= 1 else "QUEDAN %d DÍAS" % days

## Líneas del aviso de una temporada terminada (r como lo da /me/seasons): puesto y liga, y lo que se ganó.
static func summary(r: Dictionary) -> PackedStringArray:
	var league := str(r.get("league", "bronze"))
	var rank := int(r.get("rank", 0))
	var lines := PackedStringArray(["PUESTO %d · LIGA %s" % [rank, LEAGUE_NAMES.get(league, "BRONCE")]])
	var prizes := PackedStringArray()
	if SEASON_FRAMES.has(league):
		prizes.append("MARCO %s" % Cosmetics.frame_name(SEASON_FRAMES[league]))
	if rank == 1:
		prizes.append("TÍTULO %s" % Cosmetics.title_name("title_season_champion"))
	elif rank >= 2 and rank <= 3:
		prizes.append("TÍTULO %s" % Cosmetics.title_name("title_season_podium"))
	lines.append_array(prizes if not prizes.is_empty() else PackedStringArray(["SIN PREMIO: LLEGA A PLATA LA PRÓXIMA"]))
	return lines

## La última temporada cuyo aviso ya vio esta cuenta ("" ninguna).
static func last_seen(account: String) -> String:
	var cfg := ConfigFile.new()
	cfg.load(seen_path)
	return str(cfg.get_value("seen", account, ""))

static func mark_seen(account: String, season: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(seen_path)
	cfg.set_value("seen", account, season)
	cfg.save(seen_path)
