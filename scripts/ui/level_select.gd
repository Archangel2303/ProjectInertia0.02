extends Control

const GAME_SCENE := "res://scenes/main/game.tscn"
const WORLD_SELECT_SCENE := "res://scenes/ui/world_select.tscn"
const MAX_LEVELS := 14

func _session() -> Node:
	return get_node("/root/GameSession")

func _ready() -> void:
	_setup_level_buttons()
	$CenterContainer/Panel/VBoxContainer/BackButton.pressed.connect(_on_back)

func _setup_level_buttons() -> void:
	var vbox: VBoxContainer = $CenterContainer/Panel/VBoxContainer
	var template_button: Button = vbox.get_node("Level1Button") as Button
	var back_button: Button = vbox.get_node("BackButton") as Button
	template_button.text = "Level 1"
	template_button.pressed.connect(_on_level_selected.bind(0))
	for level_number in range(2, MAX_LEVELS + 1):
		var level_button := template_button.duplicate() as Button
		level_button.name = "Level%dButton" % level_number
		level_button.text = "Level %d" % level_number
		level_button.pressed.connect(_on_level_selected.bind(level_number - 1))
		vbox.add_child(level_button)
		vbox.move_child(level_button, back_button.get_index())

func _on_level_selected(level_index: int) -> void:
	_session().start_level(level_index)
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(WORLD_SELECT_SCENE)
