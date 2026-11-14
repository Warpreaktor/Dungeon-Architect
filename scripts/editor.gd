extends Control

## Главное окно самостоятельного приложения-редактора.
## Вся сцена собирается обычными Control-узлами, чтобы её можно было расширять.

const SIDEBAR_WIDTH := 264.0
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
	{"id": "monster", "label": "Монстр", "hint": "Место появления противника"},
	{"id": "key", "label": "Ключ", "hint": "Подбираемый предмет"},
	{"id": "potion", "label": "Зелье", "hint": "Подбираемый предмет"},
	{"id": "stairs_down", "label": "Спуск", "hint": "Переход на другую карту (ссылка добавится позже)"},
	{"id": "trigger", "label": "Триггер", "hint": "Невидимое в игре событие"},
	{"id": "player_spawn", "label": "Старт героя", "hint": "Единственная стартовая позиция"},
	{"id": "erase", "label": "Ластик", "hint": "Удалить верхний объект или стену"}
]
const TOOL_ICONS := {
	"hand": preload("res://assets/icons/hand.png"),
	"floor": preload("res://assets/icons/floor.png"),
	"wall": preload("res://assets/icons/wall.png"),
	"door": preload("res://assets/icons/door.png"),
	"chest": preload("res://assets/icons/chest.png"),
	"monster": preload("res://assets/icons/monster.png"),
	"key": preload("res://assets/icons/key.png"),
	"potion": preload("res://assets/icons/potion.png"),
	"stairs_down": preload("res://assets/icons/stairs_down.png"),
	"trigger": preload("res://assets/icons/trigger.png"),
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

var _canvas: DungeonCanvas
var _name_input: LineEdit
var _status_label: Label
var _coords_label: Label
var _stats_label: Label
var _selection_label: Label
var _sidebar_panel: PanelContainer
var _palette_buttons: Dictionary = {}
var _editor_controls: Array[Control] = []
var _play_button: Button
var _load_paths: Array[String] = []
var _load_list: ItemList
var _new_dialog: ConfirmationDialog
var _size_preset: OptionButton
var _width_input: SpinBox
var _height_input: SpinBox
var _dpad: Control
var _load_dialog: ConfirmationDialog
var _export_dialog: FileDialog
var _import_dialog: FileDialog


func _ready() -> void:
	_build_interface()
	_create_dialogs()
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
	var export_button := _button("Экспорт JSON", "Записать карту в произвольный JSON-файл", _show_export)
	_set_command_icon(export_button, "export")
	toolbar.add_child(export_button)
	_register_editor_control(export_button)
	var import_button := _button("Импорт JSON", "Прочитать карту из JSON-файла", _show_import)
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
	workspace.add_child(canvas_host)

	_canvas = DungeonCanvas.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.map_edited.connect(_on_canvas_edited)
	_canvas.edit_action_committed.connect(_on_edit_action_committed)
	_canvas.hover_changed.connect(_on_hover_changed)
	_canvas.move_selection_changed.connect(_on_move_selection_changed)
	_canvas.move_failed.connect(_on_move_failed)
	canvas_host.add_child(_canvas)
	_build_dpad(canvas_host)

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
	_selection_label = _label("Выбрано: Рука", 13, Color("#aec2d1"))
	sidebar.add_child(_selection_label)
	var grid_checkbox := CheckBox.new()
	grid_checkbox.text = "Показывать сетку"
	grid_checkbox.button_pressed = true
	grid_checkbox.toggled.connect(_toggle_grid)
	sidebar.add_child(grid_checkbox)

	sidebar.add_child(HSeparator.new())
	sidebar.add_child(_label("УПРАВЛЕНИЕ", 14, Color("#e8c58a")))
	var help := _label("Рука: перемещение одним или двумя пальцами, масштабирование двумя. Двойной тап по объекту — захват; тап по новой клетке — перенос; тап по исходной — отмена.\n\nКисть: пальцем/ЛКМ рисовать; ПКМ стирать.\n\nКолесо: масштаб. Средняя кнопка / Space+ЛКМ: перетаскивать карту на ПК.\n\nТест: стрелки/WASD — ходить; Esc — в редактор.", 12, Color("#a3b9c8"))
	sidebar.add_child(help)

	var footer := _panel(Color("#17232e"))
	root_column.add_child(footer)
	var footer_row := HBoxContainer.new()
	footer.add_child(footer_row)
	_status_label = _label("Готово", 12, Color("#c8d5dd"))
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(_status_label)
	_coords_label = _label("x: —   y: —", 12, Color("#e8c58a"))
	footer_row.add_child(_coords_label)


func _tool_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	return grid


func _add_tool_button(grid: GridContainer, tool: Dictionary) -> void:
	var key: String = str(tool["id"])
	var button := Button.new()
	button.icon = TOOL_ICONS.get(key)
	button.expand_icon = true
	button.custom_minimum_size = Vector2(66, 66)
	button.tooltip_text = "%s\n%s" % [str(tool["label"]), str(tool["hint"])]
	button.pressed.connect(_set_tool.bind(key))
	grid.add_child(button)
	_palette_buttons[key] = button
	_register_editor_control(button)


func _create_dialogs() -> void:
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
	_load_list = ItemList.new()
	_load_list.custom_minimum_size = Vector2(470, 260)
	_load_list.item_activated.connect(_load_activated)
	_load_dialog.add_child(_load_list)

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
	var display_name := kind
	for tool in TOOLS:
		if tool["id"] == kind:
			display_name = str(tool["label"])
	_selection_label.text = "Выбрано: " + display_name


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


func _on_hover_changed(cell: Vector2i) -> void:
	if cell.x < 0:
		_coords_label.text = "x: —   y: —"
	else:
		_coords_label.text = "x: %d   y: %d" % [cell.x, cell.y]


func _set_status(message: String) -> void:
	_status_label.text = message


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
		_set_status("Сохранено: " + path)


func _show_load() -> void:
	if is_play_mode:
		return
	if not _ensure_maps_dir():
		_set_status("Не удалось открыть папку карт")
		return
	_load_paths.clear()
	_load_list.clear()
	var folder := DirAccess.open(_maps_dir())
	if folder == null:
		_set_status("Папка карт не найдена")
		return
	var files := folder.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".json"):
			continue
		var path := _maps_dir().path_join(file_name)
		var label := file_name.get_basename()
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var data: Variant = JSON.parse_string(file.get_as_text())
			if typeof(data) == TYPE_DICTIONARY:
				label = str(data.get("name", label)) + "    [" + file_name + "]"
		_load_paths.append(path)
		_load_list.add_item(label)
	if _load_paths.is_empty():
		_set_status("Библиотека пуста. Сначала сохрани карту.")
		return
	_load_list.select(0)
	_load_dialog.popup_centered(Vector2i(520, 350))


func _load_activated(index: int) -> void:
	if index >= 0 and index < _load_paths.size():
		_load_dialog.hide()
		_load_from_path(_load_paths[index])


func _load_selected() -> void:
	var items := _load_list.get_selected_items()
	if items.is_empty():
		return
	var index: int = items[0]
	if index >= 0 and index < _load_paths.size():
		_load_from_path(_load_paths[index])


func _load_from_path(path: String) -> void:
	if is_play_mode:
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_set_status("Не удалось прочитать: " + path)
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	var loaded_map := DungeonMap.from_dict(data)
	if loaded_map == null:
		_set_status("Ошибка: неверный формат карты (нужен schema_version = 1)")
		return
	_set_map(loaded_map)
	_set_status("Загружено: " + path)


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
	is_play_mode = true
	_canvas.set_game_session(session)
	_canvas.center_on_cell(session.player_pos)
	_canvas.grab_focus()
	_update_mode_ui()
	_refresh_stats()
	_set_status("Тест карты: прогресс временный • Стрелки/WASD • Esc — в редактор")


func _stop_play_mode() -> void:
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
	for control in _editor_controls:
		if control is BaseButton:
			(control as BaseButton).disabled = is_play_mode
		elif control is LineEdit:
			(control as LineEdit).editable = not is_play_mode
		control.modulate = Color(1, 1, 1, 0.60) if is_play_mode else Color(1, 1, 1, 1)
	_set_tool(selected_tool)
	_update_history_buttons()


func _try_move_player(dx: int, dy: int) -> void:
	if not is_play_mode or game_session == null:
		return
	if game_session.move_by(dx, dy):
		_canvas.center_on_cell(game_session.player_pos)
		_canvas.queue_redraw()
		_refresh_stats()
		_set_status("Ход %d • Позиция героя: %d,%d" % [game_session.steps, game_session.player_pos.x, game_session.player_pos.y])
	else:
		_set_status("Тут пройти нельзя.")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if is_play_mode:
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
