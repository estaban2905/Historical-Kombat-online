## Retrato de un luchador (cabeza y hombros) dentro de un marco. Sin luchador muestra "?".
class_name AvatarFrame
extends Control

var _clip: Control
var _bust: FighterRenderer
var _has_fighter: bool = false
## Id mostrado (null hasta la primera llamada a set_fighter).
var _fighter_id: Variant = null
## Escala del luchador: menos de 1 en los retratos pequeños (filas del ranking) para que quepa la cabeza.
var _zoom: float = 1.0
## Color del borde: el marco que lleva puesto el jugador (Cosmetics) o el de siempre.
var _border: Color = HKTheme.GOLD_DARK

func _init(p_size: Vector2 = Vector2(36, 36), zoom: float = 1.0) -> void:
	_zoom = zoom
	custom_minimum_size = p_size
	size = p_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip = Control.new()
	_clip.clip_contents = true
	_clip.position = Vector2(1, 1)
	_clip.size = p_size - Vector2(2, 2)
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)

## Muestra al luchador con ese id; "" o un id que no existe dejan el marco vacío. Si es el mismo, no hace nada.
func set_fighter(fighter_id: String) -> void:
	if _fighter_id != null and fighter_id == _fighter_id:
		return
	_fighter_id = fighter_id
	if _bust != null:
		_bust.queue_free()
		_bust = null
	_has_fighter = fighter_id != "" and FighterRegistry.has(StringName(fighter_id))
	if _has_fighter:
		_bust = FighterRenderer.new()
		_bust.draw_shadow = false
		# Retrato fijo: se dibuja una vez en setup(); sin _process no se redibuja cada frame.
		_bust.set_process(false)
		_bust.setup(FighterRegistry.get_by_id(StringName(fighter_id)))
		# Pies fuera del marco: solo se ve cabeza y hombros. En los pequeños se encuadra la cara (el sombrero
		# se corta), si no un sombrero alto taparía todo el retrato.
		var top := _bust.approx_height() if _zoom >= 1.0 else _bust.crown_height() + 1.0
		_bust.scale = Vector2(_zoom, _zoom)
		_bust.position = Vector2(_clip.size.x * 0.5 - 2 * _zoom, top * _zoom + 1)
		_clip.add_child(_bust)
	queue_redraw()

## Pone el marco `key` (de Cosmetics.FRAMES); "" o desconocido deja el borde normal.
func set_frame(key: String) -> void:
	_border = Cosmetics.frame_color(key)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _border)
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color("2a1a30"))
	if not _has_fighter:
		HKTheme.draw_text(self, Vector2(0, size.y * 0.5 + 4), "?", 8, HKTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, size.x, 1)
