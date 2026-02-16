extends Node

const GUN_COLORS: Array[Color] = [
	Color("#f2f2f2"),
	Color("#58c7ff"),
	Color("#ff7f50"),
]

const BULLET_COLORS: Array[Color] = [
	Color("#ffd166"),
	Color("#8ce99a"),
	Color("#ffadad"),
]

const TRAIL_COLORS: Array[Color] = [
	Color("#fff3bf"),
	Color("#c5f6fa"),
	Color("#ffc9c9"),
]

func gun_color(index: int) -> Color:
	return GUN_COLORS[index % GUN_COLORS.size()]

func bullet_color(index: int) -> Color:
	return BULLET_COLORS[index % BULLET_COLORS.size()]

func trail_color(index: int) -> Color:
	return TRAIL_COLORS[index % TRAIL_COLORS.size()]
