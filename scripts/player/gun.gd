extends CharacterBody3D
class_name Gun

# Gun is a gameplay orchestrator. Heavy math/selection logic is delegated to
# core helper modules so this class can stay focused on sequencing/state.

enum RecoilPreset {
	ARCADE,
	INSANE,
	CUSTOM,
}

signal shot_fired
signal ammo_changed(current: int, max_ammo: int)
signal impacted(impulse: float)
signal hard_impact(magnitude: float)

const BULLET_SCENE: PackedScene = preload("res://scenes/player/bullet.tscn")
const DEFAULT_MODEL_WRAPPER_SCENE: PackedScene = preload("res://scenes/visual/gun_model_wrapper.tscn")
const GunMotionMathScript = preload("res://scripts/core/math/gun_motion_math.gd")
const VisualWrapperBuilderScript = preload("res://scripts/core/visual/visual_wrapper_builder.gd")

@export_group("Recoil Presets")
@export var recoil_preset: RecoilPreset = RecoilPreset.ARCADE
@export var apply_preset_on_ready: bool = true

@export_group("Recoil Movement")
@export var recoil_backward_impulse: float = 11.2
@export var recoil_force: float = 11.2
@export var recoil_upward_impulse: float = 10.6
@export var recoil_gravity: float = 10.2
@export_range(0.0, 1.0, 0.01) var recoil_gravity_scale: float = 0.20
@export var recoil_drag: float = 1.5
@export var recoil_max_speed: float = 15.5
@export var recoil_spin_kick_degrees: float = 90.0
@export var backspin_torque: float = 180.0

@export_group("Trajectory Control")
@export_range(0.0, 1.0, 0.01) var old_lateral_carry: float = 0.22
@export_range(0.0, 1.0, 0.01) var vertical_carry: float = 0.82

@export_group("Collision Bounce")
@export var bounce_restitution: float = 0.62
@export var collision_velocity_damping: float = 0.6
@export var collision_angular_kick: float = 0.028

@export_group("External Rotation")
@export var recoil_backflip_kick_degrees: float = 780.0
@export var recoil_roll_kick_degrees: float = 80.0
@export var recoil_yaw_torque_degrees: float = 420.0
@export var angular_restore_spring: float = 4.8
@export var angular_damping: float = 3.2
@export var spin_angular_drag: float = 0.0
@export var collision_yaw_torque: float = 0.085
@export var angular_speed_max: float = 26.0
@export var max_angular_velocity_clamp: float = 26.0
@export var external_rotation_influence_time: float = 0.22
@export_range(0.0, 1.0, 0.01) var external_restore_scale: float = 0.34
@export_range(0.0, 1.0, 0.01) var external_damping_scale: float = 0.28
@export var passive_roll_upright_spring: float = 13.5
@export var passive_roll_damping: float = 11.0

@export_group("Physics Polish")
# Airborne sideways drift cleanup without reducing recoil pop.
@export_range(0.0, 1.0, 0.01) var air_drift_damping: float = 0.12
@export var max_air_speed: float = 42.0
# Landing settle trims micro-jitter while preserving bounce.
@export var landing_vel_epsilon: float = 0.18
@export var landing_angular_drag_boost: float = 6.0
@export var landing_settle_duration: float = 0.1
# Hard-impact hook threshold and optional logging.
@export var hard_impact_threshold: float = 6.5
@export var log_impact_magnitudes: bool = false

@export_group("Velocity Leash")
# Desired travel axis tracking from recoil impulses (not from rotation).
@export_range(0.0, 1.0, 0.01) var desired_dir_blend: float = 0.25
@export var min_speed_for_leash: float = 0.5
@export var leash_strength_air: float = 2.4
@export var leash_strength_ground: float = 0.35
@export var leash_delay_after_shot: float = 0.05
@export var leash_max_perp_speed: float = 999.0
@export var ricochet_leash_boost: float = 1.8
@export var ricochet_boost_duration: float = 0.1
@export var ricochet_min_impact_speed: float = 4.0
@export var debug_log_perp: bool = false

@export_group("Ground Check")
# Rotating-body ground detection independent of visual orientation.
@export var ground_check_enabled: bool = true
@export var draw_ground_check_gizmos: bool = false
@export var ground_check_offset: Vector3 = Vector3(0.0, 0.2, 0.0)
@export var ground_check_radius: float = 0.28
@export var ground_check_distance: float = 0.35
@export var ground_check_min_normal_y: float = 0.45

@export_group("Smoothing")
@export var linear_rest_threshold: float = 0.35
@export var bounce_min_speed: float = 0.9

@export_group("Ground")
@export var floor_y: float = 0.8
@export var ground_upright_spring: float = 12.0
@export var ground_upright_damping: float = 8.5
@export var ground_upright_snap_speed: float = 0.65
@export var ground_upright_settle_damping: float = 5.0

@export_group("Flight Model")
@export_range(0.01, 0.5, 0.01) var linear_cruise_threshold_ratio: float = 0.10
@export_range(0.0, 0.1, 0.005) var linear_cruise_hysteresis_ratio: float = 0.015
@export var linear_cruise_drag: float = 0.22
@export var ground_upright_min_assist: float = 0.15
@export var airborne_wobble_damping: float = 6.0
@export var airborne_wobble_restore: float = 5.2

@export_group("Visual")
@export var use_model_wrapper: bool = false
@export var model_wrapper_scene: PackedScene = DEFAULT_MODEL_WRAPPER_SCENE

@export_group("Laser Pointer")
@export var laser_enabled: bool = true
@export var laser_max_distance: float = 140.0
@export var laser_width: float = 0.016
@export var laser_collision_mask: int = 3
@export var laser_color: Color = Color(1.0, 0.12, 0.12, 0.88)

@onready var _spin_component: Node = $SpinComponent
@onready var _ammo_component: Node = $AmmoComponent
@onready var _fire_component: Node = $FireComponent
@onready var _bounce_component: Node = $BounceComponent
@onready var _bullet_spawn_point: Marker3D = $BulletSpawnPoint
@onready var _body_mesh: MeshInstance3D = $Body
@onready var _visual_anchor: Node3D = $VisualAnchor

var _model_wrapper_instance: Node3D
var _laser_beam: MeshInstance3D
var _laser_material: StandardMaterial3D
var _laser_query := PhysicsRayQueryParameters3D.new()
var _ground_shape_query := PhysicsShapeQueryParameters3D.new()
var _ground_check_shape := SphereShape3D.new()

var _motion_velocity: Vector3 = Vector3.ZERO
var _base_y: float = 0.8
var _angular_velocity: Vector3 = Vector3.ZERO
var _spawn_position: Vector3 = Vector3.ZERO
var _physics_armed: bool = false
var _external_rotation_timer: float = 0.0
var _last_yaw_radians: float = 0.0
var _unwrapped_yaw_degrees: float = 0.0
var _linear_cruise_active: bool = false
var _project_gravity: float = 9.8
var _desired_travel_dir: Vector3 = Vector3.FORWARD
var _leash_delay_timer: float = 0.0
var _ricochet_leash_timer: float = 0.0
var _landing_settle_timer: float = 0.0
var _was_grounded: bool = false

func _ready() -> void:
	if apply_preset_on_ready:
		apply_recoil_preset(recoil_preset)
	_fire_component.setup(BULLET_SCENE)
	_ammo_component.setup(_ammo_component.max_ammo)
	_ammo_component.ammo_changed.connect(_on_ammo_changed)
	if _bullet_spawn_point == null:
		push_error("Gun is missing required child spawn point node: BulletSpawnPoint")
	_base_y = position.y
	_spawn_position = position
	floor_y = _base_y
	_project_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_last_yaw_radians = rotation.y
	_unwrapped_yaw_degrees = 0.0
	_physics_armed = false
	_external_rotation_timer = 0.0
	_linear_cruise_active = false
	_desired_travel_dir = -get_spawn_point_forward()
	_sync_tunable_aliases()
	_setup_ground_check_query()
	_setup_visual_wrapper()
	_setup_laser_pointer()
	_apply_skin()

func apply_recoil_preset(preset: RecoilPreset) -> void:
	recoil_preset = preset
	match preset:
		RecoilPreset.ARCADE:
			recoil_backward_impulse = 10.0
			recoil_force = recoil_backward_impulse
			recoil_upward_impulse = 9.7
			recoil_gravity = 7.2
			recoil_drag = 0.32
			recoil_max_speed = 14.6
			recoil_spin_kick_degrees = 260.0
			backspin_torque = maxf(backspin_torque, recoil_spin_kick_degrees)
			old_lateral_carry = 0.16
			vertical_carry = 0.76
			bounce_restitution = 0.94
			collision_velocity_damping = 0.99
			collision_angular_kick = 0.2
			recoil_backflip_kick_degrees = 1650.0
			recoil_roll_kick_degrees = 260.0
			recoil_yaw_torque_degrees = 1320.0
			angular_restore_spring = 2.8
			angular_damping = 1.85
			collision_yaw_torque = 0.38
			angular_speed_max = 58.0
			max_angular_velocity_clamp = angular_speed_max
			external_rotation_influence_time = 1.12
			external_restore_scale = 0.28
			external_damping_scale = 0.24
		RecoilPreset.INSANE:
			recoil_backward_impulse = 14.6
			recoil_force = recoil_backward_impulse
			recoil_upward_impulse = 14.2
			recoil_gravity = 8.8
			recoil_drag = 0.45
			recoil_max_speed = 21.5
			recoil_spin_kick_degrees = 130.0
			backspin_torque = maxf(backspin_torque, recoil_spin_kick_degrees)
			bounce_restitution = 0.96
			collision_velocity_damping = 0.98
			collision_angular_kick = 0.045
			recoil_backflip_kick_degrees = 1120.0
			recoil_roll_kick_degrees = 155.0
			angular_restore_spring = 3.7
			angular_damping = 2.6
			max_angular_velocity_clamp = angular_speed_max
		RecoilPreset.CUSTOM:
			pass

func _process(delta: float) -> void:
	_fire_component.tick(delta)
	_bounce_component.process_bounce(self, delta)
	_update_laser_pointer()

func _physics_process(delta: float) -> void:
	_step_spin_and_yaw(delta)
	if _reset_motion_if_unarmed():
		return
	_tick_motion_timers(delta)
	var grounded_before_move := _is_grounded_custom()
	var linear_threshold_speed := _update_linear_cruise_state()
	var pre_slide_velocity := _apply_linear_motion_step(delta)
	_resolve_linear_collisions(pre_slide_velocity)
	_clamp_motion_to_floor()
	var grounded_after_move := _is_grounded_custom()
	_apply_post_move_linear_controls(delta, grounded_before_move, grounded_after_move)
	_apply_angular_stability_controls(delta, grounded_after_move, linear_threshold_speed)
	_apply_angular_rotation_step(delta)
	_was_grounded = grounded_after_move

func _step_spin_and_yaw(delta: float) -> void:
	_spin_component.process_spin(self, delta, false)
	_update_unwrapped_rotation()

func _reset_motion_if_unarmed() -> bool:
	if _physics_armed:
		return false
	position = _spawn_position
	_motion_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	return true

func _tick_motion_timers(delta: float) -> void:
	_external_rotation_timer = maxf(0.0, _external_rotation_timer - delta)
	_leash_delay_timer = maxf(0.0, _leash_delay_timer - delta)
	_ricochet_leash_timer = maxf(0.0, _ricochet_leash_timer - delta)
	_landing_settle_timer = maxf(0.0, _landing_settle_timer - delta)

func _update_linear_cruise_state() -> float:
	var linear_threshold_speed: float = maxf(0.01, recoil_max_speed * linear_cruise_threshold_ratio)
	var exit_threshold_speed: float = maxf(0.001, recoil_max_speed * maxf(0.0, linear_cruise_threshold_ratio - linear_cruise_hysteresis_ratio))
	var current_speed: float = _motion_velocity.length()
	if _linear_cruise_active:
		if current_speed <= exit_threshold_speed:
			_linear_cruise_active = false
	else:
		if current_speed >= linear_threshold_speed:
			_linear_cruise_active = true
	return linear_threshold_speed

func _apply_linear_motion_step(delta: float) -> Vector3:
	var pre_slide_velocity := _motion_velocity
	var drag_lerp: float = 1.0 - exp(-recoil_drag * delta)
	if _linear_cruise_active:
		var cruise_lerp: float = 1.0 - exp(-linear_cruise_drag * delta)
		_motion_velocity.x = lerp(_motion_velocity.x, 0.0, cruise_lerp)
		_motion_velocity.y = lerp(_motion_velocity.y, 0.0, drag_lerp)
		_motion_velocity.z = lerp(_motion_velocity.z, 0.0, cruise_lerp)
	else:
		_motion_velocity.x = lerp(_motion_velocity.x, 0.0, drag_lerp)
		_motion_velocity.z = lerp(_motion_velocity.z, 0.0, drag_lerp)
		_motion_velocity.y -= _project_gravity * delta
	velocity = _motion_velocity
	move_and_slide()
	_motion_velocity = velocity
	return pre_slide_velocity

func _resolve_linear_collisions(pre_slide_velocity: Vector3) -> void:
	var incoming := pre_slide_velocity
	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var normal := collision.get_normal()
		if incoming.length_squared() < 0.0001:
			incoming = _motion_velocity
		var speed := incoming.length()
		if speed > bounce_min_speed:
			_motion_velocity = incoming.bounce(normal) * bounce_restitution
			_motion_velocity *= collision_velocity_damping
		else:
			_motion_velocity.x *= 0.8
			_motion_velocity.z *= 0.8
			if _motion_velocity.y < 0.0:
				_motion_velocity.y = 0.0
		_apply_angular_kick_from_normal(normal, speed)
		_apply_yaw_kick_from_collision(normal, incoming, speed)
		impacted.emit(speed)
		if speed >= hard_impact_threshold:
			hard_impact.emit(speed)
			if log_impact_magnitudes:
				print("[Gun] hard impact magnitude=", speed)
		if normal.y < ground_check_min_normal_y and speed >= ricochet_min_impact_speed:
			_ricochet_leash_timer = ricochet_boost_duration
		incoming = _motion_velocity

func _clamp_motion_to_floor() -> void:
	if position.y < floor_y:
		position.y = floor_y
		if _motion_velocity.y < 0.0:
			_motion_velocity.y = 0.0

func _apply_post_move_linear_controls(delta: float, grounded_before_move: bool, grounded_after_move: bool) -> void:
	if not grounded_before_move and grounded_after_move:
		_landing_settle_timer = landing_settle_duration
		if _motion_velocity.length() <= landing_vel_epsilon:
			_motion_velocity = Vector3.ZERO
	_apply_air_drift_cleanup(delta, grounded_after_move)
	_apply_velocity_leash(delta, grounded_after_move)
	if not grounded_after_move and max_air_speed > 0.0 and _motion_velocity.length() > max_air_speed:
		_motion_velocity = _motion_velocity.normalized() * max_air_speed

func _apply_angular_stability_controls(delta: float, grounded_after_move: bool, linear_threshold_speed: float) -> void:
	if not grounded_after_move and _motion_velocity.length() > linear_threshold_speed:
		var air_pitch_error := wrapf(rotation.x, -PI, PI)
		var air_roll_error := wrapf(rotation.z, -PI, PI)
		_angular_velocity.x += (-air_pitch_error * airborne_wobble_restore) * delta
		_angular_velocity.z += (-air_roll_error * airborne_wobble_restore) * delta
		var air_damp_lerp := 1.0 - exp(-airborne_wobble_damping * delta)
		_angular_velocity.x = lerp(_angular_velocity.x, 0.0, air_damp_lerp)
		_angular_velocity.z = lerp(_angular_velocity.z, 0.0, air_damp_lerp)
	if grounded_after_move:
		var grounded_speed := _motion_velocity.length()
		var upright_assist := clampf(1.0 - (grounded_speed / linear_threshold_speed), ground_upright_min_assist, 1.0)
		var upright_damping_scale := lerpf(0.5, 1.0, upright_assist)
		var floor_pitch_error := wrapf(rotation.x, -PI, PI)
		var floor_roll_error := wrapf(rotation.z, -PI, PI)
		_angular_velocity.x += (-floor_pitch_error * ground_upright_spring * upright_assist) * delta
		_angular_velocity.z += (-floor_roll_error * ground_upright_spring * upright_assist) * delta
		_angular_velocity.x = lerp(_angular_velocity.x, 0.0, 1.0 - exp(-(ground_upright_damping * upright_damping_scale) * delta))
		_angular_velocity.z = lerp(_angular_velocity.z, 0.0, 1.0 - exp(-(ground_upright_damping * upright_damping_scale) * delta))
		if _motion_velocity.length() < ground_upright_snap_speed and _external_rotation_timer <= 0.0:
			var settle_lerp := 1.0 - exp(-ground_upright_settle_damping * delta)
			rotation.x = lerp_angle(rotation.x, 0.0, settle_lerp)
			rotation.z = lerp_angle(rotation.z, 0.0, settle_lerp)
			_angular_velocity.x = lerp(_angular_velocity.x, 0.0, settle_lerp)
			_angular_velocity.z = lerp(_angular_velocity.z, 0.0, settle_lerp)
	if grounded_after_move and Vector2(_motion_velocity.x, _motion_velocity.z).length() < linear_rest_threshold:
		_motion_velocity.x = 0.0
		_motion_velocity.z = 0.0
	var pitch_error := wrapf(rotation.x, -PI, PI)
	var roll_error := wrapf(rotation.z, -PI, PI)
	var is_force_active := _external_rotation_timer > 0.0
	var restore_scale := external_restore_scale if is_force_active else 1.0
	var damping_scale := external_damping_scale if is_force_active else 1.0
	var damping_boost := landing_angular_drag_boost if _landing_settle_timer > 0.0 else 0.0
	var effective_angular_damping := angular_damping + spin_angular_drag + damping_boost
	_angular_velocity.x += (-pitch_error * angular_restore_spring * restore_scale) * delta
	_angular_velocity.z += (-roll_error * angular_restore_spring * restore_scale) * delta
	_angular_velocity.x = lerp(_angular_velocity.x, 0.0, 1.0 - exp(-(effective_angular_damping * damping_scale) * delta))
	_angular_velocity.y = lerp(_angular_velocity.y, 0.0, 1.0 - exp(-(effective_angular_damping * 0.72) * delta))
	_angular_velocity.z = lerp(_angular_velocity.z, 0.0, 1.0 - exp(-(effective_angular_damping * damping_scale) * delta))
	if _external_rotation_timer <= 0.0:
		var passive_roll_error := wrapf(rotation.z, -PI, PI)
		_angular_velocity.z += (-passive_roll_error * passive_roll_upright_spring) * delta
		_angular_velocity.z = lerp(_angular_velocity.z, 0.0, 1.0 - exp(-passive_roll_damping * delta))

func _apply_angular_rotation_step(delta: float) -> void:
	var angular_clamp := maxf(0.01, max_angular_velocity_clamp)
	_angular_velocity = _angular_velocity.limit_length(angular_clamp)
	if _angular_velocity.length() < 0.04 and _motion_velocity.length() < linear_rest_threshold * 0.65:
		_angular_velocity = Vector3.ZERO
	rotate_object_local(Vector3.RIGHT, _angular_velocity.x * delta)
	rotate_object_local(Vector3.UP, _angular_velocity.y * delta)
	rotate_object_local(Vector3.FORWARD, _angular_velocity.z * delta)

func try_fire() -> bool:
	if not _ammo_component.spend_one():
		return false
	if _bullet_spawn_point == null:
		_ammo_component.add_one()
		return false
	if not _fire_component.try_fire(_bullet_spawn_point, get_parent(), get_spawn_point_forward()):
		_ammo_component.add_one()
		return false
	if not _physics_armed:
		_arm_physics()
	_apply_recoil_impulse()
	_leash_delay_timer = leash_delay_after_shot
	shot_fired.emit()
	return true

func restore_bullet_from_headshot() -> void:
	_ammo_component.add_one()

func has_ammo() -> bool:
	return not _ammo_component.is_empty()

func get_ammo_count() -> int:
	return _ammo_component.current_ammo

func get_max_ammo() -> int:
	return _ammo_component.max_ammo

func _on_ammo_changed(current: int, max_ammo: int) -> void:
	ammo_changed.emit(current, max_ammo)

func _apply_skin() -> void:
	var session: GameSession = get_node("/root/GameSession") as GameSession
	var skin_manager: SkinManager = get_node("/root/SkinManager") as SkinManager
	var material := StandardMaterial3D.new()
	material.albedo_color = skin_manager.gun_color(session.selected_skin_index)
	_body_mesh.set_surface_override_material(0, material)

func _setup_visual_wrapper() -> void:
	_model_wrapper_instance = VisualWrapperBuilderScript.apply_wrapper(_body_mesh, _visual_anchor, use_model_wrapper, model_wrapper_scene)

func _setup_laser_pointer() -> void:
	if _bullet_spawn_point == null:
		return
	if not laser_enabled:
		return
	_laser_beam = MeshInstance3D.new()
	_laser_beam.name = "LaserPointer"
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(laser_width, laser_width, 1.0)
	_laser_beam.mesh = beam_mesh
	_laser_material = StandardMaterial3D.new()
	_laser_material.albedo_color = laser_color
	_laser_material.emission_enabled = true
	_laser_material.emission = laser_color
	_laser_material.emission_energy_multiplier = 3.4
	_laser_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_laser_material.no_depth_test = true
	_laser_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser_beam.material_override = _laser_material
	_bullet_spawn_point.add_child(_laser_beam)
	_laser_query.collide_with_areas = true
	_laser_query.collide_with_bodies = true
	_laser_query.hit_from_inside = false
	_laser_query.exclude = [get_rid()]
	_update_laser_beam_transform(laser_max_distance)

func _update_laser_pointer() -> void:
	if _laser_beam == null:
		return
	if not laser_enabled:
		_laser_beam.visible = false
		return
	_laser_beam.visible = true
	var origin := _bullet_spawn_point.global_position
	var direction := get_spawn_point_forward()
	var cast_end := origin + direction * laser_max_distance
	_laser_query.from = origin
	_laser_query.to = cast_end
	_laser_query.collision_mask = laser_collision_mask
	var hit := get_world_3d().direct_space_state.intersect_ray(_laser_query)
	var beam_length := laser_max_distance
	if not hit.is_empty():
		beam_length = GunMotionMathScript.clamped_laser_length(origin, hit.get("position"), laser_max_distance)
	_update_laser_beam_transform(beam_length)

func _update_laser_beam_transform(length: float) -> void:
	if _laser_beam == null:
		return
	_laser_beam.scale = Vector3(1.0, 1.0, length)
	_laser_beam.position = Vector3(0.0, 0.0, -length * 0.5)

func get_spawn_point_forward() -> Vector3:
	if _bullet_spawn_point == null:
		return Vector3.FORWARD
	var forward := (-_bullet_spawn_point.global_transform.basis.z).normalized()
	if _spin_component != null and _spin_component.has_method("get_passive_yaw_radians"):
		var passive_yaw: float = _spin_component.get_passive_yaw_radians()
		forward = forward.rotated(Vector3.UP, -passive_yaw).normalized()
	return forward

func get_motion_speed() -> float:
	return _motion_velocity.length()

func get_rotation_speed() -> float:
	return _angular_velocity.length()

func get_unwrapped_rotation_degrees() -> float:
	return _unwrapped_yaw_degrees

func _apply_recoil_impulse() -> void:
	var recoil_dir := -get_spawn_point_forward()
	recoil_dir.y = 0.0
	if recoil_dir.length_squared() < 0.0001:
		return
	recoil_dir = recoil_dir.normalized()
	_motion_velocity = GunMotionMathScript.recoil_trajectory_velocity(
		_motion_velocity,
		recoil_dir,
		old_lateral_carry,
		vertical_carry,
		recoil_force,
		0.0,
		recoil_max_speed
	)
	_motion_velocity += Vector3.UP * recoil_upward_impulse
	if _motion_velocity.length() > recoil_max_speed:
		_motion_velocity = _motion_velocity.normalized() * recoil_max_speed
	_angular_velocity.x += -deg_to_rad(recoil_backflip_kick_degrees)
	_angular_velocity.z += deg_to_rad(recoil_roll_kick_degrees) * -_spin_component.direction
	_register_external_rotation_influence(1.0)
	_spin_component.add_recoil_spin(maxf(backspin_torque, recoil_spin_kick_degrees))
	_on_shot_impulse((recoil_dir * recoil_force + Vector3.UP * recoil_upward_impulse).normalized())

func _apply_angular_kick_from_normal(normal: Vector3, impulse_speed: float) -> void:
	var kick := GunMotionMathScript.angular_kick_from_normal(normal, impulse_speed, collision_angular_kick)
	_angular_velocity.x += kick.x
	_angular_velocity.z += kick.y
	_register_external_rotation_influence(clampf(impulse_speed / 6.0, 0.55, 1.8))

func _apply_yaw_kick_from_collision(normal: Vector3, incoming_velocity: Vector3, impulse_speed: float) -> void:
	return

func _register_external_rotation_influence(influence_scale: float) -> void:
	_external_rotation_timer = maxf(_external_rotation_timer, external_rotation_influence_time * influence_scale)

func _update_unwrapped_rotation() -> void:
	var current_yaw := rotation.y
	var delta_yaw := wrapf(current_yaw - _last_yaw_radians, -PI, PI)
	_unwrapped_yaw_degrees += rad_to_deg(delta_yaw)
	_last_yaw_radians = current_yaw

func _arm_physics() -> void:
	_physics_armed = true

func _sync_tunable_aliases() -> void:
	if recoil_force <= 0.0:
		recoil_force = recoil_backward_impulse
	recoil_backward_impulse = recoil_force
	if max_angular_velocity_clamp <= 0.0:
		max_angular_velocity_clamp = angular_speed_max
	angular_speed_max = max_angular_velocity_clamp
	if backspin_torque <= 0.0:
		backspin_torque = recoil_spin_kick_degrees

func _setup_ground_check_query() -> void:
	_ground_check_shape.radius = ground_check_radius
	_ground_shape_query.shape = _ground_check_shape
	_ground_shape_query.collision_mask = collision_mask
	_ground_shape_query.exclude = [get_rid()]

func _is_grounded_custom() -> bool:
	if not ground_check_enabled:
		return is_on_floor()
	_ground_check_shape.radius = ground_check_radius
	var origin := global_position + ground_check_offset
	_ground_shape_query.transform = Transform3D(Basis.IDENTITY, origin + Vector3.DOWN * ground_check_distance)
	_ground_shape_query.collide_with_bodies = true
	_ground_shape_query.collide_with_areas = false
	var hits := get_world_3d().direct_space_state.intersect_shape(_ground_shape_query, 4)
	for hit in hits:
		var normal := hit.get("normal", Vector3.UP) as Vector3
		if normal.y >= ground_check_min_normal_y:
			return true
	return false

func _apply_air_drift_cleanup(delta: float, grounded: bool) -> void:
	if grounded:
		return
	if _motion_velocity.length() < min_speed_for_leash:
		return
	var desired_flat := Vector3(_desired_travel_dir.x, 0.0, _desired_travel_dir.z)
	if desired_flat.length_squared() < 0.0001:
		desired_flat = Vector3(_motion_velocity.x, 0.0, _motion_velocity.z)
	if desired_flat.length_squared() < 0.0001:
		return
	desired_flat = desired_flat.normalized()
	var horizontal := Vector3(_motion_velocity.x, 0.0, _motion_velocity.z)
	var parallel := desired_flat * horizontal.dot(desired_flat)
	var drift := horizontal - parallel
	var damp_lerp := clampf(air_drift_damping * delta * 60.0, 0.0, 1.0)
	drift = drift.lerp(Vector3.ZERO, damp_lerp)
	horizontal = parallel + drift
	_motion_velocity.x = horizontal.x
	_motion_velocity.z = horizontal.z

func _apply_velocity_leash(delta: float, grounded: bool) -> void:
	if _leash_delay_timer > 0.0:
		return
	var speed := _motion_velocity.length()
	if speed < min_speed_for_leash:
		return
	if _desired_travel_dir.length_squared() < 0.0001:
		return
	var desired_dir := _desired_travel_dir.normalized()
	var parallel := desired_dir * _motion_velocity.dot(desired_dir)
	var perp := _motion_velocity - parallel
	if leash_max_perp_speed > 0.0 and perp.length() > leash_max_perp_speed:
		perp = perp.normalized() * leash_max_perp_speed
	var base_strength := leash_strength_ground if grounded else leash_strength_air
	if _ricochet_leash_timer > 0.0:
		base_strength *= ricochet_leash_boost
	var leash_lerp := clampf(base_strength * delta, 0.0, 1.0)
	perp = perp.lerp(Vector3.ZERO, leash_lerp)
	_motion_velocity = parallel + perp
	if debug_log_perp:
		print("[Gun] perp_speed=", perp.length(), " speed=", speed)

func _on_shot_impulse(impulse_dir: Vector3) -> void:
	if impulse_dir.length_squared() < 0.0001:
		return
	if _desired_travel_dir.length_squared() < 0.0001:
		_desired_travel_dir = impulse_dir.normalized()
		return
	_desired_travel_dir = _desired_travel_dir.slerp(impulse_dir.normalized(), clampf(desired_dir_blend, 0.0, 1.0)).normalized()
