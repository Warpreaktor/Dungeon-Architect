extends SceneTree


func _initialize() -> void:
	_test_legacy_stairs()
	_test_portals_and_revisits()
	_test_invalid_destination()
	print("Stage 5 exits: stairs, portals, spawn and floor state OK")
	quit()


func _map_with_spawn(spawn: Vector2i) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(7, 7)
	assert(dungeon.place_entity("player_spawn", spawn.x, spawn.y))
	return dungeon


func _exit_at(dungeon: DungeonMap, position: Vector2i) -> Dictionary:
	for entity in dungeon.entities_at(position.x, position.y):
		if DungeonMap.is_exit(entity):
			return entity
	return {}


func _test_legacy_stairs() -> void:
	var first: DungeonMap = _map_with_spawn(Vector2i(1, 1))
	var second: DungeonMap = _map_with_spawn(Vector2i(3, 3))
	assert(first.place_entity("stairs_down", 2, 1))
	var stairs: Dictionary = _exit_at(first, Vector2i(2, 1))
	assert(first.set_stairs_target(str(stairs["id"]), second.map_id))
	assert(DungeonMap.exit_target_cell(stairs, second) == Vector2i(3, 3))
	var restored: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(first.to_dict())))
	assert(restored != null)
	var restored_stairs: Dictionary = _exit_at(restored, Vector2i(2, 1))
	assert(DungeonMap.stairs_target_id(restored_stairs) == second.map_id)
	assert(DungeonMap.exit_target_cell(restored_stairs, second) == Vector2i(3, 3))
	var session: GameSession = GameSession.start_for(restored)
	assert(session.move_by(1, 0))
	assert(session.is_completed)
	assert(session.next_map_id() == second.map_id)
	assert(session.next_arrival_cell(second) == Vector2i(3, 3))
	assert(session.enter_map(second))
	assert(session.player_pos == Vector2i(3, 3))
	assert(session.enter_map(restored))
	assert(session.player_pos == Vector2i(1, 1))
	var legacy: Dictionary = restored_stairs.duplicate(true)
	legacy["properties"].erase("target_position_enabled")
	legacy["properties"]["target_y"] = 2
	legacy["properties"]["target_x"] = 2
	legacy["properties"]["target_position_enabled"] = true
	assert(DungeonMap.exit_target_cell(legacy, second) == Vector2i(3, 3))
	assert(restored.set_exit_target(str(restored_stairs["id"]), second.map_id) == false)
	assert(restored.set_exit_target(str(restored_stairs["id"]), ""))
	assert(restored.set_exit_target(str(restored_stairs["id"]), second.map_id))
	assert(not restored_stairs["properties"].has("target_x"))
	assert(not restored_stairs["properties"].has("target_y"))


func _test_portals_and_revisits() -> void:
	var first: DungeonMap = _map_with_spawn(Vector2i(1, 2))
	var second: DungeonMap = _map_with_spawn(Vector2i(1, 2))
	assert(first.place_entity("portal", 2, 2))
	assert(second.place_entity("portal", 2, 2))
	var outbound: Dictionary = _exit_at(first, Vector2i(2, 2))
	var inbound: Dictionary = _exit_at(second, Vector2i(2, 2))
	assert(first.set_exit_target(str(outbound["id"]), second.map_id))
	assert(second.set_exit_target(str(inbound["id"]), first.map_id))
	var copied: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(first.to_dict())))
	assert(copied != null)
	assert(DungeonMap.exit_target_id(_exit_at(copied, Vector2i(2, 2))) == second.map_id)
	var session: GameSession = GameSession.start_for(copied)
	assert(session.move_by(1, 0))
	assert(session.has_pending_portal_choice() and not session.is_completed)
	session.resolve_pending_portal_choice("enter_portal")
	assert(session.is_completed and session.next_map_id() == second.map_id)
	assert(session.enter_map(second))
	assert(session.player_pos == Vector2i(1, 2))
	assert(session.move_by(1, 0))
	assert(session.has_pending_portal_choice() and not session.is_completed)
	session.resolve_pending_portal_choice("enter_portal")
	assert(session.is_completed and session.next_map_id() == first.map_id)
	assert(session.enter_map(copied))
	assert(session.player_pos == Vector2i(1, 2))
	assert(session.is_revealed(2, 2))
	assert(session.enter_map(second))
	assert(session.player_pos == Vector2i(1, 2))
	var plain: DungeonMap = _map_with_spawn(Vector2i(1, 1))
	assert(plain.place_entity("portal", 2, 1))
	var idle: GameSession = GameSession.start_for(plain)
	assert(idle.move_by(1, 0))
	assert(not idle.is_completed)
	assert(not idle.has_pending_portal_choice())
	assert(idle.next_map_id().is_empty())


func _test_invalid_destination() -> void:
	var first: DungeonMap = _map_with_spawn(Vector2i(1, 1))
	var second: DungeonMap = _map_with_spawn(Vector2i(2, 2))
	assert(first.place_entity("portal", 2, 1))
	var session: GameSession = GameSession.start_for(first)
	var old_position: Vector2i = session.player_pos
	assert(not DungeonMap.valid_arrival_cell(second, Vector2i(0, 0)))
	assert(session.map_data == first and session.player_pos == old_position)
	assert(second.place_entity("door", 2, 2))
	assert(not DungeonMap.valid_arrival_cell(second, Vector2i(2, 2)))
	assert(not session.enter_map(second))
	assert(session._floor_states.is_empty())
	assert(session.move_by(1, 0))
	assert(not session.is_completed)
