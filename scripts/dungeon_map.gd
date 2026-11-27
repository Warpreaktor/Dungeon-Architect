class_name DungeonMap
extends RefCounted

## Логическая модель карты. Никаких Node2D, Sprite и других графических узлов.
## Поверхность и сущности хранятся раздельно; у клетки может быть несколько сущностей.

const FORMAT_VERSION := 1
const MAX_MONSTERS_PER_ENCOUNTER: int = MonsterCatalog.MAX_ENCOUNTER_PARTICIPANTS
const MAX_SIZE := 256
# Пары слов образуют названия без грамматических несоответствий.
const NAME_PLACES := [
	"Катакомбы", "Чертоги", "Лабиринт", "Руины", "Крипта", "Склеп",
	"Пещеры", "Подземелье", "Залы", "Святилище", "Хранилище", "Шахты"
]
const NAME_SECRETS := [
	"забытого короля", "пепельной короны", "семи печатей", "лунного камня",
	"чёрного пламени", "старого смотрителя", "спящего дракона", "вечного шёпота",
	"последнего стража", "проклятого рыцаря", "потерянных имён", "каменного сердца",
	"алой луны", "железных теней", "безмолвных духов", "серебряного ключа",
	"древнего пророчества", "разбитой звезды", "погасших факелов", "тайного ордена"
]
const PORTAL_COLORS := ["blue", "cyan", "green", "orange", "pink", "purple", "red", "yellow"]
const ENTITY_TYPES := ["door", "chest", "monster", "trap", "stairs_down", "portal", "portal_local", "key", "potion", "gold", "trigger", "player_spawn", "message"]
static var CHEST_REWARDS: Array = ItemCatalog.list_ids() + ItemCatalog.LEGACY_UNLISTED_EQUIPMENT_IDS
const CHEST_VARIANT_NAMES := {
	"chest": "Сундук",
	"chest_gold": "Сундук с золотом",
	"jewelry_table": "Стол с украшениями",
	"weapon_rack": "Стойка с оружием",
	"armor_rack": "Стойка с доспехами",
	"alchemy_table": "Алхимический стол"
}
const CHEST_VARIANT_PROFILE_IDS := {
	"chest": "chest",
	"chest_gold": "coin_purse",
	"jewelry_table": "jewelry_box",
	"weapon_rack": "weapon_rack",
	"armor_rack": "armor_rack",
	"alchemy_table": "alchemy_table"
}

var map_id: String = ""
var display_name: String = "Безымянное подземелье"
var width: int = 16
var height: int = 16
var terrain: Array = []  # terrain[y][x] = "floor" или "wall"
var _entities: Array = []
var _entities_by_cell: Dictionary = {}
var _entities_by_kind: Dictionary = {}
var entities: Array:
	get:
		return _entities.duplicate()
	set(value):
		_entities = value.duplicate()
		_rebuild_entity_index()
var metadata: Dictionary = {"theme": "stone_dungeon"}


## Генератор названий для новых карт и кнопки с кубиком.
## exclude гарантирует новое название при повторном броске.
static func random_display_name(exclude: String = "") -> String:
	var count: int = NAME_PLACES.size() * NAME_SECRETS.size()
	var index: int = randi_range(0, count - 1)
	if exclude == "%s %s" % [NAME_PLACES[int(index / NAME_SECRETS.size())], NAME_SECRETS[index % NAME_SECRETS.size()]]:
		index = (index + randi_range(1, count - 1)) % count
	return "%s %s" % [NAME_PLACES[int(index / NAME_SECRETS.size())], NAME_SECRETS[index % NAME_SECRETS.size()]]


static func create_blank(w: int = 16, h: int = 16) -> DungeonMap:
	var result := DungeonMap.new()
	result.width = clampi(w, 1, MAX_SIZE)
	result.height = clampi(h, 1, MAX_SIZE)
	result.map_id = "map_%s_%05d" % [Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_"), randi_range(0, 99999)]
	result.display_name = random_display_name()
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


func narrow_passage_axis(cell: Vector2i) -> Vector2i:
	if not contains(cell.x, cell.y) or get_terrain(cell.x, cell.y) != "floor":
		return Vector2i.ZERO
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = cell + direction
		if not contains(neighbor.x, neighbor.y):
			return Vector2i.ZERO
	var horizontal: bool = get_terrain(cell.x - 1, cell.y) == "floor" and get_terrain(cell.x + 1, cell.y) == "floor"
	var vertical: bool = get_terrain(cell.x, cell.y - 1) == "floor" and get_terrain(cell.x, cell.y + 1) == "floor"
	if horizontal and get_terrain(cell.x, cell.y - 1) == "wall" and get_terrain(cell.x, cell.y + 1) == "wall":
		return Vector2i.RIGHT
	if vertical and get_terrain(cell.x - 1, cell.y) == "wall" and get_terrain(cell.x + 1, cell.y) == "wall":
		return Vector2i.DOWN
	return Vector2i.ZERO


func trap_placement_error(definition: TrapDefinition, cell: Vector2i) -> String:
	if definition.placement_constraint == "narrow_passage" and narrow_passage_axis(cell) == Vector2i.ZERO:
		return "Установите ловушку в узком проходе"
	return ""


func set_terrain(x: int, y: int, kind: String) -> bool:
	if not contains(x, y) or kind not in ["floor", "wall"]:
		return false
	if get_terrain(x, y) == kind:
		return false
	terrain[y][x] = kind
	if kind == "wall":
		for entity in entities_at(x, y):
			var trap: TrapDefinition = TrapCatalog.from_entity(entity)
			if trap != null and trap.placement_constraint == "narrow_passage":
				continue
			_remove_entity(entity)
	return true


func place_entity(kind: String, x: int, y: int, options: Dictionary = {}) -> bool:
	if not contains(x, y) or kind not in ENTITY_TYPES:
		return false
	# Не ставим монстра или сундук внутрь стены.
	if get_terrain(x, y) == "wall":
		return false
	if kind == "portal_local":
		var color: String = str(options.get("color", ""))
		if color not in PORTAL_COLORS:
			return false
		var same_color_count: int = 0
		for entity in _entities_by_kind.get("portal_local", []):
			if str(entity.get("properties", {}).get("color", "")) == color:
				same_color_count += 1
		if same_color_count >= 2:
			return false
	for entity in _entities_by_cell.get(Vector2i(x, y), []):
		if entity["type"] == kind or (kind in ["portal", "portal_local", "stairs_down"] and entity["type"] in ["portal", "portal_local", "stairs_down"]):
			return false
	# На всей карте допускается единственная стартовая позиция героя.
	if kind == "player_spawn":
		var spawns: Array = _entities_by_kind.get("player_spawn", [])
		for entity in spawns.duplicate():
			_remove_entity(entity)
	var properties: Dictionary = {}
	if kind == "door":
		properties = {"lock_id": "key"}
	elif kind == "chest":
		# Обычные сундуки и стилизованные контейнеры используют общую механику добычи.
		var variant: String = chest_variant({"type": "chest", "properties": {"variant": str(options.get("variant", "chest"))}})
		properties = {"contents": [], "loot_mode": "random"}
		if variant != "chest":
			properties["variant"] = variant
	elif kind in ["stairs_down", "portal"]:
		properties = {"target_map_id": ""}
	elif kind == "portal_local":
		properties = {"color": str(options["color"])}
	elif kind == "monster":
		var monster_id: String = str(options.get("monster_id", MonsterCatalog.DEFAULT_MONSTER_ID))
		if not MonsterCatalog.has(monster_id):
			monster_id = MonsterCatalog.DEFAULT_MONSTER_ID
		if MonsterCatalog.is_bond_companion(monster_id):
			return false
		properties = {"monster_id": monster_id, "loot_contents": [], "loot_mode": "random"}
	elif kind == "trap":
		var trap_id: String = str(options.get("trap_id", TrapCatalog.DEFAULT_TRAP_ID))
		if not TrapCatalog.has(trap_id):
			trap_id = TrapCatalog.DEFAULT_TRAP_ID
		var trap_definition: TrapDefinition = TrapCatalog.get_trap(trap_id)
		if not trap_definition.can_attach_to("floor") or not trap_placement_error(trap_definition, Vector2i(x, y)).is_empty():
			return false
		properties = {"trap_id": trap_id}
		properties.merge(TrapCatalog.settings_overrides(trap_definition, options), true)
	elif kind == "trigger":
		properties = {"event_id": ""}
	elif kind == "message":
		properties = {"text": "", "activation": "enter", "target_entity_id": ""}
	_append_entity({
		"id": "ent_%08x" % randi(),
		"type": kind,
		"x": x,
		"y": y,
		"properties": properties
	})
	return true


static func is_entity_hidden(entity: Dictionary) -> bool:
	var kind := str(entity.get("type", ""))
	if kind not in ["monster", "chest", "trap"]:
		return false
	if kind == "trap":
		return bool(TrapCatalog.settings(entity).get("hidden", true))
	return bool(entity.get("properties", {}).get("hidden", false))


static func trap_id(entity: Dictionary) -> String:
	var properties: Dictionary = entity.get("properties", {})
	return TrapCatalog.resolve_id(str(properties.get("trap_id", TrapCatalog.DEFAULT_TRAP_ID)))


static func door_trap_id(door: Dictionary) -> String:
	if str(door.get("type", "")) != "door":
		return ""
	var attachment: Variant = door.get("properties", {}).get("trap", {})
	if typeof(attachment) != TYPE_DICTIONARY:
		return ""
	var trap_id: String = str(attachment.get("trap_id", ""))
	if not TrapCatalog.has(trap_id):
		return ""
	return trap_id if TrapCatalog.get_trap(trap_id).can_attach_to("door") else ""


static func door_trap_message(door: Dictionary) -> String:
	var trap_id: String = door_trap_id(door)
	if trap_id.is_empty():
		return ""
	var attachment: Dictionary = door.get("properties", {}).get("trap", {})
	return str(attachment.get("message", TrapCatalog.get_trap(trap_id).trigger_message))


func attach_door_trap(door_id: String, trap_id: String) -> bool:
	if not TrapCatalog.has(trap_id) or not TrapCatalog.get_trap(trap_id).can_attach_to("door"):
		return false
	for entity in _entities:
		if str(entity.get("id", "")) != door_id or str(entity.get("type", "")) != "door":
			continue
		var properties: Dictionary = entity.get("properties", {})
		if properties.has("trap"):
			return false
		var updated: Dictionary = properties.duplicate(true)
		updated["trap"] = {"trap_id": trap_id}
		entity["properties"] = updated
		return true
	return false


func set_trap_configuration(entity_id: String, settings: Dictionary) -> bool:
	for entity in _entities:
		if str(entity.get("id", "")) != entity_id:
			continue
		var kind: String = str(entity.get("type", ""))
		if kind not in ["door", "trap"]:
			return false
		var door: bool = kind == "door"
		var properties: Dictionary = entity.get("properties", {}).duplicate(true)
		var definition: TrapDefinition = TrapCatalog.from_door(entity) if door else TrapCatalog.from_entity(entity)
		if definition == null:
			return false
		var target: Dictionary = properties["trap"] if door else properties
		var values: Dictionary = TrapCatalog.settings(entity)
		values.merge(settings, true)
		TrapCatalog.remove_legacy_overrides(target)
		target.erase("hidden")
		target.merge(TrapCatalog.settings_overrides(definition, values), true)
		if properties == entity.get("properties", {}):
			return false
		if door:
			properties["trap"] = target
		entity["properties"] = properties
		return true
	return false


func set_door_trap_message(door_id: String, message: String) -> bool:
	for entity in _entities:
		if str(entity.get("id", "")) != door_id or str(entity.get("type", "")) != "door":
			continue
		if door_trap_id(entity).is_empty():
			return false
		var properties: Dictionary = entity.get("properties", {}).duplicate(true)
		var attachment: Dictionary = properties["trap"].duplicate(true)
		var clean_message: String = message.strip_edges()
		if clean_message.is_empty():
			if not attachment.has("message"):
				return false
			attachment.erase("message")
		elif str(attachment.get("message", "")) == clean_message:
			return false
		else:
			attachment["message"] = clean_message
		properties["trap"] = attachment
		entity["properties"] = properties
		return true
	return false


func remove_door_trap(door_id: String) -> bool:
	for entity in _entities:
		if str(entity.get("id", "")) != door_id or str(entity.get("type", "")) != "door":
			continue
		var properties: Dictionary = entity.get("properties", {})
		if not properties.has("trap"):
			return false
		var updated: Dictionary = properties.duplicate(true)
		updated.erase("trap")
		entity["properties"] = updated
		return true
	return false


## Описание добычи принадлежит карте; старая форма reward продолжает читаться.
static func chest_contents(chest: Dictionary) -> Array[String]:
	var properties: Dictionary = chest.get("properties", {})
	var contents: Array[String] = []
	if str(properties.get("loot_mode", "")) == "random":
		return contents
	if properties.has("contents"):
		var raw: Variant = properties["contents"]
		if raw is Array:
			for item in raw:
				var kind: String = "key" if str(item) == "key_yellow" else str(item)
				if kind in CHEST_REWARDS and kind not in contents:
					contents.append(kind)
	elif properties.has("reward"):
		var legacy: String = "key" if str(properties["reward"]) == "key_yellow" else str(properties["reward"])
		if legacy in CHEST_REWARDS:
			contents.append(legacy)
	return contents


## Сумма золота задаётся для каждого сундука. Карты старого формата получают 5 монет.
static func chest_gold_amount(chest: Dictionary) -> int:
	var properties: Dictionary = chest.get("properties", {})
	return clampi(int(properties.get("gold_amount", 5)), 1, 999999)


## Набор количеств конкретных предметов. Карты до таблицы количеств
## получают штатное число единиц, а золото — legacy gold_amount.
static func chest_item_quantities(chest: Dictionary) -> Dictionary:
	return _reward_quantities(chest_contents(chest), chest.get("properties", {}), "item_quantities", "gold_amount")


static func monster_item_quantities(monster: Dictionary) -> Dictionary:
	return _reward_quantities(monster_loot_contents(monster), monster.get("properties", {}), "loot_item_quantities", "loot_gold_amount")


static func _reward_quantities(contents: Array[String], properties: Dictionary, field: String, legacy_gold_field: String) -> Dictionary:
	var raw: Variant = properties.get(field, {})
	var stored: Dictionary = raw if raw is Dictionary else {}
	var result: Dictionary = {}
	for item_id in contents:
		var definition: ItemDefinition = ItemCatalog.get_item(item_id)
		if definition == null:
			continue
		var fallback: int = clampi(int(properties.get(legacy_gold_field, 5)), 1, 999999) if item_id == "gold" else definition.default_quantity
		# Старое имя жёлтого ключа всё ещё может встретиться в данных карты.
		var raw_value: Variant = stored.get(item_id, stored.get("key_yellow", fallback) if item_id == "key" else fallback)
		result[item_id] = clampi(int(raw_value), 1, 999999 if item_id == "gold" else 9999)
	return result


static func _normalize_reward_quantities(contents: Array[String], supplied: Dictionary, properties: Dictionary, field: String, gold_field: String, fallback_gold: int) -> Dictionary:
	var existing: Dictionary = _reward_quantities(contents, properties, field, gold_field)
	var normalized: Dictionary = {}
	for item_id in contents:
		var item: ItemDefinition = ItemCatalog.get_item(item_id)
		if item == null:
			continue
		var fallback: int = fallback_gold if item_id == "gold" else int(existing.get(item_id, item.default_quantity))
		var count: int = int(supplied.get(item_id, supplied.get("key_yellow", fallback) if item_id == "key" else fallback))
		normalized[item_id] = clampi(count, 1, 999999 if item_id == "gold" else 9999)
	return normalized


static func _reward_mode(random_mode: bool, contents: Array[String]) -> String:
	if not random_mode:
		return "fixed"
	return "random" if contents.is_empty() else "mixed"


static func chest_is_random(chest: Dictionary) -> bool:
	var properties: Dictionary = chest.get("properties", {})
	if properties.has("loot_mode"):
		return str(properties["loot_mode"]) in ["random", "mixed"]
	if str(chest.get("type", "")) == "stairs_down":
		return false
	var raw: Variant = properties.get("contents", [])
	if raw is Array and not raw.is_empty():
		return false
	return str(properties.get("reward", "")).is_empty()


static func chest_variant(entity: Dictionary) -> String:
	if str(entity.get("type", "")) != "chest":
		return "chest"
	var variant: String = str(entity.get("properties", {}).get("variant", "chest"))
	return variant if CHEST_VARIANT_PROFILE_IDS.has(variant) else "chest"


static func chest_variant_name(variant: String) -> String:
	return str(CHEST_VARIANT_NAMES.get(variant, CHEST_VARIANT_NAMES["chest"]))


static func chest_profile_id(entity: Dictionary) -> String:
	return chest_variant_profile_id(chest_variant(entity))


static func chest_variant_profile_id(variant: String) -> String:
	return str(CHEST_VARIANT_PROFILE_IDS.get(variant, CHEST_VARIANT_PROFILE_IDS["chest"]))


static func loot_level(entity: Dictionary) -> int:
	var raw: Variant = entity.get("properties", {}).get("loot_level", 1)
	if typeof(raw) not in [TYPE_INT, TYPE_FLOAT]:
		return 1
	return LootProfile.normalize_level(int(raw))


func set_loot_level(entity_id: String, level: int) -> bool:
	if level != LootProfile.normalize_level(level):
		return false
	for entity in _entities:
		if str(entity.get("id", "")) != entity_id or str(entity.get("type", "")) not in ["chest", "monster", "stairs_down"]:
			continue
		if loot_level(entity) == level:
			return false
		var properties: Dictionary = entity.get("properties", {}).duplicate(true)
		if level == 1:
			properties.erase("loot_level")
		else:
			properties["loot_level"] = level
		entity["properties"] = properties
		return true
	return false


func set_loot_profile(entity_id: String, profile_id: String) -> bool:
	if not profile_id.is_empty() and LootProfileCatalog.get_profile(profile_id) == null:
		return false
	for entity in _entities:
		if str(entity.get("id", "")) != entity_id or str(entity.get("type", "")) not in ["chest", "monster", "stairs_down"]:
			continue
		var properties: Dictionary = entity.get("properties", {}).duplicate(true)
		if str(properties.get("loot_profile_id", "")) == profile_id:
			return false
		if profile_id.is_empty():
			properties.erase("loot_profile_id")
		else:
			properties["loot_profile_id"] = profile_id
		entity["properties"] = properties
		return true
	return false


func set_chest_contents(chest_id: String, new_contents: Array[String], gold_amount: int = 5, random_mode: bool = false, hidden: bool = false, quantities: Dictionary = {}) -> bool:
	var normalized: Array[String] = []
	for item in new_contents:
		var item_id: String = "key" if item == "key_yellow" else item
		if item_id in CHEST_REWARDS and item_id not in normalized:
			normalized.append(item_id)
	var amount: int = clampi(gold_amount, 1, 999999)
	for entity in _entities:
		if str(entity.get("id", "")) != chest_id or str(entity.get("type", "")) not in ["chest", "stairs_down"]:
			continue
		var current: Dictionary = entity.get("properties", {})
		var item_amounts: Dictionary = _normalize_reward_quantities(normalized, quantities, current, "item_quantities", "gold_amount", amount)
		if chest_contents(entity) == normalized and chest_is_random(entity) == random_mode and chest_item_quantities(entity) == item_amounts and bool(current.get("hidden", false)) == hidden:
			return false
		var properties: Dictionary = current.duplicate(true)
		properties["item_quantities"] = item_amounts
		properties["contents"] = normalized.duplicate()
		properties["loot_mode"] = _reward_mode(random_mode, normalized)
		properties["hidden"] = hidden
		if "gold" in normalized:
			properties["gold_amount"] = int(item_amounts["gold"])
		else:
			properties.erase("gold_amount")
		entity["properties"] = properties
		return true
	return false


## Настраиваемая награда монстра — отдельные свойства его сущности в JSON.
## Для совместимости старых карт отсутствие loot_contents означает отсутствие награды.
static func monster_party_ids(monster: Dictionary) -> Array[String]:
	var properties: Dictionary = monster.get("properties", {})
	var primary: String = MonsterCatalog.resolve_id(str(properties.get("monster_id", MonsterCatalog.DEFAULT_MONSTER_ID)))
	var definitions: Array[MonsterDefinition] = [MonsterCatalog.get_monster(primary)]
	var raw: Variant = properties.get("monster_ids", [])
	if raw is Array:
		for item in raw:
			var member_id: String = str(item)
			if MonsterCatalog.has(member_id):
				definitions.append(MonsterCatalog.get_monster(member_id))
	var party: Array[String] = []
	for definition in MonsterCatalog.normalize_legacy_encounter(definitions):
		if party.size() >= MAX_MONSTERS_PER_ENCOUNTER:
			break
		party.append(definition.monster_id)
	return party


static func valid_monster_party(party: Array[String]) -> bool:
	if party.is_empty() or party.size() > MAX_MONSTERS_PER_ENCOUNTER:
		return false
	var definitions: Array[MonsterDefinition] = []
	for member_id in party:
		if not MonsterCatalog.has(member_id):
			return false
		definitions.append(MonsterCatalog.get_monster(member_id))
	return MonsterCatalog.valid_encounter(definitions)


func set_monster_party(entity_id: String, party: Array[String]) -> bool:
	if not valid_monster_party(party):
		return false
	for entity in _entities:
		if str(entity.get("id", "")) != entity_id or str(entity.get("type", "")) != "monster":
			continue
		if monster_party_ids(entity) == party:
			return false
		var properties: Dictionary = entity.get("properties", {}).duplicate(true)
		properties["monster_id"] = party[0]
		if party.size() > 1:
			properties["monster_ids"] = party.slice(1)
		else:
			properties.erase("monster_ids")
		entity["properties"] = properties
		return true
	return false


static func monster_loot_contents(monster: Dictionary) -> Array[String]:
	var properties: Dictionary = monster.get("properties", {})
	var items: Array[String] = []
	if str(properties.get("loot_mode", "")) == "random":
		return items
	var raw: Variant = properties.get("loot_contents", [])
	if raw is Array:
		for entry in raw:
			var item_id: String = "key" if str(entry) == "key_yellow" else str(entry)
			if item_id in CHEST_REWARDS and item_id not in items:
				items.append(item_id)
	return items


static func monster_gold_amount(monster: Dictionary) -> int:
	var properties: Dictionary = monster.get("properties", {})
	return clampi(int(properties.get("loot_gold_amount", 5)), 1, 999999)


static func monster_loot_is_random(monster: Dictionary) -> bool:
	var properties: Dictionary = monster.get("properties", {})
	if properties.has("loot_mode"):
		return str(properties["loot_mode"]) in ["random", "mixed"]
	var raw: Variant = properties.get("loot_contents", [])
	return not (raw is Array and not raw.is_empty())


func set_monster_loot(monster_id: String, contents: Array[String], gold_amount: int = 5, random_mode: bool = false, hidden: bool = false, quantities: Dictionary = {}) -> bool:
	var normalized: Array[String] = []
	for item_id in contents:
		var canonical_id: String = "key" if item_id == "key_yellow" else item_id
		if canonical_id in CHEST_REWARDS and canonical_id not in normalized:
			normalized.append(canonical_id)
	var amount: int = clampi(gold_amount, 1, 999999)
	for entity in _entities:
		if str(entity.get("id", "")) != monster_id or str(entity.get("type", "")) != "monster":
			continue
		var current: Dictionary = entity.get("properties", {})
		var item_amounts: Dictionary = _normalize_reward_quantities(normalized, quantities, current, "loot_item_quantities", "loot_gold_amount", amount)
		if monster_loot_contents(entity) == normalized and monster_loot_is_random(entity) == random_mode and monster_item_quantities(entity) == item_amounts and bool(current.get("hidden", false)) == hidden:
			return false
		var properties: Dictionary = current.duplicate(true)
		properties["loot_item_quantities"] = item_amounts
		properties["loot_contents"] = normalized.duplicate()
		properties["loot_mode"] = _reward_mode(random_mode, normalized)
		properties["hidden"] = hidden
		properties.erase("loot_gold_amount")
		if "gold" in normalized:
			properties["loot_gold_amount"] = int(item_amounts["gold"])
		entity["properties"] = properties
		return true
	return false


## Смена вида монстра не затрагивает прочие объекты и сохраняется в JSON карты.
func set_monster_type(entity_id: String, monster_id: String) -> bool:
	if not MonsterCatalog.has(monster_id):
		return false
	for entity in _entities:
		if str(entity.get("id", "")) != entity_id or str(entity.get("type", "")) != "monster":
			continue
		var party: Array[String] = monster_party_ids(entity)
		party[0] = monster_id
		return set_monster_party(entity_id, party)
	return false


## Тип замка является свойством двери в JSON, а не состоянием прохождения.
func set_door_lock(door_id: String, lock_id: String) -> bool:
	var normalized: String = LockCatalog.normalize(lock_id)
	for entity in _entities:
		if str(entity.get("id", "")) != door_id or str(entity.get("type", "")) != "door":
			continue
		if LockCatalog.required_key(entity) == normalized:
			return false
		var properties: Dictionary = entity.get("properties", {}).duplicate(true)
		properties["lock_id"] = normalized
		entity["properties"] = properties
		return true
	return false


func local_portal_destination(portal_id: String) -> Vector2i:
	var source: Dictionary = {}
	for entity in _entities_by_kind.get("portal_local", []):
		if str(entity.get("id", "")) == portal_id and str(entity.get("type", "")) == "portal_local":
			source = entity
			break
	if source.is_empty():
		return Vector2i(-1, -1)
	var color: String = str(source.get("properties", {}).get("color", ""))
	if color not in PORTAL_COLORS:
		return Vector2i(-1, -1)
	var paired: Array[Dictionary] = []
	for entity in _entities_by_kind.get("portal_local", []):
		if str(entity.get("type", "")) == "portal_local" and str(entity.get("properties", {}).get("color", "")) == color:
			paired.append(entity)
	if paired.size() != 2:
		return Vector2i(-1, -1)
	var target: Dictionary = paired[1] if str(paired[0].get("id", "")) == portal_id else paired[0]
	return Vector2i(int(target["x"]), int(target["y"]))


static func is_exit(entity: Dictionary) -> bool:
	return str(entity.get("type", "")) in ["stairs_down", "stairs_up", "portal"]


static func exit_target_id(entity: Dictionary) -> String:
	return str(entity.get("properties", {}).get("target_map_id", "")).strip_edges() if is_exit(entity) else ""


static func valid_arrival_cell(destination: DungeonMap, cell: Vector2i) -> bool:
	if destination == null or destination.get_terrain(cell.x, cell.y) != "floor":
		return false
	for entity in destination.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) in ["door", "monster"]:
			return false
	return true


static func exit_target_cell(entity: Dictionary, destination: DungeonMap) -> Vector2i:
	if not is_exit(entity) or destination == null:
		return Vector2i(-1, -1)
	return destination.find_entity_position("player_spawn")


func set_exit_target(entity_id: String, target_map_id: String) -> bool:
	var normalized: String = target_map_id.strip_edges()
	for entity in _entities:
		if str(entity.get("id", "")) != entity_id or not is_exit(entity):
			continue
		var properties: Dictionary = entity.get("properties", {}).duplicate(true)
		if str(properties.get("target_map_id", "")).strip_edges() == normalized and not properties.has("target_position_enabled") and not properties.has("target_x") and not properties.has("target_y"):
			return false
		properties["target_map_id"] = normalized
		properties.erase("target_position_enabled")
		properties.erase("target_x")
		properties.erase("target_y")
		entity["properties"] = properties
		return true
	return false


static func stairs_target_id(stairs: Dictionary) -> String:
	return exit_target_id(stairs)


func set_stairs_target(stairs_id: String, target_map_id: String) -> bool:
	return set_exit_target(stairs_id, target_map_id)


## Идентификатор игрового события хранится на самой карте, не в сессии.
func set_trigger_event_id(trigger_id: String, event_id: String) -> bool:
	var normalized := event_id.strip_edges()
	for entity in _entities:
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
		_remove_entity(existing)
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
	for entry in _entities_by_cell.get(source, []):
		if str(entry["id"]) == entity_id and str(entry["type"]) == kind and int(entry["x"]) == source.x and int(entry["y"]) == source.y:
			moving = entry
			break
	if moving.is_empty():
		return false
	var trap: TrapDefinition = TrapCatalog.from_entity(moving)
	if trap != null and not trap_placement_error(trap, target).is_empty():
		return false
	for entry in entities_at(target.x, target.y):
		if str(entry["type"]) == kind or (kind in ["portal", "portal_local", "stairs_down"] and str(entry["type"]) in ["portal", "portal_local", "stairs_down"]):
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
	_entities_by_cell.erase(source)
	_entities_by_cell.erase(target)
	for entity in _entities:
		var cell := Vector2i(int(entity["x"]), int(entity["y"]))
		if cell != source and cell != target:
			continue
		if not _entities_by_cell.has(cell):
			_entities_by_cell[cell] = []
		_entities_by_cell[cell].append(entity)
	return true


func erase_at(x: int, y: int) -> bool:
	if not contains(x, y):
		return false
	var here: Array = _entities_by_cell.get(Vector2i(x, y), [])
	if not here.is_empty():
		_remove_entity(here.back())
		return true
	return set_terrain(x, y, "floor")


func _append_entity(entity: Dictionary) -> void:
	_entities.append(entity)
	_index_entity(entity)


func _index_entity(entity: Dictionary) -> void:
	var cell := Vector2i(int(entity["x"]), int(entity["y"]))
	var kind := str(entity["type"])
	if not _entities_by_cell.has(cell):
		_entities_by_cell[cell] = []
	if not _entities_by_kind.has(kind):
		_entities_by_kind[kind] = []
	_entities_by_cell[cell].append(entity)
	_entities_by_kind[kind].append(entity)


func _remove_entity(entity: Dictionary) -> void:
	_entities.erase(entity)
	var cell := Vector2i(int(entity["x"]), int(entity["y"]))
	var kind := str(entity["type"])
	var cell_entries: Array = _entities_by_cell[cell]
	cell_entries.erase(entity)
	if cell_entries.is_empty():
		_entities_by_cell.erase(cell)
	var kind_entries: Array = _entities_by_kind[kind]
	kind_entries.erase(entity)
	if kind_entries.is_empty():
		_entities_by_kind.erase(kind)


func _rebuild_entity_index() -> void:
	_entities_by_cell.clear()
	_entities_by_kind.clear()
	for entity in _entities:
		_index_entity(entity)


func entities_at(x: int, y: int) -> Array:
	var here: Array = _entities_by_cell.get(Vector2i(x, y), [])
	return here.duplicate()


func find_entity_position(kind: String) -> Vector2i:
	var matches: Array = _entities_by_kind.get(kind, [])
	if matches.is_empty():
		return Vector2i(-1, -1)
	var entity: Dictionary = matches.front()
	return Vector2i(int(entity["x"]), int(entity["y"]))


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
	var raw_id: String = str(value.get("id", "")).strip_edges()
	if raw_id.is_empty():
		raw_id = "legacy_" + JSON.stringify({"width": w, "height": h, "terrain": raw_terrain, "entities": raw_entities}).sha256_text().substr(0, 16)
	result.map_id = raw_id.validate_filename()
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
	var seen_ids: Dictionary = {}
	for index in range(raw_entities.size()):
		var entry: Variant = raw_entities[index]
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
		var entity_id: String = str(entry.get("id", "")).strip_edges()
		if entity_id.is_empty():
			entity_id = "legacy_ent_%05d" % index
		if seen_ids.has(entity_id):
			return null
		seen_ids[entity_id] = true
		var properties: Dictionary = props.duplicate(true)
		if kind == "trap":
			TrapCatalog.remove_legacy_overrides(properties)
		elif kind == "door" and properties.get("trap") is Dictionary:
			TrapCatalog.remove_legacy_overrides(properties["trap"])
		elif kind == "monster":
			var party: Array[String] = monster_party_ids({"properties": properties})
			var primary: MonsterDefinition = MonsterCatalog.get_monster(party[0])
			if MonsterCatalog.is_exclusive_encounter(primary):
				var raw_party: Variant = properties.get("monster_ids", [])
				var original_id: String = MonsterCatalog.resolve_id(str(properties.get("monster_id", MonsterCatalog.DEFAULT_MONSTER_ID)))
				if original_id != primary.monster_id or (raw_party is Array and not raw_party.is_empty()):
					properties["monster_id"] = primary.monster_id
					properties.erase("monster_ids")
		elif kind == "chest":
			var variant: String = chest_variant({"type": "chest", "properties": properties})
			if variant == "chest":
				properties.erase("variant")
			else:
				properties["variant"] = variant
		result._append_entity({"id": entity_id, "type": kind, "x": x, "y": y, "properties": properties})
	var raw_metadata: Variant = value.get("metadata", {"theme": "stone_dungeon"})
	if typeof(raw_metadata) == TYPE_DICTIONARY:
		result.metadata = raw_metadata
	return result
