class_name ProgressSnapshotCodec
extends RefCounted

const FORMAT_VERSION: int = 3
const PREVIOUS_FORMAT_VERSION: int = 2
const LEGACY_FORMAT_VERSION: int = 1
const FLOOR_FLAGS := [
	"exit_rewards", "removed", "chests", "traps", "revealed_traps", "triggers", "messages"
]


static func map_signature(map_ref: DungeonMap) -> String:
	return JSON.stringify({
		"width": map_ref.width,
		"height": map_ref.height,
		"terrain": map_ref.terrain,
		"entities": map_ref.entities
	}).sha256_text()


static func encode_floor(state: Dictionary) -> Dictionary:
	var position: Vector2i = state.get("position", Vector2i(-1, -1))
	var result: Dictionary = {
		"map_id": str(state.get("map_id", "")),
		"position": [position.x, position.y],
		"ground_loot": state.get("ground_loot", []).duplicate(true),
		"revealed": state.get("revealed", []).duplicate(true)
	}
	for field in FLOOR_FLAGS:
		result[field] = state.get(field, {}).duplicate(true)
	return result


static func decode_floor(data: Variant, map_ref: DungeonMap) -> Dictionary:
	if not (data is Dictionary) or map_ref == null or str(data.get("map_id", "")) != map_ref.map_id:
		return {}
	var raw_position: Variant = data.get("position")
	if not (raw_position is Array) or raw_position.size() != 2:
		return {}
	if not _is_integer(raw_position[0]) or not _is_integer(raw_position[1]):
		return {}
	var position := Vector2i(int(raw_position[0]), int(raw_position[1]))
	if not map_ref.contains(position.x, position.y) or map_ref.get_terrain(position.x, position.y) != "floor":
		return {}
	var raw_revealed: Variant = data.get("revealed")
	if not (raw_revealed is Array) or raw_revealed.size() != map_ref.height:
		return {}
	for row in raw_revealed:
		if not (row is Array) or row.size() != map_ref.width:
			return {}
		for visible_cell in row:
			if typeof(visible_cell) != TYPE_BOOL:
				return {}
	var raw_ground: Variant = data.get("ground_loot")
	if not (raw_ground is Array) or raw_ground.size() > map_ref.width * map_ref.height:
		return {}
	var ground_ids: Dictionary = {}
	for container in raw_ground:
		if not (container is Dictionary) or typeof(container.get("id")) != TYPE_STRING:
			return {}
		var container_id: String = str(container["id"])
		if container_id.is_empty() or ground_ids.has(container_id):
			return {}
		ground_ids[container_id] = true
		if not _is_integer(container.get("x")) or not _is_integer(container.get("y")):
			return {}
		var x: int = int(container["x"])
		var y: int = int(container["y"])
		if not map_ref.contains(x, y) or map_ref.get_terrain(x, y) != "floor":
			return {}
		if not (container.get("loot") is Array):
			return {}
		for item in container["loot"]:
			if not (item is Dictionary) or typeof(item.get("item_id")) != TYPE_STRING:
				return {}
			if ItemCatalog.get_item(str(item["item_id"])) == null or not _is_integer(item.get("quantity")) or int(item["quantity"]) <= 0:
				return {}
			if item.has("instances"):
				var instances: Variant = item["instances"]
				var definition: ItemDefinition = ItemCatalog.get_item(str(item["item_id"]))
				if not (instances is Array) or definition == null or definition.category != ItemDefinition.Category.EQUIPMENT or definition.stackable or instances.size() != int(item["quantity"]):
					return {}
				for data in instances:
					var instance: ItemInstance = ItemInstance.from_dict(data)
					if instance == null or instance.item_id != str(item["item_id"]):
						return {}
			if item.has("durabilities"):
				if not (item["durabilities"] is Array) or item["durabilities"].size() != int(item["quantity"]):
					return {}
				for durability in item["durabilities"]:
					if not _is_integer(durability) or int(durability) < 0:
						return {}
	var restored: Dictionary = {
		"map_id": map_ref.map_id,
		"position": position,
		"ground_loot": raw_ground.duplicate(true),
		"revealed": raw_revealed.duplicate(true)
	}
	for field in FLOOR_FLAGS:
		var flags: Variant = data.get(field)
		if not (flags is Dictionary):
			return {}
		for entity_id in flags:
			if typeof(entity_id) != TYPE_STRING or str(entity_id).is_empty() or typeof(flags[entity_id]) != TYPE_BOOL:
				return {}
		restored[field] = flags.duplicate(true)
	return restored


static func _is_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and float(value) == float(int(value))
