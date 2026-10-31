## Pantalla de victoria: ganador en pose triunfal, marcador de rondas,
## frase de victoria y opciones de REVANCHA / CAMBIAR LUCHADOR / MENÚ.
extends Control

@onready var btn_rematch: Button = $Buttons/Rematch
@onready var btn_select: Button = $Buttons/Select
@onready var btn_menu: Button = $Buttons/Menu

var _t: float = 0.0
var _winner_data: FighterData
## Arcade: qué toca después (next | complete | retry | over). Vacío en versus.
var _arcade: StringName = &""

func _ready() -> void:
	theme = HKTheme.theme()
	get_tree().paused = false
	if Game.is_vs_cpu():
		_arcade = Game.arcade_outcome()
	_setup_buttons()
	for b in [btn_rematch, btn_select, btn_menu]:
		b.focus_entered.connect(func(): Sfx.play(&"select"))
		b.pressed.connect(func(): Sfx.play(&"confirm"))
	if Game.last_winner == 0:
		# Empate: los dos luchadores, en pose normal.
		_add_figure(Game.p1_data(), Vector2(70, 200), 1, &"idle")
		_add_figure(Game.p2_data(), Vector2(150, 200), -1, &"idle")
	else:
		_winner_data = Game.p1_data() if Game.last_winner == 1 else Game.p2_data()
		_add_figure(_winner_data, Vector2(104, 214), 2, &"victory")
	if btn_rematch.visible:
		btn_rematch.grab_focus()
	else:
		btn_menu.grab_focus()

## Versus: revancha / cambiar luchador. Arcade: siguiente combate, continuar
## (gasta una revancha) o solo volver al menú si se acabó la partida.
func _setup_buttons() -> void:
	btn_menu.pressed.connect(func(): Game.goto(Game.SCENE_MENU))
	if _arcade == &"":
		btn_rematch.pressed.connect(func(): Game.goto(Game.SCENE_FIGHT))
		btn_select.pressed.connect(func(): Game.goto(Game.SCENE_SELECT))
		return
	btn_select.visible = false
	match _arcade:
		&"next":
			btn_rematch.text = "SIGUIENTE COMBATE"
			btn_rematch.pressed.connect(func():
				Game.arcade_advance()
				Game.goto(Game.SCENE_FIGHT))
		&"retry":
			btn_rematch.text = "CONTINUAR (%d)" % Game.arcade_continues
			btn_rematch.pressed.connect(func():
				Game.arcade_use_continue()
				Game.goto(Game.SCENE_FIGHT))
		_:
			btn_rematch.visible = false

func _add_figure(d: FighterData, pos: Vector2, s: int, pose: StringName) -> void:
	var r := FighterRenderer.new()
	add_child(r)
	move_child(r, 1)
	r.setup(d)
	r.position = pos
	r.scale = Vector2(s, absi(s))
	r.pose_name = pose

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var x0 := 208.0
	var w := 210.0
	if Game.last_winner == 0:
		HKTheme.draw_text(self, Vector2(x0, 40), "DRAW", 24, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, w, 4)
		HKTheme.draw_text(self, Vector2(x0, 56), "¡EMPATE HISTÓRICO!", 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
	else:
		var pulse := HKTheme.GOLD.lerp(Color("fff0a0"), 0.5 + 0.5 * sin(_t * 4.0))
		var title := "PLAYER %d WINS" % Game.last_winner
		if _arcade != &"":
			title = "YOU WIN" if Game.last_winner == 1 else "CPU WINS"
		HKTheme.draw_text(self, Vector2(x0, 36), title, 16, pulse, HORIZONTAL_ALIGNMENT_CENTER, w, 4)
		HKTheme.draw_text(self, Vector2(x0, 54), _winner_data.display_name, 8, HKTheme.PAPER, HORIZONTAL_ALIGNMENT_CENTER, w)
		_draw_wrapped(Vector2(x0 + 8, 92), "\"%s\"" % _winner_data.victory_quote, w - 16, Color("e8d8b8"))
	HKTheme.draw_text(self, Vector2(x0, 74), "RONDAS  %d - %d" % [Game.last_p1_rounds, Game.last_p2_rounds], 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, w)
	if _arcade != &"":
		HKTheme.draw_text(self, Vector2(x0, 18), _arcade_status(), 8, HKTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)

func _arcade_status() -> String:
	var fight := "COMBATE %d/%d" % [Game.arcade_stage + 1, Game.arcade_ladder.size()]
	match _arcade:
		&"complete":
			return "¡ARCADE COMPLETADO!"
		&"over":
			return "FIN DEL JUEGO · %s" % fight
	return "%s · %s" % [fight, Game.difficulty_name()]

func _draw_wrapped(pos: Vector2, text: String, width: float, color: Color) -> void:
	var line := ""
	var y := pos.y
	for word in text.split(" "):
		var test: String = word if line.is_empty() else line + " " + word
		if HKTheme.text_width(test, 8) > width and not line.is_empty():
			HKTheme.draw_text(self, Vector2(pos.x, y), line, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
			y += 11
			line = word
		else:
			line = test
	if not line.is_empty():
		HKTheme.draw_text(self, Vector2(pos.x, y), line, 8, color, HORIZONTAL_ALIGNMENT_LEFT, -1, 1)
