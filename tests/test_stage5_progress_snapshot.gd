extends SceneTree


func _initialize() -> void:
	_test_json_roundtrip_with_multiple_floors()
	_test_invalid_snapshots_do_not_change_world()
	print("Stage 5 progress format: roundtrip, bad saves and map references OK")
	quit()


func _map(map_id: String) -> DungeonMap:
	var map_ref: DungeonMap = DungeonMap.create_blank(9, 8)
	map_ref.map_id = map_id
	assert(map_ref.place_entity("player_spawn", 2, 2))
	return map_ref


func _at(map_ref: DungeonMap, kind: String, x: int, y: int) -> Dictionary:
	for entity in map_ref.entities_at(x, y):
		if str(entity.get("type", "")) == kind:
			return entity
	return {}


func _json(data: Dictionary) -> Dictionary:
	var decoded: Variant = JSON.parse_string(JSON.stringify(data))
	assert(decoded is Dictionary)
	return decoded


func _test_json_roundtrip_with_multiple_floors() -> void:
	var first: DungeonMap = _map("progress_first")
	var second: DungeonMap = _map("progress_second")
	var third: DungeonMap = _map("progress_third")
	assert(first.place_entity("stairs_down", 3, 2))
	assert(first.set_exit_target(str(_at(first, "stairs_down", 3, 2)["id"]), second.map_id))
	assert(first.place_entity("chest", 4, 2))
	var chest: Dictionary = _at(first, "chest", 4, 2)
	assert(first.set_chest_contents(str(chest["id"]), ["gold"], 13, false, false, {"gold": 13}))
	assert(second.place_entity("trap", 3, 3, {"trap_id": "spikes"}))
	var map_source: String = JSON.stringify(first.to_dict())
	var session: GameSession = GameSession.start_for_party(first, ["petushan", "volcha"])
	assert(session._receive_item("shield", 2, [2, 9]) == 2)
	session.party[1].health -= 4
	assert(session.move_by(1, 0))
	assert(session.enter_map(second))
	assert(session.has_stairs_up())
	session._append_ground_loot(Vector2i(3, 4), [{"item_id": "gold", "quantity": 11}])
	session.disarmed_traps[str(_at(second, "trap", 3, 3)["id"])] = true
	assert(session.move_by(0, 1))
	assert(session.enter_map(third))
	assert(session.enter_map(second))
	assert(session.has_stairs_up())
	var original: Dictionary = _json(session.progress_snapshot())
	assert(original["version"] == ProgressSnapshotCodec.FORMAT_VERSION)
	assert(original["current_map_id"] == second.map_id)
	assert(original["floors"].size() == 3)
	assert(original["floors"][second.map_id]["position"] == [2, 2])
	var maps: Dictionary = {first.map_id: first, second.map_id: second, third.map_id: third}
	var restored: GameSession = GameSession.from_progress_snapshot(original, maps)
	assert(restored != null)
	assert(restored.map_data == second)
	assert(restored.has_stairs_up())
	assert(restored.party.size() == 2)
	assert(restored.party[1].health == session.party[1].health)
	assert(restored.inventory_slot_ids() == session.inventory_slot_ids())
	assert(restored.ground_container_at(Vector2i(3, 4))["loot"][0]["quantity"] == 11)
	assert(restored.is_trap_disarmed(_at(second, "trap", 3, 3)))
	assert(_json(restored.progress_snapshot()) == original)
	assert(restored.enter_map(first))
	assert(restored.is_chest_open(chest) == session.floor_state_snapshot(first.map_id)["chests"].has(str(chest["id"])))
	assert(JSON.stringify(first.to_dict()) == map_source)


func _test_invalid_snapshots_do_not_change_world() -> void:
	var first: DungeonMap = _map("invalid_progress_first")
	var source: GameSession = GameSession.start_for(first)
	var original: Dictionary = _json(source.progress_snapshot())
	var maps: Dictionary = {first.map_id: first}
	var changed: Dictionary = original.duplicate(true)
	changed["version"] = 99
	assert(GameSession.from_progress_snapshot(changed, maps) == null)
	changed = original.duplicate(true)
	changed["current_map_id"] = "missing"
	assert(GameSession.from_progress_snapshot(changed, maps) == null)
	changed = original.duplicate(true)
	changed["floors"][first.map_id]["position"] = [999, 2]
	assert(GameSession.from_progress_snapshot(changed, maps) == null)
	changed = original.duplicate(true)
	changed["floors"][first.map_id]["revealed"][0][0] = "invalid"
	assert(GameSession.from_progress_snapshot(changed, maps) == null)
	changed = original.duplicate(true)
	changed["floors"][first.map_id]["removed"]["x"] = 10
	assert(GameSession.from_progress_snapshot(changed, maps) == null)
	changed = original.duplicate(true)
	changed["party"]["active_heroes"][0]["hero_id"] = "missing"
	assert(GameSession.from_progress_snapshot(changed, maps) == null)
	changed = original.duplicate(true)
	changed["stairs_history"].append({"from": "missing", "to": first.map_id})
	assert(GameSession.from_progress_snapshot(changed, maps) == null)
	assert(_json(source.progress_snapshot()) == original)
