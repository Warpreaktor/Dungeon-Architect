class_name DungeonMap
extends RefCounted

## Логическая модель карты. Никаких Node2D, Sprite и других графических узлов.
## Поверхность и сущности хранятся раздельно; у клетки может быть несколько сущностей.

const FORMAT_VERSION := 1
const MAX_SIZE := 256
const ENTITY_TYPES := ["door", "chest", "monster", "stairs_down", "key", "potion", "trigger", "player_spawn"]

var map_id: String = ""
var display_name: String = "Безымянное подземелье"
var width: int = 16
var height: int = 16
var terrain: Array = []  # terrain[y][x] = "floor" или "wall"
var entities: Array = [] # [{"id", "type", "x", "y", "properties"}, ...]
var metadata: Dictionary = {"theme": "stone_dungeon"}


static func create_blank(w: int = 16, h: int = 16) -> DungeonMap:
	var result := DungeonMap.new()
	result.width = clampi(w, 1, MAX_SIZE)
	result.height = clampi(h, 1, MAX_SIZE)
	result.map_id = "map_%s_%05d" % [Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_"), randi_range(0, 99999)]
	for y in range(result.height):
		var row: Array = []
		for x in range(result.width):
			row.append("wall" if result.width > 2 and result.height > 2 and (x == 0 or y == 0 or x == result.width - 1 or y == result.height - 1) else "floor")
		result.terrain.append(row)
	return result


func contains(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func get_terrain(x: int, y: int) -> String:
	if not contains(x, y):
		return "wall"
	return str(terrain[y][x])


func set_terrain(x: int, y: int, kind: String) -> bool:
	if not contains(x, y) or kind not in ["floor", "wall"]:
		return false
	if get_terrain(x, y) == kind:
		return false
	terrain[y][x] = kind
	if kind == "wall":
		for i in range(entities.size() - 1, -1, -1):
			if int(entities[i]["x"]) == x and int(entities[i]["y"]) == y:
				entities.remove_at(i)
	return true


func place_entity(kind: String, x: int, y: int, options: Dictionary = {}) -> bool:
	if not contains(x, y) or kind not in ENTITY_TYPES:
		return false
	# Не ставим монстра или сундук внутрь стены.
	if get_terrain(x, y) == "wall":
		return false
	for entity in entities:
		if entity["type"] == kind and int(entity["x"]) == x and int(entity["y"]) == y:
			return false
	# На всей карте допускается единственная стартовая позиция героя.
	if kind == "player_spawn":
		for i in range(entities.size() - 1, -1, -1):
			if entities[i]["type"] == "player_spawn":
				entities.remove_at(i)
	var properties: Dictionary = {}
	if kind == "chest":
		# Новый сундук пустой: содержимое автор задаёт после размещения.
		properties = {"contents": []}
	elif kind == "stairs_down":
		properties = {"target_map_id": "", "target_x": 0, "target_y": 0}
	elif kind == "trigger":
		properties = {"event_id": ""}
	entities.append({
		"id": "ent_%08x" % randi(),
		"type": kind,
		"x": x,
		"y": y,
		"properties": properties
	})
	return true


## Описание добычи принадлежит карте; старая форма reward продолжает читаться.
static func chest_contents(chest: Dictionary) -> Array[String]:
	var properties: Dictionary = chest.get("properties", {})
	var contents: Array[String] = []
	if properties.has("contents"):
		var raw: Variant = properties["contents"]
		if raw is Array:
			for item in raw:
				var kind: String = str(item)
				if kind in ["key", "potion"] and kind not in contents:
					contents.append(kind)
	elif properties.has("reward"):
		var legacy: String = str(properties["reward"])
		if legacy in ["key", "potion"]:
			contents.append(legacy)
	return contents


func set_chest_contents(chest_id: String, new_contents: Array[String]) -> bool:
	var normalized: Array[String] = []
	for item in new_contents:
		if item in ["key", "potion"] and item not in normalized:
			normalized.append(item)
	for entity in entities:
		if str(entity.get("id", "")) == chest_id and str(entity.get("type", "")) == "chest":
			if chest_contents(entity) == normalized:
				return false
			entity["properties"] = {"contents": normalized.duplicate()}
			return true
	return false


## Идентификатор игрового события хранится на самой карте, не в сессии.
func set_trigger_event_id(trigger_id: String, event_id: String) -> bool:
	var normalized := event_id.strip_edges()
	for entity in entities:
		if str(entity.get("id", "")) != trigger_id or str(entity.get("type", "")) != "trigger":
			continue
		var properties: Dictionary = entity.get("properties", {})
		if str(properties.get("event_id", "")) == normalized:
			return false
		var updated: Dictionary = properties.duplicate(true)
		updated["event_id"] = normalized
		entity["properties"] = updated
		return true
	return false


## Атомарный перенос: проверяем цель до изменения исходной клетки.
## kind == "wall" переносит стену; остальные kind — существующую сущность.
func move_existing(kind: String, entity_id: String, source: Vector2i, target: Vector2i) -> bool:
	if source == target or not contains(source.x, source.y) or not contains(target.x, target.y):
		return false
	if kind == "wall":
		if get_terrain(source.x, source.y) != "wall" or get_terrain(target.x, target.y) != "floor":
			return false
		if not entities_at(target.x, target.y).is_empty():
			return false
		terrain[source.y][source.x] = "floor"
		terrain[target.y][target.x] = "wall"
		return true
	if get_terrain(target.x, target.y) == "wall":
		return false
	var moving: Dictionary = {}
	for entry in entities:
		if str(entry["id"]) == entity_id and str(entry["type"]) == kind and int(entry["x"]) == source.x and int(entry["y"]) == source.y:
			moving = entry
			break
	if moving.is_empty():
		return false
	for entry in entities_at(target.x, target.y):
		if str(entry["type"]) == kind:
			return false
	moving["x"] = target.x
	moving["y"] = target.y
	return true


func erase_at(x: int, y: int) -> bool:
	if not contains(x, y):
		return false
	for i in range(entities.size() - 1, -1, -1):
		if int(entities[i]["x"]) == x and int(entities[i]["y"]) == y:
			entities.remove_at(i)
			return true
	return set_terrain(x, y, "floor")


func entities_at(x: int, y: int) -> Array:
	var result: Array = []
	for entity in entities:
		if int(entity["x"]) == x and int(entity["y"]) == y:
			result.append(entity)
	return result


func find_entity_position(kind: String) -> Vector2i:
	for entity in entities:
		if str(entity["type"]) == kind:
			return Vector2i(int(entity["x"]), int(entity["y"]))
	return Vector2i(-1, -1)


func to_dict() -> Dictionary:
	return {
		"schema_version": FORMAT_VERSION,
		"id": map_id,
		"name": display_name,
		"width": width,
		"height": height,
		"terrain": terrain,
		"entities": entities,
		"metadata": metadata,
		"connections": [] # Зарезервировано для объединения карт в подземелье.
	}


static func from_dict(value: Variant) -> DungeonMap:
	if typeof(value) != TYPE_DICTIONARY:
		return null
	if int(value.get("schema_version", -1)) != FORMAT_VERSION:
		return null
	var w := int(value.get("width", 0))
	var h := int(value.get("height", 0))
	if w < 1 or w > MAX_SIZE or h < 1 or h > MAX_SIZE:
		return null
	var raw_terrain: Variant = value.get("terrain", null)
	var raw_entities: Variant = value.get("entities", [])
	if typeof(raw_terrain) != TYPE_ARRAY or raw_terrain.size() != h or typeof(raw_entities) != TYPE_ARRAY:
		return null
	var result := DungeonMap.create_blank(w, h)
	result.map_id = str(value.get("id", result.map_id)).validate_filename()
	if result.map_id.is_empty():
		return null
	result.display_name = str(value.get("name", "Безымянное подземелье"))
	result.terrain.clear()
	for row in raw_terrain:
		if typeof(row) != TYPE_ARRAY or row.size() != w:
			return null
		var new_row: Array = []
		for tile in row:
			if tile not in ["floor", "wall"]:
				return null
			new_row.append(tile)
		result.terrain.append(new_row)
	result.entities.clear()
	for entry in raw_entities:
		if typeof(entry) != TYPE_DICTIONARY:
			return null
		var x := int(entry.get("x", -1))
		var y := int(entry.get("y", -1))
		var kind := str(entry.get("type", ""))
		if not result.contains(x, y) or kind not in ENTITY_TYPES:
			return null
		var props: Variant = entry.get("properties", {})
		if typeof(props) != TYPE_DICTIONARY:
			return null
		result.entities.append({"id": str(entry.get("id", "ent_%08x" % randi())), "type": kind, "x": x, "y": y, "properties": props})
	var raw_metadata: Variant = value.get("metadata", {"theme": "stone_dungeon"})
	if typeof(raw_metadata) == TYPE_DICTIONARY:
		result.metadata = raw_metadata
	return result
