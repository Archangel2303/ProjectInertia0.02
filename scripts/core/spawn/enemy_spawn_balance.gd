extends RefCounted
class_name EnemySpawnBalance

static func build_level_wave(level_index: int) -> Array[int]:
	var wave: Array[int] = []
	var base_count := 12 + level_index * 4
	for i in range(base_count):
		if i % 7 == 0:
			wave.append(3)
		elif i % 5 == 0:
			wave.append(1)
		elif i % 3 == 0:
			wave.append(2)
		else:
			wave.append(0)
	return wave

static func endless_difficulty(endless_elapsed_total: float, endless_player_kills: int) -> float:
	var time_factor := endless_elapsed_total / 30.0
	var kill_factor := float(endless_player_kills) * 0.07
	return minf(10.0, 1.0 + time_factor + kill_factor)

static func endless_max_alive(difficulty: float) -> int:
	return int(clampi(4 + int(round(difficulty * 1.3)), 4, 18))

static func endless_burst_count(difficulty: float) -> int:
	return int(clampi(1 + int(floor(difficulty / 2.0)), 1, 4))

static func endless_spawn_cadence(difficulty: float) -> float:
	return clampf(1.8 - difficulty * 0.12, 0.45, 1.8)

static func pick_enemy_type_for_difficulty(rng: RandomNumberGenerator, difficulty: float) -> int:
	var roll := rng.randf()
	if difficulty < 2.5:
		if roll < 0.70:
			return 0
		if roll < 0.90:
			return 2
		return 1
	if difficulty < 5.0:
		if roll < 0.45:
			return 0
		if roll < 0.70:
			return 2
		if roll < 0.88:
			return 1
		return 3
	if difficulty < 7.5:
		if roll < 0.25:
			return 0
		if roll < 0.50:
			return 2
		if roll < 0.75:
			return 1
		return 3
	if roll < 0.15:
		return 0
	if roll < 0.40:
		return 2
	if roll < 0.65:
		return 1
	return 3
