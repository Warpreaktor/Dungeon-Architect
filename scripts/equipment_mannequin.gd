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
var _session: GameSession


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
	_apply_two_handed_shadow()
	_layout_slots()


func show_hero(session: GameSession) -> void:
	_session = session
	_portrait.texture = session.hero.definition.portrait if session != null and session.hero != null else null
	for slot_id in slots:
		var slot: EquipmentSlotControl = slots[slot_id]
		slot.configure(str(slot_id), session)
	_layout_slots()


func _apply_two_handed_shadow() -> void:
	if _session == null or _session.hero == null:
		return
	var off_hand: EquipmentSlot = slots.get("off_hand") as EquipmentSlot
	if off_hand == null or not off_hand.item_id.is_empty():
		return
	var weapon: ItemDefinition = ItemCatalog.get_item(_session.hero.equipped_weapon_id)
	if weapon != null and weapon.two_handed and weapon.icon != null:
		off_hand.show_virtual_item(weapon.icon)


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
