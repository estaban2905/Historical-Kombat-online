## Escenario temático de un personaje. Lee su definición en StageRegistry
## y construye las cuatro capas (fondo, actores, primer plano y efectos).
class_name ThemedStage
extends Stage

## Personaje al que pertenece el escenario (se asigna antes de añadirlo al árbol).
var fighter_id: StringName = &"napoleon"

func _ready() -> void:
	var def := StageRegistry.def_for(fighter_id)
	display_name = def.get("name", display_name)
	for spec in [["back", false], ["mid", true], ["front", false], ["fx", true]]:
		var ops: Array = def.get(spec[0], [])
		if ops.is_empty():
			continue
		var layer := ThemedLayer.new()
		layer.name = String(spec[0]).capitalize()
		add_child(layer)
		layer.setup(ops, spec[1])
