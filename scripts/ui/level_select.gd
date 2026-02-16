extends Control

const GAME_SCENE := "res://scenes/main/game.tscn"
const WORLD_SELECT_SCENE := "res://scenes/ui/world_select.tscn"

func _session() -> Node:
	return get_node("/root/GameSession")

func _ready() -> void:
	$CenterContainer/Panel/VBoxContainer/Level1Button.pressed.connect(_on_level_1)
	$CenterContainer/Panel/VBoxContainer/BackButton.pressed.connect(_on_back)

func _on_level_1() -> void:
	_session().start_level(0)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(WORLD_SELECT_SCENE)
