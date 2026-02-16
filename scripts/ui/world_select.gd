extends Control

const LEVEL_SELECT_SCENE := "res://scenes/ui/level_select.tscn"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

func _ready() -> void:
	$CenterContainer/Panel/VBoxContainer/World1Button.pressed.connect(_on_world_1)
	$CenterContainer/Panel/VBoxContainer/BackButton.pressed.connect(_on_back)

func _on_world_1() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
