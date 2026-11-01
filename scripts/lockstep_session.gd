## Sincronización "lockstep con retraso de entrada" para una partida online.
##
## Cada PC simula la pelea completa y solo se intercambian los botones de cada
## tick. El botón que aprieto en el tick T se aplica en el tick T+INPUT_DELAY en
## los DOS PCs; así, cuando llega el momento de ejecutar un tick, los botones del
## rival ya vienen en camino desde hace INPUT_DELAY ticks y casi nunca hay espera.
##
## No sabe nada de la red: recibe una función para leer mis botones y otra para
## enviarlos, y se alimenta con receive(). Por eso se prueba sin conexión.
class_name LockstepSession
extends RefCounted

## Ticks de retraso: 4 = 66 ms, además de lo que tarde el paquete en llegar.
const INPUT_DELAY := 4

## 1 = controlo a P1, 2 = controlo a P2.
var side: int
## Ticks seguidos esperando los botones del rival (para avisar al jugador).
var stalled_ticks: int = 0

var _sample: Callable
var _send: Callable
## Botones por tick: míos (ya enviados) y del rival (recibidos).
var _local: Dictionary = {}
var _remote: Dictionary = {}

## sample() -> int devuelve mis botones de este instante (InputManager.sample_mask).
## send(frame: int, mask: int) los manda al rival.
func _init(p_side: int, p_sample: Callable, p_send: Callable) -> void:
	side = p_side
	_sample = p_sample
	_send = p_send

## Guarda los botones que el rival aplicará en el tick `frame`.
func receive(frame: int, mask: int) -> void:
	_remote[frame] = mask

## Fuente de entradas del combate (ver CombatManager.set_input_source).
## Devuelve [máscara_P1, máscara_P2] del tick `tick`, o [] si aún faltan los
## botones del rival: el combate espera y vuelve a preguntar en el siguiente frame.
func masks_for(tick: int) -> Array:
	var target := tick + INPUT_DELAY
	if not _local.has(target):
		var mask: int = _sample.call()
		_local[target] = mask
		_send.call(target, mask)
	# Los primeros ticks no tienen botones de nadie: arrancan en cero para ambos.
	var mine := 0
	var theirs := 0
	if tick >= INPUT_DELAY:
		if not _remote.has(tick):
			stalled_ticks += 1
			return []
		mine = _local.get(tick, 0)
		theirs = _remote[tick]
	stalled_ticks = 0
	_local.erase(tick)
	_remote.erase(tick)
	return [mine, theirs] if side == 1 else [theirs, mine]
