## Sincronización "lockstep con retraso de entrada" para una partida online.
##
## Cada PC simula la pelea completa y solo se intercambian los botones de cada
## tick. El botón que aprieto en el tick T se aplica en el tick T+delay en los
## DOS PCs; así, cuando llega el momento de ejecutar un tick, los botones del
## rival ya vienen en camino desde hace `delay` ticks y casi nunca hay espera.
##
## El retraso se ajusta solo a la latencia: cada envío lleva un acuse (el último
## tick del rival que recibí) y con él mido la ida y vuelta de mis botones. Si el
## retraso fuera menor que lo que tardan en llegar, el rival esperaría en cada
## tick y la pelea iría en cámara lenta. Cada lado ajusta SOLO su retraso: los
## botones viajan marcados con su tick, así que el otro no necesita saberlo.
##
## No sabe nada de la red: recibe una función para leer mis botones y otra para
## enviarlos, y se alimenta con receive(). Por eso se prueba sin conexión.
class_name LockstepSession
extends RefCounted

## Retraso al empezar, antes de medir nada: 4 ticks = 66 ms. Los ticks anteriores
## no llevan botones de nadie (cero en ambos PCs) y no se envían.
const INITIAL_DELAY := 4
const MIN_DELAY := 2
## 15 ticks = 250 ms: con más lag, mejor esperar que jugar con tanto retraso.
const MAX_DELAY := 15
## Subir el retraso es inmediato; bajarlo, de a un tick y como mucho una vez por segundo.
const LOWER_EVERY := 60
## Mediciones de ida y vuelta recientes que se tienen en cuenta.
const RTT_WINDOW := 60
const TICK_MS := 1000.0 / 60.0

## 1 = controlo a P1, 2 = controlo a P2.
var side: int
## Ticks de retraso de MIS botones en este momento.
var delay: int = INITIAL_DELAY
## Ida y vuelta estimada en ms (-1 = aún sin medir).
var rtt_ms: float = -1.0
## Ticks seguidos esperando los botones del rival (para avisar al jugador).
var stalled_ticks: int = 0

var _sample: Callable
var _send: Callable
var _now: Callable
## Botones por tick: míos (ya enviados) y del rival (recibidos).
var _local: Dictionary = {}
var _remote: Dictionary = {}
## Próximo tick para el que mandaré mis botones.
var _next_frame: int = INITIAL_DELAY
## Último tick del rival recibido (lo que acuso en cada envío).
var _acked: int = -1
## Cuándo mandé los botones de cada tick (ms), hasta que el rival lo acuse.
var _sent_at: Dictionary = {}
var _rtts: Array[float] = []
var _last_change: int = 0

## sample() -> int devuelve mis botones de este instante (InputManager.sample_mask).
## send(frame: int, mask: int, ack: int) los manda al rival; ack = -1 si aún no recibí nada.
## now() -> int da el reloj en ms (por defecto el del motor; las pruebas usan uno simulado).
func _init(p_side: int, p_sample: Callable, p_send: Callable, p_now: Callable = Callable()) -> void:
	side = p_side
	_sample = p_sample
	_send = p_send
	_now = p_now if p_now.is_valid() else func() -> int: return Time.get_ticks_msec()

## Guarda los botones que el rival aplicará en el tick `frame`. `ack` es el último
## tick MÍO que el rival había recibido al enviarlos (-1 si no lo dice).
func receive(frame: int, mask: int, ack: int = -1) -> void:
	_remote[frame] = mask
	_acked = maxi(_acked, frame)
	if ack >= 0 and _sent_at.has(ack):
		_rtts.append(float(_now.call() - _sent_at[ack]))
		if _rtts.size() > RTT_WINDOW:
			_rtts.pop_front()
		for f in _sent_at.keys():
			if f <= ack:
				_sent_at.erase(f)

## Fuente de entradas del combate (ver CombatManager.set_input_source).
## Devuelve [máscara_P1, máscara_P2] del tick `tick`, o [] si aún faltan los
## botones del rival: el combate espera y vuelve a preguntar en el siguiente frame.
func masks_for(tick: int) -> Array:
	_adapt_delay(tick)
	_send_until(tick + delay)
	# Los primeros ticks no tienen botones de nadie: arrancan en cero para ambos.
	var mine := 0
	var theirs := 0
	if tick >= INITIAL_DELAY:
		if not _remote.has(tick):
			stalled_ticks += 1
			return []
		mine = _local.get(tick, 0)
		theirs = _remote[tick]
	stalled_ticks = 0
	_local.erase(tick)
	_remote.erase(tick)
	return [mine, theirs] if side == 1 else [theirs, mine]

## Manda mis botones hasta el tick `target`. Si el retraso acaba de subir quedan
## ticks sin cubrir: llevan los mismos botones. Si bajó, esos ticks ya se enviaron.
func _send_until(target: int) -> void:
	if _next_frame > target:
		return
	var mask: int = _sample.call()
	var now: int = _now.call()
	while _next_frame <= target:
		_local[_next_frame] = mask
		_sent_at[_next_frame] = now
		_send.call(_next_frame, mask, _acked)
		_next_frame += 1

## Mis botones deben llegar al rival antes de que los necesite: el retraso cubre la
## ida (la mitad de la ida y vuelta) más un tick de margen. Se usa una medición alta
## de las recientes (percentil 90) para que los picos de la conexión no frenen la pelea.
func _adapt_delay(tick: int) -> void:
	if _rtts.is_empty():
		return
	var sorted := _rtts.duplicate()
	sorted.sort()
	rtt_ms = sorted[int(sorted.size() * 0.9)]
	var wanted := clampi(ceili(rtt_ms * 0.5 / TICK_MS) + 1, MIN_DELAY, MAX_DELAY)
	if wanted > delay:
		delay = wanted
		_last_change = tick
	elif wanted < delay and tick - _last_change >= LOWER_EVERY:
		delay -= 1
		_last_change = tick
