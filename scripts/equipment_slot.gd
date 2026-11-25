class_name EquipmentSlotControl
extends PanelContainer

signal selected(slot_id: String)
signal transferred(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant)

const EMPTY_ICONS: Dictionary = {
	"head": preload("res://assets/icons/equipment_slots/helmet.png"),
	"neck": preload("res://assets/icons/equipment_slots/amulet.png"),
	"body": preload("res://assets/icons/equipment_slots/armor.png"),
	"main_hand": preload("res://assets/icons/equipment_slots/sword.png"),
	"off_hand": preload("res://assets/icons/equipment_slots/shield.png"),
	"ring_left": preload("res://assets/icons/equipment_slots/ring.png"),
	"ring_right": preload("res://assets/icons/equipment_slots/ring.png"),
	"belt": preload("res://assets/icons/equipment_slots/belt.png"),
	"gloves": preload("res://assets/icons/equipment_slots/gloves.png"),
	"boots": preload("res://assets/icons/equipment_slots/boots.png")
}
const EMPTY_ICON_SHADER: Shader = preload("res://shaders/empty_equipment_icon.gdshader")

var slot_id: String = ""
var item_id: String = ""
var session: GameSession
var _icon: TextureRect
var _glyph: Label
var _empty_icon_material: ShaderMaterial
var _last_visual_state: int = -1
var _drag_drop_state: int = 0
var _panel_style := StyleBoxFlat.new()
var _mouse_drop_data: Dictionary = {}
var _drag_state_source: String = ""
var _virtual_two_handed: bool = false
var _selected: bool = false
var _rarity_color: Color = Color(0.36, 0.49, 0.57)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(58, 58)
	_empty_icon_material = ShaderMaterial.new()
	_empty_icon_material.shader = EMPTY_ICON_SHADER
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
	_panel_style.set_corner_radius_all(7)
	add_theme_stylebox_override("panel", _panel_style)
	_style(false)
	set_process(false)


func configure(next_slot_id: String, next_session: GameSession, virtual_texture: Texture2D = null) -> void:
	slot_id = next_slot_id
	session = next_session
	item_id = session.equipment_item_id(slot_id) if session != null else ""
	var item: ItemDefinition = ItemCatalog.get_item(item_id)
	var instance: ItemInstance = session.item_instance(session.equipment_instance_id(slot_id)) if session != null and item != null else null
	var rarity: Color = ItemMagicCatalog.display_color(instance) if instance != null and instance.rarity != ItemInstance.Rarity.COMMON else Color(0.36, 0.49, 0.57)
	var is_virtual: bool = item == null and virtual_texture != null
	if _rarity_color != rarity or _virtual_two_handed != is_virtual:
		_last_visual_state = -1
	_rarity_color = rarity
	_virtual_two_handed = is_virtual
	var placeholder: Texture2D = EMPTY_ICONS.get(slot_id) as Texture2D
	var texture: Texture2D = item.icon if item != null else (virtual_texture if is_virtual else placeholder)
	var material: Material = _empty_icon_material if item == null and not is_virtual else null
	var tint: Color = Color(0.62, 0.66, 0.7, 0.73) if is_virtual else Color.WHITE
	var glyph: String = "" if item != null or placeholder != null or is_virtual else str(EquipmentSlotRules.SYMBOLS.get(slot_id, ""))
	if _icon.texture != texture:
		_icon.texture = texture
	if _icon.material != material:
		_icon.material = material
	if _icon.modulate != tint:
		_icon.modulate = tint
	if _glyph.text != glyph:
		_glyph.text = glyph
	set_drag_drop_state(0)


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_last_visual_state = -1
	_style(_drag_drop_state == 1, _drag_drop_state == 2)


func set_drag_drop_state(state: int, source: String = "") -> void:
	var next_source: String = source if state != 0 else ""
	if _drag_state_source != next_source:
		_drag_state_source = next_source
		set_process(next_source == "mouse")
	if next_source != "mouse":
		_mouse_drop_data.clear()
	_drag_drop_state = state
	_style(state == 1, state == 2)


func _style(highlight: bool, invalid: bool = false) -> void:
	var state: int = 2 if invalid else (1 if highlight else (3 if _selected else 0))
	if state == _last_visual_state:
		return
	_last_visual_state = state
	_panel_style.bg_color = Color(0.13, 0.24, 0.29, 0.95) if highlight or _selected else (Color(0.075, 0.105, 0.15, 0.97) if _virtual_two_handed else Color(0.06, 0.09, 0.14, 0.97))
	_panel_style.border_color = Color(0.82, 0.29, 0.30) if invalid else (Color(0.9, 0.72, 0.38) if highlight or _selected else _rarity_color)
	_panel_style.set_border_width_all(2 if highlight or _selected else 1)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		selected.emit(slot_id)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		selected.emit(slot_id)
		accept_event()


func _get_drag_data(_pos: Vector2) -> Variant:
	if item_id.is_empty() or session == null:
		return null
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.custom_minimum_size = Vector2(58, 58)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return {"kind": "equipment", "slot": slot_id}


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("kind") or not data.has("slot") or session == null:
		return false
	if _drag_state_source == "mouse" and _mouse_drop_data == data:
		return _drag_drop_state == 1
	var accepted: bool = session.can_transfer_inventory_item(str(data["kind"]), data["slot"], "equipment", slot_id)
	_mouse_drop_data = data.duplicate()
	set_drag_drop_state(1 if accepted else 2, "mouse")
	return accepted


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _drag_state_source != "mouse":
		set_drag_drop_state(0)
		return
	if not get_viewport().gui_is_dragging() or not get_global_rect().has_point(get_global_mouse_position()):
		set_drag_drop_state(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		set_drag_drop_state(0)


func _drop_data(_pos: Vector2, data: Variant) -> void:
	transferred.emit(str(data["kind"]), data["slot"], "equipment", slot_id)
