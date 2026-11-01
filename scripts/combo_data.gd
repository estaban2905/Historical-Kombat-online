## Combo con nombre: una ruta de golpes ENLAZADOS con cancelaciones que da un
## bono de daño al último golpe si conecta.
##
## fighter.gd guarda un historial de ataques (input_history) y llama a matches()
## cada vez que empieza uno. Si coincide, marca el ataque con el combo
## (Fighter.attack_combo): si ese golpe entra, CombatManager le suma
## bonus_damage y el HUD muestra el nombre. Un combo solo cuenta si cada golpe
## (menos el primero) salió cancelando al anterior: repetir botones sin enlazar
## no basta. Se definen por personaje en FighterData.combos; si la lista está
## vacía se usan los comunes (FighterData.default_combos).
class_name ComboData
extends Resource

@export var id: StringName = &"combo"
@export var display_name: String = "Combo"
## Secuencia de ranuras de ataque, p. ej. [&"punch_light", &"punch_heavy", &"kick_heavy"].
@export var sequence: Array[StringName] = []
## Máximo de frames permitidos entre el inicio de un golpe y el del siguiente.
@export var max_gap_frames: int = 24
## Daño extra (antes de fuerza y resistencia) que suma el último golpe del combo.
@export var bonus_damage: float = 0.0

## history: Array de diccionarios {slot, frame, chained}, más reciente al final.
func matches(history: Array) -> bool:
	if sequence.is_empty() or history.size() < sequence.size():
		return false
	var start := history.size() - sequence.size()
	for i in sequence.size():
		var entry: Dictionary = history[start + i]
		if entry.slot != sequence[i]:
			return false
		if i > 0:
			if not entry.get("chained", false):
				return false
			if entry.frame - history[start + i - 1].frame > max_gap_frames:
				return false
	return true
