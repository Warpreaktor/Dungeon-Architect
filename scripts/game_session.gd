class_name GameSession
extends RefCounted

## Состояние конкретного прохождения карты. Не изменяет саму карту.

const VISION_RADIUS := 1

var map_data: DungeonMap
var hero: HeroState
var player_pos := Vector2i(-1, -1)
var steps: int = 0
var keys: int = 0
var potions: int = 0
var removed_entities: Dictionary = {} # ID объектов, исчезнувших только в этом прохождении.
var last_event_message: String = ""
var revealed: Array = [] # revealed[y][x] = bool
var visible: Array = []  # visible[y][x] = bool


static func start_for(map_ref: DungeonMap) -> GameSession:
	if map_ref == null:
		return null
	var spawn := map_ref.find_entity_position("player_spawn")
	if spawn.x < 0 or spawn.y < 0:
		return null
	var session := GameSession.new()
	session.map_data = map_ref
	session.hero = HeroState.new()
	session.player_pos = spawn
	session._init_masks()
	session._refresh_visibility()
	session._collect_pickups_at(spawn)
	return session


func _init_masks() -> void:
	revealed.clear()
	visible.clear()
	for y in range(map_data.height):
		var revealed_row: Array = []
		var visible_row: Array = []
		for x in range(map_data.width):
			revealed_row.append(false)
			visible_row.append(false)
		revealed.append(revealed_row)
		visible.append(visible_row)


func contains(x: int, y: int) -> bool:
	return map_data != null and map_data.contains(x, y)


func is_revealed(x: int, y: int) -> bool:
	return contains(x, y) and bool(revealed[y][x])


func is_visible(x: int, y: int) -> bool:
	return contains(x, y) and bool(visible[y][x])


func is_entity_removed(entity: Dictionary) -> bool:
	return removed_entities.has(str(entity.get("id", "")))


func _find_active_entity(cell: Vector2i, kind: String) -> Dictionary:
	for entity in map_data.entities_at(cell.x, cell.y):
		if str(entity["type"]) == kind and not is_entity_removed(entity):
			return entity
	return {}


func can_enter(cell: Vector2i) -> bool:
	return contains(cell.x, cell.y) and map_data.get_terrain(cell.x, cell.y) != "wall"


func move_by(dx: int, dy: int) -> bool:
	last_event_message = ""
	var target := player_pos + Vector2i(dx, dy)
	if not can_enter(target):
		return false

	var door := _find_active_entity(target, "door")
	if not door.is_empty():
		if keys <= 0:
			last_event_message = "Дверь заперта. Нужен ключ."
			return false
		keys -= 1
		removed_entities[str(door["id"])] = true
		last_event_message = "Ключ использован. Дверь открыта!"

	player_pos = target
	steps += 1
	_collect_pickups_at(target)
	_refresh_visibility()
	return true


func _collect_pickups_at(cell: Vector2i) -> void:
	for entity in map_data.entities_at(cell.x, cell.y):
		if is_entity_removed(entity):
			continue
		var pickup_message := ""
		match str(entity["type"]):
			"key":
				keys += 1
				pickup_message = "Найден ключ! Ключей: %d" % keys
			"potion":
				potions += 1
				pickup_message = "Найдено зелье! Зелий: %d" % potions
			_:
				continue
		removed_entities[str(entity["id"])] = true
		if last_event_message.is_empty():
			last_event_message = pickup_message
		else:
			last_event_message += "  " + pickup_message


func _refresh_visibility() -> void:
	for y in range(map_data.height):
		for x in range(map_data.width):
			visible[y][x] = false
	for y in range(player_pos.y - VISION_RADIUS, player_pos.y + VISION_RADIUS + 1):
		for x in range(player_pos.x - VISION_RADIUS, player_pos.x + VISION_RADIUS + 1):
			if contains(x, y):
				visible[y][x] = true
				revealed[y][x] = true
