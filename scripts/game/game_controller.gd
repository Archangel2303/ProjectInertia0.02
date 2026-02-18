extends Node3D

# GameController is the run orchestrator:
# - receives events from gun/spawner/hud/ad service
# - delegates calculations/flow policy to helper modules
# - applies resulting state changes to scene objects and UI

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/ui/level_select.tscn"
const MODE_LEVEL := 0
const MODE_ENDLESS := 1
const HighScoreServiceScript = preload("res://scripts/core/high_score_service.gd")
const ScoreSystemScript = preload("res://scripts/core/score_system.gd")
const SlowTimeMathScript = preload("res://scripts/core/math/slow_time_math.gd")
const GameRunFlowScript = preload("res://scripts/core/flow/game_run_flow.gd")
const LevelSceneResolverScript = preload("res://scripts/core/world/level_scene_resolver.gd")

@onready var _gun: Gun = $Gun
@onready var _spawner: EnemySpawner = $EnemySpawner
@onready var _hud: Node = $HUD
@onready var _camera: Node = $Camera3D
@onready var _level_content_root: Node3D = $LevelContent
@onready var _endless_chunk_manager: EndlessChunkManager = $EndlessChunkManager

var _ground: StaticBody3D
var _level_one_room: Node3D

func _session() -> Node:
	return get_node("/root/GameSession")

func _ads() -> Node:
	return get_node("/root/AdService")

var _score: int = 0
var _kills: int = 0
var _run_ended: bool = false
var _run_started: bool = false
var _ad_debug_tick: float = 0.0
var _ad_debug_visible: bool = true
var _slow_time_active: bool = false
var _slow_effectiveness: float = 0.0
var _end_bonus_claimed: bool = false
var _end_bonus_request_in_progress: bool = false
var _score_system: ScoreSystem
var _active_enemies: Array[Node] = []

# Slow-time scaling controls are intentionally isolated so this mechanic can be tuned
# without affecting score logic, spawn cadence, or camera state transitions.
const SLOW_TIME_BASE_SCALE := 0.36
const SLOW_TIME_BEST_SCALE := 0.06
const SLOW_TIME_MOVE_SPEED_FOR_MAX := 18.0
const SLOW_TIME_ROT_SPEED_FOR_MAX := 24.0
const SLOW_TIME_EFFECT_SMOOTHING := 8.0

func _ready() -> void:
	_setup_inputs()
	_score_system = ScoreSystemScript.new()
	_score_system.start_run()
	_connect_signals()
	_load_level_content_for_mode()
	_start_mode()
	_ad_debug_visible = not OS.has_feature("pc")
	_hud.set_ad_debug_visible(_ad_debug_visible)
	_hud.update_score(_score)
	_hud.update_ammo(_gun.get_ammo_count(), _gun.get_max_ammo())
	_refresh_ad_debug()

func _load_level_content_for_mode() -> void:
	var is_endless_mode: bool = _session().mode == MODE_ENDLESS
	var scene_path := LevelSceneResolverScript.resolve_for_mode(is_endless_mode, _session().level_index)
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Unable to load level scene: %s" % scene_path)
		_refresh_level_content_references()
		return

	var level_instance := packed_scene.instantiate() as Node3D
	if level_instance == null:
		push_warning("Loaded level scene is not a Node3D: %s" % scene_path)
		_refresh_level_content_references()
		return

	level_instance.name = _level_content_root.name
	_level_content_root.replace_by(level_instance)
	_level_content_root.queue_free()
	_level_content_root = level_instance
	_refresh_level_content_references()

func _refresh_level_content_references() -> void:
	_ground = _level_content_root.get_node_or_null("Ground") as StaticBody3D
	_level_one_room = _level_content_root.get_node_or_null("LevelOneRoom") as Node3D

func _exit_tree() -> void:
	if _ads().rewarded_ad_completed.is_connected(_on_rewarded_ad_completed):
		_ads().rewarded_ad_completed.disconnect(_on_rewarded_ad_completed)
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	_refresh_ad_debug_if_due(delta)
	if _run_ended:
		return

	# Runtime scoring and completion are split into small helpers so each gameplay
	# system (time, enemies, score, ammo prompts) is understandable in isolation.
	if _run_started:
		_score_system.tick(delta, _slow_time_active)
	_update_slow_time_scaling(delta)
	if _should_end_level():
		_end_run(true)
	_update_runtime_score()
	_update_extra_bullet_prompt()

func _refresh_ad_debug_if_due(delta: float) -> void:
	_ad_debug_tick -= delta
	if _ad_debug_tick <= 0.0:
		_refresh_ad_debug()
		_ad_debug_tick = 0.5

func _should_end_level() -> bool:
	if _session().mode != MODE_LEVEL:
		return false
	return all_enemies_dead() and not _spawner.has_pending_level_spawns()

func _update_runtime_score() -> void:
	if _session().mode == MODE_ENDLESS:
		_spawner.set_endless_progress(_kills)
		_score = _score_system.compute_endless_score(_kills, _score_system.clear_time_seconds)
		_hud.update_score(_score)
		return
	var running_breakdown: Dictionary = _score_system.compute_level_score(_gun.get_ammo_count())
	_score = int(running_breakdown.get("total_score", _score))
	_hud.update_score(_score)

func _update_extra_bullet_prompt() -> void:
	if GameRunFlowScript.should_offer_extra_bullet(_gun.has_ammo()):
		var ad_available: bool = GameRunFlowScript.can_use_extra_bullet_ad(
			_session().can_use_extra_bullet_ad(),
			_ads().can_show_rewarded_ad("extra_bullet")
		)
		_hud.set_extra_bullet_ad_enabled(ad_available)
		_hud.show_extra_bullet_prompt(true)
		return
	_hud.show_extra_bullet_prompt(false)

func _current_level_id() -> String:
	return GameRunFlowScript.current_level_id(_session().mode, MODE_ENDLESS, _session().level_index)

func _setup_inputs() -> void:
	if not InputMap.has_action("fire"):
		InputMap.add_action("fire")
		var fire_mouse := InputEventMouseButton.new()
		fire_mouse.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("fire", fire_mouse)
		var fire_key := InputEventKey.new()
		fire_key.physical_keycode = KEY_SPACE
		InputMap.action_add_event("fire", fire_key)

	if not InputMap.has_action("slow_time"):
		InputMap.add_action("slow_time")
		var slow_mouse := InputEventMouseButton.new()
		slow_mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("slow_time", slow_mouse)
		var slow_key := InputEventKey.new()
		slow_key.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("slow_time", slow_key)

	if not InputMap.has_action("toggle_ad_debug"):
		InputMap.add_action("toggle_ad_debug")
		var toggle_key := InputEventKey.new()
		toggle_key.physical_keycode = KEY_F3
		InputMap.action_add_event("toggle_ad_debug", toggle_key)

func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("pc"):
		return
	if event.is_action_pressed("toggle_ad_debug"):
		_ad_debug_visible = not _ad_debug_visible
		_hud.set_ad_debug_visible(_ad_debug_visible)
		_hud.show_debug_toggle_toast(_ad_debug_visible)

func _connect_signals() -> void:
	_spawner.enemy_spawned.connect(_on_enemy_spawned)
	_gun.ammo_changed.connect(_on_ammo_changed)
	_gun.impacted.connect(_on_gun_impacted)
	_hud.fire_pressed.connect(_on_fire_pressed)
	_hud.slow_time_changed.connect(_on_slow_time_changed)
	_hud.extra_bullet_ad_requested.connect(_on_extra_bullet_ad_requested)
	_hud.end_reward_ad_requested.connect(_on_end_reward_ad_requested)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.level_select_requested.connect(_on_level_select_requested)
	_hud.menu_requested.connect(_on_menu_requested)
	_ads().rewarded_ad_completed.connect(_on_rewarded_ad_completed)

func _start_mode() -> void:
	var endless_active: bool = _session().mode == MODE_ENDLESS
	_set_endless_world_active(endless_active)
	_set_level_one_room_active(_session().mode == MODE_LEVEL)
	if _session().mode == MODE_ENDLESS:
		_hud.set_mode_text("Endless")
		_spawner.configure_for_endless()
		return
	_hud.set_mode_text("Level %d" % (_session().level_index + 1))
	_spawner.configure_for_level(_session().level_index)

func _set_endless_world_active(active: bool) -> void:
	if _ground != null:
		_ground.visible = not active
		_ground.collision_layer = 0 if active else 1
	if _endless_chunk_manager != null and _endless_chunk_manager.has_method("set_active"):
		_endless_chunk_manager.set_active(active)

func _set_level_one_room_active(active: bool) -> void:
	if _level_one_room == null:
		return
	_level_one_room.visible = active
	for child in _level_one_room.get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).collision_layer = 1 if active else 0

func _on_enemy_spawned(enemy: Node) -> void:
	_active_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_exited.bind(enemy))
	if _session().mode == MODE_ENDLESS:
		enemy.set_target(_gun)
	enemy.killed.connect(_on_enemy_killed)

func _on_enemy_killed(_points: int, headshot: bool, hit_location: int) -> void:
	_kills += 1
	_score_system.record_kill(hit_location, _gun.get_unwrapped_rotation_degrees())
	if _session().mode == MODE_LEVEL:
		var breakdown: Dictionary = _score_system.compute_level_score(_gun.get_ammo_count())
		_score = int(breakdown.get("total_score", _score))
		_hud.update_score(_score)
	if headshot:
		_gun.restore_bullet_from_headshot()

func _on_enemy_exited(enemy: Node) -> void:
	_active_enemies.erase(enemy)

func all_enemies_dead() -> bool:
	for i in range(_active_enemies.size() - 1, -1, -1):
		var enemy: Node = _active_enemies[i]
		if enemy == null or not is_instance_valid(enemy):
			_active_enemies.remove_at(i)
	return _score_system.all_enemies_dead(_active_enemies)

func _on_ammo_changed(current: int, max_ammo: int) -> void:
	_hud.update_ammo(current, max_ammo)

func _on_fire_pressed() -> void:
	if _run_ended:
		return
	var did_fire: bool = _gun.try_fire()
	if did_fire:
		_run_started = true
		_camera.on_fired()
	if not did_fire and not _gun.has_ammo():
		var ad_available: bool = GameRunFlowScript.can_use_extra_bullet_ad(
			_session().can_use_extra_bullet_ad(),
			_ads().can_show_rewarded_ad("extra_bullet")
		)
		_hud.set_extra_bullet_ad_enabled(ad_available)
		_hud.show_extra_bullet_prompt(true)

func _on_slow_time_changed(active: bool) -> void:
	_slow_time_active = active
	_camera.set_slow_time(active)
	if _run_ended:
		Engine.time_scale = 1.0
		return
	if not active:
		Engine.time_scale = 1.0

func _on_extra_bullet_ad_requested() -> void:
	if not _session().can_use_extra_bullet_ad():
		return
	if not _ads().can_show_rewarded_ad("extra_bullet"):
		return
	_ads().show_rewarded_ad("extra_bullet")

func _on_gun_impacted(impulse: float) -> void:
	_camera.on_impact(impulse)

func _on_end_reward_ad_requested() -> void:
	if not GameRunFlowScript.can_request_end_bonus(_run_ended, _end_bonus_claimed, _end_bonus_request_in_progress):
		return
	var can_show_ad: bool = _ads().can_show_rewarded_ad("end_bonus")
	if not can_show_ad:
		var unavailable_state := GameRunFlowScript.end_bonus_button_state_for_availability(false)
		_hud.set_end_reward_ad_enabled(unavailable_state.enabled, unavailable_state.text)
		return
	_end_bonus_request_in_progress = true
	var loading_state := GameRunFlowScript.end_bonus_loading_state()
	_hud.set_end_reward_ad_enabled(loading_state.enabled, loading_state.text)
	_ads().show_rewarded_ad("end_bonus")

func _on_rewarded_ad_completed(ad_type: String, granted: bool) -> void:
	_refresh_ad_debug()
	if ad_type == "end_bonus":
		_end_bonus_request_in_progress = false
	if not granted:
		if ad_type == "end_bonus" and _run_ended and not _end_bonus_claimed:
			var can_retry: bool = _ads().can_show_rewarded_ad("end_bonus")
			var retry_state := GameRunFlowScript.end_bonus_button_state_for_availability(can_retry)
			_hud.set_end_reward_ad_enabled(retry_state.enabled, retry_state.text)
		return
	if ad_type == "extra_bullet":
		_session().mark_extra_bullet_ad_used()
		_gun.restore_bullet_from_headshot()
		_hud.show_extra_bullet_prompt(false)
		return
	if ad_type == "end_bonus" and _run_ended:
		if _end_bonus_claimed:
			return
		_end_bonus_claimed = true
		var claimed_state := GameRunFlowScript.end_bonus_claimed_state()
		_hud.set_end_reward_ad_enabled(claimed_state.enabled, claimed_state.text)
		_score = GameRunFlowScript.apply_end_bonus(_score)
		_hud.refresh_end_panel_score(_score)
		var level_id := _current_level_id()
		HighScoreServiceScript.update_high_score(level_id, _score)

func _end_run(cleared_level: bool) -> void:
	if _run_ended:
		return
	_run_ended = true
	_end_bonus_claimed = false
	_end_bonus_request_in_progress = false
	Engine.time_scale = 1.0
	_hud.show_extra_bullet_prompt(false)
	_update_runtime_score()
	var level_id := _current_level_id()
	var is_new_high: bool = HighScoreServiceScript.update_high_score(level_id, _score)
	var high_score: int = HighScoreServiceScript.load_high_score_by_level_id(level_id)
	_hud.show_end_panel(cleared_level, _score, high_score, is_new_high)
	var can_claim_end_bonus: bool = _ads().can_show_rewarded_ad("end_bonus")
	var initial_state := GameRunFlowScript.end_bonus_button_state_for_availability(can_claim_end_bonus)
	_hud.set_end_reward_ad_enabled(initial_state.enabled, initial_state.text)

func _on_restart_requested() -> void:
	_hud.show_extra_bullet_prompt(false)
	get_tree().reload_current_scene()

func _on_level_select_requested() -> void:
	_hud.show_extra_bullet_prompt(false)
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

func _on_menu_requested() -> void:
	_hud.show_extra_bullet_prompt(false)
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MENU_SCENE)

func _refresh_ad_debug() -> void:
	_hud.update_ad_debug(
		_ads().active_provider_name(),
		_ads().can_show_rewarded_ad("extra_bullet"),
		_ads().can_show_rewarded_ad("end_bonus")
	)

func _update_slow_time_scaling(delta: float) -> void:
	if not _slow_time_active:
		_slow_effectiveness = move_toward(_slow_effectiveness, 0.0, SLOW_TIME_EFFECT_SMOOTHING * delta)
		return
	var move_speed_norm: float = clamp(_gun.get_motion_speed() / SLOW_TIME_MOVE_SPEED_FOR_MAX, 0.0, 1.0)
	var rot_speed_norm: float = clamp(_gun.get_rotation_speed() / SLOW_TIME_ROT_SPEED_FOR_MAX, 0.0, 1.0)
	var target_effect := SlowTimeMathScript.target_effect(move_speed_norm, rot_speed_norm)
	_slow_effectiveness = SlowTimeMathScript.smoothed_effect(_slow_effectiveness, target_effect, SLOW_TIME_EFFECT_SMOOTHING, delta)
	Engine.time_scale = SlowTimeMathScript.time_scale(SLOW_TIME_BASE_SCALE, SLOW_TIME_BEST_SCALE, _slow_effectiveness)
