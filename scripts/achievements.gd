## Los logros del juego. La regla de cada uno (y cuánto llevas) la calcula el servidor (GET /me/achievements);
## aquí están el orden, el nombre y la descripción. Un logro que el servidor mande y no esté aquí no se muestra.
class_name Achievements
extends RefCounted

## [clave, nombre, descripción]. La clave es la que manda el servidor.
const LIST := [
	["first_win", "PRIMERA SANGRE", "GANA TU PRIMER DUELO"],
	["wins_10", "VETERANO", "GANA 10 DUELOS"],
	["wins_50", "LEYENDA", "GANA 50 DUELOS"],
	["played_25", "HABITUAL", "JUEGA 25 DUELOS"],
	["streak_5", "IMPARABLE", "5 VICTORIAS SEGUIDAS"],
	["flawless", "VICTORIA PERFECTA", "GANA SIN PERDER RONDA"],
	["story_done", "VENCISTE AL NEXO", "TERMINA LA HISTORIA"],
	["all_endings", "TODOS LOS FINALES", "VE LOS TRES FINALES"],
	["hidden_ending", "EL TIEMPO LIBRE", "VE EL FINAL OCULTO"],
	["collector", "COLECCIONISTA", "GANA 20 LUCHADORES"],
	["full_roster", "PLANTEL COMPLETO", "GANA 38 LUCHADORES"],
]

## El logro oculto: no dice cómo se llama hasta cumplirlo.
const HIDDEN := "hidden_ending"

## Cada logro del juego con lo que lleva el jugador: [{key, name, desc, progress, goal, done}], en el orden de LIST.
## `server` es la respuesta de Backend.fetch_achievements; lo que falte sale a 0.
static func merge(server: Array) -> Array:
	var by_key := {}
	for a in server:
		by_key[str(a.get("key", ""))] = a
	var out := []
	for entry in LIST:
		var s: Dictionary = by_key.get(entry[0], {})
		var done := bool(s.get("done", false))
		var hidden: bool = entry[0] == HIDDEN and not done
		out.append({
			"key": entry[0],
			"name": "???" if hidden else entry[1],
			"desc": "UN FINAL SECRETO" if hidden else entry[2],
			"progress": int(s.get("progress", 0)),
			"goal": maxi(int(s.get("goal", 1)), 1),
			"done": done,
		})
	return out

static func done_count(merged: Array) -> int:
	var n := 0
	for a in merged:
		if a["done"]:
			n += 1
	return n
