class_name EquipmentSlotControl
extends PanelContainer

signal selected(slot_id: String)
signal transferred(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant)

var slot_id: String = ""
var item_id: String = ""
var session: GameSession
var _icon: TextureRect
var _glyph: Label
var _last_visual_state: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(58, 58)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 6
	_icon.offset_right = -6
	_icon.offset_top = 6
	_icon.offset_bottom = -6
	_glyph = Label.new()
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph.add_theme_font_size_override("font_size", 23)
	add_child(_glyph)
	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_style(false)


func configure(next_slot_id: String, next_session: GameSession) -> void:
	slot_id = next_slot_id
	session = next_session
	item_id = session.equipment_item_id(slot_id) if session != null else ""
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	_icon.texture = item.icon if item != null else null
	_glyph.text = str(EquipmentSlotRules.SYMBOLS.get(slot_id, "")) if item == null else ""
	_style(false)


func _style(highlight: bool, invalid: bool = false) -> void:
	var state: int = 2 if invalid else (1 if highlight else 0)
	if state == _last_visual_state:
		return
	_last_visual_state = state
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.24, 0.29, 0.95) if highlight else Color(0.06, 0.09, 0.14, 0.97)
	style.border_color = Color(0.82, 0.29, 0.30) if invalid else (Color(0.9, 0.72, 0.38) if highlight else Color(0.36, 0.49, 0.57))
	style.set_border_width_all(2 if highlight else 1)
	style.set_corner_radius_all(7)
	add_theme_stylebox_override("panel", style)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(slot_id)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		selected.emit(slot_id)
		accept_event()


func _get_drag_data(_pos: Vector2) -> Variant:
	if item_id.is_empty():
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.custom_minimum_size = Vector2(58, 58)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"kind": "equipment", "slot": slot_id}


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	var accepted: bool = data is Dictionary and data.has("kind") and data.has("slot") and session != null and session.can_transfer_inventory_item(str(data["kind"]), data["slot"], "equipment", slot_id)
	_style(accepted, not accepted)
	return accepted


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _icon != null:
		_style(false)


func _drop_data(_pos: Vector2, data: Variant) -> void:
	transferred.emit(str(data["kind"]), data["slot"], "equipment", slot_id)
