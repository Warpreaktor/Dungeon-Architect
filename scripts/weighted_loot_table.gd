class_name WeightedLootTable
extends Resource

@export var weights: Dictionary = {}
@export var quantity_ranges: Dictionary = {}
@export var victory_milestones: PackedInt32Array = PackedInt32Array()
@export var depth_milestones: PackedInt32Array = PackedInt32Array()
@export var minimum_item_stage: Dictionary = {}


func stage_for_victories(victories: int) -> int:
	var stage: int = 0
	for milestone in victory_milestones:
		if victories < milestone:
			break
		stage += 1
	return stage


func stage_for_progress(victories: int, depth: int) -> int:
	var depth_stage: int = 0
	for milestone in depth_milestones:
		if depth < milestone:
			break
		depth_stage += 1
	return maxi(stage_for_victories(victories), depth_stage)


func allows(item_id: String, stage: int) -> bool:
	return stage >= maxi(int(minimum_item_stage.get(item_id, 0)), 0)


func draw_id(available_weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: int = 0
	for weight in available_weights.values():
		total += maxi(int(weight), 0)
	if total <= 0 or rng == null:
		return ""
	var roll: int = rng.randi_range(0, total - 1)
	for item_id in available_weights:
		roll -= maxi(int(available_weights[item_id]), 0)
		if roll < 0:
			return str(item_id)
	return ""


func quantity(item_id: String, default_quantity: int, rng: RandomNumberGenerator) -> int:
	if not quantity_ranges.has(item_id):
		return default_quantity
	var bounds: Vector2i = quantity_ranges[item_id]
	var minimum: int = mini(bounds.x, bounds.y)
	var maximum: int = maxi(bounds.x, bounds.y)
	return rng.randi_range(minimum, maximum) if rng != null else default_quantity
