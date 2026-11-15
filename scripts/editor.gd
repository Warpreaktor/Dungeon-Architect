extends Control

## Главное окно самостоятельного приложения-редактора.
## Вся сцена собирается обычными Control-узлами, чтобы её можно было расширять.

const SIDEBAR_WIDTH := 264.0
const HERO_HUD_SCENE: PackedScene = preload("res://scenes/hero_hud.tscn")
const GAME_NOTICE_SCENE: PackedScene = preload("res://scenes/game_notice.tscn")
const CHEST_CONTENTS_SCENE: PackedScene = preload("res://scenes/chest_contents_popup.tscn")
const TRIGGER_PROPERTIES_SCENE: PackedScene = preload("res://scenes/trigger_properties_popup.tscn")
const BATTLE_VIEW_SCENE: PackedScene = preload("res://scenes/battle_view.tscn")
const VICTORY_VIEW_SCENE: PackedScene = preload("res://scenes/victory_view.tscn")
const MESSAGE_EDITOR_SCENE: PackedScene = preload("res://scenes/message_editor_popup.tscn")
const GAME_DIALOGUE_SCENE: PackedScene = preload("res://scenes/game_dialogue_view.tscn")
const INVENTORY_VIEW_SCENE: PackedScene = preload("res://scenes/inventory_view.tscn")
const EDITOR_SETTINGS_PATH := "user://editor_state.cfg"
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
	"redo": preload("res://assets/icons/commands/redo.png")
}
const TOOLS := [
	{"id": "hand", "label": "Рука", "hint": "Безопасно перемещать и масштабировать карту одним или двумя пальцами"},
	{"id": "floor", "label": "Пол", "hint": "Убирает стену; поверхность становится проходимой"},
	{"id": "wall", "label": "Стена", "hint": "Непроходимая клетка"},
	{"id": "door", "label": "Дверь", "hint": "Дверь на клетке пола"},
	{"id": "chest", "label": "Сундук", "hint": "Контейнер с добычей"},
	{"id": "stairs_down", "label": "Спуск", "hint": "Выход из подземелья (позже станет переходом на другую карту)"},
	{"id": "trigger", "label": "Триггер", "hint": "Невидимое в игре событие"},
	{"id": "message", "label": "Послание", "hint": "Авторский текст при входе в клетку или открытии двери"},
	{"id": "player_spawn", "label": "Старт героя", "hint": "Единственная стартовая позиция"},
	{"id": "erase", "label": "Ластик", "hint": "Удалить верхний объект или стену"}
]
const TOOL_ICONS := {
	"hand": preload("res://assets/icons/hand.png"),
	"floor": preload("res://assets/icons/floor.png"),
	"wall": preload("res://assets/icons/wall.png"),
	"door": preload("res://assets/icons/door.png"),
	"chest": preload("res://assets/icons/chest.png"),
	"stairs_down": preload("res://assets/icons/stairs_down.png"),
	"trigger": preload("res://assets/icons/trigger.png"),
	"message": preload("res://assets/icons/message.png"),
	"player_spawn": preload("res://assets/icons/player_spawn.png"),
	"erase": preload("res://assets/icons/erase.png")
}

var map_data: DungeonMap
var game_session: GameSession
var is_dirty: bool = false
var selected_tool: String = "hand"
var is_play_mode: bool = false
var _editor_camera_offset := Vector2.ZERO
var _editor_camera_zoom: float = 1.0
const HISTORY_LIMIT := 40
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _undo_button: Button
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
var _sidebar_panel: PanelContainer
var _palette_buttons: Dictionary = {}
var _chest_popup: ChestContentsPopup
var _trigger_popup: TriggerPropertiesPopup
var _message_popup: MessageEditorPopup
var _game_dialogue: GameDialogueView
var _pending_game_messages: Array[Dictionary] = []
var _editor_controls: Array[Control] = []
var _play_button: Button
var _load_paths: Array[String] = []
var _load_list: ItemList
var _preview_textures: Array[Texture2D] = []
var _rename_dialog: ConfirmationDialog
var _rename_input: LineEdit
var _delete_dialog: ConfirmationDialog
var _delete_path: String = ""
var _unsaved_dialog: ConfirmationDialog
var _pending_action: Callable
var _log_console: RichTextLabel
var _log_toggle: Button
var _log_open: bool = false
const PREVIEW_WIDTH := 176
const PREVIEW_HEIGHT := 116
const PREVIEW_FLOOR: Texture2D = preload("res://assets/stone_floor.png")
const PREVIEW_WALL: Texture2D = preload("res://assets/stone_wall.png")
const PREVIEW_COLORS := {
    "door": Color("#c58a49"), "chest": Color("#edc06c"),
    "monster": Color("#e65d73"), "key": Color("#ffe8a3"),
    "potion": Color("#b89bff"), "gold": Color("#f4ce67"), "stairs_down": Color("#5bd2e7"),
    "trigger": Color("#ce90e5"), "player_spawn": Color("#70f2aa"),
    "message": Color("#ffdd93")
}
var _new_dialog: ConfirmationDialog
var _size_preset: OptionButton
var _width_input: SpinBox
var _height_input: SpinBox
var _dpad: Control
var _hero_hud: HeroHUD
var _inventory_view: InventoryView
var _inventory_button: Button
var _game_notice: GameNotice
var _load_dialog: ConfirmationDialog
var _export_dialog: FileDialog
var _import_dialog: FileDialog


func _ready() -> void:
	_build_interface()
	_create_dialogs()
	if not _restore_last_map():
		_set_map(DungeonMap.create_blank())
		_set_status("Чистая карта готова. Выбери инструмент и рисуй лабиринт.")


func _build_interface() -> void:
	var root_column := VBoxContainer.new()
	root_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_column.add_theme_constant_override("separation", 0)
	add_child(root_column)

	var header := _panel(Color("#1c2935"))
	root_column.add_child(header)
	# Команды переносятся на следующую строку на узких экранах.
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 7)
	toolbar.add_theme_constant_override("v_separation", 6)
	header.add_child(toolbar)
	var title := _label("DUNGEON  /  ARCHITECT", 19, Color("#e8c58a"))
	title.custom_minimum_size.x = 190
	toolbar.add_child(title)

	var new_button := _button("Новая", "Создать пустую карту", _request_new)
	_set_command_icon(new_button, "new")
	toolbar.add_child(new_button)
	_register_editor_control(new_button)

	var save_button := _button("Сохранить", "Сохранить в библиотеку карт приложения (Ctrl+S)", _save_internal)
	_set_command_icon(save_button, "save")
	toolbar.add_child(save_button)
	_register_editor_control(save_button)

	var load_button := _button("Загрузить", "Открыть карту из библиотеки", _show_load)
	_set_command_icon(load_button, "load")
	toolbar.add_child(load_button)
	_register_editor_control(load_button)

	_undo_button = _button("Отменить", "Отменить действие (Ctrl+Z)", _undo_edit)
	_set_command_icon(_undo_button, "undo")
	toolbar.add_child(_undo_button)
	_redo_button = _button("Повторить", "Повторить действие (Ctrl+Y / Ctrl+Shift+Z)", _redo_edit)
	_set_command_icon(_redo_button, "redo")
	toolbar.add_child(_redo_button)

	toolbar.add_child(_separator())
	var export_button := _button("Экспорт", "Сохранить карту в файл", _show_export)
	_set_command_icon(export_button, "export")
	toolbar.add_child(export_button)
	_register_editor_control(export_button)
	var import_button := _button("Импорт", "Загрузить карту из файла", _show_import)
	_set_command_icon(import_button, "import")
	toolbar.add_child(import_button)
	_register_editor_control(import_button)
	toolbar.add_child(_separator())
	var center_button := _button("Центр", "Показать всю карту", _fit_map)
	_set_command_icon(center_button, "center")
	toolbar.add_child(center_button)
	_play_button = _button("Тест", "Проверить текущую карту без сохранения игрового прогресса", _toggle_play_mode)
	_set_command_icon(_play_button, "test")
	toolbar.add_child(_play_button)

	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 0)
	root_column.add_child(workspace)

	var canvas_host := Control.new()
	canvas_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas_host = canvas_host
	workspace.add_child(canvas_host)

	_canvas = DungeonCanvas.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.map_edited.connect(_on_canvas_edited)
	_canvas.edit_action_committed.connect(_on_edit_action_committed)
	_canvas.move_selection_changed.connect(_on_move_selection_changed)
	_canvas.move_failed.connect(_on_move_failed)
	_canvas.configurable_entity_tapped.connect(_on_configurable_entity_tapped)
	_canvas.message_cell_tapped.connect(_on_message_cell_tapped)
	canvas_host.add_child(_canvas)
	_build_dpad(canvas_host)

	# Интерфейс героя — самостоятельная сцена, не часть логики редактора.
	_hero_hud = HERO_HUD_SCENE.instantiate() as HeroHUD
	_hero_hud.visible = false
	canvas_host.add_child(_hero_hud)
	_inventory_button = _button("Инвентарь", "Просмотреть найденные предметы (I)", _toggle_inventory)
	_inventory_button.icon = preload("res://assets/hud/bag.png")
	_inventory_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_inventory_button.offset_left = -174.0
	_inventory_button.offset_top = 14.0
	_inventory_button.offset_right = -14.0
	_inventory_button.offset_bottom = 60.0
	_inventory_button.focus_mode = Control.FOCUS_NONE
	_inventory_button.visible = false
	canvas_host.add_child(_inventory_button)
	_inventory_view = INVENTORY_VIEW_SCENE.instantiate() as InventoryView
	_inventory_view.closed.connect(_on_inventory_closed)
	_inventory_view.item_use_requested.connect(_on_inventory_use_requested)
	_inventory_view.equipment_requested.connect(_on_inventory_equipment_requested)
	add_child(_inventory_view)
	_game_notice = GAME_NOTICE_SCENE.instantiate() as GameNotice
	_game_notice.visible = false
	canvas_host.add_child(_game_notice)
	_game_dialogue = GAME_DIALOGUE_SCENE.instantiate() as GameDialogueView
	_game_dialogue.closed.connect(_on_game_dialogue_closed)
	add_child(_game_dialogue)

	_sidebar_panel = _panel(Color("#202d39"))
	_sidebar_panel.custom_minimum_size.x = SIDEBAR_WIDTH
	workspace.add_child(_sidebar_panel)
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sidebar_panel.add_child(sidebar_scroll)
	var sidebar := VBoxContainer.new()
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 10)
	sidebar_scroll.add_child(sidebar)

	sidebar.add_child(_label("КАРТА", 14, Color("#e8c58a")))
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Название карты"
	_name_input.tooltip_text = "Имя будет записано в JSON"
	_name_input.text_changed.connect(_on_name_changed)
	sidebar.add_child(_name_input)
	_register_editor_control(_name_input)

	_stats_label = _label("32 × 32", 13, Color("#9ab0bf"))
	sidebar.add_child(_stats_label)
	sidebar.add_child(HSeparator.new())
	sidebar.add_child(_label("УПРАВЛЕНИЕ КАРТОЙ", 14, Color("#e8c58a")))
	var control_tools := _tool_grid()
	sidebar.add_child(control_tools)
	for tool in TOOLS:
		if str(tool["id"]) in ["hand", "erase"]:
			_add_tool_button(control_tools, tool)

	sidebar.add_child(HSeparator.new())
	sidebar.add_child(_label("ЭЛЕМЕНТЫ ЛАБИРИНТА", 14, Color("#e8c58a")))
	var map_tools := _tool_grid()
	sidebar.add_child(map_tools)
	for tool in TOOLS:
		if str(tool["id"]) not in ["hand", "erase"]:
			_add_tool_button(map_tools, tool)

	sidebar.add_child(HSeparator.new())
	sidebar.add_child(_label("МОНСТРЫ", 14, Color("#e8c58a")))
	var monster_tools := _tool_grid()
	sidebar.add_child(monster_tools)
	# Каждый новый MonsterDefinition автоматически получает собственную кнопку.
	for monster_id in MonsterCatalog.DEFINITIONS:
		var monster: MonsterDefinition = MonsterCatalog.get_monster(str(monster_id))
		_add_tool_button(monster_tools, {
			"id": "monster:" + monster.monster_id,
			"label": monster.display_name,
			"hint": "Здоровье: %d · Урон: %d" % [monster.max_health, monster.attack_damage],
			"icon": monster.icon
		})

	sidebar.add_child(HSeparator.new())
	var grid_checkbox := CheckBox.new()
	grid_checkbox.text = "Показывать сетку"
	grid_checkbox.button_pressed = true
	grid_checkbox.toggled.connect(_toggle_grid)
	sidebar.add_child(grid_checkbox)

	# Нижняя консоль полностью скрыта до раскрытия: только небольшая кнопка.
	var console_row := HBoxContainer.new()
	root_column.add_child(console_row)
	_log_toggle = _button("▴", "Развернуть консоль сообщений", _toggle_log_console)
	_log_toggle.focus_mode = Control.FOCUS_NONE
	_log_toggle.custom_minimum_size = Vector2(32, 26)
	console_row.add_child(_log_toggle)
	_log_console = RichTextLabel.new()
	_log_console.custom_minimum_size.y = 145
	_log_console.scroll_following = true
	_log_console.selection_enabled = true
	_log_console.visible = false
	root_column.add_child(_log_console)


func _tool_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	return grid


func _add_tool_button(grid: GridContainer, tool: Dictionary) -> void:
	var key: String = str(tool["id"])
	var button := Button.new()
	button.icon = tool.get("icon", TOOL_ICONS.get(key)) as Texture2D
	button.expand_icon = true
	button.custom_minimum_size = Vector2(66, 66)
	button.tooltip_text = "%s\n%s" % [str(tool["label"]), str(tool["hint"])]
	button.pressed.connect(_set_tool.bind(key))
	grid.add_child(button)
	_palette_buttons[key] = button
	_register_editor_control(button)


func _create_dialogs() -> void:
	_chest_popup = CHEST_CONTENTS_SCENE.instantiate() as ChestContentsPopup
	_chest_popup.contents_changed.connect(_on_chest_contents_changed)
	add_child(_chest_popup)
	_trigger_popup = TRIGGER_PROPERTIES_SCENE.instantiate() as TriggerPropertiesPopup
	_trigger_popup.event_id_changed.connect(_on_trigger_event_id_changed)
	add_child(_trigger_popup)
	_message_popup = MESSAGE_EDITOR_SCENE.instantiate() as MessageEditorPopup
	_message_popup.saved.connect(_on_message_saved)
	_message_popup.removed.connect(_on_message_removed)
	add_child(_message_popup)

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
	add_child(_load_dialog)
	var library_layout := VBoxContainer.new()
	library_layout.custom_minimum_size = Vector2(620, 370)
	_load_dialog.add_child(library_layout)
	_load_list = ItemList.new()
	_load_list.custom_minimum_size = Vector2(620, 300)
	_load_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_load_list.icon_mode = ItemList.ICON_MODE_TOP
	_load_list.fixed_icon_size = Vector2i(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	_load_list.max_columns = 3
	_load_list.same_column_width = true
	_load_list.item_activated.connect(_load_activated)
	library_layout.add_child(_load_list)
	var library_actions := HBoxContainer.new()
	library_layout.add_child(library_actions)
	library_actions.add_child(_button("Переименовать", "Изменить название выбранной карты", _request_rename))
	library_actions.add_child(_button("Копировать", "Создать отдельную копию карты", _duplicate_selected))
	library_actions.add_child(_button("Удалить", "Удалить выбранную карту после подтверждения", _request_delete))

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
			button.pressed.connect(_move_from_dpad.bind(direction))
			grid.add_child(button)
		else:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(68, 68)
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(spacer)


func _move_from_dpad(direction: Vector2i) -> void:
	_try_move_player(direction.x, direction.y)


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


func _register_editor_control(control: Control) -> void:
	_editor_controls.append(control)


func _set_map(new_map: DungeonMap) -> void:
	map_data = new_map
	game_session = null
	is_play_mode = false
	_name_input.text = map_data.display_name
	_canvas.set_map(map_data)
	_undo_stack.clear()
	_redo_stack.clear()
	_update_history_buttons()
	_set_tool(selected_tool)
	_refresh_stats()
	_update_mode_ui()
	is_dirty = false


func _refresh_stats() -> void:
	var base := "%d × %d клеток   •   %d объектов" % [map_data.width, map_data.height, map_data.entities.size()]
	if is_play_mode and game_session != null:
		base += "   •   ходов: %d" % game_session.steps
	_stats_label.text = base
	_update_hero_hud()


func _update_hero_hud() -> void:
	if not is_play_mode or game_session == null:
		return
	_hero_hud.set_hero(game_session.hero)


func _on_configurable_entity_tapped(kind: String, entity_id: String) -> void:
	match kind:
		"chest":
			_on_chest_tapped(entity_id)
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


func _on_chest_tapped(chest_id: String) -> void:
	if is_play_mode:
		return
	_canvas.finish_edit_stroke()
	for entity in map_data.entities:
		if str(entity.get("id", "")) == chest_id and str(entity.get("type", "")) == "chest":
			_chest_popup.configure(chest_id, DungeonMap.chest_contents(entity), DungeonMap.chest_gold_amount(entity))
			_chest_popup.popup_centered_clamped(Vector2i(420, 490), 0.9)
			return


func _on_chest_contents_changed(chest_id: String, contents: Array[String], gold_amount: int) -> void:
	if is_play_mode:
		return
	var before := _canvas.capture_edit_state()
	if map_data.set_chest_contents(chest_id, contents, gold_amount):
		_on_edit_action_committed(before, _canvas.capture_edit_state())
		_on_canvas_edited()
		_canvas.queue_redraw()


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


func _toggle_grid(value: bool) -> void:
	_canvas.show_grid = value
	_canvas.queue_redraw()


func _fit_map() -> void:
	_canvas.fit_to_view()


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
	is_dirty = true
	_set_status("Изменения не сохранены • Ctrl+S для сохранения")


func _set_status(message: String) -> void:
	if _last_log_message == message:
		return
	_last_log_message = message
	if _log_console != null:
		_log_console.append_text("[%s] %s\n" % [Time.get_time_string_from_system(), message])


func _toggle_log_console() -> void:
	_log_open = not _log_open
	_log_console.visible = _log_open
	_log_toggle.text = "▾" if _log_open else "▴"
	_log_toggle.tooltip_text = "Свернуть консоль сообщений" if _log_open else "Развернуть консоль сообщений"


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
	return "user://maps"


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
	file.close()
	return true


func _save_internal() -> void:
	if is_play_mode:
		return
	if not _ensure_maps_dir():
		_set_status("Не удалось создать папку карт")
		return
	var path := _maps_dir().path_join(map_data.map_id + ".json")
	if _write_map(path):
		is_dirty = false
		_remember_last_map(map_data.map_id)
		_set_status("Сохранено: " + path)


func _show_load() -> void:
	if is_play_mode:
		return
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


func _make_preview(data: DungeonMap) -> ImageTexture:
	# Миниатюра строится из сохранённой карты и не требует отдельного PNG.
	var img := Image.create(PREVIEW_WIDTH, PREVIEW_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color("#101820"))
	var cell_size := minf(float(PREVIEW_WIDTH - 12) / float(data.width), float(PREVIEW_HEIGHT - 12) / float(data.height))
	var drawn_width := float(data.width) * cell_size
	var drawn_height := float(data.height) * cell_size
	var left := (float(PREVIEW_WIDTH) - drawn_width) * 0.5
	var top := (float(PREVIEW_HEIGHT) - drawn_height) * 0.5
	var floor_image := PREVIEW_FLOOR.get_image()
	var wall_image := PREVIEW_WALL.get_image()
	var x_start := maxi(0, floori(left))
	var y_start := maxi(0, floori(top))
	var x_end := mini(PREVIEW_WIDTH, ceili(left + drawn_width))
	var y_end := mini(PREVIEW_HEIGHT, ceili(top + drawn_height))
	for py in range(y_start, y_end):
		for px in range(x_start, x_end):
			var world_x := (float(px) - left) / cell_size
			var world_y := (float(py) - top) / cell_size
			var cx := floori(world_x)
			var cy := floori(world_y)
			if not data.contains(cx, cy):
				continue
			var source := wall_image if data.get_terrain(cx, cy) == "wall" else floor_image
			var sx := clampi(floori(fposmod(world_x, 1.0) * float(source.get_width())), 0, source.get_width() - 1)
			var sy := clampi(floori(fposmod(world_y, 1.0) * float(source.get_height())), 0, source.get_height() - 1)
			img.set_pixel(px, py, source.get_pixel(sx, sy))
	for entity in data.entities:
		var kind := str(entity.get("type", ""))
		if not PREVIEW_COLORS.has(kind):
			continue
		var center_x := roundi(left + (float(entity["x"]) + 0.5) * cell_size)
		var center_y := roundi(top + (float(entity["y"]) + 0.5) * cell_size)
		var dot_radius := clampi(roundi(cell_size * 0.23), 1, 4)
		var dot := Rect2i(center_x - dot_radius, center_y - dot_radius, dot_radius * 2 + 1, dot_radius * 2 + 1)
		img.fill_rect(dot.intersection(Rect2i(0, 0, PREVIEW_WIDTH, PREVIEW_HEIGHT)), PREVIEW_COLORS[kind])
	return ImageTexture.create_from_image(img)


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
		_load_dialog.hide()
		_load_from_path(_load_paths[index])


func _load_selected() -> void:
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
	_delete_dialog.dialog_text = "Удалить карту %s? Это действие нельзя отменить." % _load_list.get_item_text(_load_list.get_selected_items()[0]).replace("\n", " ")
	_delete_dialog.popup_centered()


func _delete_selected() -> void:
	if _delete_path.is_empty():
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


func _toggle_play_mode() -> void:
	if is_play_mode:
		_stop_play_mode()
	else:
		_start_play_mode()


func _start_play_mode() -> void:
	var session := GameSession.start_for(map_data)
	if session == null:
		_set_status("Нельзя начать тест: поставь на карте точку старта героя.")
		return
	## Камера редактора не принадлежит временной тестовой сессии.
	_editor_camera_offset = _canvas.camera_offset
	_editor_camera_zoom = _canvas.zoom
	game_session = session
	_inventory_view.dismiss()
	_pending_game_messages.clear()
	is_play_mode = true
	_canvas.set_game_session(session)
	_canvas.center_on_cell(session.player_pos)
	_canvas.grab_focus()
	_update_mode_ui()
	_refresh_stats()
	_set_status("Тест карты запущен. Прогресс временный.")
	if not session.last_event_message.is_empty():
		_set_status(session.last_event_message)
	_log_trigger_events()
	_collect_game_messages()


func _stop_play_mode() -> void:
	_remove_victory_view()
	_abort_combat()
	_game_notice.clear()
	_game_dialogue.dismiss()
	_inventory_view.dismiss()
	_pending_game_messages.clear()
	game_session = null
	is_play_mode = false
	_canvas.set_game_session(null)
	_canvas.zoom = _editor_camera_zoom
	_canvas.camera_offset = _editor_camera_offset
	_canvas.queue_redraw()
	_update_mode_ui()
	_refresh_stats()
	_set_status("Возврат в редактор. Карта не изменена.")


func _update_mode_ui() -> void:
	_sidebar_panel.visible = not is_play_mode
	_play_button.text = "Редактор" if is_play_mode else "Тест"
	_set_command_icon(_play_button, "editor" if is_play_mode else "test")
	_play_button.tooltip_text = "Выйти из теста и вернуться к редактированию" if is_play_mode else "Проверить текущую карту без сохранения игрового прогресса"
	_dpad.visible = is_play_mode
	_hero_hud.visible = is_play_mode
	_inventory_button.visible = is_play_mode
	_game_notice.visible = is_play_mode
	for control in _editor_controls:
		if control is BaseButton:
			(control as BaseButton).disabled = is_play_mode
		elif control is LineEdit:
			(control as LineEdit).editable = not is_play_mode
		control.modulate = Color(1, 1, 1, 0.60) if is_play_mode else Color(1, 1, 1, 1)
	_set_tool(selected_tool)
	_update_history_buttons()


func _toggle_inventory() -> void:
	if not is_play_mode or game_session == null or _combat_active or _victory_view != null or _game_dialogue.visible:
		return
	if _inventory_view.visible:
		_inventory_view.close_by_player()
	else:
		_inventory_view.open_for(game_session)
		_dpad.visible = false


func _on_inventory_closed() -> void:
	if is_play_mode and not _combat_active and _victory_view == null:
		_dpad.visible = true
		_canvas.grab_focus()


func _on_inventory_use_requested(item_id: String) -> void:
	if not is_play_mode or game_session == null or not _inventory_view.visible:
		return
	var result: Dictionary = game_session.use_item(item_id)
	_inventory_view.show_use_result(item_id, str(result.get("message", "")))
	if bool(result.get("used", false)):
		_refresh_stats()


func _on_inventory_equipment_requested(item_id: String, equip: bool) -> void:
	if not is_play_mode or game_session == null or not _inventory_view.visible:
		return
	var changed: bool = game_session.equip_item(item_id) if equip else game_session.unequip_item(item_id)
	if not changed:
		return
	_inventory_view.show_equipment_result(item_id)
	_refresh_stats()


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
	_game_dialogue.show_event(event)


func _on_game_dialogue_closed() -> void:
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
	if not is_play_mode or game_session == null or _combat_active or _victory_view != null or _game_dialogue.visible or _inventory_view.visible:
		return
	var moved := game_session.move_by(dx, dy)
	if game_session.has_pending_encounter():
		_collect_game_messages()
		if not _game_dialogue.visible:
			_start_combat()
		return
	if moved:
		_canvas.center_on_cell(game_session.player_pos)
	# Сундук меняет вид при открытии, даже если сам герой не сдвинулся.
	_canvas.queue_redraw()
	_refresh_stats()
	_log_trigger_events()
	_collect_game_messages()
	if _game_dialogue.visible:
		return
	if game_session.is_completed:
		_show_victory_view()
		return
	if not game_session.last_event_message.is_empty():
		_show_game_event(game_session.last_event_message)


## При встрече камера приближается к противнику, затем открывается
## отдельная сцена боя поверх карты. Исследование остаётся в памяти.
func _start_combat() -> void:
	_combat_active = true
	_dpad.visible = false
	_hero_hud.visible = false
	_game_notice.clear()
	_pre_combat_zoom = _canvas.zoom
	var original_offset: Vector2 = _canvas.camera_offset
	var focus_zoom: float = minf(_pre_combat_zoom * 1.5, 3.5)
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
	_battle_view.battle_won.connect(_finish_combat)
	_battle_view.battle_lost.connect(_lose_combat)
	_battle_view.begin(CombatSession.new(game_session.pending_monster_definition(), game_session.hero), game_session.hero)


func _finish_combat() -> void:
	if not _combat_active or game_session == null:
		return
	var moved: bool = game_session.win_pending_encounter()
	if _battle_view != null:
		_battle_view.queue_free()
		_battle_view = null
	_combat_active = false
	_canvas.zoom = _pre_combat_zoom
	_canvas.center_on_cell(game_session.player_pos)
	_dpad.visible = true
	_hero_hud.visible = true
	_canvas.grab_focus()
	_canvas.queue_redraw()
	_refresh_stats()
	_log_trigger_events()
	_collect_game_messages()
	if _game_dialogue.visible:
		return
	if game_session.is_completed:
		_show_victory_view()
		return
	if not game_session.last_event_message.is_empty():
		_show_game_event(game_session.last_event_message)
	elif not moved:
		_set_status("Монстр побеждён, но клетка пока недоступна.")


func _lose_combat() -> void:
	if not _combat_active or game_session == null:
		return
	if _battle_view != null:
		_battle_view.queue_free()
		_battle_view = null
	_combat_active = false
	_canvas.zoom = _pre_combat_zoom
	_canvas.center_on_cell(game_session.player_pos)
	_canvas.queue_redraw()
	_refresh_stats()
	_show_end_view(true)


## Финальный экран не уничтожает карту и сессию, а лишь блокирует исследование.
## Позже эту же сцену можно будет использовать как экран завершения этажа.
func _show_victory_view() -> void:
	_show_end_view(false)


func _show_end_view(defeated: bool) -> void:
	if not is_play_mode or game_session == null or _victory_view != null or _game_dialogue.visible:
		return
	_dpad.visible = false
	_hero_hud.visible = false
	_game_notice.clear()
	_victory_view = VICTORY_VIEW_SCENE.instantiate() as VictoryView
	add_child(_victory_view)
	_victory_view.retry_requested.connect(_restart_test_after_victory)
	_victory_view.editor_requested.connect(_stop_play_mode)
	if defeated:
		_victory_view.show_defeat(game_session.steps, game_session.pending_monster_definition())
		_set_status("Герой пал в сражении. Приключение не завершено.")
	else:
		_victory_view.show_result(game_session.steps)
		_set_status("Приключение завершено: выход найден.")


func _restart_test_after_victory() -> void:
	_stop_play_mode()
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
	if event is InputEventKey and event.pressed and not event.echo:
		if is_play_mode:
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
				if event.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]:
					_game_dialogue.dismiss_by_player()
				get_viewport().set_input_as_handled()
				return
			if _victory_view != null:
				if event.keycode == KEY_ESCAPE:
					_stop_play_mode()
					get_viewport().set_input_as_handled()
				elif event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D]:
					get_viewport().set_input_as_handled()
				return
			if _combat_active:
				if event.keycode in [KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_W, KEY_A, KEY_S, KEY_D]:
					get_viewport().set_input_as_handled()
				return
			match event.keycode:
				KEY_ESCAPE:
					_stop_play_mode()
					get_viewport().set_input_as_handled()
				KEY_UP, KEY_W:
					_try_move_player(0, -1)
					get_viewport().set_input_as_handled()
				KEY_DOWN, KEY_S:
					_try_move_player(0, 1)
					get_viewport().set_input_as_handled()
				KEY_LEFT, KEY_A:
					_try_move_player(-1, 0)
					get_viewport().set_input_as_handled()
				KEY_RIGHT, KEY_D:
					_try_move_player(1, 0)
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
