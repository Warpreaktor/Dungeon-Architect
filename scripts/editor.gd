extends Control

signal menu_requested

## Главное окно самостоятельного приложения-редактора.
## Вся сцена собирается обычными Control-узлами, чтобы её можно было расширять.

const PALETTE_WIDTH := 252.0
const COMPACT_LAYOUT_WIDTH := 1160.0
# Разделяем постоянные команды, настройки запуска и визуальные слои.
const FILE_HOME := 1
const FILE_NEW := 2
const FILE_LOAD := 3
const FILE_IMPORT := 4
const FILE_EXPORT := 5
const SETTINGS_MAP_PROPERTIES := 1
const SETTINGS_TEST_HERO := 2
const SETTINGS_CONSOLE := 3
const SETTINGS_CAMPAIGN := 4
const SETTINGS_DEVELOPER := 5
const VIEW_REACHABILITY := 1
const VIEW_GRID := 2
const HERO_HUD_SCENE: PackedScene = preload("res://scenes/hero_hud.tscn")
const GAME_NOTICE_SCENE: PackedScene = preload("res://scenes/game_notice.tscn")
const CHEST_CONTENTS_SCENE: PackedScene = preload("res://scenes/chest_contents_popup.tscn")
const DOOR_PROPERTIES_SCENE: PackedScene = preload("res://scenes/door_properties_popup.tscn")
const TRIGGER_PROPERTIES_SCENE: PackedScene = preload("res://scenes/trigger_properties_popup.tscn")
const ARSENAL_VIEW_SCRIPT: Script = preload("res://scripts/battle_arsenal_view.gd")
const BATTLE_VIEW_SCENE: PackedScene = preload("res://scenes/battle_view.tscn")
const VICTORY_VIEW_SCENE: PackedScene = preload("res://scenes/victory_view.tscn")
const MESSAGE_EDITOR_SCENE: PackedScene = preload("res://scenes/message_editor_popup.tscn")
const GAME_DIALOGUE_SCENE: PackedScene = preload("res://scenes/game_dialogue_view.tscn")
const DOOR_CROSSBOW_SOUND: AudioStream = preload("res://assets/audio/traps/door_crossbow.wav")
const INVENTORY_VIEW_SCENE: PackedScene = preload("res://scenes/inventory_view.tscn")
const GAME_COMMAND_BAR_SCENE: PackedScene = preload("res://scenes/game_command_bar.tscn")
const GAME_SYSTEM_MENU_SCENE: PackedScene = preload("res://scenes/game_system_menu.tscn")
const MAP_SCREEN_SCENE: PackedScene = preload("res://scenes/map_screen.tscn")
const MINI_MAP_SCENE: PackedScene = preload("res://scenes/mini_map.tscn")
const EDITOR_SETTINGS_PATH := "user://editor_state.cfg"
const SAVE_FEEDBACK_SECONDS := 1.25
const SAVE_CONFIRMATION_ICON: Texture2D = preload("res://assets/icons/commands/saved.svg")
const COMMAND_ICONS := {
	"new": preload("res://assets/icons/commands/new.png"),
	"save": preload("res://assets/icons/commands/save.png"),
	"load": preload("res://assets/icons/commands/load.png"),
	"export": preload("res://assets/icons/commands/export.png"),
	"import": preload("res://assets/icons/commands/import.png"),
	"center": preload("res://assets/icons/commands/center.png"),
	"test": preload("res://assets/icons/commands/test.png"),
	"editor": preload("res://assets/icons/commands/editor.png"),
	"undo": preload("res://assets/icons/commands/undo.png"),
	"redo": preload("res://assets/icons/commands/redo.png"),
	"file": preload("res://assets/icons/commands/file.png"),
	"layers": preload("res://assets/icons/commands/layers.png"),
	"settings": preload("res://assets/icons/commands/settings.png"),
	"inspector": preload("res://assets/icons/commands/inspector.png"),
	"dice": preload("res://assets/icons/commands/dice.svg")
}
const TOOLS := [
	{"id": "hand", "label": "Рука", "hint": "Безопасно перемещать и масштабировать карту одним или двумя пальцами"},
	{"id": "floor", "label": "Пол", "hint": "Убирает стену; поверхность становится проходимой"},
	{"id": "wall", "label": "Стена", "hint": "Непроходимая клетка"},
	{"id": "door", "label": "Дверь", "hint": "Дверь на клетке пола"},
	{"id": "chest", "label": "Сундук", "hint": "Контейнер с добычей"},
	{"id": "stairs_down", "label": "Спуск", "hint": "Выход из подземелья или переход на следующую карту"},
	{"id": "portal", "label": "Магический портал", "hint": "Переход на связанную карту"},
	{"id": "trigger", "label": "Триггер", "hint": "Невидимое в игре событие"},
	{"id": "message", "label": "Послание", "hint": "Авторский текст при входе в клетку или открытии двери"},
	{"id": "player_spawn", "label": "Старт героя", "hint": "Единственная стартовая позиция"},
	{"id": "erase", "label": "Ластик", "hint": "Удалить верхний объект или стену"}
]
const TOOL_ICONS := {
	"hand": preload("res://assets/icons/commands/hand.png"),
	"floor": preload("res://assets/icons/map_objects/floor.png"),
	"wall": preload("res://assets/icons/map_objects/wall.png"),
	"door": preload("res://assets/icons/map_objects/door.png"),
	"chest": DungeonCanvas.CHEST_TEXTURE,
	"stairs_down": preload("res://assets/icons/map_objects/stairs_down.png"),
	"trigger": preload("res://assets/icons/map_objects/trigger.png"),
	"message": preload("res://assets/icons/map_objects/message.png"),
	"player_spawn": preload("res://assets/icons/map_objects/player_spawn.png"),
	"erase": preload("res://assets/icons/commands/erase.png")
}

var map_data: DungeonMap
var standalone_game: bool = false
var _startup_game_map: DungeonMap
var _startup_party_ids: Array[String] = [HeroCatalog.DEFAULT_HERO_ID]
var _startup_game_session: GameSession
var _startup_campaign: CampaignDefinition
var _progress_save_store: ProgressSaveStore = ProgressSaveStore.new()
var _progress_maps_directory: String = SavedMapLibrary.DIRECTORY
var _editor_maps_directory: String = SavedMapLibrary.DIRECTORY
var _campaign_library: CampaignLibrary = CampaignLibrary.new()
var _test_party_ids: Array[String] = [HeroCatalog.DEFAULT_HERO_ID]
var _developer_preview: GameSession
var _developer_inventory: DeveloperInventoryDialog
var _editor_header: PanelContainer
var _floating_console: FloatingDebugConsole
var _arsenal_view: BattleArsenalView
var _game_command_bar: GameCommandBar
var _game_system_menu: GameSystemMenu
var _map_screen: MapScreen
var _mini_map: PanelContainer
var _mini_overview: MapOverview
var _minimap_enabled: bool = true
var game_session: GameSession
var is_dirty: bool = false
var selected_tool: String = "hand"
var is_play_mode: bool = false
var _trap_playback_active: bool = false
var _editor_camera_offset := Vector2.ZERO
var _editor_camera_zoom: float = 1.0
const HISTORY_LIMIT := 40
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _undo_button: Button
var _save_button: Button
var _save_feedback_timer: Timer
var _brand_label: Label
var _file_menu: MenuButton
var _settings_menu: MenuButton
var _layers_menu: MenuButton
var _issues_toggle: Button
var _settings_dialog: AcceptDialog
var _settings_tabs: TabContainer
var _test_hero_panel: EditorTestHeroPanel
var _issues_dialog: PopupPanel
var _palette_toggle: Button
var _palette_panel: PanelContainer
var _fit_button: Button
var _compact_layout: bool = false
var _show_palette: bool = true
var _reachability_enabled: bool = false
var _reachability_refresh_timer: Timer
var _issues_list: VBoxContainer
var _issues_container: VBoxContainer
var _current_issue_count: int = 0
var _redo_button: Button

var _canvas_host: Control
var _canvas: DungeonCanvas
var _battle_view: BattleView
var _victory_view: VictoryView
var _combat_active: bool = false
var _combat_camera_tween: Tween
var _pre_combat_zoom: float = 1.0
var _name_input: LineEdit
var _last_log_message: String = ""
var _stats_label: Label
var _palette_buttons: Dictionary = {}
var _touch_info: TouchInfoOverlay
var _chest_popup: ChestContentsPopup
var _monster_loot_popup: ChestContentsPopup
var _door_popup: DoorPropertiesPopup
var _trap_popup: TrapPropertiesPopup
var _trigger_popup: TriggerPropertiesPopup
var _message_popup: MessageEditorPopup
var _game_dialogue: GameDialogueView
var _pending_game_messages: Array[Dictionary] = []
var _active_game_message: Dictionary = {}
var _editor_controls: Array[Control] = []
var _play_button: Button
var _load_paths: Array[String] = []
var _load_list: ItemList
var _library_actions: HBoxContainer
var _campaign_link_actions: HBoxContainer
var _campaign_add_mode: bool = false
var _campaign_link_label: Label
var _stairs_reward_button: Button
var _unlink_stairs_button: Button
var _linking_exit_id: String = ""
var _campaign_creation_dialog: ConfirmationDialog
var _campaign_name_input: LineEdit
var _campaign_dialog: AcceptDialog
var _campaign_diagnostics_dialog: AcceptDialog
var _campaign_diagnostics_text: TextEdit
var _campaign_list: ItemList
var _campaign_title_input: LineEdit
var _campaign_start_choice: OptionButton
var _campaign_available_choice: OptionButton
var _campaign_current_id: String = ""
var _campaign_member_paths: Array[String] = []
var _campaign_available_ids: Array[String] = []
var _campaign_remove_confirm: ConfirmationDialog
var _campaign_delete_confirm: ConfirmationDialog
var _campaign_pending_remove: String = ""
var _legacy_campaign_dialog: ConfirmationDialog
var _legacy_campaign_name: LineEdit
var _legacy_campaign_destination: OptionButton
var _legacy_campaign_members: ItemList
var _legacy_campaign_start: OptionButton
var _legacy_campaign_ids: Array[String] = []
var _legacy_campaign_existing_ids: Array[String] = []
var _pending_campaign_destination_path: String = ""
var _pending_next_map: DungeonMap

var _preview_textures: Array[Texture2D] = []
var _rename_dialog: ConfirmationDialog
var _rename_input: LineEdit
var _delete_dialog: ConfirmationDialog
var _delete_path: String = ""
var _unsaved_dialog: ConfirmationDialog
var _pending_action: Callable
var _log_console: RichTextLabel
var _log_open: bool = false
const PREVIEW_WIDTH := 176
const PREVIEW_HEIGHT := 116
var _new_dialog: ConfirmationDialog
var _size_preset: OptionButton
var _width_input: SpinBox
var _height_input: SpinBox
var _dpad: Control
var _held_dpad_direction := Vector2i.ZERO
var _held_move_keys: Array[int] = []
var _blocked_hold_direction := Vector2i.ZERO
var _hero_hud: HeroHUD
var _inventory_view: InventoryView
var _ground_loot_view: GroundLootView
var _game_notice: GameNotice
var _load_dialog: ConfirmationDialog
var _export_dialog: FileDialog
var _import_dialog: FileDialog


## Вызывается главным меню до добавления сцены в дерево.
func configure_for_game(data: DungeonMap, hero_ids: Array[String], campaign: CampaignDefinition = null) -> void:
	standalone_game = true
	_startup_game_map = data
	_startup_party_ids = hero_ids.duplicate()
	_startup_campaign = campaign


func configure_for_resume(session: GameSession) -> void:
	if session == null or session.map_data == null:
		return
	standalone_game = true
	_startup_game_map = session.map_data
	_startup_game_session = session


func _ready() -> void:
	_reachability_refresh_timer = Timer.new()
	_reachability_refresh_timer.one_shot = true
	_reachability_refresh_timer.wait_time = 0.15
	_reachability_refresh_timer.timeout.connect(_refresh_reachability)
	add_child(_reachability_refresh_timer)
	_load_test_party_selection()
	_touch_info = TouchInfoOverlay.new()
	add_child(_touch_info)
	_build_interface()
	_create_dialogs()
	get_viewport().size_changed.connect(_on_editor_viewport_resized)
	_on_editor_viewport_resized()
	if standalone_game:
		_set_map(_startup_game_map)
		_start_play_mode()
	elif not _restore_last_map():
		_set_map(DungeonMap.create_blank())
		_set_status("Создана новая карта.")


func _build_interface() -> void:
	var root_column := VBoxContainer.new()
	root_column.name = "EditorLayout"
	root_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_column.add_theme_constant_override("separation", 0)
	add_child(root_column)

	var header := _panel(Color("#1c2935"))
	header.name = "EditorHeader"
	_editor_header = header
	root_column.add_child(header)
	# Одна предсказуемая строка: редкие операции в меню, карта не уступает место кнопкам.
	var toolbar := HBoxContainer.new()
	toolbar.name = "EditorToolbar"
	toolbar.add_theme_constant_override("separation", 6)
	header.add_child(toolbar)
	# У логотипа собственная минимальная ширина: обычный Label переносил даже "DA" по буквам.
	_brand_label = _label("DUNGEON /\nARCHITECT", 19, Color("#e8c58a"))
	_brand_label.name = "EditorBrand"
	_brand_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_brand_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_brand_label.custom_minimum_size = Vector2(174, 52)
	_brand_label.tooltip_text = "DUNGEON / ARCHITECT"
	toolbar.add_child(_brand_label)

	_file_menu = MenuButton.new()
	_file_menu.name = "FileMenu"
	_file_menu.text = "Файл"
	_file_menu.icon = COMMAND_ICONS["file"]
	_file_menu.custom_minimum_size.y = 44
	_file_menu.tooltip_text = "Карты и главное меню"
	var file_popup := _file_menu.get_popup()
	file_popup.add_icon_item(COMMAND_ICONS["new"], "Новая карта", FILE_NEW)
	file_popup.add_icon_item(COMMAND_ICONS["load"], "Загрузить из библиотеки", FILE_LOAD)
	file_popup.add_separator()
	file_popup.add_icon_item(COMMAND_ICONS["import"], "Импорт JSON", FILE_IMPORT)
	file_popup.add_icon_item(COMMAND_ICONS["export"], "Экспорт JSON", FILE_EXPORT)
	file_popup.add_separator()
	file_popup.add_item("В главное меню", FILE_HOME)
	file_popup.id_pressed.connect(_on_file_action_selected)
	toolbar.add_child(_file_menu)
	_register_editor_control(_file_menu)

	_settings_menu = MenuButton.new()
	_settings_menu.name = "SettingsMenu"
	_settings_menu.text = "Настройки"
	_settings_menu.icon = COMMAND_ICONS["settings"]
	_settings_menu.custom_minimum_size.y = 44
	_settings_menu.tooltip_text = "Настройки редактора и текущей карты"
	var settings_popup := _settings_menu.get_popup()
	settings_popup.add_icon_item(COMMAND_ICONS["inspector"], "Свойства карты", SETTINGS_MAP_PROPERTIES)
	settings_popup.add_item("Тестовый герой", SETTINGS_TEST_HERO)
	settings_popup.add_item("Управление кампанией", SETTINGS_CAMPAIGN)
	settings_popup.add_check_item("Показать консоль", SETTINGS_CONSOLE)
	if DeveloperMode.is_available():
		settings_popup.add_check_item("Режим разработчика", SETTINGS_DEVELOPER)
		settings_popup.set_item_checked(settings_popup.get_item_index(SETTINGS_DEVELOPER), DeveloperMode.is_enabled())
	settings_popup.id_pressed.connect(_on_settings_option_selected)
	toolbar.add_child(_settings_menu)
	_register_editor_control(_settings_menu)

	_save_button = _button("Сохранить", "Сохранить карту (Ctrl+S)", _save_internal)
	_set_command_icon(_save_button, "save")
	_save_button.custom_minimum_size.y = 44
	toolbar.add_child(_save_button)
	_register_editor_control(_save_button)
	_save_feedback_timer = Timer.new()
	_save_feedback_timer.one_shot = true
	_save_feedback_timer.wait_time = SAVE_FEEDBACK_SECONDS
	_save_feedback_timer.timeout.connect(_clear_save_feedback)
	add_child(_save_feedback_timer)

	_undo_button = _button("", "Отменить (Ctrl+Z)", _undo_edit)
	_set_command_icon(_undo_button, "undo")
	_undo_button.custom_minimum_size = Vector2(44, 44)
	toolbar.add_child(_undo_button)
	_redo_button = _button("", "Повторить (Ctrl+Y / Ctrl+Shift+Z)", _redo_edit)
	_set_command_icon(_redo_button, "redo")
	_redo_button.custom_minimum_size = Vector2(44, 44)
	toolbar.add_child(_redo_button)

	var flexible_space := Control.new()
	flexible_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(flexible_space)

	_palette_toggle = _button("Объекты", "Показать инструменты и объекты", _toggle_palette_panel)
	_palette_toggle.name = "PaletteToggle"
	_palette_toggle.toggle_mode = true
	_palette_toggle.icon = TOOL_ICONS["hand"]
	_palette_toggle.custom_minimum_size.y = 44
	toolbar.add_child(_palette_toggle)
	_register_editor_control(_palette_toggle)

	_layers_menu = MenuButton.new()
	_layers_menu.name = "LayersMenu"
	_layers_menu.text = "Слои"
	_layers_menu.icon = COMMAND_ICONS["layers"]
	_layers_menu.custom_minimum_size.y = 44
	_layers_menu.tooltip_text = "Визуальные слои карты"
	var layers_popup := _layers_menu.get_popup()
	layers_popup.add_icon_check_item(TOOL_ICONS["player_spawn"], "Достижимость", VIEW_REACHABILITY)
	layers_popup.add_icon_check_item(TOOL_ICONS["floor"], "Сетка", VIEW_GRID)
	layers_popup.set_item_checked(layers_popup.get_item_index(VIEW_GRID), true)
	layers_popup.id_pressed.connect(_on_view_option_selected)
	toolbar.add_child(_layers_menu)
	_register_editor_control(_layers_menu)

	_issues_toggle = _button("Замечания", "Показать диагностику подземелья", _open_issues_dialog)
	_issues_toggle.name = "IssuesToggle"
	_issues_toggle.icon = COMMAND_ICONS["inspector"]
	_issues_toggle.custom_minimum_size.y = 44
	_issues_toggle.visible = false
	toolbar.add_child(_issues_toggle)
	_register_editor_control(_issues_toggle)

	_play_button = _button("Тест", "Проверить карту без сохранения игрового прогресса", _toggle_play_mode)
	_set_command_icon(_play_button, "test")
	_play_button.custom_minimum_size.y = 44
	toolbar.add_child(_play_button)


	var workspace := HBoxContainer.new()
	workspace.name = "EditorWorkspace"
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 0)
	root_column.add_child(workspace)

	# Палитра располагается справа от карты и панели свойств.
	_palette_panel = _panel(Color("#202d39"))
	_palette_panel.name = "PalettePanel"
	_palette_panel.custom_minimum_size.x = PALETTE_WIDTH
	workspace.add_child(_palette_panel)
	var palette_scroll := ScrollContainer.new()
	palette_scroll.name = "PaletteScroll"
	palette_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	palette_scroll.scroll_deadzone = 12
	_palette_panel.add_child(palette_scroll)
	var palette := VBoxContainer.new()
	palette.name = "PaletteContent"
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette.add_theme_constant_override("separation", 10)
	palette_scroll.add_child(palette)

	var canvas_host := Control.new()
	canvas_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_host = canvas_host
	canvas_host.name = "MapViewport"
	workspace.add_child(canvas_host)

	_canvas = DungeonCanvas.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.map_edited.connect(_on_canvas_edited)
	_canvas.edit_action_committed.connect(_on_edit_action_committed)
	_canvas.move_selection_changed.connect(_on_move_selection_changed)
	_canvas.move_failed.connect(_on_move_failed)
	_canvas.placement_rejected.connect(_on_placement_rejected)
	_canvas.configurable_entity_tapped.connect(_on_configurable_entity_tapped)
	_canvas.developer_interaction_enabled = DeveloperMode.is_enabled() and not standalone_game
	_canvas.message_cell_tapped.connect(_on_message_cell_tapped)
	_canvas.ground_loot_tapped.connect(_open_ground_loot)
	canvas_host.add_child(_canvas)
	# Накладная кнопка не участвует в расчёте ширины панели редактора.
	var viewport_actions := Control.new()
	viewport_actions.name = "ViewportActions"
	viewport_actions.anchor_left = 1.0
	viewport_actions.anchor_right = 1.0
	viewport_actions.offset_left = -143.0
	viewport_actions.offset_right = -12.0
	viewport_actions.offset_top = 12.0
	viewport_actions.offset_bottom = 58.0
	viewport_actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_host.add_child(viewport_actions)
	_fit_button = _button("Центр", "Вписать карту в окно", _fit_map)
	_set_command_icon(_fit_button, "center")
	viewport_actions.add_child(_fit_button)
	_fit_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_register_editor_control(_fit_button)
	_build_dpad(canvas_host)

	# Интерфейс героя — самостоятельная сцена, не часть логики редактора.
	_hero_hud = HERO_HUD_SCENE.instantiate() as HeroHUD
	_hero_hud.status_info_requested.connect(_on_party_status_info_requested)
	_hero_hud.character_requested.connect(_open_character)
	_hero_hud.visible = false
	canvas_host.add_child(_hero_hud)
	# Экранные команды — отдельная сцена, не часть HUD персонажа.
	_game_command_bar = GAME_COMMAND_BAR_SCENE.instantiate() as GameCommandBar
	_game_command_bar.inventory_requested.connect(_toggle_inventory)
	_game_command_bar.menu_requested.connect(_open_game_system_menu)
	_game_command_bar.map_requested.connect(_toggle_map_screen)
	_game_command_bar.visible = false
	canvas_host.add_child(_game_command_bar)
	_mini_map = MINI_MAP_SCENE.instantiate() as PanelContainer
	_mini_overview = _mini_map.get_node("Overview") as MapOverview
	_mini_overview.miniature = true
	_mini_map.visible = false
	canvas_host.add_child(_mini_map)
	_map_screen = MAP_SCREEN_SCENE.instantiate() as MapScreen
	_map_screen.closed.connect(_on_map_closed)
	_map_screen.minimap_changed.connect(_set_minimap_enabled)
	add_child(_map_screen)
	_game_system_menu = GAME_SYSTEM_MENU_SCENE.instantiate() as GameSystemMenu
	_game_system_menu.continue_requested.connect(_close_game_system_menu)
	_game_system_menu.save_requested.connect(_save_progress)
	_game_system_menu.leave_requested.connect(_leave_from_game_system_menu)
	_game_system_menu.test_open_map_changed.connect(_set_test_open_map)
	_game_system_menu.console_changed.connect(_set_console_from_game_menu)
	add_child(_game_system_menu)
	_arsenal_view = ARSENAL_VIEW_SCRIPT.new() as BattleArsenalView
	_arsenal_view.closed.connect(_on_arsenal_closed)
	add_child(_arsenal_view)
	_inventory_view = INVENTORY_VIEW_SCENE.instantiate() as InventoryView
	_inventory_view.closed.connect(_on_inventory_closed)
	_inventory_view.item_use_requested.connect(_on_inventory_use_requested)
	_inventory_view.equipment_changed.connect(_refresh_stats)
	add_child(_inventory_view)
	_ground_loot_view = GroundLootView.new()
	_ground_loot_view.closed.connect(_on_ground_loot_closed)
	_ground_loot_view.loot_changed.connect(_on_ground_loot_changed)
	add_child(_ground_loot_view)
	_game_notice = GAME_NOTICE_SCENE.instantiate() as GameNotice
	_game_notice.visible = false
	canvas_host.add_child(_game_notice)

	_game_dialogue = GAME_DIALOGUE_SCENE.instantiate() as GameDialogueView
	_game_dialogue.closed.connect(_on_game_dialogue_closed)
	_game_dialogue.choice_selected.connect(_on_trap_choice_selected)
	add_child(_game_dialogue)

	var tools_section := _palette_section(palette, "Tools", "ИНСТРУМЕНТЫ")
	var control_tools := _tool_grid()
	control_tools.name = "ToolsGrid"
	tools_section.add_child(control_tools)
	for tool in TOOLS:
		if str(tool["id"]) in ["hand", "erase"]:
			_add_tool_button(control_tools, tool)

	var map_section := _palette_section(palette, "MapObjects", "ОБЪЕКТЫ")
	var map_tools := _tool_grid()
	map_tools.name = "MapObjectsGrid"
	map_section.add_child(map_tools)
	for tool in TOOLS:
		if str(tool["id"]) not in ["hand", "erase"]:
			_add_tool_button(map_tools, tool)

	var portals_section := _palette_section(palette, "Portals", "ЦВЕТНЫЕ ПОРТАЛЫ")
	var portals_grid := _tool_grid()
	portals_grid.name = "PortalsGrid"
	portals_section.add_child(portals_grid)
	var portal_labels := {
		"blue": "Синий", "cyan": "Голубой", "green": "Зелёный", "orange": "Оранжевый",
		"pink": "Розовый", "purple": "Фиолетовый", "red": "Красный", "yellow": "Жёлтый"
	}
	for color_id in DungeonMap.PORTAL_COLORS:
		_add_tool_button(portals_grid, {
			"id": "portal_local:" + color_id,
			"label": "Портал: " + str(portal_labels[color_id]),
			"hint": "Перемещение между парными порталами этого цвета",
			"icon": ImageAsset.texture("res://assets/icons/portals/portal_%s.png" % color_id)
		})

	var monsters_section := _palette_section(palette, "Monsters", "МОНСТРЫ")
	var common_monsters := _palette_tool_group(monsters_section, "CommonMonsters", "ОБЫЧНЫЕ")
	var elite_monsters := _palette_tool_group(monsters_section, "EliteMonsters", "ЭЛИТА")
	var bosses_section := _palette_section(palette, "Bosses", "БОССЫ")
	var boss_monsters := _tool_grid()
	boss_monsters.name = "BossesGrid"
	bosses_section.add_child(boss_monsters)
	for monster_id in MonsterCatalog.list_placeable_ids():
		var monster: MonsterDefinition = MonsterCatalog.get_monster(str(monster_id))
		var target_grid: GridContainer = common_monsters
		if monster.rank == MonsterDefinition.Rank.BOSS:
			target_grid = boss_monsters
		elif monster.rank == MonsterDefinition.Rank.ELITE:
			target_grid = elite_monsters
		_add_tool_button(target_grid, {
			"id": "monster:" + monster.monster_id,
			"label": monster.display_name,
			"hint": "Здоровье: %d · Сила: %d · Ловкость: %d" % [monster.max_health, monster.strength, monster.agility],
			"icon": monster.icon
		})
	_palette_tool_group_visibility(monsters_section, common_monsters)
	_palette_tool_group_visibility(monsters_section, elite_monsters)
	(bosses_section.get_parent() as Control).visible = boss_monsters.get_child_count() > 0

	var traps_section := _palette_section(palette, "Traps", "ЛОВУШКИ")
	for placement in ["floor", "door"]:
		var trap_ids: Array[String] = TrapCatalog.list_ids(placement)
		if trap_ids.is_empty():
			continue
		var trap_tools := _palette_tool_group(traps_section, "FloorTraps" if placement == "floor" else "DoorTraps", "НАПОЛЬНЫЕ" if placement == "floor" else "ДВЕРНЫЕ")
		for trap_id in trap_ids:
			var trap: TrapDefinition = TrapCatalog.get_trap(str(trap_id))
			_add_tool_button(trap_tools, {
				"id": "trap:" + trap.trap_id,
				"label": trap.display_name,
				"hint": trap.get_description() if not trap.get_description().is_empty() else "Ловушка: %s" % trap.display_name,
				"icon": trap.icon
			})

	# Перестановка дочернего Control в HBoxContainer меняет порядок панелей
	# без переподключения сигналов и пересоздания палитры.
	workspace.move_child(_palette_panel, workspace.get_child_count() - 1)

	_floating_console = FloatingDebugConsole.new()
	_floating_console.name = "FloatingConsole"
	add_child(_floating_console)
	_log_console = _floating_console.log_node()
	_floating_console.console_open_changed.connect(_on_console_visibility_changed)
	var config := ConfigFile.new()
	config.load(EDITOR_SETTINGS_PATH)
	_log_open = bool(config.get_value("interface", "show_console", false))
	_floating_console.set_open(_log_open)
	_floating_console.set_game_controls_visible(is_play_mode or standalone_game)


func _palette_section(parent: VBoxContainer, section_id: String, title: String, expanded: bool = true) -> VBoxContainer:
	if parent.get_child_count() > 0:
		parent.add_child(HSeparator.new())
	var section := VBoxContainer.new()
	section.name = "%sSection" % section_id
	parent.add_child(section)
	var header := Button.new()
	header.name = "Header"
	header.flat = true
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size.y = 34
	header.focus_mode = Control.FOCUS_NONE
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color("#e8c58a"))
	header.set_meta("section_title", title)
	section.add_child(header)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.visible = expanded
	content.add_theme_constant_override("separation", 8)
	section.add_child(content)
	header.pressed.connect(_toggle_palette_section.bind(header, content))
	_refresh_palette_section_header(header, content)
	return content


func _palette_tool_group(parent: VBoxContainer, group_id: String, title: String) -> GridContainer:
	var wrapper := VBoxContainer.new()
	wrapper.name = "%sGroup" % group_id
	wrapper.add_theme_constant_override("separation", 6)
	parent.add_child(wrapper)
	var label := _label(title, 12, Color("#b9c9d8"))
	label.name = "Label"
	wrapper.add_child(label)
	var grid := _tool_grid()
	grid.name = "Grid"
	wrapper.add_child(grid)
	return grid


func _palette_tool_group_visibility(parent: VBoxContainer, grid: GridContainer) -> void:
	if grid == null:
		return
	var group: Control = grid.get_parent() as Control
	if group != null and group.get_parent() == parent:
		group.visible = grid.get_child_count() > 0


func _toggle_palette_section(header: Button, content: Control) -> void:
	content.visible = not content.visible
	_refresh_palette_section_header(header, content)


func _refresh_palette_section_header(header: Button, content: Control) -> void:
	var title: String = str(header.get_meta("section_title", ""))
	header.text = ("▼ " if content.visible else "▶ ") + title


func _tool_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	return grid


func _add_tool_button(grid: GridContainer, tool: Dictionary) -> void:
	var key: String = str(tool["id"])
	var button := Button.new()
	var icon: Texture2D = tool.get("icon", TOOL_ICONS.get(key)) as Texture2D
	if key == "portal" and icon == null:
		icon = ImageAsset.texture("res://assets/icons/portals/portal_gateway.png")
	button.icon = icon
	button.expand_icon = true
	button.custom_minimum_size = Vector2(66, 66)
	button.tooltip_text = "%s\n%s" % [str(tool["label"]), str(tool.get("hint", ""))]
	button.pressed.connect(_on_tool_button_pressed.bind(button, key))
	grid.add_child(button)
	_touch_info.attach_long_press(button, func() -> String: return button.tooltip_text)
	_palette_buttons[key] = button
	_register_editor_control(button)


func _create_dialogs() -> void:
	_chest_popup = CHEST_CONTENTS_SCENE.instantiate() as ChestContentsPopup
	_chest_popup.contents_changed.connect(_on_chest_contents_changed)
	add_child(_chest_popup)
	_monster_loot_popup = CHEST_CONTENTS_SCENE.instantiate() as ChestContentsPopup
	_monster_loot_popup.monster_configuration_changed.connect(_on_monster_configuration_changed)
	add_child(_monster_loot_popup)
	_door_popup = DOOR_PROPERTIES_SCENE.instantiate() as DoorPropertiesPopup
	_door_popup.configuration_changed.connect(_on_door_configuration_changed)
	add_child(_door_popup)
	_trap_popup = TrapPropertiesPopup.new()
	_trap_popup.name = "TrapPropertiesPopup"
	_trap_popup.configuration_changed.connect(_on_trap_configuration_changed)
	add_child(_trap_popup)
	_trigger_popup = TRIGGER_PROPERTIES_SCENE.instantiate() as TriggerPropertiesPopup
	_trigger_popup.event_id_changed.connect(_on_trigger_event_id_changed)
	add_child(_trigger_popup)
	_message_popup = MESSAGE_EDITOR_SCENE.instantiate() as MessageEditorPopup
	_message_popup.saved.connect(_on_message_saved)
	_message_popup.removed.connect(_on_message_removed)
	add_child(_message_popup)

	# Настройки не занимают постоянную колонку редактора.
	_settings_dialog = AcceptDialog.new()
	_settings_dialog.name = "MapSettingsDialog"
	_settings_dialog.title = "Настройки"
	_settings_dialog.ok_button_text = "Закрыть"
	add_child(_settings_dialog)
	var settings_tabs := TabContainer.new()
	settings_tabs.name = "SettingsTabs"
	settings_tabs.custom_minimum_size = Vector2(430, 188)
	_settings_dialog.add_child(settings_tabs)
	_settings_tabs = settings_tabs
	var map_tab := MarginContainer.new()
	map_tab.name = "Свойства карты"
	for margin_side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		map_tab.add_theme_constant_override(margin_side, 12)
	settings_tabs.add_child(map_tab)
	# Вертикальная форма не сжимает подписи в узкую колонку.
	var map_properties := VBoxContainer.new()
	map_properties.name = "MapProperties"
	map_properties.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	map_properties.add_theme_constant_override("separation", 12)
	map_tab.add_child(map_properties)
	var name_caption := _label("Название карты", 15, Color("#d5e0e7"))
	name_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	map_properties.add_child(name_caption)
	var name_row := HBoxContainer.new()
	name_row.name = "MapNameRow"
	name_row.add_theme_constant_override("separation", 8)
	map_properties.add_child(name_row)
	_name_input = LineEdit.new()
	_name_input.name = "MapName"
	_name_input.placeholder_text = "Название карты"
	_name_input.tooltip_text = "Название сохраняется вместе с картой"
	_name_input.custom_minimum_size = Vector2(0, 44)
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_input.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_name_input.keep_editing_on_text_submit = false
	_name_input.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_input)
	_register_editor_control(_name_input)
	var random_name_button := Button.new()
	random_name_button.name = "RandomMapName"
	random_name_button.icon = COMMAND_ICONS["dice"]
	random_name_button.expand_icon = true
	random_name_button.custom_minimum_size = Vector2(44, 44)
	random_name_button.tooltip_text = "Придумать другое название карты"
	random_name_button.pressed.connect(_generate_map_name)
	name_row.add_child(random_name_button)
	_register_editor_control(random_name_button)
	var size_caption := _label("Размер карты", 15, Color("#d5e0e7"))
	size_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	map_properties.add_child(size_caption)
	_stats_label = _label("", 15, Color("#9ab0bf"))
	_stats_label.name = "MapSize"
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_stats_label.tooltip_text = "Размер задаётся при создании карты и здесь не меняется"
	map_properties.add_child(_stats_label)

	_test_hero_panel = EditorTestHeroPanel.new()
	_test_hero_panel.name = "Тестирование"
	_settings_tabs.add_child(_test_hero_panel)
	_test_hero_panel.select_party(_test_party_ids)
	_test_hero_panel.party_selected.connect(_on_test_party_selected)
	if DeveloperMode.is_available() and not standalone_game:
		_developer_inventory = DeveloperInventoryDialog.new()
		_developer_inventory.name = "DeveloperInventory"
		add_child(_developer_inventory)
		_developer_inventory.loadout_changed.connect(_on_developer_loadout_changed)

	# Диагностика остаётся доступной по запросу, но не забирает ширину у карты.
	_issues_dialog = PopupPanel.new()
	_issues_dialog.name = "IssuesDialog"
	add_child(_issues_dialog)
	var issues_margin := MarginContainer.new()
	for margin_side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		issues_margin.add_theme_constant_override(margin_side, 12)
	_issues_dialog.add_child(issues_margin)
	_issues_container = VBoxContainer.new()
	_issues_container.visible = false
	_issues_container.custom_minimum_size = Vector2(400, 260)
	_issues_container.add_theme_constant_override("separation", 12)
	issues_margin.add_child(_issues_container)
	_issues_container.add_child(_label("ПРОВЕРКА ПОДЗЕМЕЛЬЯ", 15, Color("#e8c58a")))
	var issues_scroll := ScrollContainer.new()
	issues_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	issues_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	issues_scroll.scroll_deadzone = 12
	_issues_container.add_child(issues_scroll)
	_issues_list = VBoxContainer.new()
	_issues_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_issues_list.add_theme_constant_override("separation", 6)
	issues_scroll.add_child(_issues_list)

	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "Новая карта"
	_new_dialog.dialog_text = "Размер новой карты. Несохранённые изменения будут потеряны."
	_new_dialog.ok_button_text = "Создать"
	_new_dialog.confirmed.connect(_new_map)
	add_child(_new_dialog)

	var options := VBoxContainer.new()
	options.custom_minimum_size.x = 330
	_new_dialog.add_child(options)
	_size_preset = OptionButton.new()
	_size_preset.add_item("16 × 16 (по умолчанию)")
	_size_preset.add_item("32 × 32")
	_size_preset.add_item("48 × 48")
	_size_preset.add_item("64 × 64")
	_size_preset.add_item("Свой размер")
	_size_preset.item_selected.connect(_on_size_preset_selected)
	options.add_child(_size_preset)

	var size_row := HBoxContainer.new()
	options.add_child(size_row)
	size_row.add_child(_label("Ширина", 14, Color("#c8d5dd")))
	_width_input = _dimension_input()
	size_row.add_child(_width_input)
	size_row.add_child(_label("Высота", 14, Color("#c8d5dd")))
	_height_input = _dimension_input()
	size_row.add_child(_height_input)
	_width_input.value_changed.connect(_on_custom_size_changed)
	_height_input.value_changed.connect(_on_custom_size_changed)

	_load_dialog = ConfirmationDialog.new()
	_load_dialog.title = "Библиотека карт"
	_load_dialog.ok_button_text = "Загрузить"
	_load_dialog.confirmed.connect(_load_selected)
	_load_dialog.canceled.connect(_cancel_exit_link_selection)
	add_child(_load_dialog)
	var library_layout := VBoxContainer.new()
	library_layout.custom_minimum_size = Vector2(620, 370)
	_load_dialog.add_child(library_layout)
	_load_list = ItemList.new()
	_load_list.custom_minimum_size = Vector2(620, 300)
	_load_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_load_list.auto_height = true
	_load_list.icon_mode = ItemList.ICON_MODE_TOP
	_load_list.fixed_icon_size = Vector2i(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	_load_list.max_columns = 3
	_load_list.same_column_width = true
	_load_list.item_activated.connect(_load_activated)
	var library_scroll := ScrollContainer.new()
	library_scroll.custom_minimum_size = Vector2(620, 300)
	library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	library_scroll.scroll_deadzone = 12
	library_layout.add_child(library_scroll)
	library_scroll.add_child(_load_list)
	_library_actions = HBoxContainer.new()
	library_layout.add_child(_library_actions)
	_library_actions.add_child(_button("Переименовать", "Изменить название выбранной карты", _request_rename))
	_library_actions.add_child(_button("Копировать", "Создать отдельную копию карты", _duplicate_selected))
	_library_actions.add_child(_button("Удалить", "Удалить выбранную карту после подтверждения", _request_delete))
	_campaign_link_label = Label.new()
	_campaign_link_label.visible = false
	library_layout.add_child(_campaign_link_label)
	_campaign_link_actions = HBoxContainer.new()
	_campaign_link_actions.visible = false
	library_layout.add_child(_campaign_link_actions)
	_campaign_link_actions.add_child(_button("Карты кампании", "", _show_campaign_member_maps))
	_campaign_link_actions.add_child(_button("Добавить существующую карту", "", _show_campaign_add_map))
	_campaign_link_actions.add_child(_button("Создать карту", "", _create_campaign_link_map))
	_unlink_stairs_button = _button("Без перехода", "Оставить лестницу финальным выходом", _unlink_selected_exit)
	_unlink_stairs_button.visible = false
	library_layout.add_child(_unlink_stairs_button)
	_stairs_reward_button = _button("Награда", "Настроить награду за прохождение", _edit_stairs_reward)
	_stairs_reward_button.hide()
	library_layout.add_child(_stairs_reward_button)

	_campaign_creation_dialog = ConfirmationDialog.new()
	_campaign_creation_dialog.title = "Создание кампании"
	_campaign_creation_dialog.ok_button_text = "Создать"
	_campaign_creation_dialog.dialog_hide_on_ok = false
	_campaign_creation_dialog.confirmed.connect(_confirm_campaign_creation)
	_campaign_creation_dialog.canceled.connect(_cancel_campaign_creation)
	add_child(_campaign_creation_dialog)
	var campaign_form := VBoxContainer.new()
	campaign_form.custom_minimum_size.x = 380
	_campaign_creation_dialog.add_child(campaign_form)
	campaign_form.add_child(_label("Название кампании", 15, Color("#d5e0e7")))
	_campaign_name_input = LineEdit.new()
	_campaign_name_input.placeholder_text = "Название"
	_campaign_name_input.custom_minimum_size.y = 44
	campaign_form.add_child(_campaign_name_input)

	_campaign_dialog = AcceptDialog.new()
	_campaign_dialog.title = "Управление кампанией"
	_campaign_dialog.ok_button_text = "Закрыть"
	add_child(_campaign_dialog)
	var manager := VBoxContainer.new()
	manager.custom_minimum_size = Vector2(570, 390)
	_campaign_dialog.add_child(manager)
	manager.add_child(_label("Название кампании", 15, Color("#d5e0e7")))
	var campaign_name_row := HBoxContainer.new()
	manager.add_child(campaign_name_row)
	_campaign_title_input = LineEdit.new()
	_campaign_title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_name_row.add_child(_campaign_title_input)
	campaign_name_row.add_child(_button("Переименовать", "", _rename_campaign))
	manager.add_child(_label("Стартовая карта", 15, Color("#d5e0e7")))
	var start_row := HBoxContainer.new()
	manager.add_child(start_row)
	_campaign_start_choice = OptionButton.new()
	_campaign_start_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_row.add_child(_campaign_start_choice)
	start_row.add_child(_button("Назначить", "", _set_campaign_start))
	manager.add_child(_label("Карты кампании", 15, Color("#d5e0e7")))
	_campaign_list = ItemList.new()
	_campaign_list.custom_minimum_size.y = 140
	_campaign_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	manager.add_child(_campaign_list)
	var member_actions := HBoxContainer.new()
	manager.add_child(member_actions)
	member_actions.add_child(_button("Открыть карту", "", _open_campaign_selected_map))
	member_actions.add_child(_button("Исключить", "", _request_campaign_detach))
	manager.add_child(_label("Добавить свободную карту", 15, Color("#d5e0e7")))
	var add_row := HBoxContainer.new()
	manager.add_child(add_row)
	_campaign_available_choice = OptionButton.new()
	_campaign_available_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(_campaign_available_choice)
	add_row.add_child(_button("Добавить", "", _attach_campaign_map))
	var campaign_footer := HBoxContainer.new()
	manager.add_child(campaign_footer)
	campaign_footer.add_child(_button("Диагностика связей", "", _show_campaign_diagnostics))
	campaign_footer.add_child(_button("Удалить кампанию", "", _request_campaign_delete))
	_campaign_diagnostics_dialog = AcceptDialog.new()
	_campaign_diagnostics_dialog.title = "Диагностика кампаний"
	_campaign_diagnostics_dialog.ok_button_text = "Закрыть"
	add_child(_campaign_diagnostics_dialog)
	_campaign_diagnostics_text = TextEdit.new()
	_campaign_diagnostics_text.editable = false
	_campaign_diagnostics_text.custom_minimum_size = Vector2(590, 340)
	_campaign_diagnostics_dialog.add_child(_campaign_diagnostics_text)
	_legacy_campaign_dialog = ConfirmationDialog.new()
	_legacy_campaign_dialog.title = "Собрать карты в кампанию"
	_legacy_campaign_dialog.ok_button_text = "Подтвердить состав"
	_legacy_campaign_dialog.dialog_hide_on_ok = false
	_legacy_campaign_dialog.wrap_controls = false
	_legacy_campaign_dialog.confirmed.connect(_confirm_legacy_campaign)
	add_child(_legacy_campaign_dialog)
	var legacy_scroll := ScrollContainer.new()
	legacy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legacy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	legacy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	legacy_scroll.follow_focus = true
	_legacy_campaign_dialog.add_child(legacy_scroll)
	var legacy_form := VBoxContainer.new()
	legacy_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legacy_scroll.add_child(legacy_form)
	legacy_form.add_child(_label("Название новой кампании", 15, Color("#d5e0e7")))
	_legacy_campaign_name = LineEdit.new()
	legacy_form.add_child(_legacy_campaign_name)
	legacy_form.add_child(_label("Куда добавить карты", 15, Color("#d5e0e7")))
	_legacy_campaign_destination = OptionButton.new()
	_legacy_campaign_destination.fit_to_longest_item = false
	legacy_form.add_child(_legacy_campaign_destination)
	legacy_form.add_child(_label("Связанные карты (выберите участников)", 15, Color("#d5e0e7")))
	_legacy_campaign_members = ItemList.new()
	_legacy_campaign_members.select_mode = ItemList.SELECT_MULTI
	_legacy_campaign_members.custom_minimum_size.y = 130
	_legacy_campaign_members.size_flags_vertical = Control.SIZE_FILL
	_legacy_campaign_members.multi_selected.connect(_on_legacy_member_selected)
	legacy_form.add_child(_legacy_campaign_members)
	legacy_form.add_child(_label("Стартовая карта", 15, Color("#d5e0e7")))
	_legacy_campaign_start = OptionButton.new()
	_legacy_campaign_start.fit_to_longest_item = false
	legacy_form.add_child(_legacy_campaign_start)
	_legacy_campaign_destination.item_selected.connect(_on_legacy_destination_changed)
	_campaign_remove_confirm = ConfirmationDialog.new()
	_campaign_remove_confirm.title = "Исключить карту"
	_campaign_remove_confirm.confirmed.connect(_confirm_campaign_detach)
	add_child(_campaign_remove_confirm)
	_campaign_delete_confirm = ConfirmationDialog.new()
	_campaign_delete_confirm.title = "Удалить кампанию"
	_campaign_delete_confirm.confirmed.connect(_confirm_campaign_delete)
	add_child(_campaign_delete_confirm)

	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Переименование карты"
	_rename_dialog.ok_button_text = "Переименовать"
	_rename_dialog.confirmed.connect(_rename_selected)
	add_child(_rename_dialog)
	_rename_input = LineEdit.new()
	_rename_input.custom_minimum_size.x = 350
	_rename_dialog.add_child(_rename_input)

	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Удаление карты"
	_delete_dialog.ok_button_text = "Удалить"
	_delete_dialog.confirmed.connect(_delete_selected)
	add_child(_delete_dialog)

	_unsaved_dialog = ConfirmationDialog.new()
	_unsaved_dialog.title = "Несохранённая карта"
	_unsaved_dialog.dialog_text = "Изменения карты не сохранены. Продолжить без сохранения?"
	_unsaved_dialog.ok_button_text = "Продолжить"
	_unsaved_dialog.confirmed.connect(_run_pending_action)
	add_child(_unsaved_dialog)

	_export_dialog = FileDialog.new()
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.add_filter("*.json", "Карты JSON", "application/json")
	_export_dialog.use_native_dialog = true
	_export_dialog.file_selected.connect(_export_to_path)
	add_child(_export_dialog)

	_import_dialog = FileDialog.new()
	_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_import_dialog.add_filter("*.json", "Карты JSON", "application/json")
	_import_dialog.use_native_dialog = true
	_import_dialog.file_selected.connect(_load_from_path)
	add_child(_import_dialog)


func _dimension_input() -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 1
	spin.max_value = DungeonMap.MAX_SIZE
	spin.step = 1
	spin.rounded = true
	spin.value = 16
	spin.custom_minimum_size.x = 90
	spin.get_line_edit().virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	spin.get_line_edit().keep_editing_on_text_submit = false
	return spin


func _on_size_preset_selected(index: int) -> void:
	if index >= 0 and index < 4:
		var dimension: int = [16, 32, 48, 64][index]
		_width_input.set_value_no_signal(dimension)
		_height_input.set_value_no_signal(dimension)


func _on_custom_size_changed(_value: float) -> void:
	_size_preset.select(4)


func _build_dpad(host: Control) -> void:
	_dpad = Control.new()
	_dpad.anchor_top = 1.0
	_dpad.anchor_bottom = 1.0
	_dpad.offset_left = 16.0
	_dpad.offset_top = -244.0
	_dpad.offset_right = 244.0
	_dpad.offset_bottom = -16.0
	_dpad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dpad.visible = false
	host.add_child(_dpad)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	_dpad.add_child(grid)
	for i in range(9):
		if i in [1, 3, 5, 7]:
			var direction := Vector2i.ZERO
			var symbol := ""
			match i:
				1:
					direction = Vector2i.UP
					symbol = "▲"
				3:
					direction = Vector2i.LEFT
					symbol = "◀"
				5:
					direction = Vector2i.RIGHT
					symbol = "▶"
				7:
					direction = Vector2i.DOWN
					symbol = "▼"
			var button := Button.new()
			button.text = symbol
			button.focus_mode = Control.FOCUS_NONE
			button.custom_minimum_size = Vector2(68, 68)
			button.add_theme_font_size_override("font_size", 28)
			button.button_down.connect(_on_dpad_down.bind(direction))
			button.button_up.connect(_on_dpad_up.bind(direction))
			grid.add_child(button)
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(68, 68)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(spacer)


## Движение начинается на нажатии и повторяется после завершения анимации.
func _on_dpad_down(direction: Vector2i) -> void:
	if not _movement_input_allowed():
		return
	_held_dpad_direction = direction
	_blocked_hold_direction = Vector2i.ZERO
	_advance_held_move()


func _on_dpad_up(direction: Vector2i) -> void:
	if _held_dpad_direction == direction:
		_held_dpad_direction = Vector2i.ZERO
		_blocked_hold_direction = Vector2i.ZERO


func _direction_for_key(keycode: int) -> Vector2i:
	match keycode:
		KEY_UP, KEY_W:
			return Vector2i.UP
		KEY_DOWN, KEY_S:
			return Vector2i.DOWN
		KEY_LEFT, KEY_A:
			return Vector2i.LEFT
		KEY_RIGHT, KEY_D:
			return Vector2i.RIGHT
	return Vector2i.ZERO


func _held_move_direction() -> Vector2i:
	if _held_dpad_direction != Vector2i.ZERO:
		return _held_dpad_direction
	if not _held_move_keys.is_empty():
		return _direction_for_key(_held_move_keys.back())
	return Vector2i.ZERO


func _clear_held_movement() -> void:
	_held_dpad_direction = Vector2i.ZERO
	_held_move_keys.clear()
	_blocked_hold_direction = Vector2i.ZERO


func _movement_input_allowed() -> bool:
	return not _trap_playback_active and is_play_mode and game_session != null and not _combat_active and _victory_view == null and not _game_dialogue.visible and not _inventory_view.visible and not _game_system_menu.visible and not _map_screen.visible


func _advance_held_move() -> void:
	var direction := _held_move_direction()
	if direction == Vector2i.ZERO or direction == _blocked_hold_direction or not _movement_input_allowed() or _canvas.is_player_moving():
		return
	var previous_pos: Vector2i = game_session.player_pos
	_try_move_player(direction.x, direction.y)
	if _held_move_direction() == direction and (not is_play_mode or game_session == null or game_session.player_pos == previous_pos):
		# Упёрлись в стену/закрытую дверь: не спамим попытками каждый кадр.
		_blocked_hold_direction = direction


func _process(_delta: float) -> void:
	_advance_held_move()


func _panel(bg: Color) -> PanelContainer:
	var node := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	node.add_theme_stylebox_override("panel", style)
	return node


func _label(content: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = content
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


func _set_command_icon(button: Button, icon_name: String) -> void:
	button.icon = COMMAND_ICONS[icon_name]
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = false


func _button(content: String, hint: String, callback: Callable) -> Button:
	var node := Button.new()
	node.text = content
	node.tooltip_text = hint
	node.custom_minimum_size.y = 38
	node.pressed.connect(callback)
	return node


func _separator() -> VSeparator:
	var result := VSeparator.new()
	result.custom_minimum_size.x = 8
	return result


func _on_file_action_selected(id: int) -> void:
	match id:
		FILE_HOME:
			_request_return_to_menu()
		FILE_NEW:
			_request_new()
		FILE_LOAD:
			_show_load()
		FILE_IMPORT:
			_show_import()
		FILE_EXPORT:
			_show_export()


func _on_view_option_selected(id: int) -> void:
	match id:
		VIEW_REACHABILITY:
			_toggle_reachability()
		VIEW_GRID:
			_toggle_grid(not _canvas.show_grid)


func _toggle_reachability() -> void:
	if is_play_mode or map_data == null:
		return
	_reachability_enabled = not _reachability_enabled
	var popup := _layers_menu.get_popup()
	popup.set_item_checked(popup.get_item_index(VIEW_REACHABILITY), _reachability_enabled)
	if _reachability_enabled:
		_canvas.finish_edit_stroke()
		_refresh_reachability()
	else:
		_clear_reachability()
	_issues_container.visible = _reachability_enabled
	_update_issues_caption()


func _toggle_palette_panel() -> void:
	_show_palette = not _show_palette
	_apply_editor_panels()


func _on_editor_viewport_resized() -> void:
	var compact := get_viewport_rect().size.x < COMPACT_LAYOUT_WIDTH
	if compact != _compact_layout:
		_compact_layout = compact
		_show_palette = true
	_apply_editor_panels()


func _update_brand_caption() -> void:
	if _brand_label == null:
		return
	var compact := get_viewport_rect().size.x < COMPACT_LAYOUT_WIDTH
	_brand_label.text = "DA" if compact else "DUNGEON /\nARCHITECT"
	_brand_label.custom_minimum_size.x = 44.0 if compact else 174.0


func _apply_editor_panels() -> void:
	if _palette_panel == null:
		return
	_update_brand_caption()
	var editing := not is_play_mode and not standalone_game
	_palette_panel.visible = editing and _show_palette
	_palette_toggle.visible = editing and _compact_layout
	var narrow := get_viewport_rect().size.x < 900
	_palette_toggle.text = "" if narrow else "Объекты"
	_settings_menu.text = "" if get_viewport_rect().size.x < 760 else "Настройки"
	_layers_menu.text = "" if narrow else "Слои"
	_refresh_save_button_caption()
	_palette_toggle.set_pressed_no_signal(_show_palette)
	_fit_button.visible = editing
	_update_issues_caption()


func _on_settings_option_selected(id: int) -> void:
	if id == SETTINGS_CONSOLE:
		_toggle_log_console()
		return
	if is_play_mode or standalone_game:
		return
	match id:
		SETTINGS_MAP_PROPERTIES:
			if map_data == null:
				return
			_name_input.text = map_data.display_name
			_refresh_stats()
			_settings_tabs.current_tab = 0
			_settings_dialog.popup_centered_clamped(Vector2i(490, 260))
		SETTINGS_CAMPAIGN:
			_open_campaign_manager()
		SETTINGS_TEST_HERO:
			_settings_tabs.current_tab = 1
			_test_hero_panel.select_party(_test_party_ids)
			_settings_dialog.popup_centered_clamped(Vector2i(490, 440))
		SETTINGS_DEVELOPER:
			if not DeveloperMode.is_available():
				return
			var enabled: bool = not DeveloperMode.is_enabled()
			if not DeveloperMode.set_enabled(enabled):
				_set_status("Не удалось сохранить режим разработчика")
				return
			_settings_menu.get_popup().set_item_checked(_settings_menu.get_popup().get_item_index(SETTINGS_DEVELOPER), enabled)
			_canvas.developer_interaction_enabled = enabled
			_developer_preview = null
			if _developer_inventory != null:
				_developer_inventory.hide()


func _on_test_party_selected(hero_ids: Array[String]) -> void:
	if hero_ids.is_empty() or hero_ids.size() > GameSession.MAX_PARTY_SIZE:
		return
	for hero_id in hero_ids:
		if not HeroCatalog.has(hero_id):
			return
	var unique_ids: Dictionary = {}
	for hero_id in hero_ids:
		if unique_ids.has(hero_id):
			return
		unique_ids[hero_id] = true
	_test_party_ids = hero_ids.duplicate()
	_developer_preview = null
	var config := ConfigFile.new()
	config.load(EDITOR_SETTINGS_PATH)
	config.set_value("editor", "test_party_ids", _test_party_ids)
	if config.save(EDITOR_SETTINGS_PATH) != OK:
		_set_status("Не удалось сохранить состав тестового отряда")


func _load_test_party_selection() -> void:
	if standalone_game:
		return
	var config := ConfigFile.new()
	if config.load(EDITOR_SETTINGS_PATH) != OK:
		return
	var saved_ids: Variant = config.get_value("editor", "test_party_ids", [])
	var valid_ids: Array[String] = []
	if saved_ids is Array:
		for entry in saved_ids:
			var hero_id: String = str(entry)
			if HeroCatalog.has(hero_id) and not valid_ids.has(hero_id):
				valid_ids.append(hero_id)
			if valid_ids.size() >= GameSession.MAX_PARTY_SIZE:
				break
	if valid_ids.is_empty():
		var legacy_id: String = str(config.get_value("editor", "test_hero_id", HeroCatalog.DEFAULT_HERO_ID))
		if HeroCatalog.has(legacy_id):
			valid_ids.append(legacy_id)
	if not valid_ids.is_empty():
		_test_party_ids = valid_ids


func _open_issues_dialog() -> void:
	if _reachability_enabled and not is_play_mode:
		_issues_dialog.popup_centered_clamped(Vector2i(470, 330))


func _update_issues_caption() -> void:
	if _issues_toggle == null:
		return
	_issues_toggle.visible = _reachability_enabled and not is_play_mode and not standalone_game
	var caption := "Замечания (%d)" % _current_issue_count
	_issues_toggle.text = "" if get_viewport_rect().size.x < 900 else caption
	_issues_toggle.tooltip_text = caption + ". Показать список диагностики"


func _focus_issue(cell: Vector2i) -> void:
	if map_data != null and map_data.contains(cell.x, cell.y):
		_issues_dialog.hide()
		_canvas.center_on_cell(cell)


func _show_reachability_issues(result: Dictionary) -> void:
	var issues: Array[Dictionary] = DungeonDiagnostics.analyze(map_data, result)
	_current_issue_count = issues.size()
	_update_issues_caption()
	for child in _issues_list.get_children():
		_issues_list.remove_child(child)
		child.queue_free()
	if issues.is_empty():
		_issues_list.add_child(_label("✓ Проблем не обнаружено", 13, Color("#80ca9d")))
	for issue in issues:
		var severity: String = str(issue["severity"])
		var prefix := "✕ " if severity == "error" else ("⚠ " if severity == "warning" else "ⓘ ")
		var item := _button(prefix + str(issue["message"]), "Показать место на карте", func() -> void: _focus_issue(issue["cell"]))
		item.icon = TOOL_ICONS.get(str(issue["icon"]), TOOL_ICONS["hand"])
		item.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.alignment = HORIZONTAL_ALIGNMENT_LEFT
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.add_theme_color_override("font_color", Color("#ff9e9e") if severity == "error" else (Color("#efcd8d") if severity == "warning" else Color("#b3ccdf")))
		_issues_list.add_child(item)


func _schedule_reachability_refresh() -> void:
	if _reachability_enabled and not is_play_mode and map_data != null:
		# Сгруппировать последовательные изменения при рисовании кистью.
		_reachability_refresh_timer.start()


func _refresh_reachability() -> void:
	if not _reachability_enabled or is_play_mode or map_data == null or _canvas == null:
		return
	var result: Dictionary = DungeonReachability.analyze(map_data)
	_issues_container.visible = true
	_canvas.reachability_result = result
	_canvas.queue_redraw()
	_show_reachability_issues(result)
	if not bool(result.get("has_spawn", false)):
		_set_status("Проверка пути: на карте нет точки старта.")
		return
	var certain: Dictionary = result["reachable"]
	var possible: Dictionary = result["possible"]
	var summary: String = "Проверка пути: %d доступно, ещё %d условно доступно (победы и скрытые сундуки)." % [certain.size(), maxi(possible.size() - certain.size(), 0)]
	if not bool(result["complete"]):
		summary += " Анализ ограничен по числу состояний: результат неполный."
	_set_status(summary)


func _clear_reachability() -> void:
	if _reachability_refresh_timer != null:
		_reachability_refresh_timer.stop()
	if _issues_container != null:
		_issues_container.visible = false
	if _issues_dialog != null:
		_issues_dialog.hide()
	_current_issue_count = 0
	_update_issues_caption()
	if _canvas != null:
		_canvas.reachability_result.clear()
		_canvas.queue_redraw()


func _register_editor_control(control: Control) -> void:
	_editor_controls.append(control)


func _set_map(new_map: DungeonMap) -> void:
	_clear_save_feedback()
	_clear_reachability()
	_developer_preview = null
	map_data = new_map
	game_session = null
	is_play_mode = false
	_name_input.text = map_data.display_name
	_canvas.set_map(map_data)
	_schedule_reachability_refresh()
	_undo_stack.clear()
	_redo_stack.clear()
	_update_history_buttons()
	_set_tool(selected_tool)
	_refresh_stats()
	_update_mode_ui()
	is_dirty = false


func _refresh_stats() -> void:
	_stats_label.text = "%d × %d клеток (только просмотр)" % [map_data.width, map_data.height]
	_update_hero_hud()


func _update_hero_hud() -> void:
	if not is_play_mode or game_session == null:
		return
	_hero_hud.set_party(game_session.party_members())


func _on_party_status_info_requested(title: String, description: String) -> void:
	_touch_info.show_info(title, description)


func _flash_party_damage() -> void:
	if game_session == null:
		return
	for event in game_session.take_party_damage_events():
		var member: HeroState = event.get("member") as HeroState
		var member_index: int = game_session.party_members().find(member)
		if member_index >= 0:
			_hero_hud.flash_hero(member_index)
		_canvas.flash_player_damage()


func _on_configurable_entity_tapped(kind: String, entity_id: String) -> void:
	match kind:
		"player_spawn":
			_open_developer_inventory()
		"door":
			_on_door_tapped(entity_id)
		"trap":
			_on_trap_tapped(entity_id)
		"stairs_down", "portal":
			_on_exit_tapped(entity_id)
		"chest":
			_on_chest_tapped(entity_id)
		"monster":
			_on_monster_tapped(entity_id)
		"trigger":
			_on_trigger_tapped(entity_id)
		"message":
			for entity in map_data.entities:
				if str(entity.get("id", "")) == entity_id and str(entity.get("type", "")) == "message":
					_on_message_cell_tapped(Vector2i(int(entity["x"]), int(entity["y"])))
					return


func _on_message_cell_tapped(cell: Vector2i) -> void:
	if is_play_mode or map_data == null:
		return
	_canvas.finish_edit_stroke()
	var existing := map_data.message_at(cell.x, cell.y)
	var properties: Dictionary = existing.get("properties", {})
	var target_kind := ""
	for kind in ["monster", "door", "chest"]:
		for entity in map_data.entities_at(cell.x, cell.y):
			if str(entity.get("type", "")) == kind:
				target_kind = kind
				break
		if not target_kind.is_empty():
			break
	_message_popup.configure(cell, str(properties.get("text", "")), target_kind)
	_message_popup.popup_centered_clamped(Vector2i(540, 390), 0.9)


func _on_message_saved(cell: Vector2i, text: String) -> void:
	if is_play_mode:
		return
	var before := _canvas.capture_edit_state()
	if map_data.set_message_at(cell.x, cell.y, text):
		_on_edit_action_committed(before, _canvas.capture_edit_state())
		_on_canvas_edited()
		_canvas.queue_redraw()


func _on_message_removed(cell: Vector2i) -> void:
	_on_message_saved(cell, "")


func _on_trigger_tapped(trigger_id: String) -> void:
	if is_play_mode:
		return
	_canvas.finish_edit_stroke()
	for entity in map_data.entities:
		if str(entity.get("id", "")) == trigger_id and str(entity.get("type", "")) == "trigger":
			var properties: Dictionary = entity.get("properties", {})
			_trigger_popup.configure(trigger_id, str(properties.get("event_id", "")))
			_trigger_popup.popup_centered_clamped(Vector2i(390, 220), 0.9)
			return


func _on_trigger_event_id_changed(trigger_id: String, event_id: String) -> void:
	if is_play_mode:
		return
	var before := _canvas.capture_edit_state()
	if map_data.set_trigger_event_id(trigger_id, event_id):
		_on_edit_action_committed(before, _canvas.capture_edit_state())
		_on_canvas_edited()
		_canvas.queue_redraw()


func _on_exit_tapped(entity_id: String) -> void:
	if is_play_mode:
		return
	_canvas.finish_edit_stroke()
	var selected_exit: Dictionary = {}
	for entity in map_data.entities:
		if str(entity.get("id", "")) == entity_id and DungeonMap.is_exit(entity):
			selected_exit = entity
			break
	if selected_exit.is_empty():
		return
	_linking_exit_id = entity_id
	_pending_campaign_destination_path = ""
	_campaign_add_mode = false
	_refresh_library()
	_load_dialog.title = "Переход на карту"
	_load_dialog.ok_button_text = "Связать"
	_library_actions.visible = false
	_campaign_link_actions.visible = true
	_campaign_link_label.visible = true
	_refresh_campaign_link_library()
	_unlink_stairs_button.visible = true
	_stairs_reward_button.visible = str(selected_exit["type"]) == "stairs_down"
	var linked_id: String = DungeonMap.exit_target_id(selected_exit)
	var linked_map: DungeonMap = null
	for index in range(_load_paths.size()):
		var candidate: DungeonMap = _read_map(_load_paths[index])
		if candidate != null and candidate.map_id == linked_id:
			linked_map = candidate
			_load_list.select(index)
			break
	if not linked_id.is_empty():
		if linked_map == null:
			_set_status("Ошибка связи: карта %s отсутствует или не читается." % linked_id)
		elif not DungeonMap.valid_arrival_cell(linked_map, linked_map.find_entity_position("player_spawn")):
			_set_status("Ошибка связи: на карте «%s» недоступна точка появления героя." % linked_map.display_name)
	_load_dialog.popup_centered_clamped(Vector2i(720, 590), 0.9)


func _edit_stairs_reward() -> void:
	for entity in map_data.entities:
		if str(entity.get("id", "")) == _linking_exit_id and str(entity.get("type", "")) == "stairs_down":
			_load_dialog.hide()
			_chest_popup.configure_exit(entity)
			_chest_popup.popup_centered_clamped(Vector2i(470, 530), 0.9)
			return


func _link_selected_exit() -> void:
	if _linking_exit_id.is_empty():
		return
	var path: String = _selected_library_path()
	if path.is_empty():
		return
	var destination: DungeonMap = _read_map(path)
	if not _valid_exit_destination(destination):
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var campaign: CampaignDefinition = _campaign_library.campaign_for_map(map_data.map_id, maps)
	if not _campaign_library.last_error.is_empty():
		_set_status(_campaign_library.last_error)
		return
	if campaign == null:
		_pending_campaign_destination_path = path
		_campaign_name_input.text = map_data.display_name
		_load_dialog.hide()
		_campaign_creation_dialog.popup_centered_clamped(Vector2i(490, 220), 0.9)
		_campaign_name_input.grab_focus()
		_campaign_name_input.select_all()
		return
	if not _campaign_library.attach_map(campaign.campaign_id, destination.map_id, maps):
		_set_status(_campaign_library.last_error)
		return
	_apply_exit_link(destination)


func _valid_exit_destination(destination: DungeonMap) -> bool:
	if destination == null or destination.map_id.is_empty():
		_set_status("Не удалось прочитать выбранное подземелье.")
		return false
	if not DungeonMap.valid_arrival_cell(destination, destination.find_entity_position("player_spawn")):
		_set_status("На целевой карте нужна свободная точка старта героя.")
		return false
	return true


func _confirm_campaign_creation() -> void:
	if map_data == null or _pending_campaign_destination_path.is_empty() or _linking_exit_id.is_empty() or is_play_mode:
		_cancel_campaign_creation()
		return
	var exit_exists: bool = false
	for entity in map_data.entities:
		if str(entity.get("id", "")) == _linking_exit_id and DungeonMap.is_exit(entity):
			exit_exists = true
			break
	if not exit_exists:
		_cancel_campaign_creation()
		return
	var name: String = _campaign_name_input.text.strip_edges()
	if name.is_empty():
		_set_status("Укажи название кампании.")
		return
	var destination: DungeonMap = _read_map(_pending_campaign_destination_path)
	if not _valid_exit_destination(destination):
		_cancel_campaign_creation()
		return
	_save_internal()
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	if is_dirty or not maps.has(map_data.map_id):
		_set_status("Сначала необходимо сохранить текущую карту.")
		return
	var campaign: CampaignDefinition = _campaign_library.campaign_for_map(map_data.map_id, maps)
	if not _campaign_library.last_error.is_empty():
		_set_status(_campaign_library.last_error)
		return
	if campaign == null:
		campaign = _campaign_library.create_campaign(name, map_data.map_id, maps)
		if campaign == null:
			_set_status(_campaign_library.last_error)
			return
	var selected_path: String = _pending_campaign_destination_path
	var exit_id: String = _linking_exit_id
	_pending_campaign_destination_path = ""
	_campaign_creation_dialog.hide()
	_on_exit_tapped(exit_id)
	_show_campaign_add_map()
	var index: int = _load_paths.find(selected_path)
	if index >= 0:
		_load_list.select(index)


func _cancel_campaign_creation() -> void:
	_pending_campaign_destination_path = ""
	_linking_exit_id = ""


func _cancel_exit_link_selection() -> void:
	_pending_campaign_destination_path = ""
	_linking_exit_id = ""
	_campaign_add_mode = false


func _apply_exit_link(destination: DungeonMap) -> void:
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var campaign: CampaignDefinition = _campaign_library.campaign_for_map(map_data.map_id, maps)
	if campaign == null or not _campaign_library.last_error.is_empty() or not campaign.map_ids.has(destination.map_id):
		_set_status("Переход разрешён только между картами одной кампании.")
		return
	var before: Dictionary = _canvas.capture_edit_state()
	if map_data.set_exit_target(_linking_exit_id, destination.map_id):
		_on_edit_action_committed(before, _canvas.capture_edit_state())
		_on_canvas_edited()
		_canvas.queue_redraw()
	_set_status("Переход ведёт в «%s»." % destination.display_name)
	_linking_exit_id = ""
	_load_dialog.hide()


func _unlink_selected_exit() -> void:
	if _linking_exit_id.is_empty():
		return
	var before: Dictionary = _canvas.capture_edit_state()
	if map_data.set_exit_target(_linking_exit_id, ""):
		_on_edit_action_committed(before, _canvas.capture_edit_state())
		_on_canvas_edited()
		_canvas.queue_redraw()
	_linking_exit_id = ""
	_load_dialog.hide()


func _find_linked_map(map_id: String) -> DungeonMap:
	# Не полагаемся на имя файла: карта идентифицируется полем id внутри JSON.
	var folder := DirAccess.open(_maps_dir())
	if folder == null:
		return null
	for filename in folder.get_files():
		if not filename.ends_with(".json"):
			continue
		var candidate := _read_map(_maps_dir().path_join(filename))
		if candidate != null and candidate.map_id == map_id:
			return candidate
	return null


func _on_door_tapped(door_id: String) -> void:
	if is_play_mode:
		return
	_canvas.finish_edit_stroke()
	for entity in map_data.entities:
		if str(entity.get("id", "")) == door_id and str(entity.get("type", "")) == "door":
			var attachment: Variant = entity.get("properties", {}).get("trap", {})
			if not attachment is Dictionary:
				attachment = {}
			_door_popup.configure(door_id, LockCatalog.required_key(entity), DungeonMap.door_trap_id(entity), str(attachment.get("message", "")), TrapCatalog.settings(entity))
			_door_popup.popup_centered_clamped(Vector2i(510, 460), 0.9)
			return


func _on_door_configuration_changed(door_id: String, lock_id: String, trap_message: String, remove_trap: bool, settings: Dictionary = {}) -> void:
	if is_play_mode:
		return
	var before := _canvas.capture_edit_state()
	var changed: bool = map_data.set_door_lock(door_id, lock_id)
	if remove_trap:
		changed = map_data.remove_door_trap(door_id) or changed
	else:
		changed = map_data.set_door_trap_message(door_id, trap_message) or changed
		if not settings.is_empty():
			changed = map_data.set_trap_configuration(door_id, settings) or changed
	if changed:
		_on_edit_action_committed(before, _canvas.capture_edit_state())
		_on_canvas_edited()
		_canvas.queue_redraw()


func _on_trap_tapped(entity_id: String) -> void:
	if is_play_mode or map_data == null:
		return
	_canvas.finish_edit_stroke()
	for entity in map_data.entities:
		if str(entity.get("id", "")) == entity_id and str(entity.get("type", "")) == "trap" and TrapCatalog.from_entity(entity) != null:
			_trap_popup.configure(entity)
			_trap_popup.popup_centered_clamped(Vector2i(400, 200), 0.9)
			return


func _on_trap_configuration_changed(entity_id: String, settings: Dictionary) -> void:
	if is_play_mode or map_data == null:
		return
	var before: Dictionary = _canvas.capture_edit_state()
	if map_data.set_trap_configuration(entity_id, settings):
		_on_edit_action_committed(before, _canvas.capture_edit_state())
		_on_canvas_edited()
		_canvas.queue_redraw()


func _on_chest_tapped(chest_id: String) -> void:
	if is_play_mode:
		return
	_canvas.finish_edit_stroke()
	for entity in map_data.entities:
		if str(entity.get("id", "")) == chest_id and str(entity.get("type", "")) == "chest":
			_chest_popup.configure(chest_id, DungeonMap.chest_contents(entity), DungeonMap.chest_gold_amount(entity), false, DungeonMap.chest_is_random(entity), bool(entity.get("properties", {}).get("hidden", false)), DungeonMap.chest_item_quantities(entity))
			_chest_popup.popup_centered_clamped(Vector2i(470, 530), 0.9)
			return


func _on_chest_contents_changed(chest_id: String, contents: Array[String], gold_amount: int, random_mode: bool, hidden: bool, quantities: Dictionary) -> void:
	if is_play_mode:
		return
	var before := _canvas.capture_edit_state()
	if map_data.set_chest_contents(chest_id, contents, gold_amount, random_mode, hidden, quantities):
		_on_edit_action_committed(before, _canvas.capture_edit_state())
		_on_canvas_edited()
		_canvas.queue_redraw()


func _on_monster_tapped(monster_entity_id: String) -> void:
	if is_play_mode:
		return
	_canvas.finish_edit_stroke()
	for entity in map_data.entities:
		if str(entity.get("id", "")) == monster_entity_id and str(entity.get("type", "")) == "monster":
			_monster_loot_popup.configure(monster_entity_id, DungeonMap.monster_loot_contents(entity), DungeonMap.monster_gold_amount(entity), true, DungeonMap.monster_loot_is_random(entity), bool(entity.get("properties", {}).get("hidden", false)), DungeonMap.monster_item_quantities(entity), DungeonMap.monster_party_ids(entity))
			_monster_loot_popup.popup_centered_clamped(Vector2i(470, 630), 0.9)
			return


func _on_monster_configuration_changed(monster_entity_id: String, party: Array[String], contents: Array[String], gold_amount: int, random_mode: bool, hidden: bool, quantities: Dictionary) -> void:
	if is_play_mode:
		return
	var before := _canvas.capture_edit_state()
	var changed: bool = map_data.set_monster_party(monster_entity_id, party)
	changed = map_data.set_monster_loot(monster_entity_id, contents, gold_amount, random_mode, hidden, quantities) or changed
	if changed:
		_on_edit_action_committed(before, _canvas.capture_edit_state())
		_on_canvas_edited()
		_canvas.queue_redraw()


func _on_tool_button_pressed(button: Button, kind: String) -> void:
	if _touch_info.consume_long_press(button):
		return
	_set_tool(kind)


func _set_tool(kind: String) -> void:
	selected_tool = kind
	_canvas.set_selected_tool(kind)
	for key in _palette_buttons.keys():
		var button: Button = _palette_buttons[key]
		var active: bool = key == kind
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#476b74") if active else Color("#2a3a48")
		style.border_width_left = 3 if active else 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.border_color = Color("#e8c58a") if active else Color("#44525d")
		style.corner_radius_top_left = 6
		style.corner_radius_bottom_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.content_margin_left = 6
		style.content_margin_top = 6
		style.content_margin_right = 6
		style.content_margin_bottom = 6
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.modulate = Color(1, 1, 1, 1) if not is_play_mode else Color(1, 1, 1, 0.55)


func _on_move_selection_changed(description: String) -> void:
	if description.is_empty():
		_set_status("Захват отменён.")
	else:
		_set_status("Захвачено: %s. Тапни по новой клетке или по исходной для отмены." % description)


func _on_move_failed() -> void:
	_set_status("Перенос невозможен: целевая клетка занята или не подходит.")


func _on_placement_rejected(message: String) -> void:
	_set_status(message)
	_game_notice.show()
	_game_notice.show_message(message)


func _toggle_grid(value: bool) -> void:
	_canvas.show_grid = value
	var popup := _layers_menu.get_popup()
	popup.set_item_checked(popup.get_item_index(VIEW_GRID), value)
	_canvas.queue_redraw()


func _fit_map() -> void:
	_canvas.fit_to_view()


func _generate_map_name() -> void:
	if is_play_mode or map_data == null:
		return
	var new_name := DungeonMap.random_display_name(map_data.display_name)
	_name_input.text = new_name
	_on_name_changed(new_name)


func _on_name_changed(value: String) -> void:
	if map_data != null:
		map_data.display_name = value
		_mark_dirty()


func _on_edit_action_committed(before: Dictionary, after: Dictionary) -> void:
	if is_play_mode or before == after:
		return
	_undo_stack.append({"before": before, "after": after})
	if _undo_stack.size() > HISTORY_LIMIT:
		_undo_stack.pop_front()
	_redo_stack.clear()
	_update_history_buttons()


func _undo_edit() -> void:
	if is_play_mode:
		return
	_canvas.finish_edit_stroke()
	if _undo_stack.is_empty():
		return
	var action: Dictionary = _undo_stack.pop_back()
	_canvas.restore_edit_state(action["before"])
	_redo_stack.append(action)
	_update_history_buttons()
	_on_canvas_edited()
	_set_status("Действие отменено")


func _redo_edit() -> void:
	if is_play_mode:
		return
	_canvas.finish_edit_stroke()
	if _redo_stack.is_empty():
		return
	var action: Dictionary = _redo_stack.pop_back()
	_canvas.restore_edit_state(action["after"])
	_undo_stack.append(action)
	_update_history_buttons()
	_on_canvas_edited()
	_set_status("Действие повторено")


func _update_history_buttons() -> void:
	_undo_button.disabled = is_play_mode or _undo_stack.is_empty()
	_redo_button.disabled = is_play_mode or _redo_stack.is_empty()


func _on_canvas_edited() -> void:
	_mark_dirty()
	_refresh_stats()


func _mark_dirty() -> void:
	if is_play_mode:
		return
	_clear_save_feedback()
	_schedule_reachability_refresh()
	is_dirty = true
	_set_status("Изменения не сохранены • Ctrl+S для сохранения")


func _set_status(message: String) -> void:
	if _last_log_message == message:
		return
	_last_log_message = message
	if _log_console != null:
		_log_console.append_text("[%s] %s\n" % [Time.get_time_string_from_system(), message])


## Боевые события не проходят через _set_status: одинаковые удары не
## должны исчезать из журнала из-за дедупликации строк состояния.
func _append_combat_log(message: String) -> void:
	if _log_console == null or message.is_empty():
		return
	_log_console.append_text("[%s] %s\n" % [Time.get_time_string_from_system(), message])


func _toggle_log_console() -> void:
	_floating_console.set_open(not _floating_console.is_open())


func _on_console_visibility_changed(opened: bool) -> void:
	_log_open = opened
	var config := ConfigFile.new()
	config.load(EDITOR_SETTINGS_PATH)
	config.set_value("interface", "show_console", opened)
	config.save(EDITOR_SETTINGS_PATH)
	if _settings_menu != null:
		var popup := _settings_menu.get_popup()
		var index: int = popup.get_item_index(SETTINGS_CONSOLE)
		if index >= 0:
			popup.set_item_checked(index, opened)
	if _game_system_menu != null:
		_game_system_menu.sync_console(opened)


func _set_console_from_game_menu(enabled: bool) -> void:
	_floating_console.set_open(enabled)


func _request_new() -> void:
	if is_play_mode:
		return
	_size_preset.select(0)
	_width_input.set_value_no_signal(16)
	_height_input.set_value_no_signal(16)
	_new_dialog.popup_centered()


func _new_map() -> void:
	var width := int(_width_input.value)
	var height := int(_height_input.value)
	_set_map(DungeonMap.create_blank(width, height))
	_set_status("Создана пустая карта %d×%d." % [width, height])


func _maps_dir() -> String:
	return _editor_maps_directory


## На устройстве запоминаем только ID сохранённой карты, не игровые данные.
func _remember_last_map(map_id: String) -> void:
	var config := ConfigFile.new()
	config.load(EDITOR_SETTINGS_PATH)
	config.set_value("editor", "last_map_id", map_id)
	if config.save(EDITOR_SETTINGS_PATH) != OK:
		_set_status("Не удалось запомнить последнюю карту")


func _restore_last_map() -> bool:
	var config := ConfigFile.new()
	if config.load(EDITOR_SETTINGS_PATH) != OK:
		return false
	var saved_id := str(config.get_value("editor", "last_map_id", ""))
	if saved_id.is_empty() or not saved_id.is_valid_filename():
		return false
	var path := _maps_dir().path_join(saved_id + ".json")
	if not FileAccess.file_exists(path):
		return false
	var saved_map := _read_map(path)
	if saved_map == null or saved_map.map_id != saved_id:
		return false
	_set_map(saved_map)
	_set_status("Открыта последняя карта: " + saved_map.display_name)
	return true


func _forget_last_map_if_deleted(path: String) -> void:
	var config := ConfigFile.new()
	if config.load(EDITOR_SETTINGS_PATH) != OK:
		return
	if str(config.get_value("editor", "last_map_id", "")) != path.get_file().get_basename():
		return
	config.set_value("editor", "last_map_id", null)
	config.save(EDITOR_SETTINGS_PATH)


func _ensure_maps_dir() -> bool:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_maps_dir())) == OK


func _write_map(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("Ошибка записи: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(map_data.to_dict(), "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_set_status("Ошибка записи: " + error_string(write_error))
		return false
	return true


func _save_internal() -> void:
	if is_play_mode or standalone_game:
		return
	_clear_save_feedback()
	if not _ensure_maps_dir():
		_set_status("Не удалось создать папку карт")
		return
	var path := _maps_dir().path_join(map_data.map_id + ".json")
	if _write_map(path):
		is_dirty = false
		_remember_last_map(map_data.map_id)
		_set_status("Сохранено: " + path)
		_show_save_feedback()


func _refresh_save_button_caption() -> void:
	var confirmed: bool = _save_feedback_timer != null and not _save_feedback_timer.is_stopped()
	_save_button.text = "" if get_viewport_rect().size.x < 760 else ("Сохранено" if confirmed else "Сохранить")


func _show_save_feedback() -> void:
	_save_feedback_timer.start()
	_save_button.icon = SAVE_CONFIRMATION_ICON
	_save_button.self_modulate = Color(0.75, 1.0, 0.8)
	_save_button.tooltip_text = "Карта сохранена"
	_refresh_save_button_caption()


func _clear_save_feedback() -> void:
	if _save_button == null or _save_feedback_timer == null:
		return
	_save_feedback_timer.stop()
	_set_command_icon(_save_button, "save")
	_save_button.self_modulate = Color.WHITE
	_save_button.tooltip_text = "Сохранить карту (Ctrl+S)"
	_refresh_save_button_caption()


func _show_load() -> void:
	if is_play_mode:
		return
	_linking_exit_id = ""
	_pending_campaign_destination_path = ""
	_load_dialog.title = "Библиотека карт"
	_load_dialog.ok_button_text = "Загрузить"
	_library_actions.visible = true
	_campaign_link_actions.visible = false
	_campaign_link_label.visible = false
	_campaign_add_mode = false
	_unlink_stairs_button.visible = false
	_stairs_reward_button.hide()
	_refresh_library()
	if _load_paths.is_empty():
		_set_status("Библиотека пуста. Сначала сохрани карту.")
		return
	_load_dialog.popup_centered(Vector2i(720, 530))


func _refresh_library() -> void:
	_load_paths.clear()
	_load_list.clear()
	_preview_textures.clear()
	if not _ensure_maps_dir():
		_set_status("Не удалось открыть папку карт")
		return
	var folder := DirAccess.open(_maps_dir())
	if folder == null:
		return
	var files := folder.get_files()
	files.sort()
	for filename in files:
		if not filename.ends_with(".json"):
			continue
		var path := _maps_dir().path_join(filename)
		var data := _read_map(path)
		if data == null:
			continue
		var title := "%s\n%d × %d" % [data.display_name, data.width, data.height]
		var thumbnail := _make_preview(data)
		_preview_textures.append(thumbnail)
		_load_list.add_item(title, thumbnail)
		var idx := _load_list.item_count - 1
		_load_list.set_item_tooltip(idx, "%s\n%s" % [data.display_name, filename])
		_load_paths.append(path)
	if not _load_paths.is_empty():
		_load_list.select(0)


func _refresh_campaign_link_library() -> void:
	if _linking_exit_id.is_empty():
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var campaigns: Dictionary = _campaign_library.load_all(maps)
	if not _campaign_library.last_error.is_empty():
		_set_status(_campaign_library.last_error)
		_load_paths.clear()
		_load_list.clear()
		return
	var campaign: CampaignDefinition = null
	var occupied: Dictionary = {}
	for entry in campaigns.values():
		for id in entry.map_ids:
			occupied[id] = entry.campaign_id
		if entry.map_ids.has(map_data.map_id):
			campaign = entry
	_campaign_link_label.text = "Карты кампании: %s" % campaign.display_name if campaign != null else "Сначала создайте кампанию при привязке карты"
	var paths: Array[String] = _load_paths.duplicate()
	_load_paths.clear()
	_load_list.clear()
	_preview_textures.clear()
	for path in paths:
		var data: DungeonMap = _read_map(path)
		if data == null:
			continue
		if campaign != null:
			if _campaign_add_mode and occupied.has(data.map_id):
				continue
			if not _campaign_add_mode and not campaign.map_ids.has(data.map_id):
				continue
		else:
			if occupied.has(data.map_id):
				continue
		var thumbnail: ImageTexture = _make_preview(data)
		_preview_textures.append(thumbnail)
		_load_list.add_item("%s\n%d × %d" % [data.display_name, data.width, data.height], thumbnail)
		_load_paths.append(path)
	if not _load_paths.is_empty():
		_load_list.select(0)
	_load_dialog.ok_button_text = "Добавить и связать" if _campaign_add_mode else "Связать"


func _show_campaign_member_maps() -> void:
	if _linking_exit_id.is_empty():
		return
	_campaign_add_mode = false
	_refresh_library()
	_refresh_campaign_link_library()


func _show_campaign_add_map() -> void:
	if _linking_exit_id.is_empty():
		return
	_campaign_add_mode = true
	_refresh_library()
	_refresh_campaign_link_library()
	_campaign_link_label.text = "Карты вне кампаний"


func _create_campaign_link_map() -> void:
	if _linking_exit_id.is_empty():
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var campaign: CampaignDefinition = _campaign_library.campaign_for_map(map_data.map_id, maps)
	if campaign == null or not _campaign_library.last_error.is_empty():
		_set_status("Сначала создайте кампанию, связав существующую карту.")
		return
	var created: DungeonMap = DungeonMap.create_blank(16, 16)
	if not created.place_entity("player_spawn", 1, 1):
		return
	if not _ensure_maps_dir():
		return
	var path: String = _maps_dir().path_join(created.map_id + ".json")
	if FileAccess.file_exists(path):
		_set_status("Карта с этим идентификатором уже существует.")
		return
	var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if writer == null:
		_set_status("Не удалось создать файл карты.")
		return
	writer.store_string(JSON.stringify(created.to_dict(), "\t"))
	writer.flush()
	var write_error: int = writer.get_error()
	writer = null
	if write_error != OK or not _campaign_library.attach_map(campaign.campaign_id, created.map_id, SavedMapLibrary.load_all(_maps_dir())):
		DirAccess.remove_absolute(path)
		_set_status("Не удалось присоединить карту: %s" % _campaign_library.last_error)
		return
	_apply_exit_link(created)


func _make_preview(data: DungeonMap) -> ImageTexture:
	return MapPreview.make_preview(data)


func _read_map(path: String) -> DungeonMap:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return DungeonMap.from_dict(JSON.parse_string(file.get_as_text()))


func _selected_library_path() -> String:
	var selection := _load_list.get_selected_items()
	if selection.is_empty():
		return ""
	var idx: int = selection[0]
	if idx < 0 or idx >= _load_paths.size():
		return ""
	return _load_paths[idx]


func _load_activated(index: int) -> void:
	if index >= 0 and index < _load_paths.size():
		if not _linking_exit_id.is_empty():
			_load_list.select(index)
			_link_selected_exit()
		else:
			_load_dialog.hide()
			_load_from_path(_load_paths[index])


func _load_selected() -> void:
	if not _linking_exit_id.is_empty():
		_link_selected_exit()
		return
	var path := _selected_library_path()
	if not path.is_empty():
		_load_from_path(path)


func _confirm_if_dirty(action: Callable) -> void:
	if not is_dirty:
		action.call()
		return
	_pending_action = action
	_unsaved_dialog.popup_centered()


func _run_pending_action() -> void:
	if _pending_action.is_valid():
		_pending_action.call()
	_pending_action = Callable()


func _load_from_path(path: String) -> void:
	if is_play_mode:
		return
	_confirm_if_dirty(_load_from_path_confirmed.bind(path))


func _load_from_path_confirmed(path: String) -> void:
	var loaded_map := _read_map(path)
	if loaded_map == null:
		_set_status("Ошибка чтения карты: " + path)
		return
	_set_map(loaded_map)
	if path == _maps_dir().path_join(loaded_map.map_id + ".json"):
		_remember_last_map(loaded_map.map_id)
	_set_status("Загружено: " + path)


func _open_campaign_manager() -> void:
	if is_play_mode or map_data == null:
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var campaign: CampaignDefinition = _campaign_library.campaign_for_map(map_data.map_id, maps)
	if not _campaign_library.last_error.is_empty():
		_set_status(_campaign_library.last_error)
		_campaign_current_id = ""
		_show_campaign_diagnostics()
		return
	if campaign == null:
		_open_legacy_campaign_dialog(maps)
		return
	_campaign_current_id = campaign.campaign_id
	_refresh_campaign_manager()
	_campaign_dialog.popup_centered_clamped(Vector2i(650, 630), 0.9)


func _open_legacy_campaign_dialog(maps: Dictionary) -> void:
	if map_data == null or not maps.has(map_data.map_id):
		_set_status("Сначала сохраните карту в библиотеке.")
		return
	var campaigns: Dictionary = _campaign_library.load_all(maps)
	if not _campaign_library.last_error.is_empty():
		_set_status(_campaign_library.last_error)
		return
	_legacy_campaign_ids = _campaign_library.legacy_linked_maps(map_data.map_id, maps)
	_legacy_campaign_existing_ids.clear()
	_legacy_campaign_destination.clear()
	_legacy_campaign_destination.add_item("Создать кампанию")
	var sorted_campaigns: Array = campaigns.keys()
	sorted_campaigns.sort()
	for campaign_id in sorted_campaigns:
		_legacy_campaign_existing_ids.append(campaign_id)
		_legacy_campaign_destination.add_item((campaigns[campaign_id] as CampaignDefinition).display_name)
	_legacy_campaign_name.text = map_data.display_name
	_legacy_campaign_members.clear()
	for map_id in _legacy_campaign_ids:
		var owner: CampaignDefinition = null
		for entry in campaigns.values():
			if entry.map_ids.has(map_id):
				owner = entry
				break
		var label: String = (maps[map_id] as DungeonMap).display_name
		if owner != null:
			label += " [%s]" % owner.display_name
		_legacy_campaign_members.add_item(label)
		if owner == null:
			_legacy_campaign_members.select(_legacy_campaign_members.item_count - 1, false)
	_on_legacy_destination_changed(0)
	var available: Vector2i = get_window().size
	var dialog_size := Vector2i(mini(520, int(available.x * 0.82)), mini(460, int(available.y * 0.72)))
	_legacy_campaign_dialog.popup_centered(dialog_size)


func _on_legacy_destination_changed(_index: int) -> void:
	_legacy_campaign_name.editable = _legacy_campaign_destination.selected == 0
	_refresh_legacy_start_choices()


func _on_legacy_member_selected(_index: int, _selected: bool) -> void:
	_refresh_legacy_start_choices()


func _refresh_legacy_start_choices() -> void:
	var previously_selected: String = ""
	if _legacy_campaign_start.selected >= 0:
		previously_selected = str(_legacy_campaign_start.get_item_metadata(_legacy_campaign_start.selected))
	_legacy_campaign_start.clear()
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	for index in _legacy_campaign_members.get_selected_items():
		if index >= _legacy_campaign_ids.size():
			continue
		var id: String = _legacy_campaign_ids[index]
		if not maps.has(id):
			continue
		_legacy_campaign_start.add_item((maps[id] as DungeonMap).display_name)
		_legacy_campaign_start.set_item_metadata(_legacy_campaign_start.item_count - 1, id)
	var preferred: String = previously_selected if not previously_selected.is_empty() else map_data.map_id
	for index in range(_legacy_campaign_start.item_count):
		if str(_legacy_campaign_start.get_item_metadata(index)) == preferred:
			_legacy_campaign_start.select(index)
			break


func _confirm_legacy_campaign() -> void:
	if map_data == null or _legacy_campaign_start.selected < 0:
		_set_status("Выберите участников и стартовую карту.")
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var selected_ids: Array[String] = []
	for index in _legacy_campaign_members.get_selected_items():
		if index < _legacy_campaign_ids.size():
			selected_ids.append(_legacy_campaign_ids[index])
	if not selected_ids.has(map_data.map_id):
		_set_status("Текущая карта должна входить в кампанию.")
		return
	var destination_index: int = _legacy_campaign_destination.selected
	var existing_id: String = ""
	var start_id: String = str(_legacy_campaign_start.get_item_metadata(_legacy_campaign_start.selected))
	if destination_index > 0:
		if destination_index - 1 >= _legacy_campaign_existing_ids.size():
			return
		existing_id = _legacy_campaign_existing_ids[destination_index - 1]
		var campaign: CampaignDefinition = _campaign_library.load_campaign(existing_id, maps)
		if campaign == null:
			_set_status(_campaign_library.last_error)
			return
		start_id = campaign.start_map_id
	var created: CampaignDefinition = _campaign_library.assemble_legacy_campaign(_legacy_campaign_name.text, start_id, selected_ids, maps, existing_id)
	if created == null:
		_set_status(_campaign_library.last_error)
		return
	_legacy_campaign_dialog.hide()
	_set_status("Карты присоединены к кампании «%s»." % created.display_name)


func _campaign_map_path(map_id: String) -> String:
	var folder: DirAccess = DirAccess.open(_maps_dir())
	if folder == null:
		return ""
	for filename in folder.get_files():
		if not filename.ends_with(".json"):
			continue
		var path: String = _maps_dir().path_join(filename)
		var candidate: DungeonMap = _read_map(path)
		if candidate != null and candidate.map_id == map_id:
			return path
	return ""


func _show_campaign_diagnostics() -> void:
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var issues: Array[Dictionary] = _campaign_library.diagnose_graph(maps)
	var lines: Array[String] = []
	for issue in issues:
		if not _campaign_current_id.is_empty() and not str(issue["campaign_id"]).is_empty() and issue["campaign_id"] != _campaign_current_id:
			continue
		var severity: String = str(issue["severity"])
		var label_text: String = "Ошибка" if severity == "error" else ("Предупреждение" if severity == "warning" else "Сведения")
		var reference: String = str(issue["map_id"])
		if reference.is_empty():
			reference = str(issue["campaign_id"])
		lines.append("%s [%s]: %s" % [label_text, reference, issue["message"]])
	_campaign_diagnostics_text.text = "\n".join(lines) if not lines.is_empty() else "Ошибок и предупреждений не обнаружено."
	_campaign_diagnostics_dialog.popup_centered_clamped(Vector2i(660, 440), 0.9)


func _refresh_campaign_manager() -> void:
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var campaign: CampaignDefinition = _campaign_library.load_campaign(_campaign_current_id, maps)
	if campaign == null:
		_set_status(_campaign_library.last_error)
		_campaign_dialog.hide()
		return
	_campaign_title_input.text = campaign.display_name
	_campaign_list.clear()
	_campaign_start_choice.clear()
	_campaign_available_choice.clear()
	_campaign_member_paths.clear()
	_campaign_available_ids.clear()
	for map_id in campaign.map_ids:
		var data: DungeonMap = maps[map_id]
		var title: String = data.display_name
		_campaign_list.add_item("%s%s" % [title, " (старт)" if map_id == campaign.start_map_id else ""])
		_campaign_member_paths.append(_campaign_map_path(map_id))
		_campaign_start_choice.add_item(title)
		if map_id == campaign.start_map_id:
			_campaign_start_choice.select(_campaign_start_choice.item_count - 1)
	if not _campaign_member_paths.is_empty():
		_campaign_list.select(0)
	var campaigns: Dictionary = _campaign_library.load_all(maps)
	if not _campaign_library.last_error.is_empty():
		_set_status(_campaign_library.last_error)
		return
	var occupied: Dictionary = {}
	for entry in campaigns.values():
		for id in entry.map_ids:
			occupied[id] = true
	var free_ids: Array = maps.keys()
	free_ids.sort()
	for map_id in free_ids:
		if occupied.has(map_id):
			continue
		_campaign_available_ids.append(map_id)
		_campaign_available_choice.add_item((maps[map_id] as DungeonMap).display_name)


func _rename_campaign() -> void:
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var campaign: CampaignDefinition = _campaign_library.load_campaign(_campaign_current_id, maps)
	if campaign == null or not campaign.rename(_campaign_title_input.text):
		_set_status("Название кампании не может быть пустым.")
		return
	if not _campaign_library.save_campaign(campaign, maps):
		_set_status(_campaign_library.last_error)
		return
	_refresh_campaign_manager()


func _set_campaign_start() -> void:
	var index: int = _campaign_start_choice.selected
	if index < 0 or index >= _campaign_member_paths.size():
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var campaign: CampaignDefinition = _campaign_library.load_campaign(_campaign_current_id, maps)
	if campaign == null:
		_set_status(_campaign_library.last_error)
		return
	var selected: DungeonMap = _read_map(_campaign_member_paths[index])
	if selected == null:
		_set_status("Не удалось прочитать выбранную карту.")
		return
	if not campaign.set_start_map(selected.map_id) or not _campaign_library.save_campaign(campaign, maps):
		_set_status(_campaign_library.last_error)
		return
	_refresh_campaign_manager()


func _attach_campaign_map() -> void:
	var index: int = _campaign_available_choice.selected
	if index < 0 or index >= _campaign_available_ids.size():
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	if not _campaign_library.attach_map(_campaign_current_id, _campaign_available_ids[index], maps):
		_set_status(_campaign_library.last_error)
		return
	_refresh_campaign_manager()


func _open_campaign_selected_map() -> void:
	var selected: PackedInt32Array = _campaign_list.get_selected_items()
	if selected.is_empty() or selected[0] >= _campaign_member_paths.size():
		return
	var path: String = _campaign_member_paths[selected[0]]
	if path.is_empty():
		_set_status("Не удалось найти файл карты.")
		return
	_campaign_dialog.hide()
	_load_from_path(path)


func _request_campaign_detach() -> void:
	var selected: PackedInt32Array = _campaign_list.get_selected_items()
	if selected.is_empty() or selected[0] >= _campaign_member_paths.size():
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var candidate: DungeonMap = _read_map(_campaign_member_paths[selected[0]])
	var campaign: CampaignDefinition = _campaign_library.load_campaign(_campaign_current_id, maps)
	if candidate == null or campaign == null:
		_set_status("Не удалось прочитать выбранную карту или кампанию.")
		return
	if candidate.map_id == campaign.start_map_id:
		_set_status("Сначала назначьте другую стартовую карту.")
		return
	var sources: Array[String] = _campaign_library.incoming_links(candidate.map_id, maps, candidate.map_id)
	if not sources.is_empty():
		_set_status("Сначала уберите переход на карту из %s." % (maps[sources[0]] as DungeonMap).display_name)
		return
	_campaign_pending_remove = candidate.map_id
	_campaign_remove_confirm.dialog_text = "Исключить «%s» из кампании? Сама карта останется в библиотеке." % candidate.display_name
	_campaign_remove_confirm.popup_centered()


func _confirm_campaign_detach() -> void:
	if _campaign_pending_remove.is_empty():
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	if not _campaign_library.detach_map(_campaign_current_id, _campaign_pending_remove, maps):
		_set_status(_campaign_library.last_error)
	_campaign_pending_remove = ""
	_refresh_campaign_manager()


func _request_campaign_delete() -> void:
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var campaign: CampaignDefinition = _campaign_library.load_campaign(_campaign_current_id, maps)
	if campaign == null:
		return
	var count: int = 0
	for map_id in campaign.map_ids:
		count += _campaign_library.incoming_links(map_id, maps, map_id).size()
	_campaign_delete_confirm.dialog_text = "Удалить кампанию «%s»? Карты останутся в библиотеке, переходы между ними сохранятся. Входящих связей: %d." % [campaign.display_name, count]
	_campaign_delete_confirm.popup_centered()


func _confirm_campaign_delete() -> void:
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	if not _campaign_library.delete_campaign(_campaign_current_id, maps):
		_set_status(_campaign_library.last_error)
		return
	_campaign_current_id = ""
	_campaign_dialog.hide()
	_set_status("Кампания удалена. Карты сохранены в библиотеке.")


func _request_rename() -> void:
	var path := _selected_library_path()
	if path.is_empty():
		return
	var saved := _read_map(path)
	if saved == null:
		_set_status("Не удалось прочитать выбранную карту")
		return
	_rename_input.text = saved.display_name
	_rename_dialog.popup_centered()


func _rename_selected() -> void:
	var path := _selected_library_path()
	var new_name := _rename_input.text.strip_edges()
	if path.is_empty() or new_name.is_empty():
		_set_status("Название карты не может быть пустым")
		return
	var saved := _read_map(path)
	if saved == null:
		return
	saved.display_name = new_name
	if _write_saved_map(saved, path):
		if saved.map_id == map_data.map_id:
			map_data.display_name = new_name
			_name_input.text = new_name
		_set_status("Карта переименована: " + new_name)
		_refresh_library()


func _duplicate_selected() -> void:
	var path := _selected_library_path()
	if path.is_empty():
		return
	var original := _read_map(path)
	if original == null:
		return
	var copy := DungeonMap.from_dict(original.to_dict())
	copy.map_id = DungeonMap.create_blank().map_id
	copy.display_name = original.display_name + " (копия)"
	if _write_saved_map(copy, _maps_dir().path_join(copy.map_id + ".json")):
		_set_status("Создана копия: " + copy.display_name)
		_refresh_library()


func _request_delete() -> void:
	_delete_path = _selected_library_path()
	if _delete_path.is_empty():
		return
	var candidate: DungeonMap = _read_map(_delete_path)
	if candidate == null:
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	var owner: CampaignDefinition = _campaign_library.campaign_for_map(candidate.map_id, maps)
	if not _campaign_library.last_error.is_empty():
		_set_status(_campaign_library.last_error)
		return
	if owner != null:
		_set_status("Карта принадлежит кампании. Сначала исключите её из кампании.")
		return
	if not _campaign_library.incoming_links(candidate.map_id, maps, candidate.map_id).is_empty():
		_set_status("На карту ведут переходы. Сначала уберите входящие связи.")
		return
	_delete_dialog.dialog_text = "Удалить карту %s? Это действие нельзя отменить." % _load_list.get_item_text(_load_list.get_selected_items()[0]).replace("\n", " ")
	_delete_dialog.popup_centered()


func _delete_selected() -> void:
	if _delete_path.is_empty():
		return
	var candidate: DungeonMap = _read_map(_delete_path)
	var maps: Dictionary = SavedMapLibrary.load_all(_maps_dir())
	if candidate == null:
		return
	if _campaign_library.campaign_for_map(candidate.map_id, maps) != null or not _campaign_library.last_error.is_empty():
		_set_status("Нельзя удалить карту, принадлежащую кампании.")
		return
	if not _campaign_library.incoming_links(candidate.map_id, maps, candidate.map_id).is_empty():
		_set_status("На карту ведут переходы. Удаление отменено.")
		return
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(_delete_path))
	if err == OK:
		_forget_last_map_if_deleted(_delete_path)
		_set_status("Карта удалена из библиотеки")
		_refresh_library()
		if _load_paths.is_empty():
			_load_dialog.hide()
	else:
		_set_status("Не удалось удалить файл: %s" % err)
	_delete_path = ""


func _write_saved_map(saved: DungeonMap, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_set_status("Ошибка записи карты: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(saved.to_dict(), "\t"))
	file.close()
	return true


func _show_export() -> void:
	if is_play_mode:
		return
	_export_dialog.current_file = map_data.map_id + ".json"
	_export_dialog.popup_centered_ratio(0.8)


func _export_to_path(path: String) -> void:
	if _write_map(path):
		_set_status("Экспортировано: " + path)


func _show_import() -> void:
	if is_play_mode:
		return
	_import_dialog.popup_centered_ratio(0.8)


func _request_return_to_menu() -> void:
	if _trap_playback_active:
		return
	if standalone_game:
		_stop_play_mode()
	else:
		if is_play_mode:
			_stop_play_mode(false)
		_confirm_if_dirty(_emit_menu_requested)


func _emit_menu_requested() -> void:
	menu_requested.emit()


func _open_game_system_menu() -> void:
	if _trap_playback_active:
		return
	if not is_play_mode or game_session == null or _victory_view != null or _game_dialogue.visible or _inventory_view.visible or _ground_loot_view.visible or _game_system_menu.visible or _map_screen.visible:
		return
	_game_command_bar.visible = false
	_dpad.visible = false
	_game_system_menu.open_for(standalone_game, game_session.debug_open_map, _floating_console.is_open(), _can_save_progress())


func _close_game_system_menu() -> void:
	_game_system_menu.dismiss()
	if is_play_mode and _combat_active and _battle_view != null:
		var menu_button: Button = _battle_view.get_node_or_null("BattleMenuButton") as Button
		if menu_button != null:
			menu_button.grab_focus()
	elif is_play_mode and _victory_view == null:
		_game_command_bar.visible = true
		_dpad.visible = true
		_canvas.grab_focus()


func _can_save_progress() -> bool:
	if _trap_playback_active or not standalone_game or not is_play_mode or game_session == null:
		return false
	if _combat_active or _victory_view != null or game_session.is_party_defeated():
		return false
	return not game_session.progress_snapshot().is_empty()


func _save_progress() -> void:
	if not _can_save_progress():
		_game_system_menu.show_save_error("Сохранение сейчас недоступно.")
		return
	var maps: Dictionary = SavedMapLibrary.load_all(_progress_maps_directory)
	if not _progress_save_store.save_game(game_session, maps):
		_game_system_menu.show_save_error(_progress_save_store.last_error)
		return
	_close_game_system_menu()
	_game_notice.show_message("Прохождение сохранено")
	_set_status("Прохождение сохранено.")


func _leave_from_game_system_menu() -> void:
	_game_system_menu.dismiss()
	_stop_play_mode()


func _toggle_map_screen() -> void:
	if _trap_playback_active:
		return
	if _map_screen.visible:
		_map_screen.dismiss_by_player()
		return
	if not is_play_mode or game_session == null or _combat_active or _victory_view != null or _inventory_view.visible or _ground_loot_view.visible or _game_system_menu.visible or _game_dialogue.visible:
		return
	_map_screen.open_for(game_session, _minimap_enabled)
	_game_command_bar.visible = false
	_dpad.visible = false


func _on_map_closed() -> void:
	if is_play_mode and not _combat_active and _victory_view == null:
		_game_command_bar.visible = true
		_dpad.visible = true
		_canvas.grab_focus()


func _set_minimap_enabled(enabled: bool) -> void:
	_minimap_enabled = enabled
	_mini_map.visible = is_play_mode and enabled and not _combat_active and _victory_view == null
	if _mini_map.visible:
		_mini_overview.refresh()


func _refresh_map_overlays() -> void:
	if _mini_map.visible:
		_mini_overview.refresh()


func _set_test_open_map(enabled: bool) -> void:
	if standalone_game or game_session == null or not is_play_mode:
		return
	game_session.set_debug_open_map(enabled)
	_canvas.queue_redraw()
	_refresh_map_overlays()
	if _map_screen.visible:
		_map_screen.open_for(game_session, _minimap_enabled)


func _toggle_play_mode() -> void:
	if _trap_playback_active:
		return
	if is_play_mode:
		_stop_play_mode()
	else:
		_start_play_mode()


func _developer_session() -> GameSession:
	if not DeveloperMode.is_enabled() or standalone_game or map_data == null:
		return null
	if _developer_preview != null:
		return _developer_preview
	var temporary_map: DungeonMap = DungeonMap.from_dict(map_data.to_dict().duplicate(true))
	var session: GameSession = GameSession.start_for_party(temporary_map, _test_party_ids)
	if session == null:
		return null
	session.is_editor_test = true
	var saved: Dictionary = DeveloperMode.loadout(map_data.map_id, _test_party_ids)
	if not saved.is_empty() and not session.restore_party_state(saved):
		_set_status("Инвентарь разработчика не удалось восстановить")
	_developer_preview = session
	return session


func _open_developer_inventory() -> void:
	if not DeveloperMode.is_enabled() or standalone_game or is_play_mode or _developer_inventory == null:
		return
	var session: GameSession = _developer_session()
	if session != null:
		_developer_inventory.open_for(session)


func _on_developer_loadout_changed() -> void:
	if _developer_preview == null or map_data == null or not DeveloperMode.is_enabled():
		return
	if not DeveloperMode.save_loadout(map_data.map_id, _test_party_ids, _developer_preview.party_state_snapshot()):
		_set_status("Не удалось сохранить инвентарь разработчика")


func _start_play_mode() -> void:
	_clear_held_movement()
	_settings_dialog.hide()
	_clear_reachability()
	_pending_next_map = null
	var session: GameSession
	if standalone_game:
		session = _startup_game_session if _startup_game_session != null else GameSession.start_for_party(map_data, _startup_party_ids, false)
	else:
		var test_map: DungeonMap = DungeonMap.from_dict(map_data.to_dict().duplicate(true))
		session = GameSession.start_for_party(test_map, _test_party_ids, false)
		if session != null:
			session.is_editor_test = true
	if session == null:
		_set_status("Нельзя начать игру: на карте нет доступной точки старта героя." if standalone_game else "Нельзя начать тест: поставь на карте точку старта героя.")
		return
	if not standalone_game and DeveloperMode.is_enabled():
		var preview: GameSession = _developer_session()
		if preview != null and not session.restore_party_state(preview.party_state_snapshot()):
			_set_status("Не удалось восстановить инвентарь разработчика")
			return
	if standalone_game and _startup_campaign != null and not session.set_campaign(_startup_campaign):
		_set_status("Невозможно начать игру: стартовая карта не входит в кампанию.")
		return
	_startup_game_session = null
	## Камера редактора не принадлежит временной тестовой сессии.
	_editor_camera_offset = _canvas.camera_offset
	_editor_camera_zoom = _canvas.zoom
	game_session = session
	_inventory_view.dismiss()
	_ground_loot_view.dismiss()
	_game_system_menu.dismiss()
	_map_screen.dismiss()
	_pending_game_messages.clear()
	_active_game_message.clear()
	is_play_mode = true
	_canvas.set_game_session(session)
	_canvas.zoom = DungeonCanvas.PLAY_START_ZOOM
	_canvas.center_on_cell(session.player_pos)
	_mini_overview.show_session(session)
	_canvas.grab_focus()
	_update_mode_ui()
	# При входе из главного меню ожидаем фактический размер игрового поля.
	if standalone_game:
		call_deferred("_center_game_camera_after_layout")
	_refresh_stats()
	if not standalone_game:
		_set_status("Тест карты запущен. Прогресс временный.")
	if not session.last_event_message.is_empty():
		_set_status(session.last_event_message)
	_log_trigger_events()
	_collect_game_messages()


func _center_game_camera_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_play_mode and game_session != null:
		_canvas.center_on_cell(game_session.player_pos)


func _stop_play_mode(return_to_menu: bool = true) -> void:
	_trap_playback_active = false
	_clear_held_movement()
	_pending_next_map = null
	_remove_victory_view()
	_abort_combat()
	_game_notice.clear()
	_game_dialogue.dismiss()
	_inventory_view.dismiss()
	_ground_loot_view.dismiss()
	_game_system_menu.dismiss()
	_map_screen.dismiss()
	_mini_map.visible = false
	_pending_game_messages.clear()
	_active_game_message.clear()
	game_session = null
	is_play_mode = false
	_canvas.set_game_session(null)
	_canvas.map_data = map_data # Возвращаем исходную карту без отложенного fit_to_view().
	_canvas.zoom = _editor_camera_zoom
	_canvas.camera_offset = _editor_camera_offset
	_canvas.queue_redraw()
	_update_mode_ui()
	_refresh_stats()
	_schedule_reachability_refresh()
	if standalone_game and return_to_menu:
		menu_requested.emit()
	else:
		_set_status("Возврат в редактор. Карта не изменена.")


func _update_mode_ui() -> void:
	if is_play_mode or standalone_game:
		_clear_save_feedback()
	_editor_header.visible = not (is_play_mode or standalone_game)
	_apply_editor_panels()
	for control in [_file_menu, _settings_menu, _save_button, _undo_button, _redo_button, _layers_menu]:
		control.visible = not is_play_mode and not standalone_game
	_floating_console.set_game_controls_visible(is_play_mode or standalone_game)
	_play_button.text = "Редактор" if is_play_mode else "Тест"
	_set_command_icon(_play_button, "editor" if is_play_mode else "test")
	_play_button.tooltip_text = "Выйти из теста и вернуться к редактированию" if is_play_mode else "Проверить текущую карту без сохранения игрового прогресса"
	_dpad.visible = is_play_mode
	_hero_hud.visible = is_play_mode
	_game_command_bar.visible = is_play_mode and not _combat_active and _victory_view == null
	_mini_map.visible = is_play_mode and _minimap_enabled and not _combat_active and _victory_view == null
	_game_notice.visible = is_play_mode
	for control in _editor_controls:
		if control is BaseButton:
			(control as BaseButton).disabled = is_play_mode
		elif control is LineEdit:
			(control as LineEdit).editable = not is_play_mode
		control.modulate = Color(1, 1, 1, 0.60) if is_play_mode else Color(1, 1, 1, 1)
	_set_tool(selected_tool)
	_update_history_buttons()


func _open_character(member: HeroState) -> void:
	if _trap_playback_active:
		return
	if _arsenal_view.visible:
		return
	if not is_play_mode or game_session == null or _combat_active or _victory_view != null or _game_dialogue.visible or _inventory_view.visible or _ground_loot_view.visible or _game_system_menu.visible or _map_screen.visible:
		return
	_arsenal_view.open_for(member)
	_game_command_bar.visible = false
	_dpad.visible = false


func _on_arsenal_closed() -> void:
	if is_play_mode and not _combat_active and _victory_view == null:
		_game_command_bar.visible = true
		_dpad.visible = true
		_canvas.grab_focus()


func _toggle_inventory() -> void:
	if _trap_playback_active:
		return
	if not is_play_mode or game_session == null or _combat_active or _victory_view != null or _game_dialogue.visible or _game_system_menu.visible or _map_screen.visible:
		return
	if _inventory_view.visible:
		_inventory_view.close_by_player()
	else:
		_inventory_view.open_for(game_session)
		_game_command_bar.visible = false
		_dpad.visible = false


func _open_ground_loot(container_id: String) -> void:
	if _trap_playback_active:
		return
	if not is_play_mode or game_session == null or _combat_active or _victory_view != null or _game_dialogue.visible or _inventory_view.visible or _ground_loot_view.visible or _game_system_menu.visible or _map_screen.visible:
		return
	var container: Dictionary = game_session.ground_container_by_id(container_id)
	if container.is_empty():
		return
	var cell := Vector2i(int(container["x"]), int(container["y"]))
	if absi(cell.x - game_session.player_pos.x) + absi(cell.y - game_session.player_pos.y) > 1:
		return
	_ground_loot_view.open_for(game_session, container_id)
	_game_command_bar.visible = false
	_dpad.visible = false


func _on_ground_loot_closed() -> void:
	if is_play_mode and not _combat_active and _victory_view == null:
		_game_command_bar.visible = true
		_dpad.visible = true
		_canvas.grab_focus()


func _on_ground_loot_changed() -> void:
	_canvas.queue_redraw()
	_refresh_stats()
	_refresh_map_overlays()


func _on_inventory_closed() -> void:
	if is_play_mode and not _combat_active and _victory_view == null:
		_game_command_bar.visible = true
		_dpad.visible = true
		_canvas.grab_focus()


func _on_inventory_use_requested(item_id: String, bag_index: int) -> void:
	if not is_play_mode or game_session == null or not _inventory_view.visible:
		return
	var previous_vision: int = game_session.hero.vision_bonus if game_session.hero != null and game_session.hero.has_vision_effect() else 0
	var result: Dictionary = game_session.use_item(item_id, game_session._inventory_equipment_member(), bag_index)
	_inventory_view.show_use_result(item_id, str(result.get("message", "")))
	if bool(result.get("used", false)):
		_refresh_stats()
		var current_vision: int = game_session.hero.vision_bonus if game_session.hero != null and game_session.hero.has_vision_effect() else 0
		if current_vision > 0 and _canvas.zoom != DungeonCanvas.PLAY_VISION_MIN_ZOOM:
			_canvas.zoom = DungeonCanvas.PLAY_VISION_MIN_ZOOM
			_canvas.center_on_cell(game_session.player_pos)
		if previous_vision != current_vision:
			_canvas.queue_redraw()
			_refresh_map_overlays()


func _show_game_event(message: String) -> void:
	# Очевидные действия попадают лишь в технический лог.
	_set_status(message)
	if message.begins_with("Дверь заперта"):
		_game_notice.show_message("Нужен ключ")


func _collect_game_messages() -> void:
	if game_session == null:
		return
	for event in game_session.take_message_events():
		_pending_game_messages.append(event)
	_show_next_game_message()


func _show_next_game_message() -> void:
	if _game_dialogue.visible or _pending_game_messages.is_empty():
		return
	var event: Dictionary = _pending_game_messages.pop_front()
	_active_game_message = event
	if str(event.get("activation", "")) in ["trap_choice", "trap_reaction", "door_trap", "trap_result"]:
		_clear_held_movement()
	_game_dialogue.show_event(event)


func _on_trap_choice_selected(choice: String, actor_index: int) -> void:
	_active_game_message = {}
	if not is_play_mode or game_session == null or not game_session.has_pending_trap_choice():
		return
	_clear_held_movement()
	var moving_session: GameSession = game_session
	var previous_pos: Vector2i = moving_session.player_pos
	var moved: bool = moving_session.resolve_pending_trap_choice(choice, actor_index, true)
	if choice in ["back", "forward"]:
		_canvas.grab_focus()
		_complete_player_move(moving_session, previous_pos, moved, true)
		return
	if choice == "cancel":
		_canvas.grab_focus()
		_show_next_game_message()
		return
	if moving_session.has_pending_door_trap() or moving_session.has_pending_trap_choice():
		_collect_game_messages()
		return
	_canvas.grab_focus()
	_complete_player_move(moving_session, previous_pos, moved)


func _on_game_dialogue_closed() -> void:
	var closed_event: Dictionary = _active_game_message
	_active_game_message = {}
	if str(closed_event.get("activation", "")) == "door_trap" and is_play_mode and game_session != null:
		var moving_session: GameSession = game_session
		var previous_pos: Vector2i = moving_session.player_pos
		var shot := AudioStreamPlayer.new()
		shot.stream = DOOR_CROSSBOW_SOUND
		add_child(shot)
		shot.finished.connect(shot.queue_free)
		shot.play()
		var moved: bool = moving_session.resolve_pending_door_trap()
		_refresh_stats()
		_flash_party_damage()
		_complete_player_move(moving_session, previous_pos, moved, true)
		return
	if not _pending_game_messages.is_empty():
		_show_next_game_message()
	elif is_play_mode and game_session != null and game_session.has_pending_encounter():
		_start_combat()
	elif game_session != null and game_session.is_completed:
		_show_victory_view()
	elif is_play_mode:
		_canvas.grab_focus()


## Триггеры пока отправляют события только в консоль разработчика.
## Авторские сообщения выводятся отдельно, только по указанию автора.
func _log_trigger_events() -> void:
	if game_session == null:
		return
	for event in game_session.take_trigger_events():
		var cell: Vector2i = event["position"]
		var event_id := str(event["event_id"])
		if event_id.is_empty():
			_set_status("Сработал триггер на клетке (%d, %d)." % [cell.x, cell.y])
		else:
			_set_status("Сработал триггер «%s» на клетке (%d, %d)." % [event_id, cell.x, cell.y])


func _try_move_player(dx: int, dy: int) -> void:
	if _trap_playback_active:
		return
	if not is_play_mode or game_session == null or _combat_active or _victory_view != null or _game_dialogue.visible or _inventory_view.visible or _ground_loot_view.visible or _game_system_menu.visible or _map_screen.visible:
		return
	if _canvas.is_player_moving():
		return
	var previous_pos: Vector2i = game_session.player_pos
	var moving_session: GameSession = game_session
	var moved := moving_session.move_by(dx, dy, true)
	if moving_session.last_move_detected_trap:
		_clear_held_movement()
		_canvas.queue_redraw()
		_refresh_map_overlays()
		return
	if game_session.has_pending_encounter():
		_collect_game_messages()
		if not _game_dialogue.visible:
			_start_combat()
		return
	if game_session.has_pending_door_trap() or game_session.has_pending_trap_choice():
		_collect_game_messages()
		return
	_complete_player_move(moving_session, previous_pos, moved)


func _complete_player_move(moving_session: GameSession, previous_pos: Vector2i, moved: bool, wait_until_arrival: bool = false) -> void:
	var visuals: Array[Dictionary] = moving_session.take_trap_visual_events()
	var played_effect: bool = _canvas.play_trap_visuals(visuals, moving_session.player_pos) if not visuals.is_empty() else false
	if played_effect:
		_trap_playback_active = true
		_clear_held_movement()
		await _canvas.trap_playback_finished
		if not _trap_playback_active or not is_play_mode or game_session != moving_session:
			return
		_trap_playback_active = false
		if not moving_session.pending_chest_id.is_empty() and not moving_session.is_party_defeated():
			moving_session.open_pending_chest()
	elif moved:
		if (game_session.hero == null or not game_session.hero.has_vision_effect()) and _canvas.zoom < DungeonCanvas.PLAY_MIN_ZOOM:
			_canvas.zoom = DungeonCanvas.PLAY_MIN_ZOOM
		_canvas.animate_player_step(previous_pos, moving_session.player_pos)
		if not moving_session.pending_chest_id.is_empty():
			# Лишь после завершения шага появляется открытый сундук и награда.
			await _canvas.player_step_finished
			if not is_play_mode or game_session != moving_session:
				return
			if not moving_session.is_party_defeated():
				moving_session.open_pending_chest()
		elif wait_until_arrival or moving_session.has_party_damage_events():
			await _canvas.player_step_finished
			if not is_play_mode or game_session != moving_session:
				return
		elif not moving_session.ground_container_at(moving_session.player_pos).is_empty():
			await _canvas.player_step_finished
			if not is_play_mode or game_session != moving_session:
				return
	# Теперь сундук обновляется после прибытия, не во время движения.
	_canvas.queue_redraw()
	_refresh_map_overlays()
	_refresh_stats()
	_flash_party_damage()
	var trap_result: String = game_session.take_trap_result_message()
	if not trap_result.is_empty():
		_game_notice.show_message(trap_result)
	var casualties: Array[HeroState] = game_session.take_casualty_events()
	if not casualties.is_empty():
		_show_defeat_view(casualties)
		return
	_log_trigger_events()
	_collect_game_messages()
	if _game_dialogue.visible:
		return
	if game_session.is_completed:
		_show_victory_view()
		return
	var ground: Dictionary = game_session.ground_container_at(game_session.player_pos)
	if not ground.is_empty():
		_open_ground_loot(str(ground["id"]))
		return
	if not game_session.last_event_message.is_empty():
		_show_game_event(game_session.last_event_message)


## При встрече камера приближается к противнику, затем открывается
## отдельная сцена боя поверх карты. Исследование остаётся в памяти.
func _start_combat() -> void:
	_combat_active = true
	_game_command_bar.visible = false
	_dpad.visible = false
	_mini_map.visible = false
	_hero_hud.visible = false
	_game_notice.clear()
	_pre_combat_zoom = _canvas.zoom
	var original_offset: Vector2 = _canvas.camera_offset
	var focus_zoom: float = minf(_pre_combat_zoom * 1.25, DungeonCanvas.PLAY_MAX_ZOOM * 1.4)
	var target_center: Vector2 = (Vector2(game_session.encounter_target) + Vector2.ONE * 0.5) * DungeonCanvas.TILE_SIZE
	var target_offset: Vector2 = _canvas.size * 0.5 - target_center * focus_zoom
	_combat_camera_tween = create_tween()
	_combat_camera_tween.tween_method(
		_animate_combat_camera.bind(_pre_combat_zoom, focus_zoom, original_offset, target_offset),
		0.0, 1.0, 0.28
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_combat_camera_tween.finished.connect(_show_combat_view)


func _animate_combat_camera(progress: float, from_zoom: float, to_zoom: float, from_offset: Vector2, to_offset: Vector2) -> void:
	_canvas.zoom = lerpf(from_zoom, to_zoom, progress)
	_canvas.camera_offset = from_offset.lerp(to_offset, progress)
	_canvas.queue_redraw()


func _show_combat_view() -> void:
	if not _combat_active or game_session == null:
		return
	_battle_view = BATTLE_VIEW_SCENE.instantiate() as BattleView
	_canvas_host.add_child(_battle_view)
	if not standalone_game:
		_add_battle_menu_button()
	_battle_view.battle_won.connect(_finish_combat)
	_battle_view.battle_lost.connect(_lose_combat)
	_battle_view.shield_broken.connect(_on_battle_shield_broken)
	_battle_view.combat_log_line.connect(_append_combat_log)
	_battle_view.item_use_requested.connect(_on_battle_item_requested)
	var monsters: Array[MonsterDefinition] = game_session.pending_monster_definitions()
	var main_monster: MonsterDefinition = monsters[0] if not monsters.is_empty() else game_session.pending_monster_definition()
	var second_monster: MonsterDefinition = monsters[1] if monsters.size() > 1 else null
	_battle_view.begin(CombatSession.new(main_monster, game_session.hero, second_monster, game_session.trap_random.randi(), game_session.party), game_session.hero)
	_battle_view.bind_combat_items(game_session)



func _add_battle_menu_button() -> void:
	var button := Button.new()
	button.name = "BattleMenuButton"
	button.icon = preload("res://assets/hud/menu.png")
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = "Меню"
	button.custom_minimum_size = Vector2(44, 44)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = -60.0
	button.offset_right = -16.0
	button.offset_top = 12.0
	button.offset_bottom = 56.0
	button.z_index = 10
	button.pressed.connect(_open_game_system_menu)
	_battle_view.add_child(button)


func _on_battle_item_requested(item_id: String) -> void:
	if game_session == null or _battle_view == null or not _combat_active:
		return
	var outcome: Dictionary = game_session.use_combat_item(item_id, _battle_view.current_battle_state())
	_battle_view.show_combat_item_result(outcome, game_session)
	if bool(outcome.get("used", false)):
		_append_combat_log("    %s: %s · HP %d/%d" % [game_session.hero.definition.display_name,
			str(outcome.get("message", "Предмет применён")), game_session.hero.health,
			game_session.hero.effective_max_health()])
		_refresh_stats()


func _on_battle_shield_broken(_item_id: String, member: HeroState) -> void:
	if game_session != null:
		game_session.resolve_broken_shield(member)
		_update_hero_hud()


func _finish_combat() -> void:
	if not _combat_active or game_session == null or _battle_view == null:
		return
	var battle: BattleState = _battle_view.current_battle_state()
	if battle == null or not battle.is_victory:
		return
	# Победа двигает игровую позицию, а визуальное перемещение надо запускать отдельно.
	var previous_pos: Vector2i = game_session.player_pos
	var moved: bool = game_session.win_pending_encounter(battle)
	if game_session.last_move_detected_trap:
		_clear_held_movement()
	if _battle_view != null:
		_battle_view.queue_free()
		_battle_view = null
	_combat_active = false
	_canvas.zoom = _pre_combat_zoom
	_game_command_bar.visible = true
	_dpad.visible = true
	_mini_map.visible = _minimap_enabled
	_hero_hud.visible = true
	_canvas.grab_focus()
	if game_session.has_trap_visual_events():
		_complete_player_move(game_session, previous_pos, moved, true)
		return
	if moved:
		_canvas.animate_player_step(previous_pos, game_session.player_pos)
	else:
		_canvas.center_on_cell(game_session.player_pos)
	_canvas.queue_redraw()
	_refresh_map_overlays()
	_refresh_stats()
	_flash_party_damage()
	var trap_result: String = game_session.take_trap_result_message()
	if not trap_result.is_empty():
		_game_notice.show_message(trap_result)
	var casualties: Array[HeroState] = game_session.take_casualty_events()
	if not casualties.is_empty():
		_show_defeat_view(casualties)
		return
	_log_trigger_events()
	_collect_game_messages()
	if _game_dialogue.visible:
		return
	if game_session.is_completed:
		_show_victory_view()
		return
	if not game_session.last_event_message.is_empty():
		_show_game_event(game_session.last_event_message)
	elif not moved and not game_session.last_move_detected_trap:
		_set_status("Монстр побеждён, но клетка пока недоступна.")


func _lose_combat() -> void:
	if not _combat_active or game_session == null:
		return
	if _battle_view != null:
		_battle_view.queue_free()
		_battle_view = null
	_combat_active = false
	_canvas.zoom = _pre_combat_zoom
	game_session.record_casualties()
	game_session.abandon_pending_encounter()
	_canvas.center_on_cell(game_session.player_pos)
	_canvas.queue_redraw()
	_refresh_stats()
	_show_defeat_view(game_session.take_casualty_events())


func _show_defeat_view(casualties: Array[HeroState]) -> void:
	if not is_play_mode or game_session == null or casualties.is_empty() or _victory_view != null:
		return
	_clear_held_movement()
	_dpad.visible = false
	_game_command_bar.visible = false
	_mini_map.visible = false
	_hero_hud.visible = false
	_game_notice.clear()
	_pending_next_map = null
	_victory_view = VICTORY_VIEW_SCENE.instantiate() as VictoryView
	add_child(_victory_view)
	_victory_view.editor_requested.connect(_stop_play_mode)
	if standalone_game:
		_victory_view.set_exit_text("В меню")
	if game_session.is_party_defeated():
		_victory_view.show_game_over(game_session.steps, casualties)
	else:
		_victory_view.retry_requested.connect(_continue_after_defeat)
		_victory_view.show_party_defeat(game_session.steps, casualties, game_session.hero)


func _continue_after_defeat() -> void:
	if game_session == null or game_session.is_party_defeated() or _victory_view == null or not _victory_view.is_party_defeat:
		return
	_remove_victory_view()
	_game_command_bar.visible = true
	_dpad.visible = true
	_mini_map.visible = _minimap_enabled
	_hero_hud.visible = true
	_refresh_stats()
	_refresh_map_overlays()
	_canvas.grab_focus()
	_log_trigger_events()
	_collect_game_messages()
	if _game_dialogue.visible:
		return
	if game_session.is_completed:
		_show_victory_view()
		return
	var ground: Dictionary = game_session.ground_container_at(game_session.player_pos)
	if not ground.is_empty():
		_open_ground_loot(str(ground["id"]))
	if not game_session.last_event_message.is_empty():
		_show_game_event(game_session.last_event_message)


func _campaign_transition_allowed(map_id: String) -> bool:
	if game_session == null or not game_session.is_map_in_campaign(map_id):
		return false
	if game_session.campaign_id.is_empty():
		return true
	var maps: Dictionary = SavedMapLibrary.load_all(_progress_maps_directory)
	var campaign: CampaignDefinition = _campaign_library.load_campaign(game_session.campaign_id, maps)
	return campaign != null and campaign.map_ids.has(game_session.map_data.map_id) and campaign.map_ids.has(map_id)


func _show_victory_view() -> void:
	if not is_play_mode or game_session == null or _victory_view != null or _game_dialogue.visible:
		return
	_pending_next_map = null
	var target_id: String = game_session.next_map_id()
	if not target_id.is_empty():
		if not _campaign_transition_allowed(target_id):
			game_session.cancel_exit_transition()
			_game_notice.show_message("Переход за пределы кампании запрещён")
			_set_status("Целевая карта не принадлежит текущей кампании.")
			return
		var linked: DungeonMap = game_session.known_map(target_id)
		if linked == null:
			linked = _find_linked_map(target_id)
		if linked == null:
			game_session.cancel_exit_transition()
			_game_notice.show_message("Подземелье для перехода не найдено")
			_set_status("Связанное подземелье не найдено. Проверь выбор карты у выхода.")
			return
		if not game_session.can_enter_next_map(linked):
			var is_return: bool = str(game_session.current_exit().get("type", "")) == "stairs_up"
			game_session.cancel_exit_transition()
			_game_notice.show_message("Место подъёма недоступно" if is_return else "Точка появления героя недоступна")
			_set_status("Переход невозможен: проверь лестницу на предыдущем этаже." if is_return else "Переход невозможен: проверь точку старта на целевой карте.")
			return
		_pending_next_map = linked
	_dpad.visible = false
	_game_command_bar.visible = false
	_mini_map.visible = false
	_hero_hud.visible = false
	_game_notice.clear()
	_victory_view = VICTORY_VIEW_SCENE.instantiate() as VictoryView
	add_child(_victory_view)
	if _pending_next_map != null:
		_victory_view.retry_requested.connect(_enter_next_floor)
	else:
		_victory_view.retry_requested.connect(_restart_test_after_victory)
	_victory_view.editor_requested.connect(_stop_play_mode)
	if standalone_game:
		_victory_view.set_exit_text("В меню")
	if _pending_next_map != null:
		_victory_view.show_floor_transition(game_session.steps, _pending_next_map.display_name)
		_set_status("Следующий уровень: %s." % _pending_next_map.display_name)
	else:
		_victory_view.show_result(game_session.steps)
		_set_status("Приключение завершено: выход найден.")

func _enter_next_floor() -> void:
	if game_session == null or _pending_next_map == null:
		return
	var next_map: DungeonMap = _pending_next_map
	if not _campaign_transition_allowed(next_map.map_id) or not game_session.enter_map(next_map):
		game_session.cancel_exit_transition()
		_pending_next_map = null
		_remove_victory_view()
		_dpad.visible = true
		_hero_hud.visible = true
		_game_command_bar.visible = true
		_mini_map.visible = _minimap_enabled
		_canvas.grab_focus()
		_game_notice.show_message("Переход невозможен")
		_set_status("Переход не выполнен: карта или точка прибытия изменилась.")
		return
	_pending_next_map = null
	_remove_victory_view()
	_canvas.set_map(game_session.map_data)
	_canvas.set_game_session(game_session)
	_canvas.zoom = DungeonCanvas.PLAY_START_ZOOM
	_canvas.center_on_cell(game_session.player_pos)
	_mini_overview.show_session(game_session)
	_dpad.visible = true
	_hero_hud.visible = true
	_game_command_bar.visible = true
	_mini_map.visible = _minimap_enabled
	_canvas.grab_focus()
	_canvas.queue_redraw()
	_refresh_stats()
	_refresh_map_overlays()
	_collect_game_messages()
	_set_status("Ты вошёл в «%s»." % game_session.map_data.display_name)


func _restart_test_after_victory() -> void:
	_stop_play_mode(false)
	_start_play_mode()


func _remove_victory_view() -> void:
	if _victory_view != null:
		_victory_view.queue_free()
		_victory_view = null


func _abort_combat() -> void:
	if _combat_camera_tween != null and _combat_camera_tween.is_running():
		_combat_camera_tween.kill()
	_combat_camera_tween = null
	if _battle_view != null:
		_battle_view.queue_free()
		_battle_view = null
	_combat_active = false


func _input(event: InputEvent) -> void:
	if _trap_playback_active:
		var skip: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]
		skip = skip or (event is InputEventScreenTouch and event.pressed)
		skip = skip or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION)
		if skip:
			_canvas.skip_trap_playback()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and is_play_mode:
		var direction := _direction_for_key(event.keycode)
		if direction != Vector2i.ZERO:
			if not event.pressed:
				_held_move_keys.erase(event.keycode)
				_blocked_hold_direction = Vector2i.ZERO
				get_viewport().set_input_as_handled()
				return
			if event.echo:
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and not event.echo:
		if is_play_mode:
			if _map_screen.visible:
				if event.keycode in [KEY_ESCAPE, KEY_M]:
					_map_screen.dismiss_by_player()
				get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_M and not _combat_active and _victory_view == null:
				_toggle_map_screen()
				get_viewport().set_input_as_handled()
				return
			if _game_system_menu.visible:
				if event.keycode == KEY_ESCAPE:
					if _game_system_menu.settings_open():
						_game_system_menu.close_settings()
					else:
						_close_game_system_menu()
					get_viewport().set_input_as_handled()
				elif event.keycode in [KEY_I, KEY_W, KEY_A, KEY_S, KEY_D]:
					get_viewport().set_input_as_handled()
				return
			if _inventory_view.visible:
				if event.keycode in [KEY_ESCAPE, KEY_I]:
					_inventory_view.close_by_player()
					get_viewport().set_input_as_handled()
				elif event.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
					get_viewport().set_input_as_handled()
				return
			if event.keycode == KEY_I and not _combat_active and _victory_view == null and not _game_dialogue.visible:
				_toggle_inventory()
				get_viewport().set_input_as_handled()
				return
			if _game_dialogue.visible:
				if _game_dialogue.has_choices():
					if event.keycode == KEY_ESCAPE:
						_game_dialogue.dismiss_by_player()
					elif event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_TAB]:
						return
				elif event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
					_game_dialogue.dismiss_by_player()
				get_viewport().set_input_as_handled()
				return
			if _victory_view != null:
				if event.keycode == KEY_ESCAPE:
					if _victory_view.is_party_defeat:
						_continue_after_defeat()
					else:
						_stop_play_mode()
					get_viewport().set_input_as_handled()
				elif event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D]:
					get_viewport().set_input_as_handled()
				return
			if _combat_active:
				if event.keycode == KEY_ESCAPE:
					_open_game_system_menu()
					get_viewport().set_input_as_handled()
				elif event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D]:
					get_viewport().set_input_as_handled()
				return
			match event.keycode:
				KEY_ESCAPE:
					_open_game_system_menu()
					get_viewport().set_input_as_handled()
				KEY_UP, KEY_W, KEY_DOWN, KEY_S, KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
					if not _held_move_keys.has(event.keycode):
						_held_move_keys.append(event.keycode)
						_blocked_hold_direction = Vector2i.ZERO
						_advance_held_move()
					get_viewport().set_input_as_handled()
		else:
			var focused := get_viewport().gui_get_focus_owner()
			if (focused is LineEdit or focused is TextEdit) and (event.ctrl_pressed or event.meta_pressed) and event.keycode in [KEY_Z, KEY_Y]:
				return
			if (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_Z:
				if event.shift_pressed:
					_redo_edit()
				else:
					_undo_edit()
				get_viewport().set_input_as_handled()
			elif (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_Y:
				_redo_edit()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ESCAPE and _canvas.has_move_selection():
				_canvas.cancel_move_selection()
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_S and (event.ctrl_pressed or event.meta_pressed):
				_save_internal()
				get_viewport().set_input_as_handled()
