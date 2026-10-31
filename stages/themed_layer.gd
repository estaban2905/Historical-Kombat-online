## Una capa de un escenario temático: ejecuta la lista de operaciones de
## dibujo de stage_ops.gd. Las capas estáticas se dibujan una sola vez; las
## animadas se redibujan a 12 fps (suficiente para pixel art y barato en web).
class_name ThemedLayer
extends StageOps

var ops: Array = []
var animated: bool = false
var _stage: Stage
var _accum: float = 0.0

func setup(p_ops: Array, p_animated: bool) -> void:
	ops = p_ops
	animated = p_animated
	set_process(animated)
	queue_redraw()

func _ready() -> void:
	_stage = get_parent() as Stage
	set_process(animated)

func _process(delta: float) -> void:
	_t += delta
	_accum += delta
	if _accum >= 1.0 / 12.0:
		_accum = 0.0
		_ex = _stage.excitement if _stage else 0.0
		queue_redraw()

func _draw() -> void:
	for op in ops:
		var m := "op_" + String(op[0])
		if has_method(m):
			callv(m, op.slice(1))
		else:
			push_warning("StageOps: operación desconocida " + String(op[0]))
