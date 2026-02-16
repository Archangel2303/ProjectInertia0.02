extends Area3D

const DEFAULT_MODEL_WRAPPER_SCENE: PackedScene = preload("res://scenes/visual/bullet_model_wrapper.tscn")
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
	if not area.is_in_group("enemy_head"):
		return
	var enemy: Node = area.get_parent()
	if enemy and enemy.has_method("apply_hit"):
		enemy.apply_hit(true, HIT_HEAD)
		queue_free()

func _classify_hit_location(body: Node) -> int:
	if not (body is Node3D):
		return HIT_TORSO

	var body_3d := body as Node3D
	var local_hit := body_3d.to_local(global_position)

	var enemy_forward := (-body_3d.global_transform.basis.z).normalized()
	if enemy_forward.dot(_direction.normalized()) > 0.55:
		return HIT_BACK

	if local_hit.y < 0.35:
		return HIT_LIMBS
	if local_hit.y < 0.75:
		return HIT_MIDSECTION
	return HIT_TORSO

func _apply_skin() -> void:
	var session: GameSession = get_node("/root/GameSession") as GameSession
	var skin_manager: SkinManager = get_node("/root/SkinManager") as SkinManager
	var material := StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = skin_manager.trail_color(session.selected_skin_index)
	material.albedo_color = skin_manager.bullet_color(session.selected_skin_index)
	_mesh.set_surface_override_material(0, material)

func _setup_visual_wrapper() -> void:
	_mesh.visible = true
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
		_mesh.visible = false
