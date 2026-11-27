class_name LootRewardLevel
extends Resource

@export_range(0, 99, 1) var minimum_stage: int = 0
@export_range(1.0, 10.0, 0.1) var stack_quantity_multiplier: float = 1.0


func stage_for(table: WeightedLootTable, victories: int, depth: int) -> int:
	var stage: int = table.stage_for_progress(victories, depth) if table != null else 0
	return maxi(stage, minimum_stage)


func apply_quantity(reward: Dictionary) -> void:
	if is_equal_approx(stack_quantity_multiplier, 1.0):
		return
	var item: ItemDefinition = ItemCatalog.get_item(str(reward.get("item_id", "")))
	if item == null or item.category not in [ItemDefinition.Category.CURRENCY, ItemDefinition.Category.CONSUMABLE]:
		return
	var maximum: int = 999999 if item.category == ItemDefinition.Category.CURRENCY else 9999
	reward["quantity"] = clampi(ceili(int(reward["quantity"]) * stack_quantity_multiplier), 1, maximum)
