extends Camera3D

enum CameraState {
	DRIFT,
	LAUNCH,
	IMPACT_STABILIZE,
}

@export_group("Node Links")
@export var target_path: NodePath
# Spawn point path should reference the gun child marker used for bullet spawn.
@export var spawn_point_path: NodePath
@export var target_rigidbody_path: NodePath

@export_group("Base Camera")
@export var third_person_offset: Vector3 = Vector3(0.0, 2.1, 6.0)
@export var look_height: float = 0.8
@export var base_follow_smoothing: float = 8.0
@export var base_distance_min: float = 4.2
@export var base_distance_max: float = 10.5

@export_group("State Thresholds")
@export var drift_threshold: float = 1.8
@export var launch_threshold: float = 4.0
@export var threshold_hysteresis: float = 0.55
@export var launch_enter_hold: float = 0.08
@export var drift_enter_hold: float = 0.12

@export_group("Drift State")
@export var drift_vel_weight: float = 0.4
@export var drift_aim_weight: float = 0.6
@export var drift_distance: float = 5.4
@export var drift_yaw_cap_deg: float = 55.0
@export var drift_look_ahead: float = 0.75
@export var drift_damping: float = 10.5

@export_group("Launch State")
@export var launch_vel_weight: float = 0.7
@export var launch_aim_weight: float = 0.3
@export var launch_base_distance: float = 5.8
@export var launch_zoom_mult: float = 0.35
@export var launch_distance_min: float = 5.4
@export var launch_distance_max: float = 9.8
@export var launch_yaw_cap_deg: float = 34.0
@export var launch_look_ahead: float = 2.6
@export var launch_damping: float = 13.0

@export_group("Impact Stabilize")
@export var impact_threshold: float = 5.0
@export var impact_duration: float = 0.15
@export var impact_yaw_cap_multiplier: float = 0.58
@export var impact_damping_multiplier: float = 1.35

@export_group("Slow Time Modifier")
@export var slow_yaw_cap_multiplier: float = 7.0
@export var slow_distance_offset: float = -0.45
@export var slow_aim_weight_bias: float = 0.45
@export var slow_damping_multiplier: float = 3.1

@export_group("Fired Modifier")
@export var fired_bias_duration: float = 0.2
@export var fired_aim_weight_bias: float = 0.07
@export var fired_damping_multiplier: float = 0.93
@export var fired_orbit_duration: float = 0.45
@export var fired_yaw_cap_multiplier: float = 8.0
@export var fired_orbit_damping_multiplier: float = 4.6
@export var fired_look_ahead: float = 1.2

@export_group("Collision")
@export var collision_mask: int = 1
@export var collision_radius: float = 0.25
@export var collision_buffer: float = 0.2
@export var collision_smoothing: float = 18.0
@export var collision_recovery_smoothing: float = 8.0

@export_group("Debug")
@export var debug_state_name: bool = false

var _target: Node3D
var _spawn_point: Node3D
var _target_body: RigidBody3D
var _slow_time_active: bool = false
var _camera_state: CameraState = CameraState.DRIFT

var _last_target_position: Vector3 = Vector3.ZERO
var _derived_velocity: Vector3 = Vector3.ZERO
var _state_above_launch_timer: float = 0.0
var _state_below_drift_timer: float = 0.0
var _impact_timer: float = 0.0
var _fired_timer: float = 0.0
var _shot_orbit_timer: float = 0.0
var _shot_yaw: float = 0.0

var _current_yaw: float = 0.0
var _current_distance: float = 6.0
var _current_look_ahead: float = 1.0
var _current_damping: float = 8.0

var _ray_query := PhysicsRayQueryParameters3D.new()
var _ray_exclude: Array[RID] = []

func _resolve_velocity(delta: float) -> Vector3:
	if _target_body != null:
		return _target_body.linear_velocity
	if delta <= 0.0:
		return _derived_velocity
	var target_pos := _target.global_position
	_derived_velocity = (target_pos - _last_target_position) / delta
	_last_target_position = target_pos
	return _derived_velocity

func _set_state(next_state: CameraState) -> void:
	if _camera_state == next_state:
		return
	_camera_state = next_state

func _state_name() -> String:
	match _camera_state:
		CameraState.DRIFT:
			return "DRIFT"
		CameraState.LAUNCH:
			return "LAUNCH"
		_:
			return "IMPACT"

func _ready() -> void:
	if target_path != NodePath():
		_target = get_node_or_null(target_path) as Node3D
	if spawn_point_path != NodePath():
		_spawn_point = get_node_or_null(spawn_point_path) as Node3D
	if target_rigidbody_path != NodePath():
		_target_body = get_node_or_null(target_rigidbody_path) as RigidBody3D
	elif _target is RigidBody3D:
		_target_body = _target as RigidBody3D
	if _target != null:
		_last_target_position = _target.global_position
	var initial_forward := -global_transform.basis.z
	initial_forward.y = 0.0
	if initial_forward.length_squared() < 0.0001:
		initial_forward = Vector3.FORWARD
	_current_yaw = atan2(initial_forward.x, initial_forward.z)
	_current_distance = clamp(abs(third_person_offset.z), base_distance_min, base_distance_max)
	_current_look_ahead = drift_look_ahead
	_current_damping = base_follow_smoothing
	_ray_query.collide_with_areas = false
	_ray_query.collide_with_bodies = true
	_ray_query.collision_mask = collision_mask
	if _target_body != null:
		_ray_exclude.append(_target_body.get_rid())
	elif _target is CollisionObject3D:
		_ray_exclude.append((_target as CollisionObject3D).get_rid())
	_ray_query.exclude = _ray_exclude
	current = true

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var velocity := _resolve_velocity(delta)
	var speed := velocity.length()
	var speed_xz := Vector2(velocity.x, velocity.z).length()

	if _fired_timer > 0.0:
		_fired_timer = max(0.0, _fired_timer - delta)
	if _shot_orbit_timer > 0.0:
		_shot_orbit_timer = max(0.0, _shot_orbit_timer - delta)
	if _impact_timer > 0.0:
		_impact_timer = max(0.0, _impact_timer - delta)

	if _impact_timer > 0.0:
		_set_state(CameraState.IMPACT_STABILIZE)
	else:
		var above_launch := speed > launch_threshold + threshold_hysteresis
		var below_drift := speed < drift_threshold - threshold_hysteresis
		_state_above_launch_timer = _state_above_launch_timer + delta if above_launch else 0.0
		_state_below_drift_timer = _state_below_drift_timer + delta if below_drift else 0.0
		if _camera_state == CameraState.LAUNCH:
			if _state_below_drift_timer >= drift_enter_hold:
				_set_state(CameraState.DRIFT)
		else:
			if _state_above_launch_timer >= launch_enter_hold:
				_set_state(CameraState.LAUNCH)
			elif speed < drift_threshold:
				_set_state(CameraState.DRIFT)

	var vel_weight := drift_vel_weight
	var aim_weight := drift_aim_weight
	var target_distance := drift_distance
	var yaw_cap_deg := drift_yaw_cap_deg
	var look_ahead := drift_look_ahead
	var damping := drift_damping

	if _camera_state == CameraState.LAUNCH:
		vel_weight = launch_vel_weight
		aim_weight = launch_aim_weight
		target_distance = clamp(launch_base_distance + speed * launch_zoom_mult, launch_distance_min, launch_distance_max)
		yaw_cap_deg = launch_yaw_cap_deg
		look_ahead = launch_look_ahead
		damping = launch_damping
	elif _camera_state == CameraState.IMPACT_STABILIZE:
		vel_weight = drift_vel_weight
		aim_weight = drift_aim_weight
		target_distance = drift_distance
		yaw_cap_deg = drift_yaw_cap_deg * impact_yaw_cap_multiplier
		look_ahead = drift_look_ahead
		damping = drift_damping * impact_damping_multiplier

	var is_event_orbiting := _slow_time_active or _shot_orbit_timer > 0.0
	if not is_event_orbiting:
		vel_weight = 0.0
		aim_weight = 1.0
		target_distance = drift_distance
		yaw_cap_deg = drift_yaw_cap_deg
		look_ahead = 0.0
		damping = drift_damping

	if _slow_time_active:
		yaw_cap_deg *= slow_yaw_cap_multiplier
		target_distance += slow_distance_offset
		vel_weight = max(0.0, vel_weight - slow_aim_weight_bias)
		aim_weight += slow_aim_weight_bias
		damping *= slow_damping_multiplier

	if _fired_timer > 0.0:
		aim_weight += fired_aim_weight_bias
		damping *= fired_damping_multiplier

	if _shot_orbit_timer > 0.0:
		yaw_cap_deg *= fired_yaw_cap_multiplier
		damping *= fired_orbit_damping_multiplier
		look_ahead = max(look_ahead, fired_look_ahead)

	target_distance = clamp(target_distance, base_distance_min, base_distance_max)
	var weight_sum: float = max(0.001, vel_weight + aim_weight)
	vel_weight /= weight_sum
	aim_weight /= weight_sum

	var aim_dir := Vector3.FORWARD
	if _spawn_point != null:
		aim_dir = -_spawn_point.global_transform.basis.z
	else:
		aim_dir = -_target.global_transform.basis.z
	aim_dir.y = 0.0
	if aim_dir.length_squared() < 0.0001:
		aim_dir = Vector3.FORWARD
	else:
		aim_dir = aim_dir.normalized()

	var vel_dir := Vector3.ZERO
	if speed_xz > 0.01:
		vel_dir = Vector3(velocity.x, 0.0, velocity.z).normalized()

	var blend_dir := aim_dir
	if speed_xz > 0.08 and is_event_orbiting:
		blend_dir = vel_dir * vel_weight + aim_dir * aim_weight
		if blend_dir.length_squared() < 0.0001:
			blend_dir = aim_dir
		else:
			blend_dir = blend_dir.normalized()

	var desired_yaw := _current_yaw
	var has_orbit_target := false
	if _shot_orbit_timer > 0.0:
		desired_yaw = _shot_yaw
		has_orbit_target = true
	elif _slow_time_active:
		desired_yaw = atan2(aim_dir.x, aim_dir.z)
		has_orbit_target = true
	else:
		desired_yaw = _current_yaw
	var time_scale_comp: float = 1.0 / max(Engine.time_scale, 0.15)
	var yaw_cap_rad: float = deg_to_rad(max(1.0, yaw_cap_deg)) * delta * time_scale_comp
	var yaw_delta := wrapf(desired_yaw - _current_yaw, -PI, PI)
	yaw_delta = clamp(yaw_delta, -yaw_cap_rad, yaw_cap_rad)
	var capped_target_yaw := _current_yaw + yaw_delta
	var yaw_lerp := 1.0 - exp(-damping * delta)
	if _shot_orbit_timer > 0.0:
		var shot_lerp := 1.0 - exp(-(damping * 1.8) * delta)
		_current_yaw = lerp_angle(_current_yaw, desired_yaw, shot_lerp)
	else:
		_current_yaw = lerp_angle(_current_yaw, capped_target_yaw, yaw_lerp)

	_current_distance = lerp(_current_distance, target_distance, yaw_lerp)
	_current_look_ahead = lerp(_current_look_ahead, look_ahead, yaw_lerp)
	_current_damping = lerp(_current_damping, damping, yaw_lerp)

	var forward_flat := Vector3(sin(_current_yaw), 0.0, cos(_current_yaw)).normalized()
	var effective_look_ahead := _current_look_ahead if has_orbit_target else 0.0
	var target_anchor := _target.global_position + Vector3(0.0, look_height, 0.0) + forward_flat * effective_look_ahead
	var desired_position := target_anchor - forward_flat * _current_distance + Vector3(third_person_offset.x, max(0.0, third_person_offset.y - look_height), 0.0)

	_ray_query.from = target_anchor
	_ray_query.to = desired_position
	_ray_query.collision_mask = collision_mask
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ray_query)
	if not hit.is_empty():
		var hit_pos := hit["position"] as Vector3
		var hit_dist := target_anchor.distance_to(hit_pos)
		var safe_dist: float = max(0.0, hit_dist - (collision_buffer + collision_radius))
		desired_position = target_anchor - forward_flat * safe_dist

	var distance_to_desired := global_position.distance_to(desired_position)
	var smoothing := collision_smoothing if not hit.is_empty() else collision_recovery_smoothing
	var position_lerp: float = clamp((1.0 - exp(-smoothing * delta)) * min(1.0, distance_to_desired + 0.15), 0.0, 1.0)
	global_position = global_position.lerp(desired_position, position_lerp)

	look_at(target_anchor, Vector3.UP)
	rotation.z = 0.0

func set_slow_time(active: bool) -> void:
	_slow_time_active = active

func set_slow_time_active(active: bool) -> void:
	set_slow_time(active)

func on_fired() -> void:
	_fired_timer = fired_bias_duration
	_shot_orbit_timer = fired_orbit_duration
	if _spawn_point != null:
		var shot_dir := -_spawn_point.global_transform.basis.z
		shot_dir.y = 0.0
		if shot_dir.length_squared() > 0.0001:
			shot_dir = shot_dir.normalized()
			_shot_yaw = atan2(shot_dir.x, shot_dir.z)

func on_impact(impulse: float) -> void:
	if impulse < impact_threshold:
		return
	_impact_timer = impact_duration
