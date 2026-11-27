class_name MainMenu
extends Control

signal editor_requested
signal game_requested(data: DungeonMap, hero_ids: Array[String], campaign: CampaignDefinition)
signal continue_game_requested(session: GameSession)

@onready var _artwork: Node2D = $Artwork
@onready var _background: Sprite2D = $Artwork/Background
@onready var _veil: ColorRect = $Artwork/Veil
@onready var _ambience: Node2D = $Artwork/Ambience
@onready var _tunnel_fog: ColorRect = $Artwork/Ambience/TunnelFog
@onready var _safe_area: MarginContainer = $SafeArea
@onready var _title: Label = %Title
@onready var _card: PanelContainer = %Card
@onready var _home: VBoxContainer = %HomeActions
@onready var _play_actions: VBoxContainer = %PlayActions
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
const TUNNEL_FOG_BOUNDS := Rect2(0.49, 0.46, 0.34, 0.32)
const CAMPFIRE_ANCHOR := Vector2(0.44258, 0.72051)
const FIRE_ANCHORS := {
	"Campfire": CAMPFIRE_ANCHOR,
	"TorchLeft": Vector2(0.56400, 0.36663),
	"TorchRight": Vector2(0.80622, 0.34431),
	"TunnelTorchNear": Vector2(0.68062, 0.44633),
	"TunnelTorchFar": Vector2(0.71651, 0.47715),
	"Lantern": Vector2(0.11722, 0.47184)
}

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
	%PlayButton.pressed.connect(_open_play_menu)
	%CampaignButton.pressed.connect(func() -> void: _open_library(LIBRARY_CAMPAIGNS))
	%PlayBackButton.pressed.connect(_back_to_home)
	%PersonalMapsButton.pressed.connect(func() -> void: _open_library(LIBRARY_PERSONAL))
	_continue_game_button.pressed.connect(_continue_saved_game)
	%EditorButton.pressed.connect(func() -> void: editor_requested.emit())
	%BackButton.pressed.connect(_open_play_menu)
	_start_button.pressed.connect(_start_selected)
	_map_list.item_selected.connect(_on_map_selected)
	_map_list.item_activated.connect(_on_map_activated)
	_hero_selection.party_chosen.connect(_launch_selected_party)
	_hero_selection.back_requested.connect(_return_to_library)
	_hero_selection.visibility_changed.connect(_update_selection_screen)
	_update_selection_screen()
	get_viewport().size_changed.connect(_resize_layout)
	resized.connect(_resize_layout)
	_resize_layout()
	%PlayButton.grab_focus()


func _update_selection_screen() -> void:
	$SafeArea.visible = not _hero_selection.visible


func _resize_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	_layout_ambience()
	var available: Vector2 = size
	var side_menu: bool = (_home.visible or _play_actions.visible) and available.x >= 640.0 and available.aspect() >= 1.3
	var margin: int = _safe_area.get_theme_constant("margin_left")
	var right_margin: int = margin
	var card_width: float = minf(780.0, maxf(260.0, available.x - 48.0))
	var title_size: int = 28
	if side_menu:
		var artwork_width: float = _background.texture.get_width() * _artwork.scale.x
		card_width = clampf(artwork_width * 0.32, 284.0, 400.0)
		title_size = clampi(roundi(artwork_width * 0.026), 19, 28)
		var center_x: float = _artwork.position.x + artwork_width * 0.28
		right_margin = maxi(margin, roundi(available.x + margin - 2.0 * center_x))
	_safe_area.add_theme_constant_override("margin_right", right_margin)
	_title.add_theme_font_size_override("font_size", title_size)
	_card.custom_minimum_size.x = card_width
	_map_list.custom_minimum_size.y = clampf(available.y * 0.41, 120.0, 320.0)
	_map_list.max_columns = clampi(floori((_card.custom_minimum_size.x - 48.0) / 215.0), 1, 3)


func _layout_ambience() -> void:
	if not is_node_ready() or _background.texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var texture_size: Vector2 = _background.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fill_scale: float = maxf(size.x / texture_size.x, size.y / texture_size.y)
	var drawn_size: Vector2 = texture_size * fill_scale
	_artwork.scale = Vector2.ONE * fill_scale
	var offset: Vector2 = (size - drawn_size) * 0.5
	var lantern_anchor: Vector2 = FIRE_ANCHORS["Lantern"]
	var torch_anchor: Vector2 = FIRE_ANCHORS["TorchRight"]
	var safe_left: float = maxf(0.0, lantern_anchor.x - 0.025) * drawn_size.x
	var safe_right: float = minf(1.0, torch_anchor.x + 0.025) * drawn_size.x
	var min_offset: float = maxf(size.x - drawn_size.x, -safe_left)
	var max_offset: float = minf(0.0, size.x - safe_right)
	if min_offset <= max_offset:
		offset.x = clampf(offset.x, min_offset, max_offset)
	_artwork.position = offset
	_veil.size = texture_size
	_tunnel_fog.position = texture_size * TUNNEL_FOG_BOUNDS.position
	_tunnel_fog.size = texture_size * TUNNEL_FOG_BOUNDS.size
	for fire_name in FIRE_ANCHORS:
		var fire: FireEffect = _ambience.get_node(NodePath(str(fire_name))) as FireEffect
		var anchor: Vector2 = FIRE_ANCHORS[fire_name]
		fire.position = texture_size * anchor


func _open_library(mode: int = LIBRARY_CAMPAIGNS) -> void:
	_library_mode = mode
	_selected_game_map = null
	_selected_campaign_id = ""
	_library_title.text = "Выбор кампании" if mode == LIBRARY_CAMPAIGNS else "Свои карты"
	_no_maps.text = "Кампаний пока нет" if mode == LIBRARY_CAMPAIGNS else "Свободных карт пока нет"
	_home_error.hide()
	_home.visible = false
	_play_actions.hide()
	_library.visible = true
	_hero_selection.visible = false
	_error_message.visible = false
	_load_saved_maps()
	_resize_layout()
	if _start_button.disabled:
		%BackButton.grab_focus()
	else:
		_start_button.grab_focus()


func _open_play_menu() -> void:
	_home.hide()
	_library.hide()
	_hero_selection.hide()
	_selected_game_map = null
	_selected_campaign_id = ""
	_home_error.hide()
	_refresh_continue_action()
	_play_actions.show()
	_resize_layout()
	if _continue_game_button.visible:
		_continue_game_button.grab_focus()
	else:
		%CampaignButton.grab_focus()


func _back_to_home() -> void:
	_play_actions.hide()
	_home.show()
	_resize_layout()
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
		if _continue_game_button.visible:
			_continue_game_button.grab_focus()
		else:
			%CampaignButton.grab_focus()
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
			_map_list.add_item(campaign.display_name, thumbnail)
			var index: int = _map_list.item_count - 1
			_map_list.set_item_tooltip(index, campaign.display_name)
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
	_hero_selection.reset_selection()
	_hero_selection.focus_first()

func _return_to_library() -> void:
	_hero_selection.visible = false
	_library.visible = true
	_start_button.grab_focus()


func _launch_selected_party(hero_ids: Array[String]) -> void:
	if hero_ids.is_empty() or hero_ids.size() > GameSession.MAX_PARTY_SIZE:
		return
	var unique_ids: Dictionary = {}
	for hero_id in hero_ids:
		if not HeroCatalog.has(hero_id) or unique_ids.has(hero_id):
			return
		unique_ids[hero_id] = true
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
				game_requested.emit(dungeon, hero_ids.duplicate(), null)
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
	game_requested.emit(starting_map, hero_ids.duplicate(), campaign)


func _show_changed_selection(message: String) -> void:
	_hero_selection.visible = false
	_library.visible = true
	_load_saved_maps()
	_error_message.text = message
	_error_message.show()
