extends RefCounted
class_name EnemyHitboxUtil

const HIT_LIMBS := 0
const HIT_TORSO := 1
const HIT_MIDSECTION := 2
const HIT_BACK := 3
const HIT_HEAD := 4

static func is_shield_area_name(area_name: String) -> bool:
	return area_name.contains("shield")

static func is_armor_area_name(area_name: String) -> bool:
	return area_name.contains("armor")

static func hit_location_from_area_name(area_name: String) -> int:
	if area_name.contains("shield"):
		return HIT_HEAD
	if area_name.contains("armor"):
		return HIT_TORSO
	if area_name.contains("head"):
		return HIT_HEAD
	if area_name.contains("back"):
		return HIT_BACK
	if area_name.contains("mid") or area_name.contains("pelvis") or area_name.contains("hip") or area_name.contains("waist"):
		return HIT_MIDSECTION
	if area_name.contains("torso") or area_name.contains("chest") or area_name.contains("spine"):
		return HIT_TORSO
	if area_name.contains("arm") or area_name.contains("hand") or area_name.contains("leg") or area_name.contains("foot"):
		return HIT_LIMBS
	return HIT_TORSO

static func collect_meshes(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
			if child is MeshInstance3D:
				meshes.append(child as MeshInstance3D)
	return meshes

static func collect_areas(root: Node) -> Array[Area3D]:
	var areas: Array[Area3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
			if child is Area3D:
				areas.append(child as Area3D)
	return areas
