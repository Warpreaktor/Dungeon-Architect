class_name ItemInstance
extends RefCounted

enum Rarity { COMMON, MAGIC, RARE, UNIQUE }

var instance_id: String = ""
var item_id: String = ""
var durability: int = 0
var rarity: int = Rarity.COMMON
var quality_id: String = ""
var affix_ids: Array[String] = []
var modifiers: Dictionary = {}
var unique_id: String = ""


static func create(id: String, definition: ItemDefinition, current_durability: int = -1) -> ItemInstance:
	if id.is_empty() or definition == null or definition.category != ItemDefinition.Category.EQUIPMENT or definition.stackable:
		return null
	var result := ItemInstance.new()
	result.instance_id = id
	result.item_id = definition.item_id
	result.quality_id = ItemMagicCatalog.RULES.default_quality_id
	if definition.equipment_slot == ItemDefinition.EquipmentSlot.SHIELD:
		var maximum: int = maxi(definition.max_durability, definition.defense_bonus)
		result.durability = maximum if current_durability < 0 else current_durability
	return result


func stat(field: String) -> int:
	return ItemMagicCatalog.effective_value(ItemCatalog.get_item(item_id), self, field)


func display_name() -> String:
	return ItemMagicCatalog.display_name(ItemCatalog.get_item(item_id), self)


func to_dict() -> Dictionary:
	return {"instance_id": instance_id, "item_id": item_id, "durability": durability,
		"rarity": int(rarity), "quality_id": quality_id, "affix_ids": affix_ids.duplicate(),
		"modifiers": modifiers.duplicate(true), "unique_id": unique_id}


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
	var saved_quality: Variant = data.get("quality_id", ItemMagicCatalog.RULES.default_quality_id)
	if typeof(saved_quality) != TYPE_STRING or ItemMagicCatalog.quality(saved_quality) == null or not ItemMagicCatalog.quality(saved_quality).accepts(item):
		return null
	result.quality_id = saved_quality
	var saved_affixes: Variant = data.get("affix_ids", [])
	if not (saved_affixes is Array):
		return null
	for saved_id in saved_affixes:
		if typeof(saved_id) != TYPE_STRING or ItemMagicCatalog.affix(saved_id) == null or result.affix_ids.has(saved_id):
			return null
		var definition: ItemAffixDefinition = ItemMagicCatalog.affix(saved_id)
		if not definition.accepts(item) or not ItemMagicCatalog.modifier_is_valid(item, definition.stat_id):
			return null
		result.affix_ids.append(saved_id)
	result.rarity = kind
	result.unique_id = str(data["unique_id"])
	for key in data["modifiers"]:
		if typeof(key) != TYPE_STRING or str(key).is_empty():
			return null
		if typeof(data["modifiers"][key]) not in [TYPE_INT, TYPE_FLOAT]:
			return null
		result.modifiers[key] = data["modifiers"][key]
	if not result.affix_ids.is_empty():
		var rarity_definition: ItemRarityDefinition = ItemMagicCatalog.rarity(result.rarity)
		if rarity_definition == null or not rarity_definition.accepts(item) or result.affix_ids.size() < rarity_definition.minimum_affixes or result.affix_ids.size() > rarity_definition.maximum_affixes:
			return null
		var allowed: Dictionary = {}
		for affix_id in result.affix_ids:
			var affix_definition: ItemAffixDefinition = ItemMagicCatalog.affix(affix_id)
			var key: String = affix_definition.stat_id
			var bounds: Vector2i = allowed.get(key, Vector2i.ZERO)
			allowed[key] = bounds + Vector2i(mini(affix_definition.minimum_value, affix_definition.maximum_value), maxi(affix_definition.minimum_value, affix_definition.maximum_value))
		if allowed.size() != result.modifiers.size():
			return null
		for key in allowed:
			if not result.modifiers.has(key) or float(result.modifiers[key]) != float(int(result.modifiers[key])):
				return null
			var value: int = int(result.modifiers[key])
			var bounds: Vector2i = allowed[key]
			if value < bounds.x or value > bounds.y:
				return null
	return result


static func _is_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(value) == float(int(value))
