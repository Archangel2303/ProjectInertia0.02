extends CharacterBody3D
class_name Enemy

# Enemy owns runtime state (alive, shield, armor, movement target) while
# hitbox discovery/classification is delegated to shared combat utilities.
const EnemyHitboxUtilScript = preload("res://scripts/core/combat/enemy_hitbox_util.gd")

const HIT_LIMBS := 0
const HIT_TORSO := 1
const HIT_MIDSECTION := 2
const HIT_BACK := 3
const HIT_HEAD := 4

signal killed(points: int, headshot: bool, hit_location: int)

enum EnemyType {
	REGULAR,
	SHIELDED,
	ARMORED,
	ARMORED_SHIELDED,
}

@export var enemy_type: EnemyType = EnemyType.REGULAR
@export var move_speed: float = 2.2
@export var is_static: bool = false

var _armor_hits_left: int = 1
var _shield_hits_left: int = 0
var _alive: bool = true
var _target: Node3D

var _body_mesh: MeshInstance3D
var _shield_mesh: MeshInstance3D
var _armor_mesh: MeshInstance3D
var _armor_area: Area3D

func _ready() -> void:
	_resolve_scene_nodes()
	_register_hitboxes()
	match enemy_type:
		EnemyType.REGULAR:
			_armor_hits_left = 1
			_shield_hits_left = 0
		EnemyType.SHIELDED:
			_armor_hits_left = 1
			_shield_hits_left = 1
		EnemyType.ARMORED:
			_armor_hits_left = 2
			_shield_hits_left = 0
		EnemyType.ARMORED_SHIELDED:
			_armor_hits_left = 2
			_shield_hits_left = 1
	_update_shield_visual()
	_update_armor_visual()
	_apply_visuals()
	if _body_mesh != null:
		_body_mesh.visible = true

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

func apply_hit(headshot: bool, hit_location: int = -1, hit_source: Node = null) -> void:
	if not _alive:
		return
	var resolved_hit_location: int = hit_location
	if resolved_hit_location < 0:
		resolved_hit_location = HIT_HEAD if headshot else HIT_TORSO

	if _shield_hits_left > 0 and _shield_blocks_hit(resolved_hit_location, hit_source):
		_shield_hits_left -= 1
		_update_shield_visual()
		return

	if headshot:
		_die(true, resolved_hit_location)
		return

	_armor_hits_left -= 1
	_update_armor_visual()
	if _armor_hits_left <= 0:
		_die(false, resolved_hit_location)

func _die(headshot: bool, hit_location: int) -> void:
	_alive = false
	var points := 150 if headshot else 100
	if enemy_type == EnemyType.ARMORED or enemy_type == EnemyType.ARMORED_SHIELDED:
		points += 50
	killed.emit(points, headshot, hit_location)
	queue_free()

func _apply_visuals() -> void:
	if _body_mesh == null:
		return

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("#f8f9fa")
	if enemy_type == EnemyType.ARMORED or enemy_type == EnemyType.ARMORED_SHIELDED:
		body_mat.albedo_color = Color("#adb5bd")
	_body_mesh.set_surface_override_material(0, body_mat)

	if _armor_mesh != null:
		var armor_mat := StandardMaterial3D.new()
		armor_mat.albedo_color = Color("#6c757d")
		armor_mat.metallic = 0.72
		armor_mat.roughness = 0.42
		_armor_mesh.set_surface_override_material(0, armor_mat)

	if _shield_mesh != null:
		var shield_mat := StandardMaterial3D.new()
		shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shield_mat.albedo_color = Color(0.3, 0.7, 1.0, 0.45)
		_shield_mesh.set_surface_override_material(0, shield_mat)

func is_static_enemy() -> bool:
	return is_static

func _update_shield_visual() -> void:
	if _shield_mesh != null:
		_shield_mesh.visible = _shield_hits_left > 0

func _update_armor_visual() -> void:
	var armor_active := _armor_hits_left > 1
	if _armor_mesh != null:
		_armor_mesh.visible = armor_active
	if _armor_area != null:
		_armor_area.monitoring = armor_active
		_armor_area.monitorable = armor_active

func _shield_blocks_hit(hit_location: int, hit_source: Node) -> bool:
	if hit_source is Area3D and (hit_source as Area3D).is_in_group("enemy_shield"):
		return true
	return hit_location == HIT_HEAD

func _resolve_scene_nodes() -> void:
	var meshes: Array[MeshInstance3D] = EnemyHitboxUtilScript.collect_meshes(self)
	for mesh in meshes:
		var lowered := mesh.name.to_lower()
		if lowered.contains("shield"):
			if _shield_mesh == null:
				_shield_mesh = mesh
			continue
		if lowered.contains("armor"):
			if _armor_mesh == null:
				_armor_mesh = mesh
			continue
		if _body_mesh == null and (lowered.contains("body") or lowered.contains("base") or lowered.contains("man")):
			_body_mesh = mesh

	for area in EnemyHitboxUtilScript.collect_areas(self):
		if area.name.to_lower().contains("armor"):
			_armor_area = area
			break

	if _body_mesh == null and not meshes.is_empty():
		_body_mesh = meshes[0]

func _register_hitboxes() -> void:
	for area in EnemyHitboxUtilScript.collect_areas(self):
		var area_name := area.name.to_lower()
		var hit_location := EnemyHitboxUtilScript.hit_location_from_area_name(area_name)
		area.set_meta("enemy_hit_location", hit_location)
		area.add_to_group("enemy_hitbox")

		if hit_location == HIT_HEAD:
			area.add_to_group("enemy_head")

		if EnemyHitboxUtilScript.is_shield_area_name(area_name):
			area.add_to_group("enemy_shield")

		if EnemyHitboxUtilScript.is_armor_area_name(area_name):
			area.add_to_group("enemy_armor")
