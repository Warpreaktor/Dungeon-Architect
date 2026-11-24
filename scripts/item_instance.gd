class_name ItemInstance
extends RefCounted

enum Rarity { COMMON, MAGIC, RARE, UNIQUE }

var instance_id: String = ""
var item_id: String = ""
var durability: int = 0
var rarity: int = Rarity.COMMON
var modifiers: Dictionary = {}
var unique_id: String = ""


static func create(id: String, definition: ItemDefinition, current_durability: int = -1) -> ItemInstance:
	if id.is_empty() or definition == null or definition.category != ItemDefinition.Category.EQUIPMENT or definition.stackable:
		return null
	var result := ItemInstance.new()
	result.instance_id = id
	result.item_id = definition.item_id
	if definition.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD:
		var maximum: int = maxi(definition.max_durability, definition.defense_bonus)
		result.durability = maximum if current_durability < 0 else current_durability
	return result


func to_dict() -> Dictionary:
	return {"instance_id": instance_id, "item_id": item_id, "durability": durability,
		"rarity": int(rarity), "modifiers": modifiers.duplicate(true), "unique_id": unique_id}


static func from_dict(data: Variant) -> ItemInstance:
	if not (data is Dictionary):
		return null
	if typeof(data.get("instance_id")) != TYPE_STRING or typeof(data.get("item_id")) != TYPE_STRING:
		return null
	var item: ItemDefinition = ItemCatalog.get_item(str(data["item_id"]))
	if item == null or item.category != ItemDefinition.Category.EQUIPMENT or item.stackable:
		return null
	if not _is_integer(data.get("durability")) or not _is_integer(data.get("rarity")):
		return null
	var kind: int = int(data["rarity"])
	if kind < Rarity.COMMON or kind > Rarity.UNIQUE or not (data.get("modifiers") is Dictionary):
		return null
	if typeof(data.get("unique_id")) != TYPE_STRING:
		return null
	var durability_value: int = int(data["durability"])
	if durability_value < 0 or durability_value > 100000000:
		return null
	var result: ItemInstance = create(str(data["instance_id"]), item, durability_value)
	if result == null:
		return null
	result.rarity = kind
	result.unique_id = str(data["unique_id"])
	for key in data["modifiers"]:
		if typeof(key) != TYPE_STRING or str(key).is_empty():
			return null
		if typeof(data["modifiers"][key]) not in [TYPE_INT, TYPE_FLOAT]:
			return null
		result.modifiers[key] = data["modifiers"][key]
	return result


static func _is_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(value) == float(int(value))
