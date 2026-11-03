## Botón VOLVER común a todas las pantallas: siempre en la misma esquina (abajo a la izquierda), del mismo
## tamaño y con los mismos sonidos. El clic derecho lo pulsa igual que ESC. Los demás botones de la pantalla
## se colocan a su derecha (ver RIGHT_EDGE).
class_name BackButton
extends Button

const POS := Vector2(14, 222)
const SIZE := Vector2(70, 14)
## Desde aquí hacia la derecha queda libre para el resto de botones de abajo.
const RIGHT_EDGE := POS.x + SIZE.x + 6.0

## Crea el botón dentro de `screen` y ejecuta `on_press` al pulsarlo.
static func add_to(screen: Control, on_press: Callable) -> BackButton:
	var b := BackButton.new()
	b.text = "VOLVER"
	b.custom_minimum_size = SIZE
	screen.add_child(b)
	b.position = POS
	b.size = SIZE   # tras añadirlo: ya tiene el tema (ver profile.gd)
	b.focus_entered.connect(func(): Sfx.play(&"select"))
	b.pressed.connect(func(): Sfx.play(&"confirm"))
	b.pressed.connect(on_press)
	return b

## _input y no _unhandled_input: el Control raíz de cada pantalla se queda los clics antes de que lleguen allí.
func _input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_RIGHT:
		return
	if is_visible_in_tree() and not disabled and not Game.is_changing_scene():
		get_viewport().set_input_as_handled()
		pressed.emit()
