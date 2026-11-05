## Reglas del combate: rondas, temporizador y fin de partida.
##   - Gana el combate quien consiga Game.rounds_to_win rondas (2).
##   - Cada ronda dura Game.round_time segundos (99) y empieza con vida llena.
##   - K.O.: la ronda termina en cuanto alguien llega a 0.
##   - Tiempo agotado: gana quien conserve más % de vida; igual = empate.
##   - Doble K.O. o igualdad de vida = empate (nadie suma ronda).
class_name RoundManager
extends Node

enum Phase { INTRO, FIGHT, ROUND_END, MATCH_END }

var phase: Phase = Phase.INTRO
var round_number: int = 1
var wins: Array[int] = [0, 0, 0]  # índices 1 y 2
var time_left: float = 99.0
## Para pruebas automáticas: acelera las pausas entre mensajes.
var pause_scale: float = 1.0

var combat: CombatManager
var _ko_pending: bool = false
## Máquina de la ronda (todo avanza con los ticks del combate, nada espera con await):
## `_step` es el paso dentro de ROUND_END, `_wait_until` el tick en que acaba la espera actual.
## Los tres entran en la foto del estado (SimState) para poder volver a un tick.
var _step: int = 0
var _wait_until: int = 0
var _winner: int = 0

func _ready() -> void:
	combat = get_parent() as CombatManager
	# El reloj cuenta ticks del combate, no tiempo del motor: si el combate espera
	# (partida online) o se pausa, el reloj se detiene con él.
	combat.ticked.connect(_on_tick)

## Corta la partida sin resultado (se cayó la conexión): ya no hay rondas ni reloj.
func abort() -> void:
	phase = Phase.MATCH_END
	combat.set_controls(false)

func start_match() -> void:
	wins = [0, 0, 0]
	round_number = 1
	combat.fighter_knocked_out.connect(_on_fighter_ko)
	start_round()

## Entrenamiento: sin cuenta atrás, reloj ni fin de ronda; se pelea desde el primer frame.
func start_training() -> void:
	wins = [0, 0, 0]
	round_number = 1
	_ko_pending = false
	time_left = float(Game.round_time)
	combat.reset_round()
	combat.hud.set_round(1, wins)
	combat.set_controls(true)
	phase = Phase.FIGHT

func start_round() -> void:
	phase = Phase.INTRO
	_ko_pending = false
	time_left = float(Game.round_time)
	combat.reset_round()
	combat.set_controls(false)
	combat.present(combat.hud, &"set_round", [round_number, wins.duplicate()])
	combat.present(combat.hud, &"show_message", ["ROUND %d" % round_number, 1.1, HKTheme.PAPER])
	combat.present(combat.hud, &"show_stage_name", [combat.stage_name()])
	combat.sfx(&"round")
	_begin_wait(1.2)

const TICK_SECONDS := 1.0 / 60.0

## Avanza la ronda un tick. Es lo único que mueve intro, reloj, K.O. y cambio de ronda.
func _on_tick() -> void:
	match phase:
		Phase.INTRO:
			if combat.tick_count >= _wait_until:
				combat.present(combat.hud, &"show_message", ["FIGHT!", 0.8, HKTheme.GOLD])
				combat.sfx(&"fight")
				combat.set_controls(true)
				phase = Phase.FIGHT
		Phase.FIGHT:
			if Game.mode == Game.Mode.TRAINING:
				return
			# El reloj se detiene durante la cinemática de un ultimate.
			if combat.cinematic_frames > 0:
				return
			time_left = maxf(time_left - TICK_SECONDS, 0.0)
			if time_left <= 0.0:
				_end_round("TIME")
			elif _ko_pending:
				# Se espera al final del tick por si ambos caen a la vez (doble K.O.).
				_end_round("KO")
		Phase.ROUND_END:
			if combat.tick_count >= _wait_until:
				_advance_round_end()

func seconds_left() -> int:
	return int(ceil(time_left))

func _on_fighter_ko(_fighter: Fighter) -> void:
	if phase == Phase.FIGHT:
		_ko_pending = true

func _end_round(reason: String) -> void:
	if phase != Phase.FIGHT:
		return
	phase = Phase.ROUND_END
	_step = 0
	combat.set_controls(false)
	var p1 := combat.p1
	var p2 := combat.p2
	_winner = 0
	var r1 := p1.health / p1.data.max_health
	var r2 := p2.health / p2.data.max_health
	if r1 > r2 + 0.0001:
		_winner = 1
	elif r2 > r1 + 0.0001:
		_winner = 2
	if _winner != 0:
		wins[_winner] += 1
		Passives.on_round_won(p1 if _winner == 1 else p2)
	combat.present(combat.hud, &"set_round", [round_number, wins.duplicate()])
	if reason == "KO":
		combat.present(combat.hud, &"show_message", ["K.O.", 1.4, HKTheme.BLOOD])
	else:
		combat.present(combat.hud, &"show_message", ["TIME", 1.4, HKTheme.PAPER])
	_begin_wait(1.6)

## Pasos del fin de ronda, cada uno tras su espera: resultado -> fin de partida o siguiente ronda.
func _advance_round_end() -> void:
	match _step:
		0:
			if _winner == 1:
				combat.p1.set_victory()
				combat.present(combat.hud, &"show_message", ["PLAYER 1 WINS", 1.8, HKTheme.GOLD])
			elif _winner == 2:
				combat.p2.set_victory()
				combat.present(combat.hud, &"show_message", ["CPU WINS" if Game.is_vs_cpu() else "PLAYER 2 WINS", 1.8, HKTheme.GOLD])
			else:
				combat.present(combat.hud, &"show_message", ["DRAW", 1.8, HKTheme.PAPER])
			_step = 1
			_begin_wait(2.2)
		1:
			# Esto es simulación: pasa en el MISMO tick en todos los PCs (nunca depende de la red).
			# Lo irreversible (cambiar de escena) va por present(), que espera a que el tick se confirme.
			var match_winner := 0
			if wins[1] >= Game.rounds_to_win:
				match_winner = 1
			elif wins[2] >= Game.rounds_to_win:
				match_winner = 2
			if match_winner != 0 or round_number >= Game.max_rounds:
				if match_winner == 0 and wins[1] != wins[2]:
					match_winner = 1 if wins[1] > wins[2] else 2
				phase = Phase.MATCH_END
				combat.present(Game, &"set_match_result", [match_winner, wins[1], wins[2]])
				combat.present(Game, &"goto", [Game.SCENE_RESULTS])
			# Cada ronda se juega en el escenario de un luchador distinto (ver Game.stage_owner).
			elif combat.stage_changes_for(round_number + 1):
				# El fundido es solo visual; el cambio de escenario espera ticks fijos.
				combat.present(Game, &"fade_to_black", [0.14])
				_step = 2
				_begin_wait(0.15)
			else:
				_next_round()
		2:
			combat.swap_stage(round_number + 1)
			_next_round()
			# Después de _next_round(): start_round() vacía la cola de eventos (reset_round) y borraría este
			# fundido, dejando la pantalla en negro mientras el combate sigue (bug online del round 2).
			combat.present(Game, &"fade_from_black", [0.22])

func _next_round() -> void:
	round_number += 1
	start_round()

## Espera `seconds` de combate: cuenta ticks, no segundos de reloj ni señales del motor, así la ronda
## avanza en el MISMO tick en todos los PCs de una partida online. Con la pausa el combate no avanza.
func _begin_wait(seconds: float) -> void:
	_wait_until = combat.tick_count + ceili(seconds * 60.0 * pause_scale)
