## Traduce las acciones del Input Map (p1_* / p2_*) a una interfaz común
## para cada jugador. El luchador nunca lee teclas directamente: pregunta
## a su InputManager. Así el mismo código sirve para P1, P2, una futura IA
## o las pruebas automáticas (que usan las entradas "virtuales").
class_name InputManager
extends RefCounted

## Nombres de acción sin prefijo. Con prefijo quedan p1_left, p2_block, etc.
const MOVE_ACTIONS: Array[StringName] = [&"left", &"right", &"jump", &"crouch", &"block"]
const ATTACK_ACTIONS: Array[StringName] = [
	&"punch_light", &"punch_heavy", &"special_1",
	&"kick_light", &"kick_heavy", &"special_2",
]

var player_id: int = 1
var prefix: String = "p1_"
## Si es false, se ignora el teclado (solo cuentan las entradas virtuales).
var use_keyboard: bool = true

## Entradas virtuales (IA / tests). held: se mantienen; pressed: duran 1 frame.
var virtual_held: Dictionary = {}
var virtual_pressed: Dictionary = {}

func _init(p_player_id: int = 1) -> void:
	player_id = p_player_id
	prefix = "p%d_" % player_id

func action_name(action: StringName) -> StringName:
	return StringName(prefix + String(action))

func is_held(action: StringName) -> bool:
	if virtual_held.get(action, false):
		return true
	return use_keyboard and Input.is_action_pressed(action_name(action))

## Pulsación de un solo frame (ataques, salto).
func just_pressed(action: StringName) -> bool:
	if virtual_pressed.get(action, false):
		return true
	return use_keyboard and Input.is_action_just_pressed(action_name(action))

## -1 izquierda, 0 nada, 1 derecha.
func horizontal() -> int:
	return int(is_held(&"right")) - int(is_held(&"left"))

## Devuelve la primera ranura de ataque pulsada este frame (o &"").
func pressed_attack() -> StringName:
	for a in ATTACK_ACTIONS:
		if just_pressed(a):
			return a
	return &""

## Llamar al final de cada frame lógico.
func end_frame() -> void:
	virtual_pressed.clear()

# --- Entrada empaquetada (red, repeticiones, pruebas) --------------------
## Orden fijo de bits de un frame de entrada. NO reordenar: forma parte del
## protocolo de red y de las repeticiones guardadas.
const FRAME_ACTIONS: Array[StringName] = [
	&"left", &"right", &"jump", &"crouch", &"block",
	&"punch_light", &"punch_heavy", &"special_1",
	&"kick_light", &"kick_heavy", &"special_2",
]

## Máscara de la última entrada aplicada con apply_mask (para detectar pulsaciones nuevas).
var _applied_mask: int = 0

## Lee el teclado/entradas virtuales de este frame y lo empaqueta en un entero.
## Un ataque cuenta como pulsado si se mantiene o si se pulsó en este frame.
func sample_mask() -> int:
	var mask := 0
	for i in FRAME_ACTIONS.size():
		var a := FRAME_ACTIONS[i]
		if is_held(a) or (a in ATTACK_ACTIONS and just_pressed(a)):
			mask |= 1 << i
	return mask

## Sustituye las entradas por las de la máscara. Una pulsación de ataque
## "nueva" es un bit que antes no estaba activo, igual que just_pressed.
func apply_mask(mask: int) -> void:
	virtual_held.clear()
	virtual_pressed.clear()
	for i in FRAME_ACTIONS.size():
		if (mask >> i) & 1 == 0:
			continue
		var a := FRAME_ACTIONS[i]
		virtual_held[a] = true
		if a in ATTACK_ACTIONS and (_applied_mask >> i) & 1 == 0:
			virtual_pressed[a] = true
	_applied_mask = mask

# --- API para IA / pruebas ---------------------------------------------
func press(action: StringName) -> void:
	virtual_pressed[action] = true

func hold(action: StringName, value: bool = true) -> void:
	if value:
		virtual_held[action] = true
	else:
		virtual_held.erase(action)

func release_all() -> void:
	virtual_held.clear()
	virtual_pressed.clear()
