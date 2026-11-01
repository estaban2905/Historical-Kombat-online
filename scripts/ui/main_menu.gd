## Menú principal: ARCADE, VERSUS LOCAL, ENTRENAMIENTO, DIFICULTAD, PERSONAJES, OPCIONES, CRÉDITOS.
## ARCADE (1 jugador contra la CPU) y VERSUS LOCAL (2 jugadores) llevan a la
## selección de luchador. DIFICULTAD cambia el nivel de la CPU.
## El resto abre pantallas informativas mientras no estén implementadas.
extends Control

@onready var buttons: VBoxContainer = $Buttons
@onready var btn_play: Button = $Buttons/Play
@onready var btn_versus: Button = $Buttons/Versus
@onready var btn_training: Button = $Buttons/Training
@onready var btn_difficulty: Button = $Buttons/Difficulty
@onready var btn_roster: Button = $Buttons/Roster
@onready var btn_controls: Button = $Buttons/Controls
@onready var btn_options: Button = $Buttons/Options
@onready var btn_credits: Button = $Buttons/Credits
@onready var info: PanelContainer = $Info
@onready var info_title: Label = $Info/Box/Title
@onready var info_body: Label = $Info/Box/Body
@onready var info_back: Button = $Info/Box/Back
@onready var footer: Label = $Footer

const ROSTER_PER_PAGE := 3

var _last_focus: Button
var _roster_mode: bool = false
var _roster_page: int = 0

func _ready() -> void:
	theme = HKTheme.theme()
	get_tree().paused = false
	footer.text = "v%s" % Game.VERSION
	btn_play.pressed.connect(func(): _go_select(Game.Mode.ARCADE))
	btn_versus.pressed.connect(func(): _go_select(Game.Mode.VERSUS))
	btn_training.pressed.connect(func(): _go_select(Game.Mode.TRAINING))
	btn_difficulty.pressed.connect(_cycle_difficulty)
	btn_roster.pressed.connect(_show_roster)
	btn_controls.pressed.connect(func(): Game.goto(Game.SCENE_CONTROLS))
	btn_options.pressed.connect(_show_options)
	btn_credits.pressed.connect(_show_credits)
	info_back.pressed.connect(_close_info)
	_refresh_difficulty()
	for b in [btn_play, btn_versus, btn_training, btn_difficulty, btn_roster, btn_controls, btn_options, btn_credits, info_back]:
		b.focus_entered.connect(func(): Sfx.play(&"select"))
		b.pressed.connect(func(): Sfx.play(&"confirm"))
	info.visible = false
	_spawn_previews()
	_build_account_button()
	btn_play.grab_focus()

## Botón pequeño en la esquina: ENTRAR (sin sesión) o "NOMBRE · SALIR" (con sesión).
## Solo existe si hay un servidor configurado.
func _build_account_button() -> void:
	if not Backend.is_configured():
		return
	var b := Button.new()
	b.position = Vector2(212, 4)
	b.custom_minimum_size = Vector2(210, 14)
	b.size = Vector2(210, 14)
	b.clip_text = true
	if Backend.is_logged_in():
		b.text = "%s · %d PTS · SALIR" % [Backend.username().to_upper().left(10), int(Backend.profile.get("points", 0))]
	else:
		b.text = "INICIAR SESIÓN"
	b.pressed.connect(_on_account_pressed)
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	add_child(b)

func _on_account_pressed() -> void:
	Sfx.play(&"confirm")
	if Backend.is_logged_in():
		await Backend.sign_out()
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

func _open_info(title: String, body: String) -> void:
	_last_focus = get_viewport().gui_get_focus_owner() as Button
	info_title.text = title
	info_body.text = body
	info.visible = true
	buttons.visible = false
	info_back.grab_focus()

func _close_info() -> void:
	_roster_mode = false
	info.visible = false
	buttons.visible = true
	if _last_focus:
		_last_focus.grab_focus()
	else:
		btn_play.grab_focus()

## Se usa _input (y no _unhandled_input) para que la navegación de foco del
## botón VOLVER no se coma las flechas al pasar de página.
func _input(event: InputEvent) -> void:
	if not (info.visible and _roster_mode):
		return
	if event.is_action_pressed(&"ui_left"):
		_change_roster_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_right"):
		_change_roster_page(1)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if info.visible and event.is_action_pressed(&"ui_cancel"):
		_close_info()
		get_viewport().set_input_as_handled()

func _show_roster() -> void:
	_roster_mode = true
	_roster_page = 0
	_open_info("PERSONAJES", _roster_text())

## Una página de la lista de luchadores (ROSTER_PER_PAGE por página).
func _roster_text() -> String:
	var all := FighterRegistry.all()
	var pages := ceili(all.size() / float(ROSTER_PER_PAGE))
	var lines := PackedStringArray()
	for i in range(_roster_page * ROSTER_PER_PAGE, mini((_roster_page + 1) * ROSTER_PER_PAGE, all.size())):
		var d := all[i]
		lines.append("%d. %s (%s)" % [i + 1, d.display_name, d.era])
		lines.append("   %s · VIDA %d · FZA %.2f" % [d.country.to_upper(), d.max_health, d.strength])
		lines.append("   ESP 1: %s" % d.special_1.display_name.to_upper())
		lines.append("   ESP 2: %s" % d.special_2.display_name.to_upper())
	lines.append("")
	lines.append("PÁG %d/%d · ← → CAMBIAR · %d LUCHADORES" % [_roster_page + 1, pages, all.size()])
	return "\n".join(lines)

func _change_roster_page(step: int) -> void:
	var pages := ceili(FighterRegistry.all().size() / float(ROSTER_PER_PAGE))
	_roster_page = (_roster_page + step + pages) % pages
	info_body.text = _roster_text()
	Sfx.play(&"select")

func _show_options() -> void:
	_open_info("OPCIONES", "NO DISPONIBLE EN LA VERSIÓN 0.1.\n\n" +
		"CONTROLES ACTUALES\n" +
		"J1: A/D MOVER · W SALTO · S AGACHAR\n" +
		"    ESPACIO BLOQUEO\n" +
		"    U/I PUÑOS · J/K PATADAS · O/L ESPECIALES\n" +
		"J2: FLECHAS · NUM0 BLOQUEO\n" +
		"    NUM1/2 PUÑOS · NUM4/5 PATADAS\n" +
		"    NUM3/6 ESPECIALES\n" +
		"    (SIN NUMPAD: SUPR FIN AVPÁG / INS INICIO REPÁG\n" +
		"     Y ENTER PARA BLOQUEAR)\n" +
		"ESC / P: PAUSA")

func _show_credits() -> void:
	_open_info("CRÉDITOS", "HISTORY COMBAT\nEL TORNEO DE LOS SIGLOS\n\n" +
		"PROTOTIPO %s HECHO CON GODOT 4\n\n" % Game.VERSION +
		"GRÁFICOS Y SONIDOS: ORIGINALES,\nGENERADOS POR CÓDIGO (PROVISIONALES)\n\n" +
		"FUENTE: PRESS START 2P\n(CODEMAN38, SIL OPEN FONT LICENSE)\n\n" +
		"PARODIA DE FICCIÓN. NINGÚN\nPERSONAJE REAL PARTICIPÓ EN EL TORNEO.")
