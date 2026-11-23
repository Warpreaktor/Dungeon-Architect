extends SceneTree

var _test_directory: String


func _initialize() -> void:
	_test_directory = "user://da_505_saves_%d" % Time.get_ticks_usec()
	_test_roundtrip_and_backup()
	_test_rejects_invalid_data()
	_test_directory_failure()
	_cleanup()
	print("Stage 5 save store: writes, versions, backup recovery, failed writes and unchanged maps OK")
	quit()


func _map(map_id: String) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	dungeon.map_id = map_id
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return dungeon


func _write_text(path: String, value: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(value)
	file = null


func _read_snapshot(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert(file != null)
	var data: Variant = JSON.parse_string(file.get_as_text())
	assert(data is Dictionary)
	return data


func _test_roundtrip_and_backup() -> void:
	var first: DungeonMap = _map("da505_first")
	var second: DungeonMap = _map("da505_second")
	assert(first.place_entity("chest", 3, 3))
	assert(first.place_entity("stairs_down", 3, 2))
	var stair_id: String = ""
	for entity in first.entities_at(3, 2):
		if entity.get("type") == "stairs_down":
			stair_id = str(entity["id"])
	assert(not stair_id.is_empty())
	assert(first.set_exit_target(stair_id, second.map_id))
	var original_first: String = JSON.stringify(first.to_dict())
	var maps: Dictionary = {first.map_id: first, second.map_id: second}
	var session: GameSession = GameSession.start_for_party(first, ["petushan", "volcha"])
	assert(session != null)
	assert(session._receive_item("shield", 2, [4, 11]) == 2)
	session.party[1].health -= 5
	session.steps = 15
	assert(session.move_by(1, 0))
	assert(session.enter_map(second))
	session.steps = 15
	session._append_ground_loot(Vector2i(3, 2), [{"item_id": "gold", "quantity": 8}])
	var expected: Dictionary = session.progress_snapshot()
	var store := ProgressSaveStore.new(_test_directory)
	assert(not store.has_valid_save(maps))
	assert(store.load_game(maps) == null)
	assert(not store.last_error.is_empty())
	assert(store.save_game(session, maps))
	assert(store.last_error.is_empty())
	var save_path: String = _test_directory.path_join(ProgressSaveStore.SAVE_FILE)
	var backup_path: String = _test_directory.path_join(ProgressSaveStore.BACKUP_FILE)
	var temp_path: String = _test_directory.path_join(ProgressSaveStore.TEMP_FILE)
	assert(FileAccess.file_exists(save_path))
	assert(not FileAccess.file_exists(backup_path))
	assert(store.has_valid_save(maps))
	var loaded: GameSession = store.load_game(maps)
	assert(loaded != null)
	assert(loaded != session)
	assert(JSON.stringify(loaded.progress_snapshot()) == JSON.stringify(expected))
	assert(loaded.party[1].health == session.party[1].health)
	assert(loaded.inventory_slot_ids() == session.inventory_slot_ids())
	assert(loaded.has_stairs_up())
	assert(JSON.stringify(first.to_dict()) == original_first)

	session.steps = 42
	assert(store.save_game(session, maps))
	assert(_read_snapshot(backup_path)["party"]["steps"] == 15)
	assert(_read_snapshot(save_path)["party"]["steps"] == 42)
	_write_text(save_path, "broken JSON")
	assert(store.has_valid_save(maps))
	assert(store.load_game(maps).steps == 15)
	session.steps = 61
	assert(store.save_game(session, maps))
	assert(store.load_game(maps).steps == 61)
	assert(_read_snapshot(backup_path)["party"]["steps"] == 15)
	assert(DirAccess.remove_absolute(save_path) == OK)
	_write_text(temp_path, "interrupted write")
	assert(store.load_game(maps).steps == 15)
	session.steps = 73
	assert(store.save_game(session, maps))
	assert(store.load_game(maps).steps == 73)
	assert(not FileAccess.file_exists(temp_path))
	assert(JSON.stringify(first.to_dict()) == original_first)


func _test_rejects_invalid_data() -> void:
	var map_ref: DungeonMap = _map("da505_bad")
	var maps: Dictionary = {map_ref.map_id: map_ref}
	var session: GameSession = GameSession.start_for(map_ref)
	var root: String = _test_directory.path_join("rejected")
	var store := ProgressSaveStore.new(root)
	assert(store.save_game(session, maps))
	var save_path: String = root.path_join(ProgressSaveStore.SAVE_FILE)
	var backup_path: String = root.path_join(ProgressSaveStore.BACKUP_FILE)
	var valid_content: String = FileAccess.get_file_as_string(save_path)
	session.is_completed = true
	assert(not store.save_game(session, maps))
	assert(FileAccess.get_file_as_string(save_path) == valid_content)
	session.is_completed = false
	assert(not store.save_game(session, {}))
	assert(FileAccess.get_file_as_string(save_path) == valid_content)
	assert(store.load_game({}) == null)
	assert(store.has_valid_save(maps))
	_write_text(save_path, "not JSON")
	assert(store.load_game(maps) == null)
	assert(not store.save_game(session, maps))
	assert(FileAccess.get_file_as_string(save_path) == "not JSON")
	assert(not FileAccess.file_exists(backup_path))
	_write_text(save_path, valid_content)
	assert(store.save_game(session, maps))
	_write_text(save_path, '{"version": 999}')
	assert(store.has_valid_save(maps))
	assert(store.load_game(maps) != null)
	assert(store.last_error.is_empty())


func _test_directory_failure() -> void:
	var file_path: String = _test_directory.path_join("block_directory")
	_write_text(file_path, "ordinary file")
	var store := ProgressSaveStore.new(file_path)
	var dungeon: DungeonMap = _map("da505_blocked")
	var session: GameSession = GameSession.start_for(dungeon)
	assert(not store.save_game(session, {dungeon.map_id: dungeon}))
	assert(not store.last_error.is_empty())
	assert(FileAccess.get_file_as_string(file_path) == "ordinary file")


func _cleanup() -> void:
	_cleanup_dir(_test_directory)


func _cleanup_dir(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for child in DirAccess.get_directories_at(path):
		_cleanup_dir(path.path_join(child))
	DirAccess.remove_absolute(path)
