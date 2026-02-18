extends RefCounted
class_name BulletHitUtil

static func classify_hit_location(body: Node, global_hit_position: Vector3, bullet_direction: Vector3) -> int:
	if not (body is Node3D):
		return 1
	var body_3d := body as Node3D
	var local_hit := body_3d.to_local(global_hit_position)
	var enemy_forward := (-body_3d.global_transform.basis.z).normalized()
	if enemy_forward.dot(bullet_direction.normalized()) > 0.55:
		return 3
	if local_hit.y < 0.35:
		return 0
	if local_hit.y < 0.75:
		return 2
	return 1

static func find_enemy_for_hit_node(node: Node) -> Node:
	var cursor: Node = node
	while cursor != null:
		if cursor.has_method("apply_hit"):
			return cursor
		cursor = cursor.get_parent()
	return null
