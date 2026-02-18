extends Node3D
class_name EndlessChunkManager

const ChunkGridUtilScript = preload("res://scripts/core/world/chunk_grid_util.gd")

# Player path used to determine which chunk to generate around.
@export var player_path: NodePath

# Chunk tuning.
# - chunk_size controls tile width/length.
# - active_radius_chunks controls how many chunks stay generated around player.
# - cleanup_radius_chunks controls when far chunks are removed.
@export var chunk_size: float = 24.0
@export var active_radius_chunks: int = 2
@export var cleanup_radius_chunks: int = 4

# Floor tuning for each generated chunk.
@export var floor_height: float = -0.2
@export var floor_thickness: float = 0.3

var _player: Node3D
var _active: bool = false
var _center_chunk: Vector2i = Vector2i(999999, 999999)
var _chunks: Dictionary[Vector2i, Node3D] = {}

func _ready() -> void:
	_resolve_player()

func _process(_delta: float) -> void:
	if not _active:
		return
	if _player == null:
		_resolve_player()
		if _player == null:
			return

	var player_chunk := ChunkGridUtilScript.world_to_chunk(_player.global_position, chunk_size)
	if player_chunk != _center_chunk:
		_center_chunk = player_chunk
		_generate_visible_chunk_window()
		_cleanup_far_chunks()

func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	visible = active

	if _active:
		_resolve_player()
		if _player == null:
			return
		_center_chunk = ChunkGridUtilScript.world_to_chunk(_player.global_position, chunk_size)
		_generate_visible_chunk_window()
		_cleanup_far_chunks()
		return

	_clear_all_chunks()

func _resolve_player() -> void:
	if player_path == NodePath():
		return
	_player = get_node_or_null(player_path) as Node3D

func _generate_visible_chunk_window() -> void:
	for x in range(_center_chunk.x - active_radius_chunks, _center_chunk.x + active_radius_chunks + 1):
		for z in range(_center_chunk.y - active_radius_chunks, _center_chunk.y + active_radius_chunks + 1):
			var key := Vector2i(x, z)
			if _chunks.has(key):
				continue
			_chunks[key] = _create_chunk(key)

func _create_chunk(key: Vector2i) -> Node3D:
	var chunk_root := Node3D.new()
	chunk_root.name = "Chunk_%d_%d" % [key.x, key.y]
	chunk_root.position = Vector3(key.x * chunk_size, 0.0, key.y * chunk_size)
	add_child(chunk_root)

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	chunk_root.add_child(floor_body)

	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(chunk_size, floor_thickness, chunk_size)
	collision.shape = floor_shape
	collision.position = Vector3(0.0, floor_height, 0.0)
	floor_body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(chunk_size, floor_thickness, chunk_size)
	mesh_instance.mesh = floor_mesh
	mesh_instance.position = Vector3(0.0, floor_height, 0.0)

	var material := StandardMaterial3D.new()
	var checker := ChunkGridUtilScript.checker_value(key)
	material.albedo_color = Color(checker, checker, checker)
	mesh_instance.set_surface_override_material(0, material)
	floor_body.add_child(mesh_instance)

	return chunk_root

func _cleanup_far_chunks() -> void:
	var keys_to_remove: Array[Vector2i] = []
	for chunk_key in _chunks.keys():
		if ChunkGridUtilScript.should_cleanup_chunk(chunk_key, _center_chunk, cleanup_radius_chunks):
			keys_to_remove.append(chunk_key)

	for key in keys_to_remove:
		var chunk: Node3D = _chunks.get(key)
		if chunk != null and is_instance_valid(chunk):
			chunk.queue_free()
		_chunks.erase(key)

func _clear_all_chunks() -> void:
	for key in _chunks.keys():
		var chunk: Node3D = _chunks.get(key)
		if chunk != null and is_instance_valid(chunk):
			chunk.queue_free()
	_chunks.clear()