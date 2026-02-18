extends RefCounted
class_name GunMotionMath

static func recoil_trajectory_velocity(
	current_velocity: Vector3,
	recoil_dir: Vector3,
	old_lateral_carry: float,
	vertical_carry: float,
	recoil_backward_impulse: float,
	recoil_upward_impulse: float,
	recoil_max_speed: float
) -> Vector3:
	var horizontal_velocity := Vector3(current_velocity.x, 0.0, current_velocity.z)
	var forward_component := recoil_dir * horizontal_velocity.dot(recoil_dir)
	var lateral_component := horizontal_velocity - forward_component
	horizontal_velocity = forward_component + lateral_component * old_lateral_carry
	horizontal_velocity += recoil_dir * recoil_backward_impulse
	var next_velocity := Vector3(
		horizontal_velocity.x,
		current_velocity.y * vertical_carry + recoil_upward_impulse,
		horizontal_velocity.z
	)
	if next_velocity.length() > recoil_max_speed:
		next_velocity = next_velocity.normalized() * recoil_max_speed
	return next_velocity

static func angular_kick_from_normal(normal: Vector3, impulse_speed: float, collision_angular_kick: float) -> Vector2:
	var kick_scale := impulse_speed * collision_angular_kick
	return Vector2(normal.z * kick_scale, -normal.x * kick_scale)

static func collision_yaw_delta(
	normal: Vector3,
	incoming_velocity: Vector3,
	impulse_speed: float,
	collision_yaw_torque: float
) -> float:
	var horizontal_incoming := Vector3(incoming_velocity.x, 0.0, incoming_velocity.z)
	if horizontal_incoming.length_squared() < 0.0001:
		return 0.0
	var tangent := horizontal_incoming.normalized().cross(normal)
	return tangent.y * impulse_speed * collision_yaw_torque

static func clamped_laser_length(origin: Vector3, hit_position: Variant, max_distance: float) -> float:
	if hit_position is Vector3:
		return maxf(0.06, origin.distance_to(hit_position as Vector3))
	return max_distance
