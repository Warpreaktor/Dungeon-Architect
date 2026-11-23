extends SceneTree


func _initialize() -> void:
	_test_return_to_the_same_stair()
	_test_nested_stairs_and_repeated_visits()
	_test_two_stairs_lead_to_one_map()
	_test_old_save_history_and_map_changes()
	_test_invalid_exit_and_legacy_maps()
	_test_incompatible_save_is_not_overwritten()
	print("DA-5.08: return stairs, nested floors, legacy maps, changed maps and safe failures OK")
	quit()


func _map(map_id: String, spawn: Vector2i = Vector2i(2, 2)) -> DungeonMap:
	var map_ref: DungeonMap = DungeonMap.create_blank(9, 9)
	map_ref.map_id = map_id
	assert(map_ref.place_entity("player_spawn", spawn.x, spawn.y))
	return map_ref


func _exit(map_ref: DungeonMap, cell: Vector2i) -> Dictionary:
	for entity in map_ref.entities_at(cell.x, cell.y):
		if str(entity.get("type", "")) == "stairs_down":
			return entity
	return {}


func _linked(first: DungeonMap, second: DungeonMap, cell: Vector2i) -> void:
	assert(first.place_entity("stairs_down", cell.x, cell.y))
	assert(first.set_exit_target(str(_exit(first, cell)["id"]), second.map_id))


func _ascend(session: GameSession, previous: DungeonMap) -> void:
	var spawn: Vector2i = session.map_data.find_entity_position("player_spawn")
	assert(session.player_pos == spawn)
	assert(session.move_by(0, 1))
	assert(session.move_by(0, -1))
	assert(session.is_completed)
	assert(session.current_exit().get("type") == "stairs_up")
	assert(session.next_map_id() == previous.map_id)
	assert(session.can_enter_next_map(previous))
	assert(session.enter_map(previous))


func _json(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert(parsed is Dictionary)
	return parsed


func _test_return_to_the_same_stair() -> void:
	var upper: DungeonMap = _map("return_upper", Vector2i(2, 2))
	var lower: DungeonMap = _map("return_lower", Vector2i(4, 4))
	_linked(upper, lower, Vector2i(6, 5))
	var source_stair_id: String = str(_exit(upper, Vector2i(6, 5))["id"])
	var source_json: String = JSON.stringify(upper.to_dict())
	var session: GameSession = GameSession.start_for(upper)
	assert(session.move_by(1, 0))
	assert(session.move_by(1, 0))
	assert(session.move_by(1, 0))
	assert(session.move_by(1, 0))
	assert(session.move_by(0, 1))
	assert(session.move_by(0, 1))
	assert(session.move_by(0, 1))
	assert(session.is_completed)
	assert(session.enter_map(lower))
	assert(session.player_pos == Vector2i(4, 4))
	assert(session._stairs_history.size() == 1)
	assert(session._stairs_history[0]["from_cell"] == [6, 5])
	assert(session._stairs_history[0]["from_exit_id"] == source_stair_id)
	var snapshots: Dictionary = _json(session.progress_snapshot())
	var maps: Dictionary = {upper.map_id: upper, lower.map_id: lower}
	var restored: GameSession = GameSession.from_progress_snapshot(snapshots, maps)
	assert(restored != null)
	assert(restored.next_map_id().is_empty())
	assert(restored.move_by(0, 1))
	assert(restored.move_by(0, -1))
	assert(restored.next_arrival_cell(upper) == Vector2i(6, 5))
	assert(restored.can_enter_next_map(upper))
	assert(restored.enter_map(upper))
	assert(restored.player_pos == Vector2i(6, 5))
	assert(restored._stairs_history.is_empty())
	assert(JSON.stringify(upper.to_dict()) == source_json)
	assert(not restored.is_completed)


func _test_nested_stairs_and_repeated_visits() -> void:
	var first: DungeonMap = _map("nested_first")
	var second: DungeonMap = _map("nested_second")
	var third: DungeonMap = _map("nested_third")
	_linked(first, second, Vector2i(4, 2))
	_linked(second, third, Vector2i(5, 2))
	var session: GameSession = GameSession.start_for(first)
	assert(session.move_by(1, 0))
	assert(session.move_by(1, 0))
	assert(session.enter_map(second))
	assert(session.move_by(1, 0))
	assert(session.move_by(1, 0))
	assert(session.move_by(1, 0))
	assert(session.enter_map(third))
	assert(session._stairs_history.size() == 2)
	_ascend(session, second)
	assert(session.player_pos == Vector2i(5, 2))
	assert(session._stairs_history.size() == 1)
	assert(session.move_by(-1, 0))
	assert(session.move_by(-1, 0))
	assert(session.move_by(-1, 0))
	assert(session.current_exit().get("type") == "stairs_up")
	assert(session.next_arrival_cell(first) == Vector2i(4, 2))
	assert(session.enter_map(first))
	assert(session.player_pos == Vector2i(4, 2))
	assert(session._stairs_history.is_empty())
	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(session.enter_map(second))
	assert(session.has_stairs_up())
	_ascend(session, first)
	assert(session.player_pos == Vector2i(4, 2))


func _test_two_stairs_lead_to_one_map() -> void:
	var upper: DungeonMap = _map("two_stairs_upper")
	var lower: DungeonMap = _map("two_stairs_lower")
	_linked(upper, lower, Vector2i(3, 2))
	_linked(upper, lower, Vector2i(5, 2))
	var session: GameSession = GameSession.start_for(upper)
	assert(session.move_by(1, 0))
	assert(session.enter_map(lower))
	_ascend(session, upper)
	assert(session.player_pos == Vector2i(3, 2))
	assert(session.move_by(0, 1))
	assert(session.move_by(1, 0))
	assert(session.move_by(1, 0))
	assert(session.move_by(0, -1))
	assert(session.is_completed)
	assert(session.enter_map(lower))
	assert(session.player_pos == lower.find_entity_position("player_spawn"))
	_ascend(session, upper)
	assert(session.player_pos == Vector2i(5, 2))
	assert(session._stairs_history.is_empty())


func _test_old_save_history_and_map_changes() -> void:
	var first: DungeonMap = _map("legacy_save_first")
	var second: DungeonMap = _map("legacy_save_second")
	_linked(first, second, Vector2i(3, 2))
	var session: GameSession = GameSession.start_for(first)
	assert(session.move_by(1, 0))
	assert(session.enter_map(second))
	var original: Dictionary = _json(session.progress_snapshot())
	var maps: Dictionary = {first.map_id: first, second.map_id: second}
	var legacy: Dictionary = original.duplicate(true)
	legacy["stairs_history"][0].erase("from_cell")
	legacy["stairs_history"][0].erase("from_exit_id")
	legacy["floors"][first.map_id].erase("map_signature")
	legacy["floors"][second.map_id].erase("map_signature")
	var restored: GameSession = GameSession.from_progress_snapshot(legacy, maps)
	assert(restored != null)
	assert(restored._stairs_history[0]["from_cell"] == [3, 2])
	assert(restored._stairs_history[0]["from_exit_id"] == _exit(first, Vector2i(3, 2))["id"])
	_ascend(restored, first)
	assert(restored.player_pos == Vector2i(3, 2))

	first.display_name = "Другое название подземелья"
	assert(GameSession.from_progress_snapshot(original, maps) != null)
	var map_source: String = JSON.stringify(first.to_dict())
	first.set_terrain(4, 5, "wall")
	assert(GameSession.from_progress_snapshot(original, maps) == null)
	var changed_map: DungeonMap = DungeonMap.from_dict(JSON.parse_string(map_source))
	assert(changed_map != null)
	var missing_maps: Dictionary = {second.map_id: second}
	assert(GameSession.from_progress_snapshot(original, missing_maps) == null)
	assert(GameSession.from_progress_snapshot(original, {first.map_id: changed_map, second.map_id: second}) != null)

	var corrupted: Dictionary = original.duplicate(true)
	corrupted["stairs_history"][0]["from_cell"] = [100, 100]
	assert(GameSession.from_progress_snapshot(corrupted, {first.map_id: changed_map, second.map_id: second}) == null)
	corrupted = original.duplicate(true)
	corrupted["stairs_history"][0]["from_exit_id"] = "deleted_stair"
	assert(GameSession.from_progress_snapshot(corrupted, {first.map_id: changed_map, second.map_id: second}) == null)
	corrupted = original.duplicate(true)
	corrupted["stairs_history"][0]["from_cell"] = "wrong_type"
	assert(GameSession.from_progress_snapshot(corrupted, {first.map_id: changed_map, second.map_id: second}) == null)


func _test_invalid_exit_and_legacy_maps() -> void:
	var first: DungeonMap = _map("invalid_return_first")
	var second: DungeonMap = _map("invalid_return_second")
	_linked(first, second, Vector2i(3, 2))
	var session: GameSession = GameSession.start_for(first)
	assert(session.move_by(1, 0))
	assert(session.enter_map(second))
	assert(session.move_by(0, 1))
	assert(session.move_by(0, -1))
	var previous_position: Vector2i = session.player_pos
	var previous_history: Array = session._stairs_history.duplicate(true)
	var previous_floor: Dictionary = session.floor_state_snapshot(first.map_id)
	assert(not session.can_enter_next_map(_map("wrong_map")))
	assert(not session.enter_map(_map("wrong_map")))
	assert(session.player_pos == previous_position)
	assert(session._stairs_history == previous_history)
	assert(session.floor_state_snapshot(first.map_id) == previous_floor)
	assert(first.set_exit_target(str(_exit(first, Vector2i(3, 2))["id"]), "missing_map"))
	assert(not session.can_enter_next_map(first))
	assert(not session.enter_map(first))
	assert(session.map_data == second and session._stairs_history == previous_history)

	var old: Dictionary = _map("old_map").to_dict()
	old.erase("id")
	old["entities"][0].erase("id")
	var reconstructed_a: DungeonMap = DungeonMap.from_dict(_json(old))
	var reconstructed_b: DungeonMap = DungeonMap.from_dict(_json(old))
	assert(reconstructed_a != null and reconstructed_b != null)
	assert(reconstructed_a.map_id == reconstructed_b.map_id)
	assert(reconstructed_a.entities[0]["id"] == reconstructed_b.entities[0]["id"])
	assert(reconstructed_a.entities[0]["id"] == "legacy_ent_00000")
	var renamed: Dictionary = _json(old)
	renamed["name"] = "Старое подземелье с новым названием"
	assert(DungeonMap.from_dict(renamed).map_id == reconstructed_a.map_id)
	var broken: Dictionary = reconstructed_a.to_dict().duplicate(true)
	broken["entities"].append(broken["entities"][0].duplicate(true))
	assert(DungeonMap.from_dict(broken) == null)


func _test_incompatible_save_is_not_overwritten() -> void:
	var map_ref: DungeonMap = _map("compatibility_saved_map")
	var maps: Dictionary = {map_ref.map_id: map_ref}
	var session: GameSession = GameSession.start_for(map_ref)
	var directory: String = "user://da_508_%d" % Time.get_ticks_usec()
	var store := ProgressSaveStore.new(directory)
	assert(store.save_game(session, maps))
	var path: String = directory.path_join(ProgressSaveStore.SAVE_FILE)
	var saved_text: String = FileAccess.get_file_as_string(path)
	assert(store.load_game(maps) != null)

	var changed: DungeonMap = DungeonMap.from_dict(_json(map_ref.to_dict()))
	assert(changed != null)
	assert(changed.set_terrain(5, 5, "wall"))
	var changed_maps: Dictionary = {changed.map_id: changed}
	assert(store.load_game(changed_maps) == null)
	assert(not store.last_error.is_empty())
	assert(not store.has_valid_save(changed_maps))
	assert(not store.save_game(GameSession.start_for(changed), changed_maps))
	assert(FileAccess.get_file_as_string(path) == saved_text)
	assert(store.load_game(maps) != null)
	assert(not store.save_game(GameSession.start_for(_map("compatibility_other_map")), maps))
	assert(FileAccess.get_file_as_string(path) == saved_text)

	assert(DirAccess.remove_absolute(path) == OK)
	assert(DirAccess.remove_absolute(directory) == OK)
