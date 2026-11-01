## HUD arcade del combate. Se dibuja todo a mano en _draw() para que cada
## barra y cada letra caiga exactamente en la rejilla de 426x240 píxeles.
##   - Nombres, barras de vida (con estela roja de daño) y de energía.
##   - Temporizador central, indicador de ronda y medallas de rondas ganadas.
##   - Mensajes grandes (ROUND 1, FIGHT!, K.O., PLAYER 1 WINS, DRAW...).
##   - Contador de combo y aviso de energía insuficiente.
class_name HUD
extends Control

const BAR_W := 172
const BAR_H := 9
const BAR_Y := 16
const ENERGY_W := 96
const ENERGY_Y := 28
const GUARD_Y := 36
const GUARD_H := 3

var combat: CombatManager
var round_number: int = 1
var wins: Array[int] = [0, 0, 0]

var _trail: Array[float] = [1.0, 1.0, 1.0]       # estela roja (índices 1 y 2)
var _trail_delay: Array[float] = [0.0, 0.0, 0.0]
var _message: String = ""
var _message_color: Color = Color.WHITE
var _message_t: float = 0.0
var _message_dur: float = 0.0
var _stage_name: String = ""
var _stage_name_t: float = 99.0
var _combo: Array[int] = [0, 0, 0]        # golpes encadenados POR el jugador i
var _combo_t: Array[float] = [0.0, 0.0, 0.0]
var _no_energy_t: Array[float] = [0.0, 0.0, 0.0]
## Avisos de counter-hit y de combo con nombre completado, por jugador que los hace.
var _counter_t: Array[float] = [0.0, 0.0, 0.0]
var _combo_name: Array[String] = ["", "", ""]
var _combo_name_t: Array[float] = [0.0, 0.0, 0.0]
var _perfect_t: Array[float] = [0.0, 0.0, 0.0]
var _time: float = 0.0

func bind(p_combat: CombatManager) -> void:
	combat = p_combat
	combat.hit_landed.connect(_on_hit_landed)
	for f in combat.fighters:
		f.not_enough_energy.connect(func(who: Fighter): _no_energy_t[who.player_id] = 1.0)
		f.health_changed.connect(_on_health_changed)

func set_round(n: int, p_wins: Array[int]) -> void:
	round_number = n
	wins = p_wins.duplicate()

func show_message(text: String, duration: float, color: Color = Color.WHITE) -> void:
	_message = text
	_message_color = color
	_message_t = 0.0
	_message_dur = duration

## Rótulo con el nombre del escenario al empezar cada ronda.
func show_stage_name(text: String) -> void:
	_stage_name = text
	_stage_name_t = 0.0

func current_message() -> String:
	return _message if _message_t < _message_dur else ""

func _on_health_changed(f: Fighter) -> void:
	# Vida al máximo (nueva ronda): la estela se reinicia.
	if f.health >= f.data.max_health:
		_trail[f.player_id] = 1.0
	_trail_delay[f.player_id] = 0.45

func _on_hit_landed(attacker: Fighter, defender: Fighter, _atk: AttackData, result: Dictionary) -> void:
	if result.blocked:
		if result.perfect:
			_perfect_t[defender.player_id] = 1.0
		return
	_combo[attacker.player_id] = defender.combo_hits_taken
	_combo_t[attacker.player_id] = 1.2
	if result.counter:
		_counter_t[attacker.player_id] = 1.2
	if result.combo_name != "":
		_combo_name[attacker.player_id] = result.combo_name
		_combo_name_t[attacker.player_id] = 1.6

func _process(delta: float) -> void:
	_time += delta
	_message_t += delta
	_stage_name_t += delta
	if combat:
		for f in combat.fighters:
			var i := f.player_id
			var ratio := f.health / f.data.max_health
			_trail_delay[i] -= delta
			if _trail_delay[i] <= 0.0:
				_trail[i] = move_toward(_trail[i], ratio, delta * 0.6)
			_trail[i] = maxf(_trail[i], ratio)
			_combo_t[i] = maxf(_combo_t[i] - delta, 0.0)
			_no_energy_t[i] = maxf(_no_energy_t[i] - delta * 1.5, 0.0)
			_counter_t[i] = maxf(_counter_t[i] - delta, 0.0)
			_perfect_t[i] = maxf(_perfect_t[i] - delta, 0.0)
			_combo_name_t[i] = maxf(_combo_name_t[i] - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	if combat == null:
		return
	var f1 := combat.p1
	var f2 := combat.p2
	# Franja superior oscura para legibilidad
	draw_rect(Rect2(0, 0, 426, 41), Color(0.05, 0.02, 0.06, 0.55))
	_draw_side(f1, 1)
	_draw_side(f2, 2)
	_draw_timer()
	_draw_message()
	_draw_stage_name()
	_draw_ultimate_cinematic()

func _draw_stage_name() -> void:
	if _stage_name.is_empty() or _stage_name_t >= 2.8:
		return
	var a := clampf(minf(_stage_name_t / 0.3, (2.8 - _stage_name_t) / 0.4), 0.0, 1.0)
	var col := HKTheme.GOLD
	col.a = a
	draw_rect(Rect2(0, 216, 426, 14), Color(0, 0, 0, 0.5 * a))
	HKTheme.draw_text(self, Vector2(0, 227), _stage_name, 8, col, HORIZONTAL_ALIGNMENT_CENTER, 426, 2)

func _draw_side(f: Fighter, i: int) -> void:
	var left := i == 1
	var x0 := 8.0 if left else 426.0 - 8.0 - BAR_W
	# Nombre
	var label := "%s  P%d" % [f.data.short_name, i] if left else "P%d  %s" % [i, f.data.short_name]
	if left:
		HKTheme.draw_text(self, Vector2(x0, 12), label, 8, HKTheme.PAPER)
	else:
		HKTheme.draw_text(self, Vector2(x0, 12), label, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_RIGHT, BAR_W)
	# Barra de vida: marco, fondo, estela roja y relleno
	var frame := Rect2(x0 - 2, BAR_Y - 2, BAR_W + 4, BAR_H + 4)
	draw_rect(frame, HKTheme.INK)
	draw_rect(frame.grow(-1), HKTheme.GOLD_DARK)
	var inner := Rect2(x0, BAR_Y, BAR_W, BAR_H)
	draw_rect(inner, Color("2a0a10"))
	var ratio := clampf(f.health / f.data.max_health, 0.0, 1.0)
	var trail_w := roundf(BAR_W * _trail[i])
	var fill_w := roundf(BAR_W * ratio)
	# P1 se vacía hacia la izquierda, P2 hacia la derecha (simetría arcade).
	var trail_rect := Rect2(x0, BAR_Y, trail_w, BAR_H) if left else Rect2(x0 + BAR_W - trail_w, BAR_Y, trail_w, BAR_H)
	var fill_rect := Rect2(x0, BAR_Y, fill_w, BAR_H) if left else Rect2(x0 + BAR_W - fill_w, BAR_Y, fill_w, BAR_H)
	draw_rect(trail_rect, Color("e83a2a"))
	var col := Color("58d040")
	if ratio < 0.25:
		col = Color("f04030") if int(_time * 6.0) % 2 == 0 else Color("f0a030")
	elif ratio < 0.5:
		col = Color("e8c838")
	if fill_w > 0:
		draw_rect(fill_rect, col)
		draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, 2)), col.lightened(0.35))
		draw_rect(Rect2(fill_rect.position + Vector2(0, BAR_H - 2), Vector2(fill_rect.size.x, 2)), col.darkened(0.3))
	# Energía especial
	var ex := x0 if left else x0 + BAR_W - ENERGY_W
	var er := Rect2(ex, ENERGY_Y, ENERGY_W, 4)
	draw_rect(er.grow(1), HKTheme.INK)
	draw_rect(er, Color("101830"))
	var e_ratio := f.energy / Fighter.MAX_ENERGY
	var ew := roundf(ENERGY_W * e_ratio)
	var e_rect := Rect2(ex, ENERGY_Y, ew, 4) if left else Rect2(ex + ENERGY_W - ew, ENERGY_Y, ew, 4)
	var ecol := Color("3a90ff")
	if f.energy >= f.data.special_2.energy_cost:
		ecol = Color("60d0ff") if int(_time * 4.0) % 2 == 0 else Color("3aa8ff")
	var ult_ready := f.data.ultimate != null and f.energy >= f.data.ultimate.energy_cost
	if ult_ready:
		# Energía llena: el ultimate está listo (dorado parpadeante).
		ecol = HKTheme.GOLD if int(_time * 6.0) % 2 == 0 else Color("fff4b0")
	draw_rect(e_rect, ecol)
	draw_rect(Rect2(e_rect.position, Vector2(e_rect.size.x, 1)), ecol.lightened(0.4))
	# Marcas de coste de los especiales
	for cost in [f.data.special_1.energy_cost, f.data.special_2.energy_cost]:
		var mx := ex + roundf(ENERGY_W * cost / Fighter.MAX_ENERGY)
		if not left:
			mx = ex + ENERGY_W - roundf(ENERGY_W * cost / Fighter.MAX_ENERGY)
		draw_rect(Rect2(mx, ENERGY_Y - 1, 1, 6), HKTheme.PAPER)
	_draw_guard(f, ex)
	if ult_ready and not f.guard_is_broken:
		var ua := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		var ux := ex if left else ex + ENERGY_W - 120.0
		HKTheme.draw_text(self, Vector2(ux, 48), "¡ULTIMATE LISTO!", 8, HKTheme.GOLD, ua, 120)
	if _no_energy_t[i] > 0.0:
		var nx := 8.0 if left else 426.0 - 8.0 - 120.0
		var na := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		HKTheme.draw_text(self, Vector2(nx, 50), "SIN ENERGÍA", 8, HKTheme.BLOOD, na, 120)
	# Medallas de rondas ganadas (junto al reloj)
	for r in Game.rounds_to_win:
		var mx := x0 + BAR_W - 9 - r * 10 if left else x0 + 1 + r * 10
		var m := Rect2(mx, ENERGY_Y - 1, 8, 7)
		draw_rect(m.grow(1), HKTheme.INK)
		if wins[i] > r:
			draw_rect(m, HKTheme.GOLD)
			draw_rect(Rect2(m.position + Vector2(2, 1), Vector2(3, 2)), Color("fff4b0"))
		else:
			draw_rect(m, Color("3a2a2a"))
	# Contador de combo
	if _combo[i] >= 2 and _combo_t[i] > 0.0:
		var cx := 12.0 if left else 426.0 - 12.0 - 100.0
		var align := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		HKTheme.draw_text(self, Vector2(cx, 62), "%d GOLPES" % _combo[i], 8, HKTheme.GOLD, align, 100)
		HKTheme.draw_text(self, Vector2(cx, 72), "COMBO!", 8, HKTheme.BLOOD, align, 100)
	# Counter-hit y combo con nombre, debajo del contador
	var cx2 := 12.0 if left else 426.0 - 12.0 - 100.0
	var align2 := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	if _perfect_t[i] > 0.0:
		HKTheme.draw_text(self, Vector2(cx2, 84), "¡PERFECTO!", 8, Color("60ff90"), align2, 100)
	if _counter_t[i] > 0.0:
		var ccol := Color("60d0ff") if int(_time * 12.0) % 2 == 0 else HKTheme.PAPER
		HKTheme.draw_text(self, Vector2(cx2, 84), "¡COUNTER!", 8, ccol, align2, 100)
	if _combo_name_t[i] > 0.0:
		HKTheme.draw_text(self, Vector2(cx2, 94), _combo_name[i], 8, HKTheme.GOLD, align2, 100)

## Barra fina de guardia bajo la de energía (mismo lado y ancho).
## Verde-azulada llena; amarilla por debajo del 50 %; naranja por debajo del 25 %;
## parpadea en rojo mientras la guardia está rota.
func _draw_guard(f: Fighter, ex: float) -> void:
	var left := f.player_id == 1
	var r := Rect2(ex, GUARD_Y, ENERGY_W, GUARD_H)
	draw_rect(r.grow(1), HKTheme.INK)
	draw_rect(r, Color("1a2a2a"))
	var ratio := clampf(f.guard / Fighter.MAX_GUARD, 0.0, 1.0)
	var w := roundf(ENERGY_W * ratio)
	var col := Color("40d0b0")
	if f.guard_is_broken:
		col = Color("f04030") if int(_time * 10.0) % 2 == 0 else Color("f8f0d0")
	elif ratio < 0.25:
		col = Color("f08030")
	elif ratio < 0.5:
		col = Color("e8c838")
	if w > 0:
		var fill := Rect2(ex, GUARD_Y, w, GUARD_H) if left else Rect2(ex + ENERGY_W - w, GUARD_Y, w, GUARD_H)
		draw_rect(fill, col)
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, 1)), col.lightened(0.4))
	if f.guard_is_broken:
		var gx := ex if left else ex + ENERGY_W - 120.0
		var ga := HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
		HKTheme.draw_text(self, Vector2(gx, 60), "¡GUARDIA ROTA!", 8, HKTheme.BLOOD, ga, 120)

## Cinemática del ultimate: bandas negras arriba y abajo y el nombre del ataque.
func _draw_ultimate_cinematic() -> void:
	var frames := combat.cinematic_frames
	if frames <= 0 or combat.cinematic_fighter == null:
		return
	var elapsed := CombatManager.ULT_CINEMATIC_FRAMES - frames
	var slide := ease(clampf(minf(float(elapsed) / 8.0, float(frames) / 8.0), 0.0, 1.0), 0.5)
	var bar := 30.0 * slide
	draw_rect(Rect2(0, 0, 426, bar), Color(0, 0, 0, 0.92))
	draw_rect(Rect2(0, 240.0 - bar, 426, bar), Color(0, 0, 0, 0.92))
	var f := combat.cinematic_fighter
	var accent := f.data.coat_trim_color
	# Nombre del luchador (arriba) y del ataque (abajo), con un pequeño temblor al entrar.
	var pop := clampf(float(elapsed) / 6.0, 0.0, 1.0)
	var shake_x := (1.0 - pop) * 8.0 * (1.0 if elapsed % 2 == 0 else -1.0)
	if bar > 18.0:
		HKTheme.draw_text(self, Vector2(shake_x, 19), f.data.display_name, 8, HKTheme.PAPER,
			HORIZONTAL_ALIGNMENT_CENTER, 426)
		HKTheme.draw_text(self, Vector2(shake_x, 240.0 - 11.0), combat.cinematic_text, 16, accent,
			HORIZONTAL_ALIGNMENT_CENTER, 426, 3)

func _draw_timer() -> void:
	var box := Rect2(213 - 17, 3, 34, 24)
	draw_rect(box, HKTheme.INK)
	draw_rect(box.grow(-1), Color("3a1418"))
	draw_rect(Rect2(box.position + Vector2(1, 1), Vector2(box.size.x - 2, 1)), HKTheme.GOLD_DARK)
	if Game.mode == Game.Mode.TRAINING:
		# Sin reloj ni rondas.
		HKTheme.draw_text(self, Vector2(box.position.x, 23), "--", 16, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		HKTheme.draw_text(self, Vector2(0, 46), "ENTRENAMIENTO", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426)
		return
	var secs := combat.round_manager.seconds_left()
	var col := HKTheme.PAPER if secs > 10 else (HKTheme.BLOOD if int(_time * 4.0) % 2 == 0 else HKTheme.PAPER)
	HKTheme.draw_text(self, Vector2(box.position.x, 23), "%02d" % secs, 16, col, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	HKTheme.draw_text(self, Vector2(0, 46), "ROUND %d" % round_number, 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 426)

func _draw_message() -> void:
	if _message.is_empty() or _message_t >= _message_dur:
		return
	# Entrada con "pop": empieza grande y se asienta.
	var size := 24
	if _message.length() > 8:
		size = 16
	var pop := clampf(_message_t / 0.12, 0.0, 1.0)
	var fade := clampf((_message_dur - _message_t) / 0.2, 0.0, 1.0)
	var y := 112.0 - (1.0 - pop) * 12.0
	var col := _message_color
	col.a = fade
	# Banda negra detrás del mensaje
	draw_rect(Rect2(0, y - size - 6, 426, size + 14), Color(0, 0, 0, 0.45 * fade))
	HKTheme.draw_text(self, Vector2(0, y), _message, size, col, HORIZONTAL_ALIGNMENT_CENTER, 426, 4)
