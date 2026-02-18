extends CanvasLayer
class_name Hud

const HudTextsScript = preload("res://scripts/core/ui/hud_texts.gd")

signal fire_pressed
signal slow_time_changed(active: bool)
signal extra_bullet_ad_requested
signal end_reward_ad_requested
signal restart_requested
signal level_select_requested
signal menu_requested

@onready var _score_label: Label = $Root/TopBar/ScoreLabel
@onready var _ammo_label: Label = $Root/TopBar/AmmoLabel
@onready var _mode_label: Label = $Root/TopBar/ModeLabel
@onready var _left_zone: Control = $Root/Controls/LeftZone
@onready var _right_zone: Control = $Root/Controls/RightZone
@onready var _extra_bullet_prompt: Panel = $Root/ExtraBulletPrompt
@onready var _extra_bullet_button: Button = $Root/ExtraBulletPrompt/VBoxContainer/WatchAdButton
@onready var _extra_bullet_restart_button: Button = $Root/ExtraBulletPrompt/VBoxContainer/RestartButton
@onready var _extra_bullet_level_select_button: Button = $Root/ExtraBulletPrompt/VBoxContainer/LevelSelectButton
@onready var _extra_bullet_menu_button: Button = $Root/ExtraBulletPrompt/VBoxContainer/MainMenuButton
@onready var _end_panel: Panel = $Root/EndPanel
@onready var _end_title: Label = $Root/EndPanel/VBoxContainer/Title
@onready var _end_score: Label = $Root/EndPanel/VBoxContainer/Score
@onready var _end_high_score: Label = $Root/EndPanel/VBoxContainer/HighScore
@onready var _end_reward_button: Button = $Root/EndPanel/VBoxContainer/RewardAdButton
@onready var _restart_button: Button = $Root/EndPanel/VBoxContainer/RestartButton
@onready var _menu_button: Button = $Root/EndPanel/VBoxContainer/MenuButton
@onready var _ad_debug_label: Label = $Root/AdDebugPanel/VBoxContainer/AdDebugLabel
@onready var _ad_debug_panel: Panel = $Root/AdDebugPanel
@onready var _debug_toast_panel: Panel = $Root/DebugToast
@onready var _debug_toast_label: Label = $Root/DebugToast/MarginContainer/ToastLabel

var _toast_sequence: int = 0
var _toast_fade_tween: Tween

func _ready() -> void:
	_left_zone.gui_input.connect(_on_left_zone_input)
	_right_zone.gui_input.connect(_on_right_zone_input)
	_extra_bullet_button.pressed.connect(_on_extra_bullet_pressed)
	_extra_bullet_restart_button.pressed.connect(_on_restart_pressed)
	_extra_bullet_level_select_button.pressed.connect(_on_level_select_pressed)
	_extra_bullet_menu_button.pressed.connect(_on_menu_pressed)
	_end_reward_button.pressed.connect(_on_end_reward_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_extra_bullet_prompt.visible = false
	_end_panel.visible = false
	_debug_toast_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire"):
		fire_pressed.emit()
	if event.is_action_pressed("slow_time"):
		slow_time_changed.emit(true)
	if event.is_action_released("slow_time"):
		slow_time_changed.emit(false)

func set_mode_text(text: String) -> void:
	_mode_label.text = text

func update_score(score: int) -> void:
	_score_label.text = HudTextsScript.score_text(score)

func update_ammo(current: int, max_ammo: int) -> void:
	_ammo_label.text = HudTextsScript.ammo_text(current, max_ammo)

func show_extra_bullet_prompt(prompt_visible: bool) -> void:
	_extra_bullet_prompt.visible = prompt_visible
	if prompt_visible:
		_end_panel.visible = false

func set_extra_bullet_ad_enabled(enabled: bool) -> void:
	_extra_bullet_button.disabled = not enabled
	_extra_bullet_button.text = HudTextsScript.extra_bullet_button_text(enabled)

func is_extra_bullet_prompt_visible() -> bool:
	return _extra_bullet_prompt.visible

func show_end_panel(cleared: bool, score: int, high_score: int, is_new_high: bool) -> void:
	_extra_bullet_prompt.visible = false
	_end_panel.visible = true
	_end_title.text = HudTextsScript.end_title_text(cleared)
	_end_score.text = HudTextsScript.score_text(score)
	_end_high_score.text = HudTextsScript.high_score_text(high_score, is_new_high)
	set_end_reward_ad_enabled(true)

func refresh_end_panel_score(score: int) -> void:
	_end_score.text = HudTextsScript.score_text(score)

func set_end_reward_ad_enabled(enabled: bool, button_text: String = "Watch Ad: +25% Reward") -> void:
	_end_reward_button.disabled = not enabled
	_end_reward_button.text = button_text

func update_ad_debug(provider_name: String, can_extra_bullet: bool, can_end_bonus: bool) -> void:
	_ad_debug_label.text = HudTextsScript.ad_debug_text(provider_name, can_extra_bullet, can_end_bonus)

func set_ad_debug_visible(debug_visible: bool) -> void:
	_ad_debug_panel.visible = debug_visible

func show_debug_toggle_toast(debug_enabled: bool) -> void:
	_toast_sequence += 1
	var sequence: int = _toast_sequence
	_debug_toast_label.text = "Debug ON" if debug_enabled else "Debug OFF"
	_debug_toast_panel.self_modulate = Color(0.18, 0.45, 0.22, 1.0) if debug_enabled else Color(0.28, 0.28, 0.3, 1.0)
	_debug_toast_label.self_modulate = Color(0.85, 1.0, 0.85, 1.0) if debug_enabled else Color(0.9, 0.9, 0.92, 1.0)
	if _toast_fade_tween:
		_toast_fade_tween.kill()
	_debug_toast_panel.modulate.a = 1.0
	_debug_toast_panel.visible = true
	_toast_fade_tween = create_tween()
	_toast_fade_tween.tween_property(_debug_toast_panel, "modulate:a", 0.0, 1.0)
	await _toast_fade_tween.finished
	if sequence == _toast_sequence:
		_debug_toast_panel.visible = false
		_debug_toast_panel.modulate.a = 1.0

func _on_left_zone_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		slow_time_changed.emit(event.pressed)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		slow_time_changed.emit(event.pressed)

func _on_right_zone_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		fire_pressed.emit()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		fire_pressed.emit()

func _on_extra_bullet_pressed() -> void:
	extra_bullet_ad_requested.emit()

func _on_end_reward_pressed() -> void:
	end_reward_ad_requested.emit()

func _on_restart_pressed() -> void:
	restart_requested.emit()

func _on_level_select_pressed() -> void:
	level_select_requested.emit()

func _on_menu_pressed() -> void:
	menu_requested.emit()
