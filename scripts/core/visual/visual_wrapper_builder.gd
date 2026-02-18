extends RefCounted
class_name VisualWrapperBuilder

# Shared utility for swapping primitive mesh visuals with optional model wrappers.
# We centralize this so gameplay scripts stay focused on behavior orchestration.
static func apply_wrapper(
	mesh: MeshInstance3D,
	visual_anchor: Node3D,
	use_wrapper: bool,
	wrapper_scene: PackedScene
) -> Node3D:
	mesh.visible = true
	if not use_wrapper:
		return null
	if wrapper_scene == null:
		return null
	var wrapper: Node = wrapper_scene.instantiate()
	if wrapper == null:
		return null
	if wrapper is Node3D:
		var wrapper_3d := wrapper as Node3D
		visual_anchor.add_child(wrapper_3d)
		mesh.visible = false
		return wrapper_3d
	return null
