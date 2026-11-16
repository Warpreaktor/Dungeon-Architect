class_name DungeonMap
extends RefCounted

## Логическая модель карты. Никаких Node2D, Sprite и других графических узлов.
## Поверхность и сущности хранятся раздельно; у клетки может быть несколько сущностей.

const FORMAT_VERSION := 1
const MAX_SIZE := 256
const ENTITY_TYPES := ["door", "chest", "monster", "stairs_down", "key", "potion", "gold", "trigger", "player_spawn", "message"]
static var CHEST_REWARDS: Array = ["key", "potion", "gold"] + ItemCatalog.consumable_ids() + ItemCatalog.equipment_ids()

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
		properties = {"contents": [], "loot_mode": "random"}
	elif kind == "stairs_down":
		properties = {"target_map_id": "", "target_x": 0, "target_y": 0}
	elif kind == "monster":
		var monster_id: String = str(options.get("monster_id", MonsterCatalog.DEFAULT_MONSTER_ID))
		if not MonsterCatalog.DEFINITIONS.has(monster_id):
			monster_id = MonsterCatalog.DEFAULT_MONSTER_ID
		properties = {"monster_id": monster_id, "loot_contents": [], "loot_mode": "random"}
	elif kind == "trigger":
		properties = {"event_id": ""}
	elif kind == "message":
		properties = {"text": "", "activation": "enter", "target_entity_id": ""}
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
				if kind in CHEST_REWARDS and kind not in contents:
					contents.append(kind)
	elif properties.has("reward"):
		var legacy: String = str(properties["reward"])
		if legacy in CHEST_REWARDS:
			contents.append(legacy)
	return contents


## Сумма золота задаётся для каждого сундука. Карты старого формата получают 5 монет.
static func chest_gold_amount(chest: Dictionary) -> int:
	var properties: Dictionary = chest.get("properties", {})
	return clampi(int(properties.get("gold_amount", 5)), 1, 999999)


static func chest_is_random(chest: Dictionary) -> bool:
	var properties: Dictionary = chest.get("properties", {})
	if properties.has("loot_mode"):
		return str(properties["loot_mode"]) == "random"
	return chest_contents(chest).is_empty()


func set_chest_contents(chest_id: String, new_contents: Array[String], gold_amount: int = 5, random_mode: bool = false, hidden: bool = false) -> bool:
	var normalized: Array[String] = []
	for item in new_contents:
		if item in CHEST_REWARDS and item not in normalized:
			normalized.append(item)
	var amount: int = clampi(gold_amount, 1, 999999)
	for entity in entities:
		if str(entity.get("id", "")) != chest_id or str(entity.get("type", "")) != "chest":
			continue
		if chest_contents(entity) == normalized and chest_is_random(entity) == random_mode and ("gold" not in normalized or chest_gold_amount(entity) == amount) and bool(entity.get("properties", {}).get("hidden", false)) == hidden:
			return false
		var properties: Dictionary = entity.get("properties", {}).duplicate(true)
		properties["contents"] = normalized.duplicate()
		properties["loot_mode"] = "random" if random_mode else "fixed"
		properties["hidden"] = hidden
		if "gold" in normalized:
			properties["gold_amount"] = amount
		entity["properties"] = properties
		return true
	return false


## Настраиваемая награда монстра — отдельные свойства его сущности в JSON.
## Для совместимости старых карт отсутствие loot_contents означает отсутствие награды.
static func monster_loot_contents(monster: Dictionary) -> Array[String]:
	var properties: Dictionary = monster.get("properties", {})
	var items: Array[String] = []
	var raw: Variant = properties.get("loot_contents", [])
	if raw is Array:
		for entry in raw:
			var item_id: String = str(entry)
			if item_id in CHEST_REWARDS and item_id not in items:
				items.append(item_id)
	return items


static func monster_gold_amount(monster: Dictionary) -> int:
	var properties: Dictionary = monster.get("properties", {})
	return clampi(int(properties.get("loot_gold_amount", 5)), 1, 999999)


static func monster_loot_is_random(monster: Dictionary) -> bool:
	var properties: Dictionary = monster.get("properties", {})
	if properties.has("loot_mode"):
		return str(properties["loot_mode"]) == "random"
	return monster_loot_contents(monster).is_empty()


func set_monster_loot(monster_id: String, contents: Array[String], gold_amount: int = 5, random_mode: bool = false, hidden: bool = false) -> bool:
	var normalized: Array[String] = []
	for item_id in contents:
		if item_id in CHEST_REWARDS and item_id not in normalized:
			normalized.append(item_id)
	var amount: int = clampi(gold_amount, 1, 999999)
	for entity in entities:
		if str(entity.get("id", "")) != monster_id or str(entity.get("type", "")) != "monster":
			continue
		if monster_loot_contents(entity) == normalized and monster_loot_is_random(entity) == random_mode and ("gold" not in normalized or monster_gold_amount(entity) == amount) and bool(entity.get("properties", {}).get("hidden", false)) == hidden:
			return false
		var properties: Dictionary = entity.get("properties", {}).duplicate(true)
		properties["loot_contents"] = normalized.duplicate()
		properties["loot_mode"] = "random" if random_mode else "fixed"
		properties["hidden"] = hidden
		properties.erase("loot_gold_amount")
		if "gold" in normalized:
			properties["loot_gold_amount"] = amount
		entity["properties"] = properties
		return true
	return false


## Смена вида монстра не затрагивает прочие объекты и сохраняется в JSON карты.
func set_monster_type(entity_id: String, monster_id: String) -> bool:
	if not MonsterCatalog.DEFINITIONS.has(monster_id):
		return false
	for entity in entities:
		if str(entity.get("id", "")) != entity_id or str(entity.get("type", "")) != "monster":
			continue
		var old_type: String = str(entity.get("properties", {}).get("monster_id", MonsterCatalog.DEFAULT_MONSTER_ID))
		if old_type == monster_id:
			return false
		var properties: Dictionary = entity.get("properties", {}).duplicate(true)
		properties["monster_id"] = monster_id
		entity["properties"] = properties
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


## Сообщение существует отдельно от объектов клетки, но может быть связано с дверью.
func message_at(x: int, y: int) -> Dictionary:
	for entity in entities_at(x, y):
		if str(entity.get("type", "")) == "message":
			return entity
	return {}


func set_message_at(x: int, y: int, text: String) -> bool:
	if not contains(x, y) or get_terrain(x, y) == "wall":
		return false
	var existing := message_at(x, y)
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		if existing.is_empty():
			return false
		entities.erase(existing)
		return true
	# Послание прикрепляется к событию клетки, а не заменяет объект.
	# Монстр имеет приоритет: игрок должен прочитать реплику до боя.
	var activation := "enter"
	var target_id := ""
	for kind in ["monster", "door", "chest"]:
		for entity in entities_at(x, y):
			if str(entity.get("type", "")) == kind:
				activation = {"monster": "monster_encounter", "door": "door_open", "chest": "chest_open"}[kind]
				target_id = str(entity.get("id", ""))
				break
		if not target_id.is_empty():
			break
	var data := {"text": clean_text, "activation": activation, "target_entity_id": target_id}
	if not existing.is_empty():
		if existing.get("properties", {}) == data:
			return false
		existing["properties"] = data
		return true
	if not place_entity("message", x, y):
		return false
	message_at(x, y)["properties"] = data
	return true


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
	# Послание, привязанное к двери, монстру или сундуку, перемещается вместе с объектом.
	var bound_message: Dictionary = {}
	if kind in ["door", "monster", "chest"]:
		var source_message := message_at(source.x, source.y)
		if not source_message.is_empty():
			var message_properties: Dictionary = source_message.get("properties", {})
			var assigned_id := str(message_properties.get("target_entity_id", ""))
			var legacy_message := assigned_id.is_empty() and str(message_properties.get("activation", "enter")) == "enter" and kind in ["monster", "chest"]
			if assigned_id == entity_id or legacy_message:
				if not message_at(target.x, target.y).is_empty():
					return false
				bound_message = source_message
	moving["x"] = target.x
	moving["y"] = target.y
	if not bound_message.is_empty():
		bound_message["x"] = target.x
		bound_message["y"] = target.y
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
