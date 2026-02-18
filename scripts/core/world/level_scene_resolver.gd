extends RefCounted
class_name LevelSceneResolver

const LEVEL_SCENE_DIR := "res://scenes/levels"
const LEVEL_DEBUG_SCENE := "res://scenes/levels/level_debug_01.tscn"

static func scene_path_for_level(level_index: int) -> String:
	if level_index <= 0:
		return LEVEL_DEBUG_SCENE
	return "%s/level_%02d.tscn" % [LEVEL_SCENE_DIR, level_index + 1]

static func resolve_for_mode(is_endless: bool, level_index: int) -> String:
	if is_endless:
		return LEVEL_DEBUG_SCENE
	var level_scene := scene_path_for_level(level_index)
	if ResourceLoader.exists(level_scene, "PackedScene"):
		return level_scene
	return LEVEL_DEBUG_SCENE