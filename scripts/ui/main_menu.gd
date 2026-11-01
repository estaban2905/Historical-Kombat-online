## Menú principal: MODO HISTORIA, VERSUS LOCAL, DUELO ONLINE, ENTRENAMIENTO, DIFICULTAD, PERSONAJES, CONTROLES, CRÉDITOS.
## MODO HISTORIA (1 jugador contra la CPU, de hoy al origen), VERSUS LOCAL (2 jugadores) y DUELO ONLINE
## (contra otra persona por internet) llevan a la selección de luchador. DIFICULTAD cambia el nivel de la CPU.
## VERSUS LOCAL y ENTRENAMIENTO solo aparecen en el editor (desarrollo), no en builds exportadas.
## PERSONAJES, CONTROLES y CRÉDITOS abren su propia pantalla.
extends Control

@onready var btn_play: Button = $Buttons/Play
@onready var btn_versus: Button = $Buttons/Versus
@onready var btn_online: Button = $Buttons/Online
@onready var btn_training: Button = $Buttons/Training
@onready var btn_difficulty: Button = $Buttons/Difficulty
@onready var btn_roster: Button = $Buttons/Roster
@onready var btn_controls: Button = $Buttons/Controls
@onready var btn_credits: Button = $Buttons/Credits
@onready var footer: Label = $Footer

func _ready() -> void:
	theme = HKTheme.theme()
	get_tree().paused = false
	footer.text = "v%s" % Game.VERSION
	btn_play.pressed.connect(func(): _go_select(Game.Mode.ARCADE))
	btn_versus.pressed.connect(func(): _go_select(Game.Mode.VERSUS))
	btn_online.pressed.connect(func(): _go_select(Game.Mode.ONLINE))
	btn_training.pressed.connect(func(): _go_select(Game.Mode.TRAINING))
	btn_difficulty.pressed.connect(_cycle_difficulty)
	btn_roster.pressed.connect(_show_roster)
	btn_controls.pressed.connect(func(): Game.goto(Game.SCENE_CONTROLS))
	btn_credits.pressed.connect(_show_credits)
	_refresh_difficulty()
	# VERSUS LOCAL y ENTRENAMIENTO son herramientas de desarrollo: solo se ven al correr desde el editor.
	var dev := OS.has_feature("editor")
	btn_versus.visible = dev
	btn_training.visible = dev
	for b in [btn_play, btn_versus, btn_online, btn_training, btn_difficulty, btn_roster, btn_controls, btn_credits]:
		b.focus_entered.connect(func(): Sfx.play(&"select"))
		b.pressed.connect(func(): Sfx.play(&"confirm"))
	_spawn_previews()
	_build_account_button()
	btn_play.grab_focus()

## Botones cortos en las esquinas de arriba (el título ocupa el centro): RANKING a la izquierda
## y PERFIL / ENTRAR a la derecha. Con sesión, abajo a la derecha se lee "NOMBRE · PUNTOS".
## Solo existen si el servidor responde y tiene cuentas.
func _build_account_button() -> void:
	if not Backend.is_configured():
		return
	_corner_button("RANKING", Vector2(4, 4), func(): Game.goto(Game.SCENE_RANKING))
	_corner_button("PERFIL" if Backend.is_logged_in() else "ENTRAR", Vector2(338, 4), _on_account_pressed)
	if Backend.is_logged_in():
		var who := Label.new()
		who.text = "%s · %d PTS" % [Backend.username().to_upper().left(14), int(Backend.profile.get("points", 0))]
		who.position = Vector2(196, 228)
		who.size = Vector2(226, 10)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		who.add_theme_color_override("font_color", HKTheme.GOLD)
		add_child(who)

func _corner_button(text: String, pos: Vector2, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.custom_minimum_size = Vector2(84, 14)
	b.pressed.connect(func():
		Sfx.play(&"confirm")
		on_press.call())
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	add_child(b)
	b.size = Vector2(84, 14)   # tras añadirlo: ya tiene el tema

func _on_account_pressed() -> void:
	if Backend.is_logged_in():
		Game.goto(Game.SCENE_PROFILE)
		return
	Backend.guest = false
	Game.goto(Game.SCENE_LOGIN)

func _spawn_previews() -> void:
	var roster := FighterRegistry.all()
	if roster.size() < 2:
		return
	var left := FighterRenderer.new()
	add_child(left)
	left.setup(FighterRegistry.get_by_id(&"donald_trump"))
	left.position = Vector2(62, 226)
	var right := FighterRenderer.new()
	add_child(right)
	right.setup(FighterRegistry.get_by_id(&"napoleon"))
	right.position = Vector2(364, 226)
	right.scale.x = -1
	# Que queden detrás de los paneles
	move_child(left, 1)
	move_child(right, 1)

func _go_select(mode: Game.Mode) -> void:
	Game.mode = mode
	Game.goto(Game.SCENE_SELECT)

func _cycle_difficulty() -> void:
	Game.cycle_difficulty()
	_refresh_difficulty()

func _refresh_difficulty() -> void:
	btn_difficulty.text = "DIFICULTAD: %s" % Game.difficulty_name()

func _show_roster() -> void:
	Game.goto(Game.SCENE_ROSTER)

func _show_credits() -> void:
	Game.goto(Game.SCENE_CREDITS)
