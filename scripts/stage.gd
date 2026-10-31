## Clase base de los escenarios. Un escenario es una escena cuya raíz usa
## este script (o uno que herede de él). Define dónde está el suelo, los
## límites de la arena y dónde aparecen los luchadores. No tiene
## colisiones: los luchadores solo usan floor_y y los límites.
class_name Stage
extends Node2D

signal excited(amount: float)

@export var display_name: String = "ESCENARIO"
## Y de los pies de los luchadores.
@export var floor_y: float = 206.0
@export var left_bound: float = 18.0
@export var right_bound: float = 408.0
@export var p1_spawn_x: float = 150.0
@export var p2_spawn_x: float = 276.0

## Nivel de emoción del público (0..1). Sube con los golpes y decae solo.
var excitement: float = 0.0

func _process(delta: float) -> void:
	excitement = maxf(excitement - delta * 0.6, 0.0)

## Llamado por el CombatManager en cada golpe fuerte.
func excite(amount: float) -> void:
	excitement = clampf(excitement + amount, 0.0, 1.0)
	excited.emit(amount)
