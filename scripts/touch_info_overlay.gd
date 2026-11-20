class_name TouchInfoOverlay
extends CanvasLayer

const PANEL_MAX_WIDTH: float = 540.0
const PANEL_SCREEN_SHARE: float = 0.9
const PANEL_BOTTOM_MARGIN: float = 18.0
const PANEL_INSET: int = 18
const PANEL_TEXT_SIZE: int = 17
const PANEL_TITLE_SIZE: int = 22
const PANEL_SCROLL_SHARE: float = 0.62
const TOUCH_HOLD_SECONDS: float = 0.55
const TOUCH_MOVE_TOLERANCE: float = 20.0

var _backdrop: ColorRect
var _panel: PanelContainer
var _heading: Label
var _description: Label
var _scroll: ScrollContainer
var _root: Control
var _touch_holds: Dictionary = {}


func _ready() -> void:
	layer = 50
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.01, 0.02, 0.04, 0.65)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_input)
	_root.add_child(_backdrop)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#142331")
	style.border_color = Color("#d8ae70")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, PANEL_INSET)
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	_heading = Label.new()
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.add_theme_color_override("font_color", Color("#e8c58a"))
	_heading.add_theme_font_size_override("font_size", PANEL_TITLE_SIZE)
	_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_heading)
	var close := Button.new()
	close.text = "×"
	close.custom_minimum_size = Vector2(48, 48)
	close.pressed.connect(hide_info)
	top.add_child(close)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_scroll)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description.add_theme_font_size_override("font_size", PANEL_TEXT_SIZE)
	_scroll.add_child(_description)
	_root.hide()
	get_viewport().size_changed.connect(_position_panel)


func show_text(content: String) -> void:
	if content.strip_edges().is_empty():
		return
	var lines: PackedStringArray = content.split("\n", false, 1)
	show_info(lines[0], lines[1] if lines.size() > 1 else "")


func show_info(title: String, description: String) -> void:
	_heading.text = title
	_description.text = description
	_root.show()
	_position_panel()
	call_deferred("_position_panel")


func hide_info() -> void:
	_root.hide()


func is_open() -> bool:
	return _root.visible


func _position_panel() -> void:
	if _panel == null or not _root.visible:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_width: float = minf(PANEL_MAX_WIDTH, viewport_size.x * PANEL_SCREEN_SHARE)
	_panel.custom_minimum_size.x = panel_width
	_description.custom_minimum_size.x = maxf(0.0, panel_width - float(PANEL_INSET * 2))
	_scroll.custom_minimum_size.y = minf(_description.get_combined_minimum_size().y, viewport_size.y * PANEL_SCROLL_SHARE)
	_panel.size = Vector2(panel_width, 0.0)
	var wanted_height: float = _panel.get_combined_minimum_size().y
	_panel.size = Vector2(panel_width, minf(wanted_height, viewport_size.y * PANEL_SCREEN_SHARE))
	_panel.position = Vector2((viewport_size.x - panel_width) * 0.5, maxf(0.0, viewport_size.y - _panel.size.y - PANEL_BOTTOM_MARGIN))


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_info()
	elif event is InputEventScreenTouch and event.pressed:
		hide_info()


func _unhandled_key_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("ui_cancel"):
		hide_info()
		get_viewport().set_input_as_handled()


func attach_long_press(button: BaseButton, detail: Callable) -> void:
	if button == null or not is_instance_valid(button):
		return
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = TOUCH_HOLD_SECONDS
	button.add_child(timer)
	var state: Dictionary = {"active": false, "origin": Vector2.ZERO, "triggered": false}
	_touch_holds[button.get_instance_id()] = state
	timer.timeout.connect(_on_long_press.bind(button, detail))
	button.gui_input.connect(_on_touch_input.bind(button, timer))
	button.tree_exiting.connect(_forget_button.bind(button.get_instance_id()))


func _on_touch_input(event: InputEvent, button: BaseButton, timer: Timer) -> void:
	var state: Dictionary = _touch_holds.get(button.get_instance_id(), {})
	if state.is_empty():
		return
	if event is InputEventScreenTouch:
		if event.pressed and event.index == 0:
			state["origin"] = event.position
			state["active"] = true
			state["triggered"] = false
			timer.start()
		elif not event.pressed and event.index == 0:
			timer.stop()
			state["active"] = false
			if bool(state["triggered"]):
				button.accept_event()
	elif event is InputEventScreenDrag and bool(state.get("active", false)):
		if event.position.distance_to(Vector2(state["origin"])) > TOUCH_MOVE_TOLERANCE:
			timer.stop()
			state["active"] = false
	_touch_holds[button.get_instance_id()] = state


func _on_long_press(button: BaseButton, detail: Callable) -> void:
	if not is_instance_valid(button):
		return
	var state: Dictionary = _touch_holds.get(button.get_instance_id(), {})
	if state.is_empty() or not bool(state.get("active", false)):
		return
	state["triggered"] = true
	_touch_holds[button.get_instance_id()] = state
	if detail.is_valid():
		show_text(str(detail.call()))


func _forget_button(id: int) -> void:
	_touch_holds.erase(id)


func consume_long_press(button: BaseButton) -> bool:
	if button == null or not is_instance_valid(button):
		return false
	var id: int = button.get_instance_id()
	var state: Dictionary = _touch_holds.get(id, {})
	if not bool(state.get("triggered", false)):
		return false
	state["triggered"] = false
	_touch_holds[id] = state
	return true


func attach_tap(control: Control, provider: Callable) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	control.gui_input.connect(_on_tap.bind(provider))


func _on_tap(event: InputEvent, provider: Callable) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_text(str(provider.call()))
	elif event is InputEventScreenTouch and event.pressed and event.index == 0:
		show_text(str(provider.call()))
