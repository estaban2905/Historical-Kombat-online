## Reglas del combate: rondas, temporizador y fin de partida.
##   - Gana el combate quien consiga Game.rounds_to_win rondas (2).
##   - Cada ronda dura Game.round_time segundos (99) y empieza con vida llena.
##   - K.O.: la ronda termina en cuanto alguien llega a 0.
##   - Tiempo agotado: gana quien conserve más % de vida; igual = empate.
##   - Doble K.O. o igualdad de vida = empate (nadie suma ronda).
class_name RoundManager
extends Node

signal round_started(round_number: int)
signal round_finished(winner: int, reason: String)
signal match_finished(winner: int)

enum Phase { INTRO, FIGHT, ROUND_END, MATCH_END }

var phase: Phase = Phase.INTRO
var round_number: int = 1
var wins: Array[int] = [0, 0, 0]  # índices 1 y 2
var time_left: float = 99.0
## Para pruebas automáticas: acelera las pausas entre mensajes.
var pause_scale: float = 1.0

var combat: CombatManager
var _ko_pending: bool = false

func _ready() -> void:
	combat = get_parent() as CombatManager

func start_match() -> void:
	wins = [0, 0, 0]
	round_number = 1
	combat.fighter_knocked_out.connect(_on_fighter_ko)
	start_round()

func start_round() -> void:
	phase = Phase.INTRO
	_ko_pending = false
	time_left = float(Game.round_time)
	combat.reset_round()
	combat.set_controls(false)
	combat.hud.set_round(round_number, wins)
	round_started.emit(round_number)
	combat.hud.show_message("ROUND %d" % round_number, 1.1, HKTheme.PAPER)
	combat.hud.show_stage_name(combat.stage_name())
	Sfx.play(&"round")
	if not await _wait(1.2):
		return
	combat.hud.show_message("FIGHT!", 0.8, HKTheme.GOLD)
	Sfx.play(&"fight")
	combat.set_controls(true)
	phase = Phase.FIGHT

func _physics_process(delta: float) -> void:
	if phase != Phase.FIGHT:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_end_round("TIME")

func seconds_left() -> int:
	return int(ceil(time_left))

func _on_fighter_ko(_fighter: Fighter) -> void:
	# Se espera al final del frame por si ambos caen a la vez (doble K.O.).
	if phase == Phase.FIGHT and not _ko_pending:
		_ko_pending = true
		_end_round.call_deferred("KO")

func _end_round(reason: String) -> void:
	if phase != Phase.FIGHT:
		return
	phase = Phase.ROUND_END
	combat.set_controls(false)
	var p1 := combat.p1
	var p2 := combat.p2
	var winner := 0
	var r1 := p1.health / p1.data.max_health
	var r2 := p2.health / p2.data.max_health
	if r1 > r2 + 0.0001:
		winner = 1
	elif r2 > r1 + 0.0001:
		winner = 2
	if winner != 0:
		wins[winner] += 1
	round_finished.emit(winner, reason)
	combat.hud.set_round(round_number, wins)

	if reason == "KO":
		combat.hud.show_message("K.O.", 1.4, HKTheme.BLOOD)
	else:
		combat.hud.show_message("TIME", 1.4, HKTheme.PAPER)
	if not await _wait(1.6):
		return
	if winner == 1:
		p1.set_victory()
		combat.hud.show_message("PLAYER 1 WINS", 1.8, HKTheme.GOLD)
	elif winner == 2:
		p2.set_victory()
		combat.hud.show_message("CPU WINS" if Game.is_vs_cpu() else "PLAYER 2 WINS", 1.8, HKTheme.GOLD)
	else:
		combat.hud.show_message("DRAW", 1.8, HKTheme.PAPER)
	if not await _wait(2.2):
		return

	var match_winner := 0
	if wins[1] >= Game.rounds_to_win:
		match_winner = 1
	elif wins[2] >= Game.rounds_to_win:
		match_winner = 2
	if match_winner != 0 or round_number >= Game.max_rounds:
		if match_winner == 0 and wins[1] != wins[2]:
			match_winner = 1 if wins[1] > wins[2] else 2
		phase = Phase.MATCH_END
		Game.set_match_result(match_winner, wins[1], wins[2])
		match_finished.emit(match_winner)
		Game.goto(Game.SCENE_RESULTS)
	else:
		# Cada ronda se juega en el escenario de un luchador distinto (ver Game.stage_owner).
		if combat.stage_changes_for(round_number + 1):
			await Game.fade_to_black(0.14)
			if not is_inside_tree():
				return
			combat.swap_stage(round_number + 1)
			Game.fade_from_black(0.22)
		round_number += 1
		start_round()

## Espera respetando la pausa. Devuelve false si la escena ya no existe.
func _wait(seconds: float) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().create_timer(seconds * pause_scale, false).timeout
	return is_inside_tree()
