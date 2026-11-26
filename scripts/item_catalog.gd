class_name ItemCatalog
extends RefCounted

const ITEM_DIRECTORY: String = "res://items"
const LOOT_TABLE: WeightedLootTable = preload("res://data/default_loot.tres")
const LEGACY_IDS := {"key_yellow": "key"}
const LEGACY_UNLISTED_EQUIPMENT_IDS := ["leather_armor", "leather_boots", "leather_gloves", "plain_amulet", "cloth_belt", "copper_ring"]
const STARTER_ONLY_EQUIPMENT_IDS := ["burolom_drill"]

static var _prepared: bool = false
static var _default_loot_stages: Array[int] = []
static var _default_loot_weights: Dictionary = {}


static func prepare() -> void:
	if _prepared:
		return
	ResourceCatalog.warm(ITEM_DIRECTORY)
	_prepare_default_loot()
	_prepared = true


static func _prepare_default_loot() -> void:
	if not _default_loot_stages.is_empty():
		return
	_default_loot_stages.append(0)
	for minimum_stage in LOOT_TABLE.minimum_item_stage.values():
		var stage: int = maxi(int(minimum_stage), 0)
		if not _default_loot_stages.has(stage):
			_default_loot_stages.append(stage)
	_default_loot_stages.sort()
	for stage in _default_loot_stages:
		_default_loot_weights[stage] = _available_loot_weights(LOOT_TABLE, stage)


static func _available_loot_weights(table: WeightedLootTable, stage: int) -> Dictionary:
	var available: Dictionary = {}
	for item_id in table.weights:
		var item: ItemDefinition = get_item(str(item_id))
		if item != null and item.category != ItemDefinition.Category.QUEST and table.allows(str(item_id), stage):
			available[item_id] = table.weights[item_id]
	return available


static func _prepared_loot_weights(stage: int) -> Dictionary:
	if stage < 0:
		return {}
	_prepare_default_loot()
	var unlocked_stage: int = 0
	for minimum_stage in _default_loot_stages:
		if minimum_stage > stage:
			break
		unlocked_stage = minimum_stage
	return _default_loot_weights[unlocked_stage]


static func list_ids() -> Array[String]:
	var ids: Array[String] = ResourceCatalog.list_ids(ITEM_DIRECTORY)
	for item_id in LEGACY_UNLISTED_EQUIPMENT_IDS + STARTER_ONLY_EQUIPMENT_IDS:
		ids.erase(item_id)
	return ids


static func has(item_id: String) -> bool:
	return get_item(item_id) != null


static func get_item(item_id: String) -> ItemDefinition:
	return ResourceCatalog.load_by_id(ITEM_DIRECTORY, str(LEGACY_IDS.get(item_id, item_id))) as ItemDefinition


static func quantity_for_entity(entity: Dictionary) -> int:
	var definition: ItemDefinition = get_item(str(entity.get("type", "")))
	if definition == null:
		return 0
	var properties: Dictionary = entity.get("properties", {})
	return maxi(1, int(properties.get("quantity", definition.default_quantity)))


static func roll_loot(rng: RandomNumberGenerator, table: WeightedLootTable = LOOT_TABLE, stage: int = 0) -> Dictionary:
	if rng == null:
		return {}
	var available: Dictionary = _prepared_loot_weights(stage) if table == LOOT_TABLE else _available_loot_weights(table, stage)
	var item_id: String = table.draw_id(available, rng)
	if item_id.is_empty():
		return {}
	var definition: ItemDefinition = get_item(item_id)
	var reward: Dictionary = {"item_id": item_id, "quantity": table.quantity(item_id, definition.default_quantity, rng)}
	if definition.category == ItemDefinition.Category.EQUIPMENT and not definition.stackable:
		reward["roll_magic"] = true
	return reward


static func ids_by_category(category: int) -> Array[String]:
	var result: Array[String] = []
	for item_id in list_ids():
		var item: ItemDefinition = get_item(item_id)
		if item != null and item.category == category:
			result.append(item_id)
	return result


static func consumable_ids() -> Array[String]:
	return ids_by_category(ItemDefinition.Category.CONSUMABLE)


static func equipment_ids() -> Array[String]:
	return ids_by_category(ItemDefinition.Category.EQUIPMENT)
