## Ligas del ranking: según los puntos. Todos empiezan en 1000 y cada duelo mueve unos 16.
class_name League
extends RefCounted

const TIERS: Array[Dictionary] = [
	{"name": "BRONCE", "from": 0, "color": Color("d08850")},
	{"name": "PLATA", "from": 1100, "color": Color("c8ccd8")},
	{"name": "ORO", "from": 1300, "color": Color("f0c040")},
	{"name": "DIAMANTE", "from": 1500, "color": Color("70d0f0")},
]

## {name, color, progress (0-1 hacia la siguiente liga; 1 en la última), next_name ("" en la última), to_next}.
static func info(points: int) -> Dictionary:
	var i := 0
	for k in TIERS.size():
		if points >= int(TIERS[k]["from"]):
			i = k
	var tier := TIERS[i]
	if i == TIERS.size() - 1:
		return {"name": tier["name"], "color": tier["color"], "progress": 1.0, "next_name": "", "to_next": 0}
	var from := int(tier["from"])
	var upto := int(TIERS[i + 1]["from"])
	# Por debajo de 0 puntos la barra no puede ir negativa.
	var progress := clampf(float(points - from) / float(upto - from), 0.0, 1.0)
	return {"name": tier["name"], "color": tier["color"], "progress": progress,
		"next_name": TIERS[i + 1]["name"], "to_next": upto - points}
