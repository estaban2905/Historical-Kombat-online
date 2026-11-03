## Estadísticas del perfil calculadas con mis últimos duelos (el formato de Backend.fetch_matches,
## del más reciente al más antiguo). Todo es puro: sin escenas ni red, para poder probarlo.
class_name ProfileStats
extends RefCounted

## Mis resultados agrupados por luchador: [{id, wins, losses, draws, total}], el más jugado primero.
## key = "my_fighter" (con quién juego) u "opponent_fighter" (contra quién juego: los matchups).
static func by_fighter(matches: Array, key: String = "my_fighter") -> Array:
	var rows := {}
	for m in matches:
		var id := str(m.get(key, ""))
		if id == "":
			continue
		if not rows.has(id):
			rows[id] = {"id": id, "wins": 0, "losses": 0, "draws": 0, "total": 0}
		var row: Dictionary = rows[id]
		match str(m.get("result", "")):
			"win": row["wins"] += 1
			"loss": row["losses"] += 1
			_: row["draws"] += 1
		row["total"] += 1
	var out := rows.values()
	# Más jugados primero; a igualdad, más victorias; y por id para que el orden no cambie entre dibujos.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["total"] != b["total"]:
			return a["total"] > b["total"]
		if a["wins"] != b["wins"]:
			return a["wins"] > b["wins"]
		return a["id"] < b["id"])
	return out

## Porcentaje de victorias de una fila de by_fighter (0 a 1).
static func win_rate(row: Dictionary) -> float:
	return float(row["wins"]) / float(row["total"]) if int(row["total"]) > 0 else 0.0

## {best, worst}: las filas con mejor y peor porcentaje entre las que tienen al menos min_games duelos.
## Valen {} si no hay ninguna, y worst también es {} si solo hay una (no puede ser a la vez la mejor y la peor).
static func best_and_worst(rows: Array, min_games: int = 2) -> Dictionary:
	var eligible := rows.filter(func(r: Dictionary) -> bool: return int(r["total"]) >= min_games)
	if eligible.is_empty():
		return {"best": {}, "worst": {}}
	# Mejor: más porcentaje y, a igualdad, más duelos. Peor: menos porcentaje y, a igualdad, más duelos.
	var best: Dictionary = eligible[0]
	var worst: Dictionary = eligible[0]
	for r in eligible:
		if win_rate(r) > win_rate(best) or (win_rate(r) == win_rate(best) and r["total"] > best["total"]):
			best = r
		if win_rate(r) < win_rate(worst) or (win_rate(r) == win_rate(worst) and r["total"] > worst["total"]):
			worst = r
	return {"best": best, "worst": {} if worst["id"] == best["id"] else worst}

## Mis puntos tras cada duelo, del más antiguo al más reciente, con el valor inicial delante
## (n duelos -> n + 1 valores). Se reconstruye restando el delta hacia atrás desde los puntos actuales.
static func points_series(matches: Array, current_points: int, max_matches: int = 20) -> PackedInt32Array:
	var vals: Array[int] = [current_points]
	for m in matches.slice(0, max_matches):
		vals.append(vals[vals.size() - 1] - int(m.get("delta", 0)))
	vals.reverse()
	return PackedInt32Array(vals)
