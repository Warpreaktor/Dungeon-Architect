class_name WeightedLootTable
extends Resource

@export var weights: Dictionary = {}
@export var quantity_ranges: Dictionary = {}


func draw_id(available_weights: Dictionary, rng: RandomNumberGenerator = null) -> String:
	var total: int = 0
	for weight in available_weights.values():
		total += maxi(int(weight), 0)
	if total <= 0:
		return ""
	var roll: int = rng.randi_range(0, total - 1) if rng != null else randi_range(0, total - 1)
	for item_id in available_weights:
		roll -= maxi(int(available_weights[item_id]), 0)
		if roll < 0:
			return str(item_id)
	return ""


func quantity(item_id: String, default_quantity: int, rng: RandomNumberGenerator = null) -> int:
	if not quantity_ranges.has(item_id):
		return default_quantity
	var bounds: Vector2i = quantity_ranges[item_id]
	var minimum: int = mini(bounds.x, bounds.y)
	var maximum: int = maxi(bounds.x, bounds.y)
	return rng.randi_range(minimum, maximum) if rng != null else randi_range(minimum, maximum)
