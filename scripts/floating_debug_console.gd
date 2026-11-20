class_name FloatingDebugConsole
extends CanvasLayer

signal visibility_changed(opened: bool)

const MIN_SIZE: Vector2 = Vector2(280.0, 150.0)
const DEFAULT_VIEWPORT_SHARE: Vector2 = Vector2(0.56, 0.32)
const MAX_VIEWPORT_SHARE: Vector2 = Vector2(0.94, 0.82)
const VIEWPORT_PADDING: float = 12.0
const HEADER_HEIGHT: float = 38.0
const RESIZE_HANDLE_SIDE: float = 42.0
const EDGE_PADDING: float = 10.0

var _root: Control
var _panel: PanelContainer
var _log: RichTextLabel
var _gear: MenuButton
var _resize_grip: Control
var _desired_size: Vector2 = Vector2.ZERO
var _resizing: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _size_start: Vector2 = Vector2.ZERO


func _ready() -> void:
	layer = 25
	_root = Control.new()
	_root.name = "ConsoleOverlay"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.name = "ConsoleWindow"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.19, 0.21, 0.24, 0.91)
	style.border_color = Color(0.49, 0.54, 0.59, 0.87)
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = HEADER_HEIGHT
	column.add_child(header)
	var title := Label.new()
	title.text = "  Консоль событий"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = "Скрыть консоль"
	close_button.custom_minimum_size = Vector2(HEADER_HEIGHT, HEADER_HEIGHT)
	close_button.pressed.connect(func() -> void: set_open(false))
	header.add_child(close_button)
	var log_margin := MarginContainer.new()
	log_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_margin.add_theme_constant_override("margin_left", int(EDGE_PADDING))
	log_margin.add_theme_constant_override("margin_right", int(EDGE_PADDING))
	column.add_child(log_margin)
	_log = RichTextLabel.new()
	_log.name = "LogText"
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.selection_enabled = true
	_log.mouse_filter = Control.MOUSE_FILTER_STOP
	log_margin.add_child(_log)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(footer)
	_resize_grip = Control.new()
	_resize_grip.custom_minimum_size = Vector2(RESIZE_HANDLE_SIDE, RESIZE_HANDLE_SIDE)
	_resize_grip.mouse_filter = Control.MOUSE_FILTER_STOP
	_resize_grip.mouse_default_cursor_shape = Control.CURSOR_FDIAGSIZE
	_resize_grip.gui_input.connect(_on_resize_input)
	footer.add_child(_resize_grip)
	var grip_label := Label.new()
	grip_label.text = "◢"
	grip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_resize_grip.add_child(grip_label)
	_gear = MenuButton.new()
	_gear.icon = preload("res://assets/icons/commands/settings.png")
	_gear.tooltip_text = "Настройки интерфейса"
	_gear.custom_minimum_size = Vector2(HEADER_HEIGHT, HEADER_HEIGHT)
	_gear.get_popup().add_check_item("Показать консоль", 0)
	_gear.get_popup().id_pressed.connect(func(_id: int) -> void: set_open(not _panel.visible))
	_root.add_child(_gear)
	_desired_size = _root.size * DEFAULT_VIEWPORT_SHARE
	get_viewport().size_changed.connect(_fit_to_viewport)
	_panel.hide()
	_fit_to_viewport()


func log_node() -> RichTextLabel:
	return _log


func set_open(opened: bool) -> void:
	_panel.visible = opened
	_gear.get_popup().set_item_checked(0, opened)
	visibility_changed.emit(opened)
	if opened:
		_fit_to_viewport()


func is_open() -> bool:
	return _panel.visible


func set_game_controls_visible(is_game: bool) -> void:
	_gear.visible = is_game


func _fit_to_viewport() -> void:
	if _root == null:
		return
	var bounds: Vector2 = get_viewport().get_visible_rect().size
	if _desired_size == Vector2.ZERO:
		_desired_size = bounds * DEFAULT_VIEWPORT_SHARE
	var max_size: Vector2 = bounds * MAX_VIEWPORT_SHARE
	var min_size: Vector2 = Vector2(minf(MIN_SIZE.x, max_size.x), minf(MIN_SIZE.y, max_size.y))
	_panel.size = _desired_size.clamp(min_size, max_size)
	_panel.position = Vector2(VIEWPORT_PADDING, maxf(VIEWPORT_PADDING, bounds.y - _panel.size.y - VIEWPORT_PADDING))
	_gear.position = Vector2(maxf(VIEWPORT_PADDING, bounds.x - HEADER_HEIGHT - VIEWPORT_PADDING), VIEWPORT_PADDING)
	_gear.size = Vector2(HEADER_HEIGHT, HEADER_HEIGHT)


func _on_resize_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_resizing = true
		_drag_start = event.global_position
		_size_start = _panel.size
		_resize_grip.accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_resizing = true
		_drag_start = event.position
		_size_start = _panel.size
		_resize_grip.accept_event()


func _input(event: InputEvent) -> void:
	if not _resizing:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_resizing = false
	elif event is InputEventScreenTouch and not event.pressed:
		_resizing = false
	elif event is InputEventMouseMotion:
		_resize_to_pointer(event.global_position)
	elif event is InputEventScreenDrag:
		_resize_to_pointer(event.position)


func _resize_to_pointer(pointer: Vector2) -> void:
	_desired_size = _size_start + Vector2(pointer.x - _drag_start.x, _drag_start.y - pointer.y)
	_fit_to_viewport()
