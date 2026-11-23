extends SceneTree


func _initialize() -> void:
	_test_local_portal_pairs()
	_test_stairs_return_to_previous_map()
	_test_portal_link_is_not_a_stair()
	print("Stage 5 portals and stairs: paired travel, ascent and links OK")
	quit()


func _map(map_id: String) -> DungeonMap:
	var result: DungeonMap = DungeonMap.create_blank(9, 9)
	result.map_id = map_id
	assert(result.place_entity("player_spawn", 2, 2))
	return result


func _at(map_ref: DungeonMap, cell: Vector2i, kind: String) -> Dictionary:
	for entity in map_ref.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) == kind:
			return entity
	return {}


func _test_local_portal_pairs() -> void:
	var floor: DungeonMap = _map("local_pair")
	assert(floor.place_entity("portal_local", 3, 2, {"color": "blue"}))
	assert(floor.place_entity("portal_local", 6, 6, {"color": "blue"}))
	assert(floor.place_entity("portal_local", 4, 4, {"color": "red"}))
	assert(not floor.place_entity("portal_local", 4, 3, {"color": "blue"}))
	assert(not floor.place_entity("portal_local", 5, 4, {"color": "invalid"}))
	var first: Dictionary = _at(floor, Vector2i(3, 2), "portal_local")
	var second: Dictionary = _at(floor, Vector2i(6, 6), "portal_local")
	assert(floor.local_portal_destination(str(first["id"])) == Vector2i(6, 6))
	assert(floor.local_portal_destination(str(second["id"])) == Vector2i(3, 2))
	var original: String = JSON.stringify(floor.to_dict())
	var parsed: DungeonMap = DungeonMap.from_dict(JSON.parse_string(original))
	assert(parsed != null)
	assert(parsed.local_portal_destination(str(first["id"])) == Vector2i(6, 6))
	var session: GameSession = GameSession.start_for(floor)
	assert(session.move_by(1, 0))
	assert(session.player_pos == Vector2i(6, 6))
	assert(session.steps == 1)
	assert(not session.is_completed)
	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(session.player_pos == Vector2i(3, 2))
	assert(not session.is_completed)
	assert(JSON.stringify(floor.to_dict()) == original)


func _test_stairs_return_to_previous_map() -> void:
	var first: DungeonMap = _map("stairs_origin")
	var lower: DungeonMap = _map("stairs_lower")
	assert(first.place_entity("stairs_down", 3, 2))
	var exit: Dictionary = _at(first, Vector2i(3, 2), "stairs_down")
	assert(first.set_exit_target(str(exit["id"]), lower.map_id))
	var original_first: String = JSON.stringify(first.to_dict())
	var original_lower: String = JSON.stringify(lower.to_dict())
	var session: GameSession = GameSession.start_for(first)
	assert(not session.has_stairs_up())
	assert(session.move_by(1, 0))
	assert(session.is_completed)
	assert(session.enter_map(lower))
	assert(session.player_pos == Vector2i(2, 2))
	assert(session.has_stairs_up())
	assert(session.known_map(first.map_id) == first)
	for entity in lower.entities:
		assert(str(entity.get("type", "")) != "stairs_up")
	assert(session.move_by(1, 0))
	assert(session.move_by(-1, 0))
	assert(session.is_completed)
	assert(session.current_exit()["type"] == "stairs_up")
	assert(session.next_map_id() == first.map_id)
	assert(session.enter_map(session.known_map(first.map_id)))
	assert(session.map_data == first)
	assert(session.player_pos == Vector2i(3, 2))
	assert(not session.has_stairs_up())
	assert(not session.is_completed)
	assert(JSON.stringify(first.to_dict()) == original_first)
	assert(JSON.stringify(lower.to_dict()) == original_lower)
	assert(ImageAsset.texture("res://assets/icons/stairs_up.png") != null)
	assert(ImageAsset.texture("res://assets/icons/portals/portal_gateway.png") != null)


func _test_portal_link_is_not_a_stair() -> void:
	var first: DungeonMap = _map("gateway_origin")
	var second: DungeonMap = _map("gateway_destination")
	assert(first.place_entity("portal", 3, 2))
	var exit: Dictionary = _at(first, Vector2i(3, 2), "portal")
	assert(first.set_exit_target(str(exit["id"]), second.map_id))
	var session: GameSession = GameSession.start_for(first)
	assert(session.move_by(1, 0))
	assert(session.is_completed)
	assert(session.enter_map(second))
	assert(not session.has_stairs_up())
