extends Node

@export var spin_speed_degrees: float = 120.0
@export var recoil_spin_damping: float = 6.0
@export var persist_external_spin: bool = true
@export var overwrite_external_spin_on_force: bool = true
@export var disable_passive_when_backspin: bool = true
@export var backspin_block_threshold: float = 0.01
var direction: float = 1.0
var _recoil_spin_speed: float = 0.0
var _passive_yaw_radians: float = 0.0

func process_spin(target: Node3D, delta: float, suppress_base_spin: bool = false) -> void:
	var has_backspin := _recoil_spin_speed < -absf(backspin_block_threshold)
	var passive_blocked := suppress_base_spin or (disable_passive_when_backspin and has_backspin)
	var base_spin := 0.0 if passive_blocked else spin_speed_degrees * direction
	var total_spin := base_spin + _recoil_spin_speed
	target.rotate_y(deg_to_rad(total_spin * delta))
	_passive_yaw_radians = wrapf(_passive_yaw_radians + deg_to_rad(base_spin * delta), -PI, PI)
	if not persist_external_spin:
		_recoil_spin_speed = lerp(_recoil_spin_speed, 0.0, 1.0 - exp(-recoil_spin_damping * delta))

func flip_direction() -> void:
	direction *= -1.0

func add_recoil_spin(kick_degrees: float) -> void:
	var next_spin := kick_degrees * direction
	if overwrite_external_spin_on_force:
		_recoil_spin_speed = next_spin
	else:
		_recoil_spin_speed += next_spin

func has_external_spin() -> bool:
	return absf(_recoil_spin_speed) > 0.25

func get_passive_yaw_radians() -> float:
	return _passive_yaw_radians
