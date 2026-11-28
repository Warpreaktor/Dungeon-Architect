extends SceneTree

const MOVING_WALL := Vector2i(3, 3)
const WALL_TARGET := Vector2i(4, 3)
const VANISHING_WALL := Vector2i(5, 5)
const APPEARING_WALL := Vector2i(6, 3)
const TRIGGER_CELL := Vector2i(2, 2)


func _initialize() -> void:
	_test_switching_and_isolation()
	_test_blocked_transaction()
	_test_floor_state_and_save()
	print("Sliding plates geometry: atomic switching, occupancy, floor state and saves OK")
	quit()


func _map() -> DungeonMap:
	var data := DungeonMap.create_blank(9, 9)
	assert(data.place_entity("player_spawn", 1, 1))
	assert(data.set_terrain(MOVING_WALL.x, MOVING_WALL.y, "wall"))
	assert(data.set_terrain(VANISHING_WALL.x, VANISHING_WALL.y, "wall"))
	assert(data.place_entity(SlidingPlates.TRIGGER, TRIGGER_CELL.x, TRIGGER_CELL.y))
	assert(data.cycle_sliding_plates_mark(MOVING_WALL).is_empty())
	for operation in SlidingPlates.MARK_CYCLE:
		assert(data.cycle_sliding_plates_mark(VANISHING_WALL).is_empty())
	assert(data.cycle_sliding_plates_mark(APPEARING_WALL).is_empty())
	return data


func _assert_geometry(session: GameSession, shifted: bool) -> void:
	assert(session.map_data.sliding_plates_is_shifted() == shifted)
	assert(session.can_enter(MOVING_WALL) == shifted)
	assert(session.can_enter(WALL_TARGET) != shifted)
	assert(session.can_enter(VANISHING_WALL) == shifted)
	assert(session.can_enter(APPEARING_WALL) != shifted)
	assert(session.can_enter(TRIGGER_CELL))


func _switch(session: GameSession) -> Dictionary:
	return session.switch_sliding_plates(session.map_data.sliding_plates_trigger_id())


func _test_switching_and_isolation() -> void:
	var data := _map()
	var original := JSON.stringify(data.to_dict())
	var signature := ProgressSnapshotCodec.map_signature(data)
	var session := GameSession.start_for(data)
	var other := GameSession.start_for(data)
	assert(session != null and other != null)
	assert(session.map_data != data and other.map_data != session.map_data)
	var steps := session.steps
	var random_state := session.trap_random.state
	for index in range(100):
		var shifted: bool = index % 2 == 0
		var result := _switch(session)
		assert(result.size() == 4)
		assert(result[MOVING_WALL] == ("floor" if shifted else "wall"))
		result.clear()
		_assert_geometry(session, shifted)
		_assert_geometry(other, false)
		assert(JSON.stringify(data.to_dict()) == original)
		assert(JSON.stringify(session.map_data.to_dict()) == original)
		assert(ProgressSnapshotCodec.map_signature(session.map_data) == signature)
	assert(session.steps == steps and session.trap_random.state == random_state)
	assert(session.activated_triggers.is_empty() and session.discharged_traps.is_empty())
	assert(not session.execute(GameAction.switch_sliding_plates("other_trigger")).accepted)
	assert(not data.sliding_plates_is_shifted())
	var reach_a: Dictionary = DungeonReachability.analyze(session.map_data)["reachable"]
	assert(reach_a.has(WALL_TARGET) and not reach_a.has(MOVING_WALL))
	assert(not _switch(session).is_empty())
	var reach_b: Dictionary = DungeonReachability.analyze(session.map_data)["reachable"]
	assert(not reach_b.has(WALL_TARGET) and reach_b.has(MOVING_WALL))
	session.player_pos = Vector2i(3, 2)
	assert(session.execute(GameAction.move(Vector2i.DOWN)).moved)
	assert(not session.execute(GameAction.move(Vector2i.RIGHT)).moved)
	assert(session.player_pos == MOVING_WALL)


func _test_blocked_transaction() -> void:
	var session := GameSession.start_for(_map())
	assert(session != null)
	session.player_pos = WALL_TARGET
	var before := session.floor_state_snapshot()
	var blocked := _switch(session)
	assert(blocked.is_empty())
	assert(session.floor_state_snapshot() == before)
	_assert_geometry(session, false)
	session.player_pos = TRIGGER_CELL
	var loot: Array[Dictionary] = [{"item_id": "gold", "quantity": 5}]
	session._append_ground_loot(APPEARING_WALL, loot)
	before = session.floor_state_snapshot()
	assert(_switch(session).is_empty())
	assert(session.floor_state_snapshot() == before)
	var container := session.ground_container_at(APPEARING_WALL)
	session.player_pos = APPEARING_WALL
	assert(session.take_ground_loot(str(container["id"]), 0) == 5)
	session.player_pos = TRIGGER_CELL
	for kind in ["monster", "chest", "door"]:
		var entity := {"id": "occupant_" + kind, "type": kind, "x": WALL_TARGET.x, "y": WALL_TARGET.y, "properties": {}}
		session.map_data._append_entity(entity)
		assert(_switch(session).is_empty())
		_assert_geometry(session, false)
		session.map_data._remove_entity(entity)
	assert(not _switch(session).is_empty())
	_assert_geometry(session, true)
	session.player_pos = VANISHING_WALL
	before = session.floor_state_snapshot()
	assert(_switch(session).is_empty())
	assert(session.floor_state_snapshot() == before)
	_assert_geometry(session, true)
	session.player_pos = TRIGGER_CELL
	session._append_ground_loot(MOVING_WALL, loot)
	assert(_switch(session).is_empty())
	container = session.ground_container_at(MOVING_WALL)
	session.player_pos = MOVING_WALL
	assert(session.take_ground_loot(str(container["id"]), 0) == 5)
	session.player_pos = TRIGGER_CELL
	assert(not _switch(session).is_empty())
	_assert_geometry(session, false)


func _test_floor_state_and_save() -> void:
	var first := _map()
	var second := DungeonMap.create_blank(8, 8)
	assert(second.place_entity("player_spawn", 1, 1))
	var maps := {first.map_id: first, second.map_id: second}
	var session := GameSession.start_for(first)
	assert(session != null)
	var old_save := session.progress_snapshot()
	assert(not old_save["floors"][first.map_id].has("sliding_plates_shifted"))
	old_save["floors"][first.map_id].erase("sliding_plates_trigger_id")
	var legacy := GameSession.from_progress_snapshot(old_save, maps)
	assert(legacy != null)
	_assert_geometry(legacy, false)
	assert(not _switch(session).is_empty())
	session.player_pos = MOVING_WALL
	session._refresh_visibility()
	var loot: Array[Dictionary] = [{"item_id": "gold", "quantity": 3}]
	session._append_ground_loot(VANISHING_WALL, loot)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	assert(snapshot["floors"][first.map_id]["sliding_plates_shifted"] == true)
	var restored := GameSession.from_progress_snapshot(snapshot, maps)
	assert(restored != null and restored.player_pos == MOVING_WALL)
	_assert_geometry(restored, true)
	assert(_switch(restored).is_empty())
	assert(restored.enter_map(second))
	var visited_snapshot: Dictionary = JSON.parse_string(JSON.stringify(restored.progress_snapshot()))
	var loaded := GameSession.from_progress_snapshot(visited_snapshot, maps)
	assert(loaded != null and loaded.enter_map(first))
	_assert_geometry(loaded, true)
	assert(_switch(loaded).is_empty())
	var container := loaded.ground_container_at(VANISHING_WALL)
	loaded.player_pos = VANISHING_WALL
	assert(loaded.take_ground_loot(str(container["id"]), 0) == 3)
	loaded.player_pos = TRIGGER_CELL
	assert(not _switch(loaded).is_empty())
	_assert_geometry(loaded, false)
	var invalid := snapshot.duplicate(true)
	invalid["floors"][first.map_id]["position"] = [WALL_TARGET.x, WALL_TARGET.y]
	assert(GameSession.from_progress_snapshot(invalid, maps) == null)
	invalid = visited_snapshot.duplicate(true)
	invalid["floors"][second.map_id]["sliding_plates_shifted"] = true
	assert(GameSession.from_progress_snapshot(invalid, maps) == null)
	assert(first.get_terrain(MOVING_WALL.x, MOVING_WALL.y) == "wall")
	assert(first.get_terrain(WALL_TARGET.x, WALL_TARGET.y) == "floor")
