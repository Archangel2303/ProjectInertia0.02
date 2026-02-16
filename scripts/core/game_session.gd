extends Node

enum Mode {
	LEVEL,
	ENDLESS,
}

var mode: Mode = Mode.LEVEL
var level_index: int = 0
var extra_bullet_ad_used: bool = false
var selected_skin_index: int = 0

const SKIN_COUNT := 3

func start_level(index: int = 0) -> void:
	mode = Mode.LEVEL
	level_index = max(index, 0)
	extra_bullet_ad_used = false

func start_endless() -> void:
	mode = Mode.ENDLESS
	level_index = 0
	extra_bullet_ad_used = false

func can_use_extra_bullet_ad() -> bool:
	return not extra_bullet_ad_used

func mark_extra_bullet_ad_used() -> void:
	extra_bullet_ad_used = true

func cycle_skin() -> void:
	selected_skin_index = (selected_skin_index + 1) % SKIN_COUNT
