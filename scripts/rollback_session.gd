## Sincronización online con ROLLBACK: el combate nunca espera al rival.
##
## Cada PC simula la pelea completa y solo se intercambian los botones. Mis botones se aplican a los
## INPUT_DELAY ticks (poco, para que respondan casi al instante). Los del rival, mientras no llegan,
## se PREDICEN repitiendo su último botón conocido y la pelea sigue. Cuando llega un botón real que
## difiere de lo predicho, se vuelve a la foto (SimState) de ese tick y se re-simula hasta el presente:
## el jugador solo ve un pequeño salto, nunca una pausa.
##
## Protocolo con el servidor: igual que el lockstep (un mensaje por tick con su máscara y el acuse).
## Límite de adelanto: si el rival se retrasa más de MAX_AHEAD ticks, se espera (no se predice sin fin).
##
## No sabe nada de la red: recibe funciones para leer mis botones y enviarlos y se alimenta con receive().
class_name RollbackSession
extends RefCounted

## Ticks de retraso de MIS botones. Los ticks anteriores no llevan botones de nadie (cero en ambos PCs).
const INPUT_DELAY := 3
## Ticks que se puede ir por delante del último botón real del rival.
const MAX_AHEAD := 14
## Pasos de simulación con foto guardada (cubre MAX_AHEAD más una cinemática de ultimate).
const HISTORY := 160
const RTT_WINDOW := 60

var side: int
## Ticks de retraso de mis botones (fijo).
var delay: int = INPUT_DELAY
## Ida y vuelta estimada en ms (-1 = aún sin medir).
var rtt_ms: float = -1.0
## Ticks seguidos sin poder avanzar por pasarse del límite de adelanto.
var stalled_ticks: int = 0
## Diagnóstico: cuántas veces se volvió atrás, cuántos ticks se re-simularon y la mayor profundidad.
var rollbacks: int = 0
var resimulated_ticks: int = 0
var max_depth: int = 0
## Se llama con (tick, checksum) cuando un resumen de estado ya es definitivo (lo manda al servidor).
var sync_out: Callable
## Se llama cuando se está esperando al rival (Online lo usa para avisar de que se fue).
var on_stalled: Callable

## Solo pruebas: tick -> [mis botones, botones del rival usados] de la última vez que se simuló.
var trace: Dictionary = {}

var _sample: Callable
var _send: Callable
var _now: Callable
var _poll: Callable
## Botones por tick: míos, reales del rival y los que la simulación usó del rival.
var _local: Dictionary = {}
var _remote: Dictionary = {}
var _used: Dictionary = {}
## Último tick real del rival recibido y su botón (base de la predicción).
var _remote_max: int = INPUT_DELAY - 1
var _remote_last_mask: int = 0
var _next_frame: int = INPUT_DELAY
var _sent_at: Dictionary = {}
var _rtts: Array[float] = []
## Fotos de antes de cada paso, y qué paso consumió los botones de cada tick.
var _snaps: Dictionary = {}
var _step: int = 0
var _step_of_tick: Dictionary = {}
## Primer tick cuya predicción falló y hay que rehacer (-1 = ninguno).
var _redo_from: int = -1
## Resúmenes de estado por tick, hasta que sean definitivos.
var _checks: Dictionary = {}

## sample() -> int: mis botones de este instante. send(frame, mask, ack): los manda al rival.
## now() -> int: reloj en ms (las pruebas usan uno simulado). poll(): lee la red (opcional).
func _init(p_side: int, p_sample: Callable, p_send: Callable, p_now: Callable = Callable(),
		p_poll: Callable = Callable()) -> void:
	side = p_side
	_sample = p_sample
	_send = p_send
	_poll = p_poll
	_now = p_now if p_now.is_valid() else func() -> int: return Time.get_ticks_msec()

## Guarda los botones reales del rival para el tick `frame`. `ack` es el último tick MÍO que él había recibido.
func receive(frame: int, mask: int, ack: int = -1) -> void:
	_remote[frame] = mask
	if frame >= _remote_max:
		_remote_max = frame
		_remote_last_mask = mask
	# ¿Se simuló ese tick con otra predicción? Entonces hay que rehacerlo desde ahí.
	if _used.has(frame) and int(_used[frame]) != mask:
		_redo_from = frame if _redo_from < 0 else mini(_redo_from, frame)
	if ack >= 0 and _sent_at.has(ack):
		_rtts.append(float(_now.call() - _sent_at[ack]))
		if _rtts.size() > RTT_WINDOW:
			_rtts.pop_front()
		for f in _sent_at.keys():
			if f <= ack:
				_sent_at.erase(f)
		var sorted := _rtts.duplicate()
		sorted.sort()
		rtt_ms = sorted[int(sorted.size() * 0.9)]

## Primer tick cuyo botón del rival NO es real todavía: los anteriores son definitivos.
func confirmed_tick() -> int:
	return _remote_max + 1

## Botón del rival en el tick `t`: el real si llegó, si no la predicción (su último botón conocido).
func remote_for(t: int) -> int:
	if t < INPUT_DELAY:
		return 0
	if _remote.has(t):
		return _remote[t]
	return _remote_last_mask

func local_for(t: int) -> int:
	return 0 if t < INPUT_DELAY else int(_local.get(t, 0))

## Anota el resumen del estado en el tick `tick` (lo llama el combate); se manda cuando sea definitivo.
func note_checksum(tick: int, checksum: int) -> void:
	_checks[tick] = checksum

## Un frame de juego: corrige lo predicho mal y avanza un paso si el límite de adelanto lo permite.
func drive(cm: CombatManager, delta: float) -> void:
	if _poll.is_valid():
		_poll.call()
	if _redo_from >= 0:
		_rewind(cm, delta)
	cm.confirmed_tick = confirmed_tick()
	_flush_syncs()
	if cm.cinematic_frames == 0 and cm.tick_count - confirmed_tick() >= MAX_AHEAD:
		stalled_ticks += 1
		if on_stalled.is_valid():
			on_stalled.call()
		return
	stalled_ticks = 0
	_advance(cm, delta, false)
	_prune(cm.tick_count)

## Un paso de simulación con los botones conocidos (reales o predichos).
func _advance(cm: CombatManager, delta: float, replay: bool) -> void:
	var masks: Array = []
	if cm.cinematic_frames == 0:
		var t := cm.tick_count
		if not replay:
			_send_until(t + delay)
		var mine := local_for(t)
		var theirs := remote_for(t)
		_used[t] = theirs
		if trace != null:
			trace[t] = [mine, theirs]
		_step_of_tick[t] = _step
		masks = [mine, theirs] if side == 1 else [theirs, mine]
	_snaps[_step] = SimState.capture(cm)
	cm.sim_step(delta, masks)
	_step += 1

## Vuelve a la foto del primer tick mal predicho y re-simula hasta el tick en que se estaba.
func _rewind(cm: CombatManager, delta: float) -> void:
	var from := _redo_from
	_redo_from = -1
	if from >= cm.tick_count or not _step_of_tick.has(from) or not _snaps.has(_step_of_tick[from]):
		return
	var target := cm.tick_count
	var step0: int = _step_of_tick[from]
	var snap: Dictionary = _snaps[step0]
	rollbacks += 1
	max_depth = maxi(max_depth, target - from)
	SimState.restore(cm, snap)
	cm.discard_events_from(from)
	_step = step0
	# Los resúmenes de estado de ticks rehechos se vuelven a calcular.
	for t in _checks.keys():
		if t > from:
			_checks.erase(t)
	while cm.tick_count < target:
		_advance(cm, delta, true)
		resimulated_ticks += 1

## Manda mis botones hasta el tick `target` (uno por tick, sin saltarse ninguno).
func _send_until(target: int) -> void:
	if _next_frame > target:
		return
	var mask: int = _sample.call()
	var now: int = _now.call()
	while _next_frame <= target:
		_local[_next_frame] = mask
		_sent_at[_next_frame] = now
		_send.call(_next_frame, mask, _remote_max if _remote_max >= INPUT_DELAY else -1)
		_next_frame += 1

## Envía los resúmenes de estado cuyos ticks ya son definitivos (dependen de botones reales del rival).
func _flush_syncs() -> void:
	if _checks.is_empty() or not sync_out.is_valid():
		return
	var done: Array = []
	for t in _checks.keys():
		if t <= confirmed_tick():
			done.append(t)
	done.sort()
	for t in done:
		sync_out.call(t, _checks[t])
		_checks.erase(t)

## Olvida lo que ya no hace falta. Ojo: un PC que va por detrás del rival (cargó más tarde) tiene botones
## recibidos de ticks que aún no ha simulado; solo se borra lo anterior al tick actual Y al último confirmado.
func _prune(current_tick: int) -> void:
	var limit := mini(confirmed_tick(), current_tick) - 2
	for d in [_local, _remote, _used, _step_of_tick]:
		if d.size() > 64:
			for t in d.keys():
				if t < limit:
					d.erase(t)
	if _snaps.size() > HISTORY:
		for s in _snaps.keys():
			if s < _step - HISTORY:
				_snaps.erase(s)
