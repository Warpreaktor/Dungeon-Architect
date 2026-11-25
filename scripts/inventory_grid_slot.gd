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
var _rarity_color: Color = Color(0.3, 0.4, 0.46, 1)
var _cell_size: float = 54.0
var _drag_drop_state: int = 0
var _drag_state_source: String = ""
var _mouse_press_started: bool = false
var _mouse_dragged: bool = false
var _panel_style := StyleBoxFlat.new()
var _mouse_drop_data: Dictionary = {}


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
	_count.clip_text = true
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.add_theme_font_size_override("font_size", 13)
	_count.add_theme_color_override("font_color", Color(1, 0.89, 0.6))
	_count.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	_count.add_theme_constant_override("shadow_offset_x", 1)
	_count.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_count)
	_count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 5.0
	_icon.offset_top = 5.0
	_icon.offset_right = -5.0
	_icon.offset_bottom = -5.0
	_panel_style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", _panel_style)
	_apply_style()
	set_process(false)


func configure(index: int, definition: ItemDefinition, quantity: int, selected: bool, cell_size: float, next_session: GameSession = null) -> void:
	session = next_session
	slot_index = index
	item_id = definition.item_id if definition != null else ""
	var instance: ItemInstance = session.item_instance(session.inventory_instance_id(index)) if session != null and definition != null else null
	var rarity: Color = ItemMagicCatalog.display_color(instance) if instance != null and instance.rarity != ItemInstance.Rarity.COMMON else Color(0.3, 0.4, 0.46, 1)
	var style_changed: bool = rarity != _rarity_color or selected != _selected
	_rarity_color = rarity
	_selected = selected
	set_cell_size(cell_size)
	var texture: Texture2D = definition.icon if definition != null else null
	if _icon.texture != texture:
		_icon.texture = texture
	var count_text: String = str(quantity) if definition != null and quantity > 1 else ""
	if _count.text != count_text:
		_count.text = count_text
	set_drag_drop_state(0)
	if style_changed:
		_apply_style()


func set_cell_size(value: float) -> void:
	var minimum := Vector2(value, value)
	if custom_minimum_size != minimum:
		_count.add_theme_font_size_override("font_size", clampi(roundi(13.0 * value / 44.0), 1, 13))
		custom_minimum_size = minimum
	_cell_size = value


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_apply_style()


func set_drag_drop_state(state: int, source: String = "") -> void:
	var next_source: String = source if state != 0 else ""
	if _drag_state_source != next_source:
		_drag_state_source = next_source
		set_process(next_source == "mouse")
	if next_source != "mouse":
		_mouse_drop_data.clear()
	if _drag_drop_state == state:
		return
	_drag_drop_state = state
	_apply_style()


func _apply_style() -> void:
	_panel_style.bg_color = Color(0.18, 0.24, 0.29, 1) if _selected else Color(0.055, 0.085, 0.12, 1)
	_panel_style.border_color = Color(0.92, 0.73, 0.36) if _drag_drop_state == 1 else (Color(0.82, 0.28, 0.3) if _drag_drop_state == 2 else (Color(0.93, 0.73, 0.38, 1) if _selected else _rarity_color))
	_panel_style.set_border_width_all(2 if (_selected or _drag_drop_state != 0) else 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_press_started = true
			_mouse_dragged = false
		elif _mouse_press_started:
			_mouse_press_started = false
			if not _mouse_dragged and Rect2(Vector2.ZERO, size).has_point(event.position):
				activated.emit(slot_index)
		accept_event()

func _get_drag_data(_at_position: Vector2) -> Variant:
	_mouse_dragged = true
	_mouse_press_started = false
	if item_id.is_empty() or session == null:
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(_cell_size, _cell_size)
	set_drag_preview(preview)
	return {"kind": "bag", "slot": slot_index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("kind") or not data.has("slot") or session == null:
		return false
	if _drag_state_source == "mouse" and _mouse_drop_data == data:
		return _drag_drop_state == 1
	var valid: bool = session.can_transfer_inventory_item(str(data["kind"]), data["slot"], "bag", slot_index)
	_mouse_drop_data = data.duplicate()
	set_drag_drop_state(1 if valid else 2, "mouse")
	return valid


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _drag_state_source != "mouse":
		set_drag_drop_state(0)
		return
	var viewport := get_viewport()
	if viewport == null or not viewport.gui_is_dragging():
		set_drag_drop_state(0)
		return
	if not get_global_rect().has_point(get_global_mouse_position()):
		set_drag_drop_state(0)


func cancel_gesture() -> void:
	_mouse_press_started = false
	_mouse_dragged = false
	set_drag_drop_state(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _icon != null:
		cancel_gesture()


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	transferred.emit(str(data["kind"]), data["slot"], "bag", slot_index)
