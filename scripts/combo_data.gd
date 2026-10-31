## Estructura preparada para combos de comando (no activos en 0.1).
##
## Un combo es una secuencia de botones de ataque pulsados dentro de una
## ventana de tiempo. fighter.gd ya guarda un historial de entradas
## (input_history) y llama a ComboData.matches() en cada ataque; si alguno
## coincide se emite la señal Fighter.combo_performed. En la versión 0.1
## los personajes no traen combos definidos, pero basta con añadirlos al
## array `combos` de su FighterData para que se detecten.
class_name ComboData
extends Resource

@export var id: StringName = &"combo"
@export var display_name: String = "Combo"
## Secuencia de ranuras de ataque, p. ej. [&"punch_light", &"punch_light", &"kick_heavy"].
@export var sequence: Array[StringName] = []
## Máximo de frames permitidos entre una pulsación y la siguiente.
@export var max_gap_frames: int = 18
## Daño extra que suma el último golpe del combo (reservado para el futuro).
@export var bonus_damage: float = 0.0

## history: Array de diccionarios {slot: StringName, frame: int}, más reciente al final.
func matches(history: Array) -> bool:
	if sequence.is_empty() or history.size() < sequence.size():
		return false
	var start := history.size() - sequence.size()
	for i in sequence.size():
		var entry: Dictionary = history[start + i]
		if entry.slot != sequence[i]:
			return false
		if i > 0 and entry.frame - history[start + i - 1].frame > max_gap_frames:
			return false
	return true
