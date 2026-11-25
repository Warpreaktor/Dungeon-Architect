class_name EquipmentMannequin
extends Control

signal slot_selected(slot_id: String)
signal item_transferred(from_kind: String, from_slot: Variant, to_kind: String, to_slot: Variant)

const POSITIONS: Dictionary = {
	"head": Vector2(0.5, 0.07), "neck": Vector2(0.84, 0.19),
	"body": Vector2(0.5, 0.45), "main_hand": Vector2(0.12, 0.45),
	"off_hand": Vector2(0.88, 0.45), "ring_left": Vector2(0.12, 0.68),
	"ring_right": Vector2(0.88, 0.68), "belt": Vector2(0.5, 0.69),
	"gloves": Vector2(0.24, 0.9), "boots": Vector2(0.76, 0.9)
}

var slots: Dictionary = {}
var _portrait: TextureRect
var _selected_slot: String = ""


func _ready() -> void:
	clip_contents = false
	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.modulate = Color(0.45, 0.59, 0.69, 0.66)
	add_child(_portrait)
	for slot_id in EquipmentSlotRules.SLOT_IDS:
		var slot := EquipmentSlotControl.new()
		add_child(slot)
		slot.selected.connect(func(id: String) -> void: slot_selected.emit(id))
		slot.transferred.connect(func(kind: String, origin: Variant, dest_kind: String, dest: Variant) -> void: item_transferred.emit(kind, origin, dest_kind, dest))
		slots[slot_id] = slot
	resized.connect(_layout_slots)
	_layout_slots()


func show_hero(session: GameSession) -> void:
	var member: HeroState = session._inventory_equipment_member() if session != null else null
	var portrait: Texture2D = member.definition.portrait if member != null else null
	if _portrait.texture != portrait:
		_portrait.texture = portrait
	var weapon: ItemDefinition = ItemCatalog.get_item(member.equipped_weapon_id) if member != null else null
	var shadow: Texture2D = weapon.icon if weapon != null and weapon.two_handed else null
	for slot_id in slots:
		var slot: EquipmentSlotControl = slots[slot_id]
		slot.configure(str(slot_id), session, shadow if slot_id == "off_hand" else null)


func clear_session() -> void:
	for slot in slots.values():
		slot.session = null


func set_selected_slot(slot_id: String) -> void:
	if _selected_slot == slot_id:
		return
	if slots.has(_selected_slot):
		slots[_selected_slot].set_selected(false)
	_selected_slot = slot_id
	if slots.has(_selected_slot):
		slots[_selected_slot].set_selected(true)


func _layout_slots() -> void:
	if _portrait == null:
		return
	_portrait.position = Vector2(size.x * 0.23, size.y * 0.15)
	_portrait.size = Vector2(size.x * 0.54, size.y * 0.72)
	for slot_id in slots:
		var slot: EquipmentSlotControl = slots[slot_id]
		var center: Vector2 = POSITIONS.get(slot_id, Vector2(0.5, 0.5))
		slot.position = Vector2(size.x * center.x - 29, size.y * center.y - 29)
		slot.size = Vector2(58, 58)
