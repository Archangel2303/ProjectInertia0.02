extends Node

# Fire cadence control in seconds between shots.
@export var cooldown_seconds: float = 0.22
# Projectile speed scalar. Increase for snappier ballistic feel.
@export var bullet_speed: float = 28.0

var _bullet_scene: PackedScene
var _elapsed_since_shot: float = 999.0

func setup(bullet_scene: PackedScene) -> void:
	_bullet_scene = bullet_scene

func tick(delta: float) -> void:
	_elapsed_since_shot += delta

func try_fire(spawn_point: Node3D, parent_node: Node, direction_override: Vector3 = Vector3.ZERO) -> bool:
	if _bullet_scene == null:
		return false
	if _elapsed_since_shot < cooldown_seconds:
		return false
	if spawn_point == null:
		return false

	# Capture transform/direction from the gun's child spawn marker so projectile
	# origin is always at the spawn point regardless of gun orientation.
	var spawn_transform: Transform3D = spawn_point.global_transform
	var spawn_direction: Vector3 = (-spawn_transform.basis.z).normalized()
	if direction_override.length_squared() > 0.0001:
		spawn_direction = direction_override.normalized()

	var bullet: Node = _bullet_scene.instantiate()
	parent_node.add_child(bullet)
	if bullet is Node3D:
		var bullet_node: Node3D = bullet as Node3D
		bullet_node.global_transform = spawn_transform
	if bullet.has_method("setup"):
		bullet.setup(spawn_direction, bullet_speed)
	_elapsed_since_shot = 0.0
	return true
