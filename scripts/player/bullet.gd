extends Area3D

# Bullet acts as a lightweight collision/messaging container.
# Classification and lookup logic live in shared combat helpers.

const DEFAULT_MODEL_WRAPPER_SCENE: PackedScene = preload("res://scenes/visual/bullet_model_wrapper.tscn")
const BulletHitUtilScript = preload("res://scripts/core/combat/bullet_hit_util.gd")
const VisualWrapperBuilderScript = preload("res://scripts/core/visual/visual_wrapper_builder.gd")
const HIT_LIMBS := 0
const HIT_TORSO := 1
const HIT_MIDSECTION := 2
const HIT_BACK := 3
const HIT_HEAD := 4

@export var lifetime_seconds: float = 2.0
@export_group("Visual")
@export var use_model_wrapper: bool = false
@export var model_wrapper_scene: PackedScene = DEFAULT_MODEL_WRAPPER_SCENE

var _direction: Vector3 = Vector3.FORWARD
var _speed: float = 28.0

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _visual_anchor: Node3D = $VisualAnchor

var _model_wrapper_instance: Node3D

func setup(direction: Vector3, speed: float) -> void:
	_direction = direction.normalized()
	_speed = speed

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_setup_visual_wrapper()
	_apply_skin()
	await get_tree().create_timer(lifetime_seconds).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta

func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_hit"):
		body.apply_hit(false, _classify_hit_location(body))
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	var is_hitbox := area.is_in_group("enemy_hitbox")
	var is_head_group := area.is_in_group("enemy_head")
	if not is_hitbox and not is_head_group:
		return

	var enemy := BulletHitUtilScript.find_enemy_for_hit_node(area)
	if enemy == null:
		return

	var hit_location := HIT_HEAD if is_head_group else HIT_TORSO
	if area.has_meta("enemy_hit_location"):
		hit_location = int(area.get_meta("enemy_hit_location"))

	var headshot := hit_location == HIT_HEAD
	enemy.apply_hit(headshot, hit_location, area)
	queue_free()

func _classify_hit_location(body: Node) -> int:
	return BulletHitUtilScript.classify_hit_location(
		body,
		global_position,
		_direction
	)

func _apply_skin() -> void:
	var session: GameSession = get_node("/root/GameSession") as GameSession
	var skin_manager: SkinManager = get_node("/root/SkinManager") as SkinManager
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = skin_manager.trail_color(session.selected_skin_index)
	material.albedo_color = skin_manager.bullet_color(session.selected_skin_index)
	_mesh.set_surface_override_material(0, material)

func _setup_visual_wrapper() -> void:
	_model_wrapper_instance = VisualWrapperBuilderScript.apply_wrapper(_mesh, _visual_anchor, use_model_wrapper, model_wrapper_scene)
