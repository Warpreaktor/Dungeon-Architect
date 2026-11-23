extends SceneTree


func _initialize() -> void:
	_test_adventure_save_reload_and_backtracking()
	_test_rejected_saves_do_not_replace_progress()
	_test_fallen_hero_and_unclaimed_loot_survive_relaunch()
	print("DA-5.09: adventure, return stairs, rewards, loot, persistence and save guards OK")
	quit()


func _map(map_id: String, spawn: Vector2i) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(10, 9)
	dungeon.map_id = map_id
	assert(dungeon.place_entity("player_spawn", spawn.x, spawn.y))
	return dungeon


func _entity(dungeon: DungeonMap, kind: String, cell: Vector2i) -> Dictionary:
	for candidate in dungeon.entities_at(cell.x, cell.y):
		if str(candidate.get("type", "")) == kind:
			return candidate
	return {}


func _exit_link(dungeon: DungeonMap, cell: Vector2i, destination: DungeonMap) -> void:
	assert(dungeon.place_entity("stairs_down", cell.x, cell.y))
	assert(dungeon.set_exit_target(str(_entity(dungeon, "stairs_down", cell)["id"]), destination.map_id))


func _test_adventure_save_reload_and_backtracking() -> void:
	var first: DungeonMap = _map("adventure_first", Vector2i(2, 2))
	var second: DungeonMap = _map("adventure_second", Vector2i(3, 3))
	var third: DungeonMap = _map("adventure_third", Vector2i(2, 2))
	assert(first.place_entity("chest", 3, 2))
	assert(first.place_entity("door", 4, 2))
	assert(first.place_entity("monster", 5, 2, {"monster_id": "skeleton"}))
	assert(first.place_entity("trigger", 2, 2))
	assert(first.set_message_at(2, 2, "Начало приключения"))
	_exit_link(first, Vector2i(6, 2), second)
	_exit_link(second, Vector2i(4, 3), third)
	assert(second.place_entity("trap", 5, 4, {"trap_id": "spikes"}))
	assert(second.place_entity("chest", 5, 3))
	var first_chest: Dictionary = _entity(first, "chest", Vector2i(3, 2))
	var first_door: Dictionary = _entity(first, "door", Vector2i(4, 2))
	var first_monster: Dictionary = _entity(first, "monster", Vector2i(5, 2))
	var first_stair: Dictionary = _entity(first, "stairs_down", Vector2i(6, 2))
	var second_chest: Dictionary = _entity(second, "chest", Vector2i(5, 3))
	var second_trap: Dictionary = _entity(second, "trap", Vector2i(5, 4))
	assert(first.set_chest_contents(str(first_chest["id"]), ["key"], 0, false, false, {"key": 2}))
	assert(first.set_chest_contents(str(first_stair["id"]), ["gold"], 16, false, false, {"gold": 16}))
	assert(second.set_chest_contents(str(second_chest["id"]), ["potion"], 0, false, false, {"potion": 2}))
	var author_json: Dictionary = {
		first.map_id: JSON.stringify(first.to_dict()),
		second.map_id: JSON.stringify(second.to_dict()),
		third.map_id: JSON.stringify(third.to_dict())
	}
	var maps: Dictionary = {first.map_id: first, second.map_id: second, third.map_id: third}
	var session: GameSession = GameSession.start_for_party(first, ["petushan", "volcha"])
	assert(session != null and session.party.size() == 2)
	assert(session.take_trigger_events().size() == 1)
	assert(session.take_message_events().size() == 1)
	assert(session._receive_item("shield", 2, [4, 11]) == 2)
	session.party[1].health -= 3
	assert(session.move_by(1, 0))
	assert(session.is_chest_open(first_chest))
	assert(int(session.carried_items.get("key", 0)) == 2)
	assert(session.move_by(1, 0))
	assert(session.is_entity_removed(first_door))
	assert(int(session.carried_items.get("key", 0)) == 1)
	assert(not session.move_by(1, 0) and session.has_pending_encounter())
	assert(session.win_pending_encounter())
	assert(session.is_entity_removed(first_monster))
	assert(session.move_by(1, 0) and session.is_completed)
	var first_gold: int = session.hero.gold
	assert(first_gold >= 16)
	assert(session.claimed_exit_rewards.has(str(first_stair["id"])))
	assert(session.enter_map(second))
	assert(session.player_pos == Vector2i(3, 3))
	assert(session.move_by(1, 0) and session.is_completed)
	assert(session.enter_map(third))
	assert(session.player_pos == Vector2i(2, 2))
	var abandoned: Array[Dictionary] = [{"item_id": "gold", "quantity": 9}]
	session._append_ground_loot(Vector2i(3, 2), abandoned)
	var container_id: String = str(session.ground_container_at(Vector2i(3, 2))["id"])
	assert(not container_id.is_empty())
	var visited_before: Dictionary = session.visited_floor_snapshots()
	assert(visited_before.size() == 3)
	var party_before: Dictionary = session.party_state_snapshot()
	var snapshot_before: Dictionary = _json(session.progress_snapshot())
	var save_dir: String = "user://da_509_adventure_%d" % Time.get_ticks_usec()
	var store := ProgressSaveStore.new(save_dir)
	assert(store.save_game(session, maps))
	assert(FileAccess.file_exists(save_dir.path_join(ProgressSaveStore.SAVE_FILE)))
	var restored: GameSession = store.load_game(maps)
	assert(restored != null and restored != session)
	assert(_json(restored.progress_snapshot()) == snapshot_before)
	assert(restored.party_state_snapshot() == party_before)
	assert(restored.visited_floor_snapshots().size() == 3)
	assert(restored.ground_container_by_id(container_id)["loot"][0]["quantity"] == 9)

	assert(restored.move_by(0, 1))
	assert(restored.move_by(0, -1) and restored.is_completed)
	assert(restored.enter_map(second))
	assert(restored.player_pos == Vector2i(4, 3))
	assert(restored.move_by(1, 0))
	assert(restored.is_chest_open(second_chest))
	assert(int(restored.carried_items.get("potion", 0)) == 2)
	restored.disarmed_traps[str(second_trap["id"])] = true
	restored.revealed_traps[str(second_trap["id"])] = true
	assert(restored.move_by(0, 1))
	assert(restored.move_by(-1, 0))
	assert(restored.move_by(-1, 0))
	assert(restored.move_by(0, -1) and restored.is_completed)
	assert(restored.enter_map(first))
	assert(restored.player_pos == Vector2i(6, 2))
	assert(restored.is_chest_open(first_chest) and restored.is_entity_removed(first_door))
	assert(restored.is_entity_removed(first_monster))
	assert(restored.hero.gold == first_gold)
	var keys_before: int = int(restored.carried_items.get("key", 0))
	assert(restored.move_by(-1, 0))
	assert(restored.move_by(-1, 0))
	assert(restored.move_by(-1, 0))
	assert(restored.hero.gold == first_gold)
	assert(int(restored.carried_items.get("key", 0)) == keys_before)
	assert(not restored.has_pending_encounter())
	assert(restored.move_by(1, 0))
	assert(restored.move_by(1, 0))
	assert(restored.move_by(1, 0) and restored.is_completed)
	assert(restored.hero.gold == first_gold)
	assert(restored.enter_map(second))
	assert(restored.is_chest_open(second_chest))
	assert(restored.is_trap_disarmed(second_trap))
	assert(int(restored.carried_items.get("potion", 0)) == 2)
	assert(restored.move_by(1, 0) and restored.is_completed)
	assert(restored.enter_map(third))
	assert(restored.ground_container_by_id(container_id)["loot"][0]["quantity"] == 9)
	assert(restored.take_ground_loot(container_id, 0) == 9)
	assert(restored.ground_container_by_id(container_id).is_empty())
	assert(store.save_game(restored, maps))
	var again: GameSession = store.load_game(maps)
	assert(again != null and again.ground_container_by_id(container_id).is_empty())
	assert(again.party.size() == 2 and again.steps == restored.steps)
	for floor_id in maps:
		assert(JSON.stringify(maps[floor_id].to_dict()) == author_json[floor_id])
	_cleanup_store(save_dir)


func _test_rejected_saves_do_not_replace_progress() -> void:
	var dungeon: DungeonMap = _map("adventure_guard", Vector2i(2, 2))
	assert(dungeon.place_entity("monster", 3, 2, {"monster_id": "skeleton"}))
	assert(dungeon.place_entity("stairs_down", 2, 3))
	var maps: Dictionary = {dungeon.map_id: dungeon}
	var save_dir: String = "user://da_509_guard_%d" % Time.get_ticks_usec()
	var store := ProgressSaveStore.new(save_dir)
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	assert(store.save_game(session, maps))
	var save_path: String = save_dir.path_join(ProgressSaveStore.SAVE_FILE)
	var bytes: String = FileAccess.get_file_as_string(save_path)
	assert(not session.move_by(1, 0) and session.has_pending_encounter())
	assert(not store.save_game(session, maps))
	assert(FileAccess.get_file_as_string(save_path) == bytes)
	session.abandon_pending_encounter()
	assert(session.move_by(0, 1) and session.is_completed)
	assert(not store.save_game(session, maps))
	assert(FileAccess.get_file_as_string(save_path) == bytes)
	session.cancel_exit_transition()
	session.is_editor_test = true
	assert(not store.save_game(session, maps))
	assert(FileAccess.get_file_as_string(save_path) == bytes)
	assert(store.load_game(maps) != null)
	session.is_editor_test = false
	for member in session.party:
		member.health = 0
	session.record_casualties()
	assert(session.is_party_defeated())
	assert(not store.save_game(session, maps))
	assert(FileAccess.get_file_as_string(save_path) == bytes)
	_cleanup_store(save_dir)


func _test_fallen_hero_and_unclaimed_loot_survive_relaunch() -> void:
	var dungeon: DungeonMap = _map("adventure_casualty", Vector2i(2, 2))
	var original_json: String = JSON.stringify(dungeon.to_dict())
	var maps: Dictionary = {dungeon.map_id: dungeon}
	var save_dir: String = "user://da_509_casualty_%d" % Time.get_ticks_usec()
	var store := ProgressSaveStore.new(save_dir)
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	assert(session._receive_item("shield", 1, [7]) == 1)
	session.hero.gold = 23
	session.hero.health = 0
	assert(session.record_casualties().size() == 1)
	assert(session.party.size() == 1 and session.fallen_heroes.size() == 1)
	var dropped: Dictionary = session.ground_container_at(session.player_pos)
	assert(not dropped.is_empty())
	var id: String = str(dropped["id"])
	assert(store.save_game(session, maps))
	var restored: GameSession = store.load_game(maps)
	assert(restored != null)
	assert(restored.party.size() == 1 and restored.fallen_heroes.size() == 1)
	assert(restored.fallen_heroes[0].health == 0)
	assert(restored.party[0].shield_durabilities.get("shield", []) == [7])
	assert(restored.ground_container_by_id(id)["loot"][0]["quantity"] == 23)
	assert(restored.record_casualties().is_empty())
	assert(restored.take_ground_loot(id, 0) == 23)
	assert(restored.ground_container_by_id(id).is_empty())
	assert(store.save_game(restored, maps))
	var after_second_relaunch: GameSession = store.load_game(maps)
	assert(after_second_relaunch != null)
	assert(after_second_relaunch.fallen_heroes.size() == 1)
	assert(after_second_relaunch.ground_container_by_id(id).is_empty())
	assert(after_second_relaunch.party[0].gold == 23)
	assert(JSON.stringify(dungeon.to_dict()) == original_json)
	_cleanup_store(save_dir)


func _json(value: Dictionary) -> Dictionary:
	var decoded: Variant = JSON.parse_string(JSON.stringify(value))
	assert(decoded is Dictionary)
	return decoded


func _cleanup_store(path: String) -> void:
	for name in [ProgressSaveStore.SAVE_FILE, ProgressSaveStore.BACKUP_FILE, ProgressSaveStore.TEMP_FILE]:
		var file_path: String = path.path_join(name)
		if FileAccess.file_exists(file_path):
			assert(DirAccess.remove_absolute(file_path) == OK)
	assert(DirAccess.remove_absolute(path) == OK)
