class_name LootPool
extends Resource

@export var table: WeightedLootTable
@export var allowed_categories: PackedInt32Array = PackedInt32Array()
@export var allowed_slots: PackedInt32Array = PackedInt32Array()
@export var roll_count: Vector2i = Vector2i(1, 1)
@export var quantity_override: Vector2i = Vector2i.ZERO

var _stages: Array[int] = []
var _weights_by_stage: Dictionary = {}


func prepare() -> void:
	if not _stages.is_empty() or table == null:
		return
	_stages.append(0)
	for value in table.minimum_item_stage.values():
		var stage: int = maxi(int(value), 0)
		if not _stages.has(stage):
			_stages.append(stage)
	_stages.sort()
	var eligible: Dictionary = {}
	for raw_id in table.weights:
		var item_id: String = str(raw_id)
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item == null or item.category == ItemDefinition.Category.QUEST or int(table.weights[raw_id]) <= 0:
			continue
		if not allowed_categories.is_empty() and not allowed_categories.has(item.category):
			continue
		if not allowed_slots.is_empty() and not allowed_slots.has(item.equipment_slot):
			continue
		eligible[item_id] = table.weights[raw_id]
	for stage in _stages:
		var available: Dictionary = {}
		for item_id in eligible:
			if table.allows(str(item_id), stage):
				available[item_id] = eligible[item_id]
		_weights_by_stage[stage] = available


func _weights(stage: int) -> Dictionary:
	prepare()
	if _stages.is_empty() or stage < 0:
		return {}
	var unlocked: int = 0
	for threshold in _stages:
		if threshold > stage:
			break
		unlocked = threshold
	return _weights_by_stage[unlocked]


func _range_value(bounds: Vector2i, rng: RandomNumberGenerator, minimum: int) -> int:
	var low: int = maxi(mini(bounds.x, bounds.y), minimum)
	var high: int = maxi(maxi(bounds.x, bounds.y), low)
	return low if low == high else rng.randi_range(low, high)


func possible_item_ids(stage: int) -> Array[String]:
	var ids: Array[String] = []
	if maxi(roll_count.x, roll_count.y) <= 0:
		return ids
	for item_id in _weights(stage):
		ids.append(str(item_id))
	return ids


func roll(rng: RandomNumberGenerator, stage: int) -> Array[Dictionary]:
	var rewards: Array[Dictionary] = []
	if table == null or rng == null:
		return rewards
	var available: Dictionary = _weights(stage)
	if available.is_empty():
		return rewards
	for index in range(_range_value(roll_count, rng, 0)):
		var item_id: String = table.draw_id(available, rng)
		if item_id.is_empty():
			break
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		var amount: int = table.quantity(item_id, item.default_quantity, rng) if quantity_override == Vector2i.ZERO else _range_value(quantity_override, rng, 1)
		var reward: Dictionary = {"item_id": item_id, "quantity": maxi(amount, 1)}
		if item.category == ItemDefinition.Category.EQUIPMENT and not item.stackable:
			reward["roll_magic"] = true
		rewards.append(reward)
	return rewards
