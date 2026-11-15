extends Control

## Маршрутизатор стартового меню, редактора и обычного прохождения.
## Оба вида прохождения используют одну GameSession и один игровой экран.
const MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")
const EDITOR_SCENE: PackedScene = preload("res://scenes/editor.tscn")

var _active_screen: Control


func _ready() -> void:
	_open_menu()


func _show_screen(screen: Control) -> void:
	if _active_screen != null:
		remove_child(_active_screen)
		_active_screen.queue_free()
	_active_screen = screen
	add_child(screen)


func _open_menu() -> void:
	var screen := MENU_SCENE.instantiate() as MainMenu
	screen.editor_requested.connect(_open_editor)
	screen.game_requested.connect(_open_game)
	_show_screen(screen)


func _open_editor() -> void:
	var editor := EDITOR_SCENE.instantiate() as Control
	editor.connect("menu_requested", _open_menu)
	_show_screen(editor)


func _open_game(data: DungeonMap, hero_id: String) -> void:
	var game := EDITOR_SCENE.instantiate() as Control
	game.call("configure_for_game", data, hero_id)
	game.connect("menu_requested", _open_menu)
	_show_screen(game)
