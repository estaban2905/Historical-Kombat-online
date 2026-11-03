## Una fila de duelo (resultado, puntos, rival, hace cuánto, luchador y rondas) para el perfil propio y el ajeno.
class_name MatchRow
extends RefCounted

const WIN_COLOR := Color("60d060")

## Dibuja el duelo `m` (formato de Backend.fetch_matches) con la línea de texto en `y`.
static func draw(ci: CanvasItem, m: Dictionary, y: float) -> void:
	var result := str(m.get("result", ""))
	var delta := int(m.get("delta", 0))
	var color := WIN_COLOR if result == "win" else (HKTheme.BLOOD if result == "loss" else HKTheme.PAPER)
	var label := {"win": "VICTORIA", "loss": "DERROTA", "draw": "EMPATE"}.get(result, "?") as String
	if str(m.get("reason", "")) == "forfeit":
		label += "*"
	ci.draw_rect(Rect2(34, y - 9, 384, 11), Color(color.r, color.g, color.b, 0.10))
	HKTheme.draw_text(ci, Vector2(40, y), label, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(ci, Vector2(112, y), "%+d" % delta, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(ci, Vector2(150, y), "VS %s" % str(m.get("opponent", "")).to_upper().left(10), 8,
		HKTheme.PAPER, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(ci, Vector2(262, y), format_ago(str(m.get("played_at", ""))), 8,
		HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(ci, Vector2(306, y), fighter_name(str(m.get("my_fighter", ""))), 8,
		HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
	HKTheme.draw_text(ci, Vector2(390, y), "%d-%d" % [int(m.get("my_rounds", 0)), int(m.get("opponent_rounds", 0))], 8,
		HKTheme.MUTED, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)

## Marco que rodea la fila elegida con el cursor.
static func draw_cursor(ci: CanvasItem, y: float) -> void:
	ci.draw_rect(Rect2(33, y - 10, 386, 13), HKTheme.GOLD, false, 1.0)

## "AHORA", "15M", "3H", "2D", "3SEM" o "2MES": hace cuánto se jugó (played_at es ISO en UTC).
## "" si la fecha no se entiende. now_unix permite probarlo con una hora fija.
static func format_ago(played_at: String, now_unix: float = -1.0) -> String:
	if played_at.length() < 19:
		return ""
	var then := Time.get_unix_time_from_datetime_string(played_at.left(19))
	var secs := int((now_unix if now_unix >= 0.0 else Time.get_unix_time_from_system()) - then)
	if secs < 60:
		return "AHORA"
	if secs < 3600:
		return "%dM" % (secs / 60)
	if secs < 86400:
		return "%dH" % (secs / 3600)
	if secs < 7 * 86400:
		return "%dD" % (secs / 86400)
	if secs < 30 * 86400:
		return "%dSEM" % (secs / (7 * 86400))
	return "%dMES" % (secs / (30 * 86400))

## Nombre corto de un luchador por su id ("" si el juego no lo conoce).
static func fighter_name(id: String) -> String:
	if not FighterRegistry.has(StringName(id)):
		return ""
	return FighterRegistry.get_by_id(StringName(id)).short_name.left(10)
