extends SceneTree

## DA-3.06.1: запуск Godot --headless --path . --script res://tests/test_reachability.gd
func _initialize() -> void:
	var limited := _corridor()
	assert(limited.place_entity("chest", 2, 2))
	assert(limited.place_entity("door", 3, 2))
	assert(limited.place_entity("door", 5, 2))
	var chest: Dictionary = limited.entities_at(2, 2)[0]
	assert(limited.set_chest_contents(str(chest["id"]), ["key"], 5, false, false, {"key": 1}))
	var result: Dictionary = DungeonReachability.analyze(limited)
	assert(result["complete"])
	assert(result["reachable"].has(Vector2i(4, 2)))
	assert(not result["reachable"].has(Vector2i(6, 2)))
	assert(limited.set_chest_contents(str(chest["id"]), ["key"], 5, false, false, {"key": 2}))
	result = DungeonReachability.analyze(limited)
	assert(result["reachable"].has(Vector2i(6, 2)))

	var circular := _corridor()
	assert(circular.place_entity("door", 3, 2))
	assert(circular.place_entity("chest", 4, 2))
	var blocked_chest: Dictionary = circular.entities_at(4, 2)[0]
	assert(circular.set_chest_contents(str(blocked_chest["id"]), ["key"]))
	result = DungeonReachability.analyze(circular)
	assert(not result["reachable"].has(Vector2i(4, 2)))

	var hidden := _corridor()
	assert(hidden.place_entity("chest", 2, 2))
	assert(hidden.place_entity("door", 3, 2))
	var secret: Dictionary = hidden.entities_at(2, 2)[0]
	assert(hidden.set_chest_contents(str(secret["id"]), ["key"], 5, false, true))
	result = DungeonReachability.analyze(hidden)
	assert(not result["reachable"].has(Vector2i(4, 2)))
	assert(result["possible"].has(Vector2i(4, 2)))

	var random_map := _corridor()
	assert(random_map.place_entity("chest", 2, 2))
	assert(random_map.place_entity("door", 3, 2))
	result = DungeonReachability.analyze(random_map)
	assert(not result["possible"].has(Vector2i(4, 2)))

	var no_start := DungeonMap.create_blank(5, 5)
	result = DungeonReachability.analyze(no_start)
	assert(not result["has_spawn"])

	print("DA-3.06.1 reachability tests passed")
	quit()


func _corridor() -> DungeonMap:
	var data := DungeonMap.create_blank(8, 5)
	for y in range(data.height):
		for x in range(data.width):
			data.set_terrain(x, y, "wall")
	for x in range(1, 7):
		data.set_terrain(x, 2, "floor")
	assert(data.place_entity("player_spawn", 1, 2))
	return data
