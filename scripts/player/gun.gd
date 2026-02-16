extends CharacterBody3D
class_name Gun

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

@export_group("Recoil Presets")
@export var recoil_preset: RecoilPreset = RecoilPreset.ARCADE
@export var apply_preset_on_ready: bool = true

@export_group("Recoil Movement")
@export var recoil_backward_impulse: float = 11.2
@export var recoil_upward_impulse: float = 10.6
@export var recoil_gravity: float = 10.2
@export var recoil_drag: float = 1.5
@export var recoil_max_speed: float = 15.5
@export var recoil_spin_kick_degrees: float = 90.0

@export_group("Collision Bounce")
@export var bounce_restitution: float = 0.62
@export var collision_velocity_damping: float = 0.6
@export var collision_angular_kick: float = 0.028

@export_group("External Rotation")
@export var recoil_backflip_kick_degrees: float = 780.0
@export var recoil_roll_kick_degrees: float = 80.0
@export var angular_restore_spring: float = 4.8
@export var angular_damping: float = 3.2

@export_group("Ground")
@export var floor_y: float = 0.8

@export_group("Visual")
@export var use_model_wrapper: bool = false
@export var model_wrapper_scene: PackedScene = DEFAULT_MODEL_WRAPPER_SCENE

@onready var _spin_component: Node = $SpinComponent
@onready var _ammo_component: Node = $AmmoComponent
@onready var _fire_component: Node = $FireComponent
@onready var _bounce_component: Node = $BounceComponent
@onready var _bullet_spawn_point: Marker3D = $BulletSpawnPoint
@onready var _body_mesh: MeshInstance3D = $Body
@onready var _visual_anchor: Node3D = $VisualAnchor

var _model_wrapper_instance: Node3D

var _motion_velocity: Vector3 = Vector3.ZERO
var _base_y: float = 0.8
var _angular_velocity: Vector3 = Vector3.ZERO
var _last_yaw_radians: float = 0.0
var _unwrapped_yaw_degrees: float = 0.0

func _ready() -> void:
	if apply_preset_on_ready:
		apply_recoil_preset(recoil_preset)
	_fire_component.setup(BULLET_SCENE)
	_ammo_component.setup(_ammo_component.max_ammo)
	_ammo_component.ammo_changed.connect(_on_ammo_changed)
	if _bullet_spawn_point == null:
		push_error("Gun is missing required child spawn point node: BulletSpawnPoint")
	_base_y = position.y
	floor_y = _base_y
	_last_yaw_radians = rotation.y
	_unwrapped_yaw_degrees = 0.0
	_setup_visual_wrapper()
	_apply_skin()

func apply_recoil_preset(preset: RecoilPreset) -> void:
	recoil_preset = preset
	match preset:
		RecoilPreset.ARCADE:
			recoil_backward_impulse = 11.2
			recoil_upward_impulse = 10.6
			recoil_gravity = 10.2
			recoil_drag = 0.65
			recoil_max_speed = 15.5
			recoil_spin_kick_degrees = 90.0
			bounce_restitution = 0.9
			collision_velocity_damping = 0.95
			collision_angular_kick = 0.028
			recoil_backflip_kick_degrees = 780.0
			recoil_roll_kick_degrees = 80.0
			angular_restore_spring = 4.8
			angular_damping = 3.2
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
	_spin_component.process_spin(self, delta)
	_fire_component.tick(delta)
	_bounce_component.process_bounce(self, delta)
	_update_unwrapped_rotation()

func _physics_process(delta: float) -> void:
	var pre_slide_velocity := _motion_velocity
	_motion_velocity.x = move_toward(_motion_velocity.x, 0.0, recoil_drag * delta)
	_motion_velocity.z = move_toward(_motion_velocity.z, 0.0, recoil_drag * delta)
	_motion_velocity.y -= recoil_gravity * delta

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
		_motion_velocity = incoming.bounce(normal) * bounce_restitution
		_motion_velocity *= collision_velocity_damping
		_apply_angular_kick_from_normal(normal, speed)
		impacted.emit(speed)
		pre_slide_velocity = _motion_velocity

	if position.y < floor_y:
		position.y = floor_y
		if _motion_velocity.y < 0.0:
			_motion_velocity.y = 0.0

	var pitch_error := wrapf(rotation.x, -PI, PI)
	var roll_error := wrapf(rotation.z, -PI, PI)
	_angular_velocity.x += (-pitch_error * angular_restore_spring) * delta
	_angular_velocity.z += (-roll_error * angular_restore_spring) * delta
	_angular_velocity.x = lerp(_angular_velocity.x, 0.0, 1.0 - exp(-angular_damping * delta))
	_angular_velocity.z = lerp(_angular_velocity.z, 0.0, 1.0 - exp(-angular_damping * delta))
	rotate_object_local(Vector3.RIGHT, _angular_velocity.x * delta)
	rotate_object_local(Vector3.FORWARD, _angular_velocity.z * delta)

func try_fire() -> bool:
	if not _ammo_component.spend_one():
		return false
	if _bullet_spawn_point == null:
		_ammo_component.add_one()
		return false
	if not _fire_component.try_fire(_bullet_spawn_point, get_parent()):
		_ammo_component.add_one()
		return false
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
	_body_mesh.visible = true
	if not use_model_wrapper:
		return
	if model_wrapper_scene == null:
		return
	var wrapper: Node = model_wrapper_scene.instantiate()
	if wrapper == null:
		return
	if wrapper is Node3D:
		_model_wrapper_instance = wrapper as Node3D
		_visual_anchor.add_child(_model_wrapper_instance)
		_body_mesh.visible = false

func get_spawn_point_forward() -> Vector3:
	return (-_bullet_spawn_point.global_transform.basis.z).normalized()

func get_motion_speed() -> float:
	return _motion_velocity.length()

func get_rotation_speed() -> float:
	return _angular_velocity.length()

func get_unwrapped_rotation_degrees() -> float:
	return _unwrapped_yaw_degrees

func _apply_recoil_impulse() -> void:
	var recoil_dir := _bullet_spawn_point.global_transform.basis.z
	recoil_dir.y = 0.0
	if recoil_dir.length_squared() < 0.0001:
		return
	recoil_dir = recoil_dir.normalized()
	_motion_velocity += recoil_dir * recoil_backward_impulse
	_motion_velocity.y += recoil_upward_impulse
	if _motion_velocity.length() > recoil_max_speed:
		_motion_velocity = _motion_velocity.normalized() * recoil_max_speed
	var backflip_dir := -1.0 if _spin_component.direction >= 0.0 else 1.0
	_angular_velocity.x += deg_to_rad(recoil_backflip_kick_degrees) * backflip_dir
	_angular_velocity.z += deg_to_rad(recoil_roll_kick_degrees) * -_spin_component.direction
	_spin_component.add_recoil_spin(recoil_spin_kick_degrees)

func _apply_angular_kick_from_normal(normal: Vector3, impulse_speed: float) -> void:
	var kick_scale := impulse_speed * collision_angular_kick
	_angular_velocity.x += normal.z * kick_scale
	_angular_velocity.z += -normal.x * kick_scale

func _update_unwrapped_rotation() -> void:
	var current_yaw := rotation.y
	var delta_yaw := wrapf(current_yaw - _last_yaw_radians, -PI, PI)
	_unwrapped_yaw_degrees += rad_to_deg(delta_yaw)
	_last_yaw_radians = current_yaw
