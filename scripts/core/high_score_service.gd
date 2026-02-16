extends Node
class_name HighScoreService

const SAVE_PATH := "user://scores.cfg"
const LEVEL_SECTION := "level_scores"

static func _key(mode_name: String, level_index: int) -> String:
	return "%s_%d" % [mode_name, level_index]

static func load_high_score(mode_name: String, level_index: int) -> int:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		return 0
	return int(config.get_value("scores", _key(mode_name, level_index), 0))

static func save_high_score(mode_name: String, level_index: int, score: int) -> bool:
	var current_best := load_high_score(mode_name, level_index)
	if score <= current_best:
		return false
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("scores", _key(mode_name, level_index), score)
	config.save(SAVE_PATH)
	return true

static func update_high_score(level_id: String, score: int) -> bool:
	var current_best := load_high_score_by_level_id(level_id)
	if score <= current_best:
		return false
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value(LEVEL_SECTION, level_id, score)
	config.save(SAVE_PATH)
	return true

static func load_high_score_by_level_id(level_id: String) -> int:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		return 0
	return int(config.get_value(LEVEL_SECTION, level_id, 0))
