extends RefCounted
class_name CameraOrbitMath

static func normalize_weights(vel_weight: float, aim_weight: float) -> Vector2:
	var weight_sum: float = maxf(0.001, vel_weight + aim_weight)
	return Vector2(vel_weight / weight_sum, aim_weight / weight_sum)

static func blended_direction(
	aim_dir: Vector3,
	velocity: Vector3,
	speed_xz: float,
	vel_weight: float,
	aim_weight: float,
	is_event_orbiting: bool
) -> Vector3:
	if speed_xz <= 0.08 or not is_event_orbiting:
		return aim_dir
	var vel_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
	var blend_dir := vel_dir * vel_weight + aim_dir * aim_weight
	if blend_dir.length_squared() < 0.0001:
		return aim_dir
	return blend_dir.normalized()

static func desired_yaw(
	current_yaw: float,
	aim_dir: Vector3,
	shot_orbit_timer: float,
	slow_time_active: bool,
	shot_yaw: float
) -> float:
	if slow_time_active:
		return atan2(aim_dir.x, aim_dir.z)
	if shot_orbit_timer > 0.0:
		return shot_yaw
	return current_yaw

static func has_orbit_target(shot_orbit_timer: float, slow_time_active: bool) -> bool:
	return shot_orbit_timer > 0.0 or slow_time_active

static func step_yaw(
	current_yaw: float,
	desired_yaw_value: float,
	yaw_cap_deg: float,
	damping: float,
	delta: float,
	time_scale: float,
	shot_orbit_timer: float
) -> float:
	var time_scale_comp: float = 1.0 / maxf(time_scale, 0.15)
	var yaw_cap_rad: float = deg_to_rad(maxf(1.0, yaw_cap_deg)) * delta * time_scale_comp
	var yaw_delta := wrapf(desired_yaw_value - current_yaw, -PI, PI)
	yaw_delta = clampf(yaw_delta, -yaw_cap_rad, yaw_cap_rad)
	var capped_target_yaw := current_yaw + yaw_delta
	var yaw_lerp := 1.0 - exp(-damping * delta)
	if shot_orbit_timer > 0.0:
		var shot_lerp := 1.0 - exp(-(damping * 1.8) * delta)
		return lerp_angle(current_yaw, desired_yaw_value, shot_lerp)
	return lerp_angle(current_yaw, capped_target_yaw, yaw_lerp)
