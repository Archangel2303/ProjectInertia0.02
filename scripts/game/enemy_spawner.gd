extends Node3D
class_name EnemySpawner

# EnemySpawner handles when/where enemies appear.
# Balance curves and wave composition are delegated to shared spawn utilities.
signal enemy_spawned(enemy: Node)

const MODE_LEVEL := 0
const MODE_ENDLESS := 1

const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")
const EnemySpawnBalanceScript = preload("res://scripts/core/spawn/enemy_spawn_balance.gd")
const LEVEL1_STATIC_LAYOUT: Array[Dictionary] = [
	{"type": 0, "pos": Vector3(0.0, 0.55, -5.0)},
	{"type": 2, "pos": Vector3(0.0, 0.55, 5.0)},
]

@export var spawn_radius: float = 14.0
@export var spawn_height: float = 0.55

var _rng := RandomNumberGenerator.new()
var _spawn_timer: float = 0.0
var _endless_elapsed_total: float = 0.0
var _endless_player_kills: int = 0
var _alive_count: int = 0
var _mode: int = MODE_LEVEL
var _wave_queue: Array[int] = []

func _ready() -> void:
	_set_deterministic_seed(MODE_LEVEL, 0)

func configure_for_level(level_index: int) -> void:
	_mode = MODE_LEVEL
	_reset_runtime_state()
	_set_deterministic_seed(MODE_LEVEL, level_index)
	if level_index == 0:
		spawn_radius = 8.0
		_spawn_level_one_static_layout()
		return
	_wave_queue = _build_level_wave(level_index)
	spawn_radius = 12.0 + float(level_index) * 0.6

func configure_for_endless() -> void:
	_mode = MODE_ENDLESS
	_reset_runtime_state()
	_set_deterministic_seed(MODE_ENDLESS, 0)

func set_endless_progress(kills: int) -> void:
	_endless_player_kills = max(kills, 0)

func _process(delta: float) -> void:
	_spawn_timer -= delta
	if _mode == MODE_LEVEL:
		_process_level_spawn()
		return
	_process_endless_spawn(delta)

func _process_level_spawn() -> void:
	if _wave_queue.is_empty():
		return
	if _spawn_timer > 0.0:
		return
	_spawn_enemy(_wave_queue.pop_front())
	_spawn_timer = 1.0

func _process_endless_spawn(delta: float) -> void:
	_endless_elapsed_total += delta
	if _spawn_timer > 0.0:
		return
	var difficulty := EnemySpawnBalanceScript.endless_difficulty(_endless_elapsed_total, _endless_player_kills)
	var max_alive := EnemySpawnBalanceScript.endless_max_alive(difficulty)
	if _alive_count >= max_alive:
		_spawn_timer = 0.2
		return
	var slots := max_alive - _alive_count
	var burst_count := mini(slots, EnemySpawnBalanceScript.endless_burst_count(difficulty))
	for i in range(burst_count):
		var enemy_type := EnemySpawnBalanceScript.pick_enemy_type_for_difficulty(_rng, difficulty)
		_spawn_enemy(enemy_type)
	var cadence := EnemySpawnBalanceScript.endless_spawn_cadence(difficulty)
	_spawn_timer = _rng.randf_range(cadence * 0.75, cadence * 1.25)

func _spawn_enemy(enemy_type: int) -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(spawn_radius * 0.7, spawn_radius)
	var spawn_pos := global_position + Vector3(cos(angle) * radius, spawn_height, sin(angle) * radius)
	_spawn_enemy_at(enemy_type, spawn_pos, false)

func _spawn_enemy_at(enemy_type: int, spawn_pos: Vector3, static_mode: bool) -> void:
	var enemy := ENEMY_SCENE.instantiate()
	enemy.enemy_type = enemy_type
	enemy.is_static = static_mode
	add_child(enemy)
	enemy.global_position = spawn_pos
	_alive_count += 1
	enemy.tree_exited.connect(_on_enemy_exited)
	enemy_spawned.emit(enemy)

func _spawn_level_one_static_layout() -> void:
	for entry in LEVEL1_STATIC_LAYOUT:
		var enemy_type: int = int(entry.get("type", 0))
		var spawn_pos: Vector3 = entry.get("pos", Vector3.ZERO) as Vector3
		_spawn_enemy_at(enemy_type, spawn_pos, true)

func get_level_target_kills(level_index: int) -> int:
	if level_index == 0:
		return LEVEL1_STATIC_LAYOUT.size()
	return 12 + level_index * 4

func has_pending_level_spawns() -> bool:
	return _mode == MODE_LEVEL and not _wave_queue.is_empty()

func _on_enemy_exited() -> void:
	_alive_count = maxi(0, _alive_count - 1)

func _build_level_wave(level_index: int) -> Array[int]:
	return EnemySpawnBalanceScript.build_level_wave(level_index)

func _reset_runtime_state() -> void:
	_wave_queue.clear()
	_spawn_timer = 0.0
	_endless_elapsed_total = 0.0
	_endless_player_kills = 0
	_alive_count = 0

func _set_deterministic_seed(mode: int, level_index: int) -> void:
	var mode_key: int = mode + 1
	var level_key: int = level_index + 1
	var computed_seed: int = mode_key * 1_000_003 + level_key * 7_919
	_rng.seed = computed_seed
