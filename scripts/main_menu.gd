class_name MainMenu
extends Control

signal editor_requested
signal game_requested(data: DungeonMap, hero_id: String, campaign: CampaignDefinition)
signal continue_game_requested(session: GameSession)

@onready var _card: PanelContainer = %Card
@onready var _home: VBoxContainer = %HomeActions
@onready var _library: VBoxContainer = %Library
@onready var _map_list: ItemList = %MapList
@onready var _library_title: Label = %LibraryTitle
@onready var _no_maps: Label = %NoMaps
@onready var _error_message: Label = %ErrorMessage
@onready var _start_button: Button = %StartButton
@onready var _hero_selection: HeroSelection = %HeroSelection
@onready var _continue_game_button: Button = %ContinueGameButton
@onready var _home_error: Label = %HomeError
const LIBRARY_CAMPAIGNS := 0
const LIBRARY_PERSONAL := 1

var _library_mode: int = LIBRARY_CAMPAIGNS
var _personal_maps: Array[DungeonMap] = []
var _selected_game_map: DungeonMap
var _selected_campaign_id: String = ""
var _campaign_library: CampaignLibrary = CampaignLibrary.new()
var _campaigns: Array[CampaignDefinition] = []
var _save_store: ProgressSaveStore = ProgressSaveStore.new()
var _maps_directory: String = SavedMapLibrary.DIRECTORY
var _maps_by_id: Dictionary = {}

var _thumbnails: Array[Texture2D] = []


func _ready() -> void:
	%PlayButton.pressed.connect(func() -> void: _open_library(LIBRARY_CAMPAIGNS))
	%PersonalMapsButton.pressed.connect(func() -> void: _open_library(LIBRARY_PERSONAL))
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


func _open_library(mode: int = LIBRARY_CAMPAIGNS) -> void:
	_library_mode = mode
	_selected_game_map = null
	_selected_campaign_id = ""
	_library_title.text = "Выбор кампании" if mode == LIBRARY_CAMPAIGNS else "Свои карты"
	_no_maps.text = "Кампаний пока нет" if mode == LIBRARY_CAMPAIGNS else "Свободных карт пока нет"
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
	_selected_campaign_id = ""
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
	_campaigns.clear()
	_personal_maps.clear()
	_thumbnails.clear()
	_map_list.clear()
	_maps_by_id = SavedMapLibrary.load_all(_maps_directory)
	var campaigns: Dictionary = _campaign_library.load_all(_maps_by_id)
	if not _campaign_library.last_error.is_empty():
		_error_message.text = _campaign_library.last_error
		_error_message.show()
	if _library_mode == LIBRARY_CAMPAIGNS:
		var ids: Array = campaigns.keys()
		ids.sort()
		for campaign_id in ids:
			var campaign: CampaignDefinition = campaigns[campaign_id]
			var start_map: DungeonMap = _maps_by_id.get(campaign.start_map_id) as DungeonMap
			if start_map == null:
				continue
			_campaigns.append(campaign)
			var thumbnail: ImageTexture = MapPreview.make_preview(start_map)
			_thumbnails.append(thumbnail)
			_map_list.add_item("%s\nСтарт: %s" % [campaign.display_name, start_map.display_name], thumbnail)
			var index: int = _map_list.item_count - 1
			_map_list.set_item_tooltip(index, "%s\n%s" % [campaign.display_name, start_map.display_name])
	else:
		_personal_maps = unassigned_maps(_maps_by_id, campaigns)
		for dungeon in _personal_maps:
			var personal_thumbnail: ImageTexture = MapPreview.make_preview(dungeon)
			_thumbnails.append(personal_thumbnail)
			_map_list.add_item(dungeon.display_name, personal_thumbnail)
			_map_list.set_item_tooltip(_map_list.item_count - 1, dungeon.display_name)
	var has_entries: bool = not _campaigns.is_empty() if _library_mode == LIBRARY_CAMPAIGNS else not _personal_maps.is_empty()
	_no_maps.visible = not has_entries and _campaign_library.last_error.is_empty()
	_start_button.disabled = not has_entries or not _campaign_library.last_error.is_empty()
	if not _start_button.disabled:
		_map_list.select(0)


static func unassigned_maps(maps_by_id: Dictionary, campaigns: Dictionary) -> Array[DungeonMap]:
	var assigned: Dictionary = {}
	for campaign in campaigns.values():
		if not (campaign is CampaignDefinition):
			continue
		for member_id in campaign.map_ids:
			assigned[member_id] = true
	var result: Array[DungeonMap] = []
	var ids: Array = maps_by_id.keys()
	ids.sort()
	for map_id in ids:
		var dungeon: DungeonMap = maps_by_id[map_id] as DungeonMap
		if dungeon != null and not assigned.has(map_id):
			result.append(dungeon)
	return result

func _on_map_selected(_index: int) -> void:
	_error_message.visible = false
	_start_button.disabled = _map_list.get_selected_items().is_empty()


func _on_map_activated(_index: int) -> void:
	_start_selected()


func _start_selected() -> void:
	var selection: PackedInt32Array = _map_list.get_selected_items()
	if selection.is_empty():
		return
	_maps_by_id = SavedMapLibrary.load_all(_maps_directory)
	var campaigns: Dictionary = _campaign_library.load_all(_maps_by_id)
	if not _campaign_library.last_error.is_empty():
		_error_message.text = _campaign_library.last_error
		_error_message.show()
		return
	var chosen: DungeonMap
	var selected_campaign_id: String = ""
	if _library_mode == LIBRARY_CAMPAIGNS:
		if selection[0] >= _campaigns.size():
			return
		selected_campaign_id = _campaigns[selection[0]].campaign_id
		var campaign: CampaignDefinition = campaigns.get(selected_campaign_id) as CampaignDefinition
		if campaign != null:
			chosen = _maps_by_id.get(campaign.start_map_id) as DungeonMap
	else:
		if selection[0] >= _personal_maps.size():
			return
		var selected_id: String = _personal_maps[selection[0]].map_id
		for dungeon in unassigned_maps(_maps_by_id, campaigns):
			if dungeon.map_id == selected_id:
				chosen = dungeon
				break
	if chosen == null:
		_error_message.text = "Карта больше недоступна для выбранного режима"
		_error_message.show()
		return
	if chosen.find_entity_position("player_spawn") == Vector2i(-1, -1):
		_error_message.text = "На выбранной карте не задана точка старта героя"
		_error_message.show()
		return
	_selected_game_map = chosen
	_selected_campaign_id = selected_campaign_id
	_library.visible = false
	_hero_selection.visible = true
	_hero_selection.focus_first()

func _return_to_library() -> void:
	_hero_selection.visible = false
	_library.visible = true
	_start_button.grab_focus()


func _launch_selected_character(hero_id: String) -> void:
	if _selected_game_map == null:
		return
	_maps_by_id = SavedMapLibrary.load_all(_maps_directory)
	var campaigns: Dictionary = _campaign_library.load_all(_maps_by_id)
	if not _campaign_library.last_error.is_empty():
		_show_changed_selection(_campaign_library.last_error)
		return
	if _selected_campaign_id.is_empty():
		for dungeon in unassigned_maps(_maps_by_id, campaigns):
			if dungeon.map_id == _selected_game_map.map_id and dungeon.find_entity_position("player_spawn") != Vector2i(-1, -1):
				game_requested.emit(dungeon, hero_id, null)
				return
		_show_changed_selection("Карта больше не доступна в разделе «Свои карты». Выбери её заново.")
		return
	var campaign: CampaignDefinition = campaigns.get(_selected_campaign_id) as CampaignDefinition
	if campaign == null or campaign.start_map_id != _selected_game_map.map_id:
		_show_changed_selection("Стартовая карта кампании изменилась. Выбери приключение заново.")
		return
	var starting_map: DungeonMap = _maps_by_id.get(campaign.start_map_id) as DungeonMap
	if starting_map == null or starting_map.find_entity_position("player_spawn") == Vector2i(-1, -1):
		_show_changed_selection("Стартовая карта кампании недоступна.")
		return
	game_requested.emit(starting_map, hero_id, campaign)


func _show_changed_selection(message: String) -> void:
	_hero_selection.visible = false
	_library.visible = true
	_load_saved_maps()
	_error_message.text = message
	_error_message.show()
