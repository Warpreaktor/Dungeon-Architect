class_name ItemQualityDefinition
extends Resource

@export var quality_id: String = ""
@export var display_name: String = ""
@export_range(0, 10000, 1) var roll_weight: int = 0
@export_range(1, 500, 1) var scaling_percent: int = 100
@export var allowed_categories: PackedInt32Array = PackedInt32Array()
@export var allowed_slots: PackedInt32Array = PackedInt32Array()


func accepts(item: ItemDefinition) -> bool:
	return item != null and (allowed_categories.is_empty() or allowed_categories.has(item.category)) and (allowed_slots.is_empty() or allowed_slots.has(item.equipment_slot))
