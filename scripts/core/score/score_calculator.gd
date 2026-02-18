extends RefCounted
class_name ScoreCalculator

static func kill_score(hit_location: int, limb_points: int, torso_points: int, midsection_points: int, back_points: int, head_points: int, default_points: int) -> int:
	match hit_location:
		0:
			return limb_points
		1:
			return torso_points
		2:
			return midsection_points
		3:
			return back_points
		4:
			return head_points
		_:
			return default_points

static func combo_bonus(base_score: int, current_rotation: float, last_rotation: float, combo_window_degrees: float, combo_multiplier: float) -> int:
	if is_inf(last_rotation):
		return 0
	var rotation_delta := absf(current_rotation - last_rotation)
	if rotation_delta >= combo_window_degrees:
		return 0
	var computed_bonus := int(round(float(base_score) * (combo_multiplier - 1.0)))
	return maxi(computed_bonus, 0)

static func level_breakdown(
	clear_time_seconds: float,
	slow_time_usage_seconds: float,
	kill_score_total: int,
	rotation_combo_bonus_total: int,
	remaining_ammo: int,
	clear_time_max_reward: int,
	clear_time_penalty_per_second: float,
	slow_time_penalty_per_second: float,
	ammo_bonus_value: int
) -> Dictionary:
	var clear_time_score := maxi(0, int(round(float(clear_time_max_reward) - clear_time_seconds * clear_time_penalty_per_second)))
	var slow_time_penalty := maxi(0, int(round(slow_time_usage_seconds * slow_time_penalty_per_second)))
	var remaining_ammo_bonus := maxi(0, remaining_ammo) * ammo_bonus_value
	var total := clear_time_score - slow_time_penalty + kill_score_total + rotation_combo_bonus_total + remaining_ammo_bonus
	return {
		"clear_time_score": clear_time_score,
		"slow_time_penalty": slow_time_penalty,
		"kill_score_total": kill_score_total,
		"rotation_combo_bonus": rotation_combo_bonus_total,
		"remaining_ammo_bonus": remaining_ammo_bonus,
		"total_score": total,
	}

static func endless_score(enemies_killed: int, survival_time_seconds: float) -> int:
	var kill_points_total := enemies_killed * 100
	var survival_score := int(round(survival_time_seconds * 8.0))
	var scale_bonus := int(round(float(enemies_killed) * survival_time_seconds * 0.15))
	return kill_points_total + survival_score + scale_bonus

static func all_enemies_dead(enemies: Array[Node]) -> bool:
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion():
			continue
		return false
	return true
