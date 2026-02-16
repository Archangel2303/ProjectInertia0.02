extends Node

@export var spin_speed_degrees: float = 120.0
@export var recoil_spin_damping: float = 6.0
var direction: float = 1.0
var _recoil_spin_speed: float = 0.0

func process_spin(target: Node3D, delta: float) -> void:
	var total_spin := spin_speed_degrees * direction + _recoil_spin_speed
	target.rotate_y(deg_to_rad(total_spin * delta))
	_recoil_spin_speed = lerp(_recoil_spin_speed, 0.0, 1.0 - exp(-recoil_spin_damping * delta))

func flip_direction() -> void:
	direction *= -1.0

func add_recoil_spin(kick_degrees: float) -> void:
	_recoil_spin_speed += kick_degrees * direction
