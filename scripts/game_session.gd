class_name GameSession
extends RefCounted

## Состояние конкретного прохождения карты. Не изменяет саму карту.

const VISION_RADIUS := 1

var map_data: DungeonMap
var hero: HeroState
var player_pos := Vector2i(-1, -1)
var steps: int = 0
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


func can_enter(cell: Vector2i) -> bool:
	return contains(cell.x, cell.y) and map_data.get_terrain(cell.x, cell.y) != "wall"


func move_by(dx: int, dy: int) -> bool:
	var target := player_pos + Vector2i(dx, dy)
	if not can_enter(target):
		return false
	player_pos = target
	steps += 1
	_refresh_visibility()
	return true


func _refresh_visibility() -> void:
	for y in range(map_data.height):
		for x in range(map_data.width):
			visible[y][x] = false
	for y in range(player_pos.y - VISION_RADIUS, player_pos.y + VISION_RADIUS + 1):
		for x in range(player_pos.x - VISION_RADIUS, player_pos.x + VISION_RADIUS + 1):
			if contains(x, y):
				visible[y][x] = true
				revealed[y][x] = true
