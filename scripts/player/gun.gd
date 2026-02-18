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

const BULLET_SCENE: PackedScene = preload("res://scenes/player/bullet.tscn")
const DEFAULT_MODEL_WRAPPER_SCENE: PackedScene = preload("res://scenes/visual/gun_model_wrapper.tscn")
const GunMotionMathScript = preload("res://scripts/core/math/gun_motion_math.gd")
const VisualWrapperBuilderScript = preload("res://scripts/core/visual/visual_wrapper_builder.gd")

@export_group("Recoil Presets")
@export var recoil_preset: RecoilPreset = RecoilPreset.ARCADE
@export var apply_preset_on_ready: bool = true

@export_group("Recoil Movement")
@export var recoil_backward_impulse: float = 11.2
@export var recoil_upward_impulse: float = 10.6
@export var recoil_gravity: float = 10.2
@export_range(0.0, 1.0, 0.01) var recoil_gravity_scale: float = 0.20
@export var recoil_drag: float = 1.5
@export var recoil_max_speed: float = 15.5
@export var recoil_spin_kick_degrees: float = 90.0

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
@export var collision_yaw_torque: float = 0.085
@export var angular_speed_max: float = 26.0
@export var external_rotation_influence_time: float = 0.22
@export_range(0.0, 1.0, 0.01) var external_restore_scale: float = 0.34
@export_range(0.0, 1.0, 0.01) var external_damping_scale: float = 0.28
@export var passive_roll_upright_spring: float = 13.5
@export var passive_roll_damping: float = 11.0

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

var _motion_velocity: Vector3 = Vector3.ZERO
var _base_y: float = 0.8
var _angular_velocity: Vector3 = Vector3.ZERO
var _spawn_position: Vector3 = Vector3.ZERO
var _physics_armed: bool = false
var _external_rotation_timer: float = 0.0
var _last_yaw_radians: float = 0.0
var _unwrapped_yaw_degrees: float = 0.0
var _linear_cruise_active: bool = false

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
	_last_yaw_radians = rotation.y
	_unwrapped_yaw_degrees = 0.0
	_physics_armed = false
	_external_rotation_timer = 0.0
	_linear_cruise_active = false
	_setup_visual_wrapper()
	_setup_laser_pointer()
	_apply_skin()

func apply_recoil_preset(preset: RecoilPreset) -> void:
	recoil_preset = preset
	match preset:
		RecoilPreset.ARCADE:
			recoil_backward_impulse = 10.0
			recoil_upward_impulse = 9.7
			recoil_gravity = 7.2
			recoil_drag = 0.32
			recoil_max_speed = 14.6
			recoil_spin_kick_degrees = 260.0
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
			external_rotation_influence_time = 1.12
			external_restore_scale = 0.28
			external_damping_scale = 0.24
		RecoilPreset.INSANE:
			recoil_backward_impulse = 14.6
			recoil_upward_impulse = 14.2
			recoil_gravity = 8.8
			recoil_drag = 0.45
			recoil_max_speed = 21.5
			recoil_spin_kick_degrees = 130.0
			bounce_restitution = 0.96
			collision_velocity_damping = 0.98
			collision_angular_kick = 0.045
			recoil_backflip_kick_degrees = 1120.0
			recoil_roll_kick_degrees = 155.0
			angular_restore_spring = 3.7
			angular_damping = 2.6
		RecoilPreset.CUSTOM:
			pass

func _process(delta: float) -> void:
	_fire_component.tick(delta)
	_bounce_component.process_bounce(self, delta)
	_update_laser_pointer()

func _physics_process(delta: float) -> void:
	var suppress_natural_spin := _external_rotation_timer > 0.0
	if _spin_component.has_method("has_external_spin") and _spin_component.has_method("process_spin") and _spin_component.has_external_spin():
		suppress_natural_spin = true
	_spin_component.process_spin(self, delta, suppress_natural_spin)
	_update_unwrapped_rotation()

	if not _physics_armed:
		position = _spawn_position
		_motion_velocity = Vector3.ZERO
		velocity = Vector3.ZERO
		return

	_external_rotation_timer = maxf(0.0, _external_rotation_timer - delta)

	var pre_slide_velocity := _motion_velocity
	var linear_threshold_speed: float = maxf(0.01, recoil_max_speed * linear_cruise_threshold_ratio)
	var exit_threshold_speed: float = maxf(0.001, recoil_max_speed * maxf(0.0, linear_cruise_threshold_ratio - linear_cruise_hysteresis_ratio))
	var current_speed: float = _motion_velocity.length()
	if _linear_cruise_active:
		if current_speed <= exit_threshold_speed:
			_linear_cruise_active = false
	else:
		if current_speed >= linear_threshold_speed:
			_linear_cruise_active = true
	var drag_lerp: float = 1.0 - exp(-recoil_drag * delta)
	if _linear_cruise_active:
		var cruise_lerp: float = 1.0 - exp(-linear_cruise_drag * delta)
		_motion_velocity.x = lerp(_motion_velocity.x, 0.0, cruise_lerp)
		_motion_velocity.y = lerp(_motion_velocity.y, 0.0, drag_lerp)
		_motion_velocity.z = lerp(_motion_velocity.z, 0.0, cruise_lerp)
	else:
		_motion_velocity.x = lerp(_motion_velocity.x, 0.0, drag_lerp)
		_motion_velocity.z = lerp(_motion_velocity.z, 0.0, drag_lerp)
		_motion_velocity.y -= recoil_gravity * recoil_gravity_scale * delta

	velocity = _motion_velocity
	move_and_slide()
	_motion_velocity = velocity

	for index in range(get_slide_collision_count()):
		var collision := get_slide_collision(index)
		var normal := collision.get_normal()
		var incoming := pre_slide_velocity
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
		pre_slide_velocity = _motion_velocity

	if position.y < floor_y:
		position.y = floor_y
		if _motion_velocity.y < 0.0:
			_motion_velocity.y = 0.0

	if not is_on_floor() and _motion_velocity.length() > linear_threshold_speed:
		var air_pitch_error := wrapf(rotation.x, -PI, PI)
		var air_roll_error := wrapf(rotation.z, -PI, PI)
		_angular_velocity.x += (-air_pitch_error * airborne_wobble_restore) * delta
		_angular_velocity.z += (-air_roll_error * airborne_wobble_restore) * delta
		var air_damp_lerp := 1.0 - exp(-airborne_wobble_damping * delta)
		_angular_velocity.x = lerp(_angular_velocity.x, 0.0, air_damp_lerp)
		_angular_velocity.z = lerp(_angular_velocity.z, 0.0, air_damp_lerp)

	if is_on_floor():
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
	if is_on_floor() and Vector2(_motion_velocity.x, _motion_velocity.z).length() < linear_rest_threshold:
		_motion_velocity.x = 0.0
		_motion_velocity.z = 0.0

	var pitch_error := wrapf(rotation.x, -PI, PI)
	var roll_error := wrapf(rotation.z, -PI, PI)
	var is_force_active := _external_rotation_timer > 0.0
	var restore_scale := external_restore_scale if is_force_active else 1.0
	var damping_scale := external_damping_scale if is_force_active else 1.0
	_angular_velocity.x += (-pitch_error * angular_restore_spring * restore_scale) * delta
	_angular_velocity.z += (-roll_error * angular_restore_spring * restore_scale) * delta
	_angular_velocity.x = lerp(_angular_velocity.x, 0.0, 1.0 - exp(-(angular_damping * damping_scale) * delta))
	_angular_velocity.y = lerp(_angular_velocity.y, 0.0, 1.0 - exp(-(angular_damping * 0.72) * delta))
	_angular_velocity.z = lerp(_angular_velocity.z, 0.0, 1.0 - exp(-(angular_damping * damping_scale) * delta))
	if _external_rotation_timer <= 0.0:
		var passive_roll_error := wrapf(rotation.z, -PI, PI)
		_angular_velocity.z += (-passive_roll_error * passive_roll_upright_spring) * delta
		_angular_velocity.z = lerp(_angular_velocity.z, 0.0, 1.0 - exp(-passive_roll_damping * delta))
	_angular_velocity = _angular_velocity.limit_length(angular_speed_max)
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
	_spin_component.flip_direction()
	_apply_recoil_impulse()
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
		recoil_backward_impulse,
		0.0,
		recoil_max_speed
	)
	var local_up := _bullet_spawn_point.global_transform.basis.y.normalized()
	_motion_velocity += local_up * recoil_upward_impulse
	if _motion_velocity.length() > recoil_max_speed:
		_motion_velocity = _motion_velocity.normalized() * recoil_max_speed
	var backflip_dir := -1.0 if _spin_component.direction >= 0.0 else 1.0
	_angular_velocity.x += deg_to_rad(recoil_backflip_kick_degrees) * backflip_dir
	_angular_velocity.z += deg_to_rad(recoil_roll_kick_degrees) * -_spin_component.direction
	_register_external_rotation_influence(1.0)
	_spin_component.add_recoil_spin(recoil_spin_kick_degrees)

func _apply_angular_kick_from_normal(normal: Vector3, impulse_speed: float) -> void:
	var kick := GunMotionMathScript.angular_kick_from_normal(normal, impulse_speed, collision_angular_kick)
	_angular_velocity.x += kick.x
	_angular_velocity.z += kick.y
	_register_external_rotation_influence(clampf(impulse_speed / 6.0, 0.55, 1.8))

func _apply_yaw_kick_from_collision(normal: Vector3, incoming_velocity: Vector3, impulse_speed: float) -> void:
	return

func _register_external_rotation_influence(scale: float) -> void:
	_external_rotation_timer = maxf(_external_rotation_timer, external_rotation_influence_time * scale)

func _update_unwrapped_rotation() -> void:
	var current_yaw := rotation.y
	var delta_yaw := wrapf(current_yaw - _last_yaw_radians, -PI, PI)
	_unwrapped_yaw_degrees += rad_to_deg(delta_yaw)
	_last_yaw_radians = current_yaw

func _arm_physics() -> void:
	_physics_armed = true
