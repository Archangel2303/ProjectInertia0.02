extends RefCounted
class_name ScoreSystem

enum HitLocation {
	LIMBS,
	TORSO,
	MIDSECTION,
	BACK,
	HEAD,
}

# Runtime accumulators. These are reset per run by `start_run()`.
var clear_time_seconds: float = 0.0
var slow_time_usage_seconds: float = 0.0
var kill_score_total: int = 0
var rotation_combo_bonus_total: int = 0
var last_kill_rotation_unwrapped: float = INF

# Hit-region point tuning.
# Raise/lower these values to rebalance precision rewards.
var limb_points: int = 25
var torso_points: int = 60
var midsection_points: int = 60
var back_points: int = 70
var head_points: int = 120

# Global score-curve tuning.
# - clear_time_* controls fast-clear reward curve.
# - slow_time_penalty_per_second controls the slow-time tax.
# - ammo_bonus_value controls per-bullet end bonus.
var ammo_bonus_value: int = 15
var clear_time_max_reward: int = 1500
var clear_time_penalty_per_second: float = 20.0
var slow_time_penalty_per_second: float = 12.0

# Rotation combo tuning.
# A kill receives combo bonus if it occurs before rotating this many degrees
# since the previous kill. Multiplier applies to the current kill's base score.
var combo_window_degrees: float = 360.0
var combo_multiplier: float = 1.25

func start_run() -> void:
	clear_time_seconds = 0.0
	slow_time_usage_seconds = 0.0
	kill_score_total = 0
	rotation_combo_bonus_total = 0
	last_kill_rotation_unwrapped = INF

func tick(delta: float, slow_time_active: bool) -> void:
	# Call once per frame to keep time-based mechanics independent from kill events.
	clear_time_seconds += delta
	if slow_time_active:
		slow_time_usage_seconds += delta

func kill_score(hit_location: int) -> int:
	# Keep this as the single source of truth for region-based kill values.
	match hit_location:
		HitLocation.LIMBS:
			return limb_points
		HitLocation.TORSO:
			return torso_points
		HitLocation.MIDSECTION:
			return midsection_points
		HitLocation.BACK:
			return back_points
		HitLocation.HEAD:
			return head_points
		_:
			return torso_points

func record_kill(hit_location: int, rotation_at_kill: float) -> void:
	# Records kill score and applies rotation combo logic in one place.
	# `rotation_at_kill` must be an unwrapped cumulative rotation value.
	var base_score := kill_score(hit_location)
	kill_score_total += base_score

	if not is_inf(last_kill_rotation_unwrapped):
		var rotation_delta := absf(rotation_at_kill - last_kill_rotation_unwrapped)
		if rotation_delta < combo_window_degrees:
			var combo_bonus := int(round(float(base_score) * (combo_multiplier - 1.0)))
			rotation_combo_bonus_total += maxi(combo_bonus, 0)

	last_kill_rotation_unwrapped = rotation_at_kill

func compute_level_score(remaining_ammo: int) -> Dictionary:
	# Final level score composition:
	# clear-time reward - slow-time penalty + kill score + combo bonus + ammo bonus.
	var clear_time_score := maxi(
		0,
		int(round(float(clear_time_max_reward) - clear_time_seconds * clear_time_penalty_per_second))
	)
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

func compute_endless_score(enemies_killed: int, survival_time_seconds: float) -> int:
	# Endless score scales with both kill throughput and survival duration.
	# Tune constants here without changing level scoring logic.
	var kill_points_total := enemies_killed * 100
	var survival_score := int(round(survival_time_seconds * 8.0))
	var scale_bonus := int(round(float(enemies_killed) * survival_time_seconds * 0.15))
	return kill_points_total + survival_score + scale_bonus

func all_enemies_dead(enemies: Array[Node]) -> bool:
	# Returns true only when no valid enemy instance remains in the provided list.
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion():
			continue
		return false
	return true
