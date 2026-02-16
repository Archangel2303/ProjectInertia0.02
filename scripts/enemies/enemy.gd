extends CharacterBody3D
class_name Enemy

const DEFAULT_MODEL_WRAPPER_SCENE: PackedScene = preload("res://scenes/visual/enemy_model_wrapper.tscn")
const HIT_LIMBS := 0
const HIT_TORSO := 1
const HIT_MIDSECTION := 2
const HIT_BACK := 3
const HIT_HEAD := 4

signal killed(points: int, headshot: bool, hit_location: int)

@export_enum("Basic", "Armored", "BasicShield", "ArmoredShield") var enemy_type: int = 0
@export var move_speed: float = 2.2
@export var is_static: bool = false
@export_group("Visual")
@export var use_model_wrapper: bool = false
@export var model_wrapper_scene: PackedScene = DEFAULT_MODEL_WRAPPER_SCENE

var _armor_hits_left: int = 1
var _shield_hits_left: int = 0
var _alive: bool = true
var _target: Node3D

@onready var _body_mesh: MeshInstance3D = $BodyMesh
@onready var _shield_mesh: MeshInstance3D = $ShieldMesh
@onready var _head_area: Area3D = $HeadArea
@onready var _visual_anchor: Node3D = $VisualAnchor

var _model_wrapper_instance: Node3D

func _ready() -> void:
	match enemy_type:
		0:
			_armor_hits_left = 1
			_shield_hits_left = 0
		1:
			_armor_hits_left = 2
			_shield_hits_left = 0
		2:
			_armor_hits_left = 1
			_shield_hits_left = 1
		3:
			_armor_hits_left = 2
			_shield_hits_left = 1
	_shield_mesh.visible = _shield_hits_left > 0
	_head_area.add_to_group("enemy_head")
	_apply_visuals()
	_setup_visual_wrapper()

func set_target(target: Node3D) -> void:
	_target = target

func _physics_process(_delta: float) -> void:
	if not _alive or is_static or _target == null:
		return
	var direction := _target.global_position - global_position
	direction.y = 0.0
	if direction.length() > 0.55:
		velocity = direction.normalized() * move_speed
		move_and_slide()
		look_at(_target.global_position, Vector3.UP)

func apply_hit(headshot: bool, hit_location: int = -1) -> void:
	if not _alive:
		return
	if _shield_hits_left > 0:
		_shield_hits_left -= 1
		_shield_mesh.visible = _shield_hits_left > 0
		return
	if headshot:
		_die(true, HIT_HEAD if hit_location < 0 else hit_location)
		return
	_armor_hits_left -= 1
	if _armor_hits_left <= 0:
		_die(false, HIT_TORSO if hit_location < 0 else hit_location)

func _die(headshot: bool, hit_location: int) -> void:
	_alive = false
	var points := 150 if headshot else 100
	if enemy_type == 1 or enemy_type == 3:
		points += 50
	killed.emit(points, headshot, hit_location)
	queue_free()

func _apply_visuals() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("#f8f9fa")
	if enemy_type == 1 or enemy_type == 3:
		body_mat.albedo_color = Color("#adb5bd")
	_body_mesh.set_surface_override_material(0, body_mat)

	var shield_mat := StandardMaterial3D.new()
	shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shield_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.45)
	_shield_mesh.set_surface_override_material(0, shield_mat)

func _setup_visual_wrapper() -> void:
	_body_mesh.visible = true
	if not use_model_wrapper:
		return
	if model_wrapper_scene == null:
		return
	var wrapper := model_wrapper_scene.instantiate()
	if wrapper == null:
		return
	if wrapper is Node3D:
		_model_wrapper_instance = wrapper
		_visual_anchor.add_child(_model_wrapper_instance)
		_body_mesh.visible = false

func is_static_enemy() -> bool:
	return is_static
