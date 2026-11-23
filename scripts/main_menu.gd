class_name MainMenu
extends Control

signal editor_requested
signal game_requested(data: DungeonMap, hero_id: String)
signal continue_game_requested(session: GameSession)

@onready var _card: PanelContainer = %Card
@onready var _home: VBoxContainer = %HomeActions
@onready var _library: VBoxContainer = %Library
@onready var _map_list: ItemList = %MapList
@onready var _no_maps: Label = %NoMaps
@onready var _error_message: Label = %ErrorMessage
@onready var _start_button: Button = %StartButton
@onready var _hero_selection: HeroSelection = %HeroSelection
@onready var _continue_game_button: Button = %ContinueGameButton
@onready var _home_error: Label = %HomeError
var _selected_game_map: DungeonMap
var _save_store: ProgressSaveStore = ProgressSaveStore.new()
var _maps_directory: String = SavedMapLibrary.DIRECTORY
var _maps_by_id: Dictionary = {}

var _maps: Array[DungeonMap] = []
var _thumbnails: Array[Texture2D] = []


func _ready() -> void:
	%PlayButton.pressed.connect(_open_library)
	_continue_game_button.pressed.connect(_continue_saved_game)
	%EditorButton.pressed.connect(func() -> void: editor_requested.emit())
	%BackButton.pressed.connect(_back_to_home)
	_start_button.pressed.connect(_start_selected)
	_map_list.item_selected.connect(_on_map_selected)
	_map_list.item_activated.connect(_on_map_activated)
	_hero_selection.character_chosen.connect(_launch_selected_character)
	_hero_selection.back_requested.connect(_return_to_library)
	get_viewport().size_changed.connect(_resize_layout)
	_resize_layout()
	_refresh_continue_action()
	if _continue_game_button.visible:
		_continue_game_button.grab_focus()
	else:
		%PlayButton.grab_focus()


func _resize_layout() -> void:
	var available: Vector2 = get_viewport_rect().size
	_card.custom_minimum_size.x = minf(780.0, maxf(260.0, available.x - 48.0))
	_map_list.custom_minimum_size.y = clampf(available.y * 0.41, 120.0, 320.0)
	_map_list.max_columns = clampi(floori((_card.custom_minimum_size.x - 48.0) / 215.0), 1, 3)


func _open_library() -> void:
	_home_error.hide()
	_home.visible = false
	_library.visible = true
	_hero_selection.visible = false
	_error_message.visible = false
	_load_saved_maps()
	_resize_layout()
	if _start_button.disabled:
		%BackButton.grab_focus()
	else:
		_start_button.grab_focus()


func _back_to_home() -> void:
	_hero_selection.visible = false
	_selected_game_map = null
	_library.visible = false
	_home.visible = true
	_refresh_continue_action()
	if _continue_game_button.visible:
		_continue_game_button.grab_focus()
	else:
		%PlayButton.grab_focus()


func _refresh_continue_action() -> void:
	_maps_by_id = SavedMapLibrary.load_all(_maps_directory)
	_continue_game_button.visible = _save_store.has_valid_save(_maps_by_id)


func _continue_saved_game() -> void:
	_home_error.hide()
	_maps_by_id = SavedMapLibrary.load_all(_maps_directory)
	var session: GameSession = _save_store.load_game(_maps_by_id)
	if session == null:
		_home_error.text = _save_store.last_error
		_home_error.show()
		_refresh_continue_action()
		%PlayButton.grab_focus()
		return
	continue_game_requested.emit(session)


func _load_saved_maps() -> void:
	_maps.clear()
	_thumbnails.clear()
	_map_list.clear()
	_maps_by_id = SavedMapLibrary.load_all(_maps_directory)
	for map_id in _maps_by_id:
		var data: DungeonMap = _maps_by_id[map_id]
		_maps.append(data)
		var thumbnail: ImageTexture = MapPreview.make_preview(data)
		_thumbnails.append(thumbnail)
		_map_list.add_item("%s\n%d × %d" % [data.display_name, data.width, data.height], thumbnail)
		var index := _map_list.item_count - 1
		_map_list.set_item_tooltip(index, data.display_name)
	_no_maps.visible = _maps.is_empty()
	_start_button.disabled = _maps.is_empty()
	if not _maps.is_empty():
		_map_list.select(0)


func _on_map_selected(_index: int) -> void:
	_error_message.visible = false
	_start_button.disabled = _map_list.get_selected_items().is_empty()


func _on_map_activated(_index: int) -> void:
	_start_selected()


func _start_selected() -> void:
	var selection := _map_list.get_selected_items()
	if selection.is_empty():
		return
	var chosen: DungeonMap = _maps[selection[0]]
	if chosen.find_entity_position("player_spawn") == Vector2i(-1, -1):
		_error_message.text = "На карте не задана точка старта героя"
		_error_message.visible = true
		return
	_selected_game_map = chosen
	_library.visible = false
	_hero_selection.visible = true
	_hero_selection.focus_first()


func _return_to_library() -> void:
	_hero_selection.visible = false
	_library.visible = true
	_start_button.grab_focus()


func _launch_selected_character(hero_id: String) -> void:
	if _selected_game_map != null:
		game_requested.emit(_selected_game_map, hero_id)
