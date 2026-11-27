class_name MainMenu
extends Control

signal transition_finished
signal editor_requested
signal game_requested(data: DungeonMap, hero_ids: Array[String], campaign: CampaignDefinition)
signal continue_game_requested(session: GameSession)

@onready var _curtain: ColorRect = $TransitionCurtain
@onready var _artwork: Node2D = $Artwork
@onready var _background: Sprite2D = $Artwork/Background
@onready var _veil: ColorRect = $Artwork/Veil
@onready var _ambience: Node2D = $Artwork/Ambience
@onready var _tunnel_fog: ColorRect = $Artwork/Ambience/TunnelFog
@onready var _campaign_artwork: Node2D = $CampaignArtwork
@onready var _campaign_background: Sprite2D = $CampaignArtwork/Background
@onready var _campaign_veil: ColorRect = $CampaignArtwork/Veil
@onready var _campaign_ambience: Node2D = $CampaignArtwork/Ambience
@onready var _campaign_tunnel_fog: ColorRect = $CampaignArtwork/Ambience/TunnelFog
@onready var _safe_area: MarginContainer = $SafeArea
@onready var _logo: TextureRect = %Logo
@onready var _card: PanelContainer = %Card
@onready var _home: VBoxContainer = %HomeActions
@onready var _play_actions: VBoxContainer = %PlayActions
@onready var _library: VBoxContainer = %Library
@onready var _library_title: Label = %LibraryTitle
@onready var _library_layout: BoxContainer = %LibraryBody
@onready var _entry_list_title: Label = %EntryListTitle
@onready var _entry_scroll: ScrollContainer = %EntryScroll
@onready var _entry_list: VBoxContainer = %EntryList
@onready var _preview_title: Label = %PreviewTitle
@onready var _preview_frame: PanelContainer = %PreviewFrame
@onready var _preview_image: TextureRect = %PreviewImage
@onready var _preview_name: Label = %PreviewName
@onready var _preview_meta: Label = %PreviewMeta
@onready var _no_maps: Label = %NoMaps
@onready var _error_message: Label = %ErrorMessage
@onready var _start_button: Button = %StartButton
@onready var _hero_selection: HeroSelection = %HeroSelection
@onready var _continue_game_button: Button = %ContinueGameButton
@onready var _home_error: Label = %HomeError
const INTRO_FADE_SECONDS := 1.1
const INTRO_MUSIC_FADE_SECONDS := INTRO_FADE_SECONDS * 2.0
const SCREEN_FADE_SECONDS := 0.45
const ASH_SECONDS := 0.44
const ASH_STAGGER := 0.04
const LIBRARY_CAMPAIGNS := 0
const LIBRARY_PERSONAL := 1
const DEFAULT_CAMPAIGN_COVER: Texture2D = preload("res://assets/campaigns/default_cover.png")
const CAMPAIGN_COVER_DIRECTORY := "res://assets/campaigns/"
const TUNNEL_FOG_BOUNDS := Rect2(0.49, 0.46, 0.34, 0.32)
const CAMPAIGN_TUNNEL_FOG_BOUNDS := Rect2(0.38, 0.25, 0.25, 0.58)
const CAMPFIRE_ANCHOR := Vector2(0.44258, 0.72051)
const FIRE_ANCHORS := {
	"Campfire": CAMPFIRE_ANCHOR,
	"TorchLeft": Vector2(0.56400, 0.36663),
	"TorchRight": Vector2(0.80622, 0.34431),
	"TunnelTorchNear": Vector2(0.68062, 0.44633),
	"TunnelTorchFar": Vector2(0.71651, 0.47715),
	"Lantern": Vector2(0.11722, 0.47184)
}


const CAMPAIGN_FIRE_ANCHORS := {
	"TorchFrontLeft": Vector2(0.33074, 0.38257),
	"TorchFrontRight": Vector2(0.66806, 0.38257),
	"TorchMidLeftA": Vector2(0.40431, 0.46121),
	"TorchMidRightA": Vector2(0.59330, 0.46121),
	"TorchMidLeftB": Vector2(0.46172, 0.53454),
	"TorchMidRightB": Vector2(0.53408, 0.53454),
	"TorchDeepLeft": Vector2(0.48983, 0.58874),
	"TorchDeepRight": Vector2(0.51017, 0.58874)
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

var _library_covers: Array[Texture2D] = []
var _library_entries: Array[Button] = []
var _selected_library_index: int = -1
var _entry_group: ButtonGroup = ButtonGroup.new()
var _panel_style := StyleBoxFlat.new()
var _menu_style := StyleBoxEmpty.new()
var _preview_style := StyleBoxFlat.new()
var _entry_style := StyleBoxFlat.new()
var _entry_hover_style := StyleBoxFlat.new()
var _entry_selected_style := StyleBoxFlat.new()
var _entry_focus_style := StyleBoxFlat.new()
var _audio_dialog: AcceptDialog
var _transitioning := false


func _ready() -> void:
	%PlayButton.pressed.connect(_animate_play_menu)
	%AudioSettingsButton.pressed.connect(_open_audio_settings)
	_build_audio_settings()
	%CampaignButton.pressed.connect(func() -> void: _animate_library(LIBRARY_CAMPAIGNS))
	%PlayBackButton.pressed.connect(_animate_home_menu)
	%PersonalMapsButton.pressed.connect(func() -> void: _animate_library(LIBRARY_PERSONAL))
	_continue_game_button.pressed.connect(_continue_saved_game)
	%EditorButton.pressed.connect(_request_editor)
	%BackButton.pressed.connect(_animate_library_back)
	_start_button.pressed.connect(_start_selected)
	_entry_group.allow_unpress = false
	_hero_selection.party_chosen.connect(_launch_selected_party)
	_hero_selection.back_requested.connect(_return_to_library)
	_hero_selection.visibility_changed.connect(_update_selection_screen)
	_setup_card_styles()
	_configure_library_widgets()
	_update_selection_screen()
	get_viewport().size_changed.connect(_resize_layout)
	resized.connect(_resize_layout)
	_resize_layout()
	%PlayButton.grab_focus()
	_intro_fade()


func _input(_event: InputEvent) -> void:
	if _transitioning and is_visible_in_tree():
		get_viewport().set_input_as_handled()


func _begin_transition(opacity: float) -> void:
	_transitioning = true
	_curtain.color.a = opacity
	_curtain.show()


func _end_transition() -> void:
	_curtain.hide()
	_transitioning = false
	transition_finished.emit()


func _fade_to(opacity: float, duration: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_curtain, "color:a", opacity, duration)
	await tween.finished


func _intro_fade() -> void:
	_begin_transition(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var audio: GameAudioManager = GameAudioManager.instance(get_tree())
	if audio != null:
		audio.play_music(GameAudioManager.MENU_MUSIC, INTRO_MUSIC_FADE_SECONDS, Tween.TRANS_SINE)
	await _fade_to(0.0, INTRO_FADE_SECONDS)
	_end_transition()


func _visible_stone_buttons(container: Control) -> Array[StoneMenuButton]:
	var buttons: Array[StoneMenuButton] = []
	for child in container.get_children():
		if child is StoneMenuButton and child.visible:
			buttons.append(child)
	return buttons


func _ash_phase(buttons: Array[StoneMenuButton], elapsed: float, reverse: bool) -> void:
	for index in range(buttons.size()):
		var phase: float = clampf((elapsed - index * ASH_STAGGER) / ASH_SECONDS, 0.0, 1.0)
		if reverse:
			phase = 1.0 - phase
		buttons[index].set_ash_phase(minf(phase / 0.64, 1.0), smoothstep(0.48, 1.0, phase))


func _animate_ash(buttons: Array[StoneMenuButton], reverse: bool) -> void:
	if buttons.is_empty():
		return
	var duration: float = ASH_SECONDS + (buttons.size() - 1) * ASH_STAGGER
	_ash_phase(buttons, 0.0, reverse)
	var tween := create_tween()
	tween.tween_method(func(elapsed: float) -> void: _ash_phase(buttons, elapsed, reverse), 0.0, duration, duration)
	await tween.finished


func _swap_action_menu(outgoing: VBoxContainer, incoming: VBoxContainer, change_page: Callable) -> void:
	_begin_transition(0.0)
	var old_buttons: Array[StoneMenuButton] = _visible_stone_buttons(outgoing)
	await _animate_ash(old_buttons, false)
	change_page.call()
	for button in old_buttons:
		button.set_ash_phase(0.0, 0.0)
	var new_buttons: Array[StoneMenuButton] = _visible_stone_buttons(incoming)
	_ash_phase(new_buttons, 0.0, true)
	await get_tree().process_frame
	await get_tree().process_frame
	await _animate_ash(new_buttons, true)
	_end_transition()


func _animate_play_menu() -> void:
	if _transitioning or not _home.visible:
		return
	await _swap_action_menu(_home, _play_actions, _open_play_menu)


func _animate_home_menu() -> void:
	if _transitioning or not _play_actions.visible:
		return
	await _swap_action_menu(_play_actions, _home, _back_to_home)


func _fade_page(change_page: Callable) -> void:
	_begin_transition(0.0)
	await _fade_to(1.0, SCREEN_FADE_SECONDS)
	change_page.call()
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, SCREEN_FADE_SECONDS)
	_end_transition()


func _animate_library(mode: int) -> void:
	if _transitioning or not _play_actions.visible:
		return
	await _fade_page(_open_library.bind(mode))


func _animate_library_back() -> void:
	if _transitioning or not _library.visible:
		return
	await _fade_page(_open_play_menu)


func _request_editor() -> void:
	if not _transitioning:
		editor_requested.emit()


func _build_audio_settings() -> void:
	_audio_dialog = AcceptDialog.new()
	_audio_dialog.name = "AudioSettingsDialog"
	_audio_dialog.title = "Настройки звука"
	_audio_dialog.ok_button_text = "Закрыть"
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_audio_dialog.add_child(scroll)
	var controls := AudioVolumeControls.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(controls)
	add_child(_audio_dialog)


func _open_audio_settings() -> void:
	if _transitioning:
		return
	_audio_dialog.popup_centered_clamped(Vector2i(360, 430), 0.94)


func _update_selection_screen() -> void:
	$SafeArea.visible = not _hero_selection.visible
	_apply_menu_chrome()
	_refresh_background_state()


func _setup_card_styles() -> void:
	_panel_style.bg_color = Color(0.090, 0.132, 0.18, 0.84)
	_panel_style.border_width_left = 2
	_panel_style.border_width_top = 2
	_panel_style.border_width_right = 2
	_panel_style.border_width_bottom = 2
	_panel_style.border_color = Color(0.67, 0.51, 0.29, 1)
	_panel_style.corner_radius_top_left = 12
	_panel_style.corner_radius_top_right = 12
	_panel_style.corner_radius_bottom_right = 12
	_panel_style.corner_radius_bottom_left = 12
	_panel_style.shadow_color = Color(0, 0, 0, 0.65)
	_panel_style.shadow_size = 16
	_preview_style.bg_color = Color(0.035, 0.05, 0.075, 0.72)
	_preview_style.border_width_left = 2
	_preview_style.border_width_top = 2
	_preview_style.border_width_right = 2
	_preview_style.border_width_bottom = 2
	_preview_style.border_color = Color(0.73, 0.62, 0.42, 0.88)
	_preview_style.corner_radius_top_left = 16
	_preview_style.corner_radius_top_right = 16
	_preview_style.corner_radius_bottom_right = 16
	_preview_style.corner_radius_bottom_left = 16
	_preview_style.shadow_color = Color(0, 0, 0, 0.42)
	_preview_style.shadow_size = 12
	_entry_style.bg_color = Color(0.04, 0.05, 0.07, 0.62)
	_entry_style.border_width_left = 1
	_entry_style.border_width_top = 1
	_entry_style.border_width_right = 1
	_entry_style.border_width_bottom = 1
	_entry_style.border_color = Color(0.32, 0.37, 0.42, 0.6)
	_entry_style.corner_radius_top_left = 18
	_entry_style.corner_radius_top_right = 18
	_entry_style.corner_radius_bottom_right = 18
	_entry_style.corner_radius_bottom_left = 18
	_entry_style.content_margin_left = 16
	_entry_style.content_margin_right = 16
	_entry_style.content_margin_top = 12
	_entry_style.content_margin_bottom = 12
	_entry_hover_style = _entry_style.duplicate()
	_entry_hover_style.bg_color = Color(0.085, 0.10, 0.13, 0.82)
	_entry_hover_style.border_color = Color(0.66, 0.56, 0.38, 0.75)
	_entry_selected_style = _entry_style.duplicate()
	_entry_selected_style.bg_color = Color(0.10, 0.12, 0.16, 0.92)
	_entry_selected_style.border_width_left = 2
	_entry_selected_style.border_width_top = 2
	_entry_selected_style.border_width_right = 2
	_entry_selected_style.border_width_bottom = 2
	_entry_selected_style.border_color = Color(0.79, 0.67, 0.44, 0.98)
	_entry_focus_style = _entry_selected_style.duplicate()
	_entry_focus_style.shadow_color = Color(0.93, 0.76, 0.35, 0.18)
	_entry_focus_style.shadow_size = 10


func _configure_library_widgets() -> void:
	_preview_frame.add_theme_stylebox_override("panel", _preview_style)
	_preview_image.texture = null
	_preview_name.text = ""
	_preview_meta.text = ""


func _apply_menu_chrome() -> void:
	if not is_node_ready():
		return
	var menu_mode: bool = _home.visible or _play_actions.visible
	_logo.visible = menu_mode
	_card.add_theme_stylebox_override("panel", _menu_style if menu_mode else _panel_style)


func _refresh_background_state() -> void:
	if not is_node_ready():
		return
	var use_campaign_artwork: bool = _library.visible and not _hero_selection.visible and _library_mode == LIBRARY_CAMPAIGNS
	_artwork.visible = not use_campaign_artwork
	_campaign_artwork.visible = use_campaign_artwork


func _resize_layout() -> void:
	if not is_node_ready() or size.x <= 0.0 or size.y <= 0.0:
		return
	_layout_ambience()
	var available: Vector2 = size
	var menu_mode: bool = _home.visible or _play_actions.visible
	var library_mode: bool = _library.visible and not _hero_selection.visible
	var side_menu: bool = menu_mode and available.x >= 640.0 and available.aspect() >= 1.3
	var margin: int = _safe_area.get_theme_constant("margin_left")
	var right_margin: int = margin
	var top_margin: int = 12
	var bottom_margin: int = 12
	var card_width: float = minf(780.0, maxf(260.0, available.x - 48.0))
	if library_mode:
		card_width = minf(1180.0, maxf(460.0, available.x - 72.0))
		top_margin = clampi(roundi(available.y * 0.045), 12, 34)
		bottom_margin = clampi(roundi(available.y * 0.04), 12, 30)
	elif menu_mode:
		card_width = minf(card_width, 560.0)
	if side_menu:
		var artwork_width: float = _background.texture.get_width() * _artwork.scale.x
		card_width = clampf(artwork_width * 0.37, 360.0, 560.0)
		var center_x: float = _artwork.position.x + artwork_width * 0.23
		right_margin = maxi(margin, roundi(available.x + margin - 2.0 * center_x))
	if menu_mode:
		bottom_margin = clampi(roundi(available.y * 0.13), 12, 140)
		var actions: VBoxContainer = _home if _home.visible else _play_actions
		var action_count: int = 0
		for child in actions.get_children():
			if child is Button and child.visible:
				action_count += 1
		var compact_width: float = maxf(284.0, available.y * 0.62 / maxf(1.0, float(action_count)) * StoneMenuButton.STONE.get_size().aspect() + 44.0)
		card_width = minf(card_width, compact_width)
		if side_menu:
			var desired_center: float = _artwork.position.x + _background.texture.get_width() * _artwork.scale.x * 0.23
			var safe_center: float = clampf(desired_center, margin + card_width * 0.5, available.x - margin - card_width * 0.5)
			right_margin = maxi(margin, roundi(available.x + margin - 2.0 * safe_center))
		var actions_height: float = action_count * clampf(ceilf((card_width - 44.0) / StoneMenuButton.STONE.get_size().aspect()), StoneMenuButton.MIN_TOUCH_HEIGHT, StoneMenuButton.MAX_HEIGHT) + maxi(0, action_count - 1) * actions.get_theme_constant("separation")
		bottom_margin = mini(bottom_margin, maxi(12, floori(available.y - actions_height - 125.0)))
	_safe_area.add_theme_constant_override("margin_top", top_margin)
	_safe_area.add_theme_constant_override("margin_bottom", bottom_margin)
	_safe_area.add_theme_constant_override("margin_right", right_margin)
	_card.custom_minimum_size.x = card_width
	var logo_aspect: float = _logo.texture.get_width() / _logo.texture.get_height() if _logo.texture != null and _logo.texture.get_height() > 0.0 else 1.5
	var logo_width: float = maxf(1.0, minf(card_width - 44.0, minf(card_width * 0.86, 520.0)))
	var logo_height: float = minf(logo_width / logo_aspect, 360.0)
	if menu_mode:
		var actions: VBoxContainer = _home if _home.visible else _play_actions
		var reserved: float = 57.0
		var count: int = 0
		for child in actions.get_children():
			if child is Control and child.visible:
				if child is StoneMenuButton:
					reserved += clampf(ceilf((card_width - 44.0) / StoneMenuButton.STONE.get_size().aspect()), StoneMenuButton.MIN_TOUCH_HEIGHT, StoneMenuButton.MAX_HEIGHT)
				else:
					reserved += child.get_combined_minimum_size().y
				count += 1
		reserved += maxi(0, count - 1) * actions.get_theme_constant("separation")
		logo_height = maxf(20.0, minf(logo_height, available.y - top_margin - bottom_margin - reserved))
	_logo.custom_minimum_size = Vector2(logo_width, logo_height)
	if library_mode:
		_library_layout.vertical = available.x < 1080.0 or available.aspect() < 1.28
		_entry_scroll.custom_minimum_size.y = clampf(available.y * (0.34 if _library_layout.vertical else 0.48), 180.0, 440.0)
		_preview_frame.custom_minimum_size.y = clampf(available.y * (0.34 if _library_layout.vertical else 0.56), 240.0, 580.0)


func _layout_ambience() -> void:
	_layout_artwork(_artwork, _background, _veil, _ambience, _tunnel_fog, TUNNEL_FOG_BOUNDS, FIRE_ANCHORS, true)
	_layout_artwork(_campaign_artwork, _campaign_background, _campaign_veil, _campaign_ambience, _campaign_tunnel_fog, CAMPAIGN_TUNNEL_FOG_BOUNDS, CAMPAIGN_FIRE_ANCHORS, false)


func _layout_artwork(artwork: Node2D, background: Sprite2D, veil: ColorRect, ambience: Node2D, tunnel_fog: ColorRect, fog_bounds: Rect2, fire_anchors: Dictionary, clamp_horizontal: bool) -> void:
	if not is_node_ready() or background.texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var texture_size: Vector2 = background.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fill_scale: float = maxf(size.x / texture_size.x, size.y / texture_size.y)
	var drawn_size: Vector2 = texture_size * fill_scale
	artwork.scale = Vector2.ONE * fill_scale
	var offset: Vector2 = (size - drawn_size) * 0.5
	if clamp_horizontal:
		var lantern_anchor: Vector2 = FIRE_ANCHORS["Lantern"]
		var torch_anchor: Vector2 = FIRE_ANCHORS["TorchRight"]
		var safe_left: float = maxf(0.0, lantern_anchor.x - 0.025) * drawn_size.x
		var safe_right: float = minf(1.0, torch_anchor.x + 0.025) * drawn_size.x
		var min_offset: float = maxf(size.x - drawn_size.x, -safe_left)
		var max_offset: float = minf(0.0, size.x - safe_right)
		if min_offset <= max_offset:
			offset.x = clampf(offset.x, min_offset, max_offset)
	artwork.position = offset
	veil.size = texture_size
	tunnel_fog.position = texture_size * fog_bounds.position
	tunnel_fog.size = texture_size * fog_bounds.size
	for fire_name in fire_anchors:
		var fire: FireEffect = ambience.get_node(NodePath(str(fire_name))) as FireEffect
		var anchor: Vector2 = fire_anchors[fire_name]
		fire.position = texture_size * anchor


func _open_library(mode: int = LIBRARY_CAMPAIGNS) -> void:
	_library_mode = mode
	_selected_game_map = null
	_selected_campaign_id = ""
	_selected_library_index = -1
	_library_title.text = "Выбор кампании" if mode == LIBRARY_CAMPAIGNS else "Свои карты"
	_entry_list_title.text = "Кампании" if mode == LIBRARY_CAMPAIGNS else "Свои карты"
	_preview_title.text = "Карта приключения" if mode == LIBRARY_CAMPAIGNS else "Карта подземелья"
	_no_maps.text = "Кампаний пока нет" if mode == LIBRARY_CAMPAIGNS else "Свободных карт пока нет"
	_start_button.text = "Начать приключение" if mode == LIBRARY_CAMPAIGNS else "Открыть карту"
	_home_error.hide()
	_home.visible = false
	_play_actions.hide()
	_library.visible = true
	_hero_selection.visible = false
	_error_message.visible = false
	_load_saved_maps()
	_apply_menu_chrome()
	_refresh_background_state()
	_resize_layout()
	if _start_button.disabled:
		%BackButton.grab_focus()
	elif not _library_entries.is_empty():
		_library_entries[0].grab_focus()
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
	_apply_menu_chrome()
	_refresh_background_state()
	_resize_layout()
	if _continue_game_button.visible:
		_continue_game_button.grab_focus()
	else:
		%CampaignButton.grab_focus()


func _back_to_home() -> void:
	_play_actions.hide()
	_home.show()
	_apply_menu_chrome()
	_refresh_background_state()
	_resize_layout()
	%PlayButton.grab_focus()


func _refresh_continue_action() -> void:
	_maps_by_id = SavedMapLibrary.load_for_game(_maps_directory)
	_continue_game_button.visible = _save_store.has_valid_save(_maps_by_id)


func _continue_saved_game() -> void:
	if _transitioning:
		return
	_home_error.hide()
	_maps_by_id = SavedMapLibrary.load_for_game(_maps_directory)
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
	_library_covers.clear()
	_selected_library_index = -1
	_clear_library_entries()
	_maps_by_id = SavedMapLibrary.load_for_game(_maps_directory)
	var campaigns: Dictionary = _campaign_library.load_for_game(_maps_by_id)
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
			_library_covers.append(campaign_cover(campaign))
	else:
		_personal_maps = unassigned_maps(_maps_by_id, campaigns)
		for _dungeon in _personal_maps:
			_library_covers.append(DEFAULT_CAMPAIGN_COVER)
	_build_library_entries()
	var has_entries: bool = not _campaigns.is_empty() if _library_mode == LIBRARY_CAMPAIGNS else not _personal_maps.is_empty()
	_no_maps.visible = not has_entries and _campaign_library.last_error.is_empty()
	_start_button.disabled = not has_entries or not _campaign_library.last_error.is_empty()
	if has_entries:
		_select_library_index(0)
	else:
		_update_library_preview()


static func campaign_cover(campaign: CampaignDefinition) -> Texture2D:
	if campaign == null or not OfficialCampaignLibrary.is_official_id(campaign.campaign_id):
		return DEFAULT_CAMPAIGN_COVER
	var path: String = campaign.cover_image
	if not path.begins_with(CAMPAIGN_COVER_DIRECTORY) or path.contains(".."):
		return DEFAULT_CAMPAIGN_COVER
	if ResourceLoader.exists(path, "Texture2D"):
		var cover: Texture2D = ResourceLoader.load(path, "Texture2D") as Texture2D
		if cover != null:
			return cover
	return DEFAULT_CAMPAIGN_COVER


func _clear_library_entries() -> void:
	for child in _entry_list.get_children():
		_entry_list.remove_child(child)
		child.queue_free()
	_library_entries.clear()


func _build_library_entries() -> void:
	_clear_library_entries()
	var count: int = _campaigns.size() if _library_mode == LIBRARY_CAMPAIGNS else _personal_maps.size()
	for index in range(count):
		var entry := Button.new()
		entry.toggle_mode = true
		entry.button_group = _entry_group
		entry.focus_mode = Control.FOCUS_ALL
		entry.custom_minimum_size = Vector2(0, 104)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		entry.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		entry.add_theme_constant_override("icon_max_width", 82)
		entry.clip_text = false
		entry.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		entry.add_theme_stylebox_override("normal", _entry_style)
		entry.add_theme_stylebox_override("hover", _entry_hover_style)
		entry.add_theme_stylebox_override("pressed", _entry_selected_style)
		entry.add_theme_stylebox_override("hover_pressed", _entry_selected_style)
		entry.add_theme_stylebox_override("focus", _entry_focus_style)
		entry.add_theme_color_override("font_color", Color(0.94, 0.94, 0.92, 1.0))
		entry.add_theme_color_override("font_hover_color", Color(0.99, 0.97, 0.92, 1.0))
		entry.add_theme_color_override("font_pressed_color", Color(0.99, 0.97, 0.92, 1.0))
		entry.add_theme_color_override("font_focus_color", Color(0.99, 0.97, 0.92, 1.0))
		entry.add_theme_font_size_override("font_size", 20)
		entry.add_theme_constant_override("h_separation", 14)
		entry.tooltip_text = _library_entry_title(index)
		entry.text = _library_entry_text(index)
		entry.icon = _library_covers[index] if index < _library_covers.size() else null
		entry.pressed.connect(_select_library_index.bind(index))
		entry.focus_entered.connect(_select_library_index.bind(index))
		_entry_list.add_child(entry)
		_library_entries.append(entry)


func _library_entry_title(index: int) -> String:
	if _library_mode == LIBRARY_CAMPAIGNS:
		if index < 0 or index >= _campaigns.size():
			return ""
		return _campaigns[index].display_name
	if index < 0 or index >= _personal_maps.size():
		return ""
	return _personal_maps[index].display_name


func _library_entry_text(index: int) -> String:
	if _library_mode == LIBRARY_CAMPAIGNS:
		if index < 0 or index >= _campaigns.size():
			return ""
		var campaign: CampaignDefinition = _campaigns[index]
		var total_maps: int = campaign.map_ids.size()
		var subtitle: String = _campaign_size_label(total_maps)
		return "%s\n%s" % [campaign.display_name, subtitle]
	if index < 0 or index >= _personal_maps.size():
		return ""
	var dungeon: DungeonMap = _personal_maps[index]
	return "%s\nОтдельное приключение" % dungeon.display_name


static func _campaign_size_label(count: int) -> String:
	var noun: String = "глав"
	if count % 100 < 11 or count % 100 > 14:
		if count % 10 == 1:
			noun = "глава"
		elif count % 10 >= 2 and count % 10 <= 4:
			noun = "главы"
	return "%d %s" % [count, noun]


func _select_library_index(index: int) -> void:
	var count: int = _campaigns.size() if _library_mode == LIBRARY_CAMPAIGNS else _personal_maps.size()
	if index < 0 or index >= count:
		return
	_selected_library_index = index
	for button_index in range(_library_entries.size()):
		_library_entries[button_index].set_pressed_no_signal(button_index == index)
	_error_message.visible = false
	_start_button.disabled = false
	_update_library_preview()


func _update_library_preview() -> void:
	if _selected_library_index < 0:
		_preview_image.texture = null
		_preview_name.text = "Нет доступных приключений"
		_preview_meta.text = ""
		return
	if _selected_library_index < _library_covers.size():
		_preview_image.texture = _library_covers[_selected_library_index]
	else:
		_preview_image.texture = null
	if _library_mode == LIBRARY_CAMPAIGNS:
		var campaign: CampaignDefinition = _campaigns[_selected_library_index]
		_preview_name.text = campaign.display_name
		_preview_meta.text = _campaign_size_label(campaign.map_ids.size())
	else:
		var dungeon: DungeonMap = _personal_maps[_selected_library_index]
		_preview_name.text = dungeon.display_name
		_preview_meta.text = "Отдельное приключение"


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
		if dungeon != null and not assigned.has(map_id) and not OfficialCampaignLibrary.is_official_id(str(map_id)):
			result.append(dungeon)
	return result

func _start_selected() -> void:
	if _transitioning:
		return
	if _selected_library_index < 0:
		return
	_maps_by_id = SavedMapLibrary.load_for_game(_maps_directory)
	var campaigns: Dictionary = _campaign_library.load_for_game(_maps_by_id)
	if not _campaign_library.last_error.is_empty():
		_error_message.text = _campaign_library.last_error
		_error_message.show()
		return
	var chosen: DungeonMap
	var selected_campaign_id: String = ""
	if _library_mode == LIBRARY_CAMPAIGNS:
		if _selected_library_index >= _campaigns.size():
			return
		selected_campaign_id = _campaigns[_selected_library_index].campaign_id
		var campaign: CampaignDefinition = campaigns.get(selected_campaign_id) as CampaignDefinition
		if campaign != null:
			chosen = _maps_by_id.get(campaign.start_map_id) as DungeonMap
	else:
		if _selected_library_index >= _personal_maps.size():
			return
		var selected_id: String = _personal_maps[_selected_library_index].map_id
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
	_refresh_background_state()
	_hero_selection.reset_selection()
	_hero_selection.focus_first()

func _return_to_library() -> void:
	_hero_selection.visible = false
	_library.visible = true
	_refresh_background_state()
	if _selected_library_index >= 0 and _selected_library_index < _library_entries.size():
		_library_entries[_selected_library_index].grab_focus()
	else:
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
	_maps_by_id = SavedMapLibrary.load_for_game(_maps_directory)
	var campaigns: Dictionary = _campaign_library.load_for_game(_maps_by_id)
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
	_refresh_background_state()
	_load_saved_maps()
	_error_message.text = message
	_error_message.show()
	if _selected_library_index >= 0 and _selected_library_index < _library_entries.size():
		_library_entries[_selected_library_index].grab_focus()
