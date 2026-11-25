class_name ItemRarityDefinition
extends Resource

@export_range(0, 3, 1) var tier: int = 0
@export var display_name: String = ""
@export var color: Color = Color.WHITE
@export_range(0, 10000, 1) var roll_weight: int = 0
@export_range(0, 10, 1) var minimum_affixes: int = 0
@export_range(0, 10, 1) var maximum_affixes: int = 0
@export var allowed_categories: PackedInt32Array = PackedInt32Array()
@export var allowed_slots: PackedInt32Array = PackedInt32Array()


func accepts(item: ItemDefinition) -> bool:
	return item != null and (allowed_categories.is_empty() or allowed_categories.has(item.category)) and (allowed_slots.is_empty() or allowed_slots.has(item.equipment_slot))
