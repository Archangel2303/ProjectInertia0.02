extends Node

signal ammo_changed(current: int, max_ammo: int)

@export var max_ammo: int = 6
var current_ammo: int = 6

func setup(starting_ammo: int = 6) -> void:
	current_ammo = clamp(starting_ammo, 0, max_ammo)
	ammo_changed.emit(current_ammo, max_ammo)

func spend_one() -> bool:
	if current_ammo <= 0:
		return false
	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo)
	return true

func add_one() -> void:
	current_ammo = min(current_ammo + 1, max_ammo)
	ammo_changed.emit(current_ammo, max_ammo)

func is_empty() -> bool:
	return current_ammo <= 0
