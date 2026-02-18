extends RefCounted
class_name SlowTimeMath

static func target_effect(move_speed_norm: float, rot_speed_norm: float) -> float:
	var spin_intensity: float = pow(clampf(rot_speed_norm, 0.0, 1.0), 1.55)
	return clampf(move_speed_norm * 0.2 + spin_intensity * 0.8, 0.0, 1.0)

static func smoothed_effect(current_effect: float, target_effect_value: float, smoothing: float, delta: float) -> float:
	return lerp(current_effect, target_effect_value, 1.0 - exp(-smoothing * delta))

static func time_scale(base_scale: float, best_scale: float, effect: float) -> float:
	return lerp(base_scale, best_scale, clampf(effect, 0.0, 1.0))
