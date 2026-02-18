extends RefCounted
class_name ScoreSystem

# ScoreSystem is a stateful facade for scoring runtime data.
# Pure scoring formulas are delegated to ScoreCalculator so they can be reused/tested.
const ScoreCalculatorScript = preload("res://scripts/core/score/score_calculator.gd")

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
	return ScoreCalculatorScript.kill_score(hit_location, limb_points, torso_points, midsection_points, back_points, head_points, torso_points)

func record_kill(hit_location: int, rotation_at_kill: float) -> void:
	# Records kill score and applies rotation combo logic in one place.
	# `rotation_at_kill` must be an unwrapped cumulative rotation value.
	var base_score := kill_score(hit_location)
	kill_score_total += base_score
	rotation_combo_bonus_total += ScoreCalculatorScript.combo_bonus(
		base_score,
		rotation_at_kill,
		last_kill_rotation_unwrapped,
		combo_window_degrees,
		combo_multiplier
	)

	last_kill_rotation_unwrapped = rotation_at_kill

func compute_level_score(remaining_ammo: int) -> Dictionary:
	return ScoreCalculatorScript.level_breakdown(
		clear_time_seconds,
		slow_time_usage_seconds,
		kill_score_total,
		rotation_combo_bonus_total,
		remaining_ammo,
		clear_time_max_reward,
		clear_time_penalty_per_second,
		slow_time_penalty_per_second,
		ammo_bonus_value
	)

func compute_endless_score(enemies_killed: int, survival_time_seconds: float) -> int:
	return ScoreCalculatorScript.endless_score(enemies_killed, survival_time_seconds)

func all_enemies_dead(enemies: Array[Node]) -> bool:
	return ScoreCalculatorScript.all_enemies_dead(enemies)
