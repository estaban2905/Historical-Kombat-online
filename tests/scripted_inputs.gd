## Entradas pseudoaleatorias de semilla fija para las pruebas que juegan peleas enteras
## (determinismo y checksum dorado). Mismo número de semilla = mismos botones, siempre.
## Además de moverse, saltar y bloquear, pulsan ataques, especiales y, de vez en cuando, el
## ultimate (Especial 1 + Especial 2), para que las pruebas ejerciten los poderes de verdad.
class_name ScriptedInputs
extends RefCounted

const BIT_JUMP := 2
const BIT_CROUCH := 3
const BIT_BLOCK := 4
const BIT_S1 := 7
const BIT_S2 := 10

var _rng := RandomNumberGenerator.new()
var _held: Array[int] = [0, 0]

func _init(seed_value: int) -> void:
	_rng.seed = seed_value

## [máscara_P1, máscara_P2] del tick `tick` (ver CombatManager.set_input_source).
## Hay que llamarlo una vez por tick y en orden: el azar avanza con cada llamada.
func masks(tick: int) -> Array:
	var out: Array = []
	for p in 2:
		# Cada 12 ticks se elige un movimiento nuevo; los ataques se pulsan al azar.
		if tick % 12 == 0:
			_held[p] = _movement(p)
		var m: int = _held[p]
		if _rng.randf() < 0.12:
			m |= 1 << (5 + _rng.randi_range(0, 5))
		if _rng.randf() < 0.012:
			m |= (1 << BIT_S1) | (1 << BIT_S2)   # ultimate (si hay energía)
		out.append(m)
	return out

## Movimiento: avanza hacia el rival casi siempre, con saltos y bloqueos.
func _movement(player: int) -> int:
	var m := 0
	var toward := 1 if player == 0 else 0   # bit 0 = izquierda, bit 1 = derecha
	var r := _rng.randf()
	if r < 0.55:
		m |= 1 << toward
	elif r < 0.7:
		m |= 1 << (1 - toward)
	if _rng.randf() < 0.12:
		m |= 1 << BIT_JUMP
	if _rng.randf() < 0.1:
		m |= 1 << BIT_CROUCH
	if _rng.randf() < 0.1:
		m |= 1 << BIT_BLOCK
	return m

## Juega una pelea completa con estas entradas y devuelve el checksum cada `every` ticks.
## Rellena la energía de los dos de vez en cuando para que haya ultimates. `host` es el nodo
## que sostiene el combate mientras se juega.
static func play(host: Node, p1_id: StringName, p2_id: StringName, seed_value: int, ticks: int, every: int) -> Array:
	Game.p1_fighter_id = p1_id
	Game.p2_fighter_id = p2_id
	var combat := load(Game.SCENE_FIGHT).instantiate() as CombatManager
	host.add_child(combat)
	var script := ScriptedInputs.new(seed_value)
	combat.set_input_source(func(tick: int) -> Array: return script.masks(tick))
	var samples: Array = []
	var last := -1
	while combat.tick_count < ticks:
		await host.get_tree().physics_frame
		var t := combat.tick_count
		if t == last:
			continue
		last = t
		if t % 400 == 0:
			combat.p1.energy = Fighter.MAX_ENERGY
			combat.p2.energy = Fighter.MAX_ENERGY
		if t % every == 0 and t > 0:
			samples.append(combat.state_checksum())
	host.remove_child(combat)
	combat.free()
	return samples
