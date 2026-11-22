class_name InventoryGridSlot
extends PanelContainer

signal activated(index: int)
signal moved(from_index: int, to_index: int)
signal transferred(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant)

var slot_index: int = -1
var item_id: String = ""
var session: GameSession
var _icon: TextureRect
var _count: Label
var _selected: bool = false
var _cell_size: float = 54.0
var _drag_drop_state: int = 0
var _drag_state_source: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count = Label.new()
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.add_theme_font_size_override("font_size", 13)
	_count.add_theme_color_override("font_color", Color(1, 0.89, 0.6))
	_count.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_count.add_theme_constant_override("shadow_offset_x", 1)
	_count.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_count)
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_style()


func configure(index: int, definition: ItemDefinition, quantity: int, selected: bool, cell_size: float, next_session: GameSession = null) -> void:
	session = next_session
	slot_index = index
	item_id = definition.item_id if definition != null else ""
	_selected = selected
	_cell_size = cell_size
	custom_minimum_size = Vector2(cell_size, cell_size)
	if _icon != null:
		_icon.texture = definition.icon if definition != null else null
		_icon.offset_left = 5.0
		_icon.offset_top = 5.0
		_icon.offset_right = -5.0
		_icon.offset_bottom = -5.0
	if _count != null:
		_count.text = str(quantity) if definition != null and quantity > 1 else ""
	_apply_style()


func set_drag_drop_state(state: int, source: String = "") -> void:
	_drag_drop_state = state
	_drag_state_source = source if state != 0 else ""
	_apply_style()


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.24, 0.29, 1) if _selected else Color(0.055, 0.085, 0.12, 1)
	style.border_color = Color(0.92, 0.73, 0.36) if _drag_drop_state == 1 else (Color(0.82, 0.28, 0.3) if _drag_drop_state == 2 else (Color(0.93, 0.73, 0.38, 1) if _selected else Color(0.3, 0.4, 0.46, 1)))
	style.set_border_width_all(2 if (_selected or _drag_drop_state != 0) else 1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		activated.emit(slot_index)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		activated.emit(slot_index)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty():
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(_cell_size, _cell_size)
	set_drag_preview(preview)
	return {"kind": "bag", "slot": slot_index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var valid: bool = data is Dictionary and data.has("kind") and data.has("slot") and session != null and session.can_transfer_inventory_item(str(data["kind"]), data["slot"], "bag", slot_index)
	set_drag_drop_state(1 if valid else 2, "mouse")
	return valid


func _process(_delta: float) -> void:
	if _drag_state_source != "mouse":
		return
	var viewport := get_viewport()
	if viewport == null or not viewport.gui_is_dragging():
		set_drag_drop_state(0)
		return
	if not get_global_rect().has_point(get_global_mouse_position()):
		set_drag_drop_state(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _icon != null:
		set_drag_drop_state(0)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	transferred.emit(str(data["kind"]), data["slot"], "bag", slot_index)
