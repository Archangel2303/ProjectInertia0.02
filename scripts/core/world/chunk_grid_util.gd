extends RefCounted
class_name ChunkGridUtil

static func world_to_chunk(world_pos: Vector3, chunk_size: float) -> Vector2i:
	var cx := int(floor(world_pos.x / chunk_size))
	var cz := int(floor(world_pos.z / chunk_size))
	return Vector2i(cx, cz)

static func should_cleanup_chunk(chunk_key: Vector2i, center_chunk: Vector2i, cleanup_radius_chunks: int) -> bool:
	var dx: int = absi(chunk_key.x - center_chunk.x)
	var dz: int = absi(chunk_key.y - center_chunk.y)
	return dx > cleanup_radius_chunks or dz > cleanup_radius_chunks

static func checker_value(key: Vector2i, light_value: float = 0.82, dark_value: float = 0.76) -> float:
	return light_value if ((key.x + key.y) % 2 == 0) else dark_value
