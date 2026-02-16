extends Control

const GAME_SCENE := "res://scenes/main/game.tscn"
const WORLD_SELECT_SCENE := "res://scenes/ui/world_select.tscn"

@onready var _skin_label: Label = $CenterContainer/Panel/VBoxContainer/SkinLabel

func _session() -> Node:
	return get_node("/root/GameSession")

func _ready() -> void:
	$CenterContainer/Panel/VBoxContainer/StartLevelButton.pressed.connect(_on_start_level)
	$CenterContainer/Panel/VBoxContainer/StartEndlessButton.pressed.connect(_on_start_endless)
	$CenterContainer/Panel/VBoxContainer/CycleSkinButton.pressed.connect(_on_cycle_skin)
	$CenterContainer/Panel/VBoxContainer/QuitButton.pressed.connect(_on_quit)
	get_node("/root/AdService").show_banner_ad("menu_bottom")
	_refresh_skin_text()

func _on_start_level() -> void:
	get_node("/root/AdService").hide_banner_ad()
	get_tree().change_scene_to_file(WORLD_SELECT_SCENE)

func _on_start_endless() -> void:
	get_node("/root/AdService").hide_banner_ad()
	_session().start_endless()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_cycle_skin() -> void:
	_session().cycle_skin()
	_refresh_skin_text()

func _on_quit() -> void:
	get_tree().quit()

func _refresh_skin_text() -> void:
	_skin_label.text = "Skin: %d" % (_session().selected_skin_index + 1)
