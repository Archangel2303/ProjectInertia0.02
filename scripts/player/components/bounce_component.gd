extends Node

@export var amplitude: float = 0.08
@export var frequency: float = 4.2

var _base_y: float = 0.8
var _time: float = 0.0

func setup(base_y: float) -> void:
	_base_y = base_y

func process_bounce(_target: Node3D, delta: float) -> void:
	_time += delta

func current_offset_y() -> float:
	return sin(_time * frequency) * amplitude
