extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _map(id: String) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(9, 9)
	dungeon.map_id = id
	assert(dungeon.place_entity("player_spawn", 1, 1))
	return dungeon


func _link(source: DungeonMap, target: String, x: int) -> void:
	assert(source.place_entity("stairs_down", x, 2))
	for entity in source.entities_at(x, 2):
		if DungeonMap.is_exit(entity):
			assert(source.set_exit_target(str(entity["id"]), target))
			return
	assert(false)


func _has(issues: Array[Dictionary], severity: String, fragment: String) -> bool:
	for issue in issues:
		if issue["severity"] == severity and str(issue["message"]).contains(fragment):
			return true
	return false


func _run() -> void:
	var root_dir: String = "user://da517_%d" % Time.get_ticks_usec()
	var campaign_dir: String = root_dir.path_join("campaigns")
	var save_dir: String = root_dir.path_join("saves")
	var library := CampaignLibrary.new(campaign_dir)
	var first: DungeonMap = _map("first")
	var second: DungeonMap = _map("second")
	var third: DungeonMap = _map("third")
	var branch: DungeonMap = _map("branch")
	var orphan: DungeonMap = _map("orphan")
	var foreign: DungeonMap = _map("foreign")
	_link(first, "second", 2)
	_link(first, "branch", 3)
	_link(second, "third", 2)
	_link(third, "first", 2)
	_link(branch, "second", 2)
	var maps: Dictionary = {"first": first, "second": second, "third": third, "branch": branch, "orphan": orphan, "foreign": foreign}
	var original: Dictionary = {}
	for id in maps:
		original[id] = JSON.stringify((maps[id] as DungeonMap).to_dict())
	var adventure: CampaignDefinition = library.create_campaign("Основная", "first", maps)
	assert(adventure != null)
	for id in ["second", "third", "branch", "orphan"]:
		assert(library.attach_map(adventure.campaign_id, id, maps))
	var other: CampaignDefinition = library.create_campaign("Отдельная", "foreign", maps)
	assert(other != null)
	var diagnostics: Array[Dictionary] = library.diagnose_graph(maps)
	assert(_has(diagnostics, "info", "Развилка"))
	assert(_has(diagnostics, "info", "Циклический"))
	assert(_has(diagnostics, "warning", "недостижим"))
	assert(not _has(diagnostics, "error", "Выход"))
	assert(not library.detach_map(adventure.campaign_id, "second", maps))
	assert(not library.detach_map(adventure.campaign_id, "first", maps))
	var session: GameSession = GameSession.start_for(first)
	assert(session != null and session.set_campaign(adventure))
	for destination in [second, third, first]:
		assert(session.move_by(1, 0))
		assert(session.move_by(0, 1))
		assert(session.is_completed)
		assert(session.can_enter_next_map(destination))
		assert(session.enter_map(destination))
	assert(not session.enter_map(foreign))
	var store := ProgressSaveStore.new(save_dir, campaign_dir)
	assert(store.save_game(session, maps))
	var save_path: String = save_dir.path_join(ProgressSaveStore.SAVE_FILE)
	var saved_text: String = FileAccess.get_file_as_string(save_path)
	assert(store.load_game(maps).map_data.map_id == first.map_id)
	var existing: String = FileAccess.get_file_as_string(campaign_dir.path_join(adventure.campaign_id + ".json"))
	var other_path: String = campaign_dir.path_join(other.campaign_id + ".json")
	var other_text: String = FileAccess.get_file_as_string(other_path)
	var duplicated: Dictionary = JSON.parse_string(other_text)
	duplicated["map_ids"].append("second")
	_write(other_path, JSON.stringify(duplicated))
	diagnostics = library.diagnose_graph(maps)
	assert(_has(diagnostics, "error", "нескольких"))
	assert(library.load_all(maps).is_empty())
	assert(not library.last_error.is_empty())
	assert(FileAccess.get_file_as_string(other_path) == JSON.stringify(duplicated))
	_write(other_path, other_text)
	_link(second, "foreign", 4)
	diagnostics = library.diagnose_graph(maps)
	assert(_has(diagnostics, "error", "чужой кампании"))
	assert(not session.enter_map(foreign))
	for entity in second.entities_at(4, 2):
		assert(second.set_exit_target(str(entity["id"]), "missing_floor"))
	diagnostics = library.diagnose_graph(maps)
	assert(_has(diagnostics, "error", "отсутствующую карту"))
	assert(not library.detach_map(adventure.campaign_id, "second", maps))
	assert(FileAccess.get_file_as_string(save_path) == saved_text)
	assert(FileAccess.get_file_as_string(campaign_dir.path_join(adventure.campaign_id + ".json")) == existing)
	var missing_maps: Dictionary = maps.duplicate()
	missing_maps.erase("orphan")
	diagnostics = library.diagnose_graph(missing_maps)
	assert(_has(diagnostics, "error", "отсутствует в библиотеке"))
	assert(library.load_all(missing_maps).is_empty())
	assert(FileAccess.get_file_as_string(save_path) == saved_text)
	var old_json: Dictionary = first.to_dict()
	old_json.erase("id")
	var legacy_map: DungeonMap = DungeonMap.from_dict(old_json)
	assert(legacy_map != null and legacy_map.map_id.begins_with("legacy_"))
	assert(DungeonMap.exit_target_id(legacy_map.entities_at(2, 2)[0]) == "second")
	var test_session: GameSession = GameSession.start_for(first)
	test_session.is_editor_test = true
	assert(test_session.progress_snapshot().is_empty())
	assert(not store.save_game(test_session, maps))
	assert(FileAccess.get_file_as_string(save_path) == saved_text)
	for id in maps:
		if id != "second":
			assert(JSON.stringify((maps[id] as DungeonMap).to_dict()) == original[id])
	_cleanup(root_dir)
	print("DA-5.17: graph diagnostics, isolation, progress and links OK")
	quit()


func _write(path: String, content: String) -> void:
	var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(writer != null)
	writer.store_string(content)
	writer = null


func _cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for filename in DirAccess.get_files_at(path):
		assert(DirAccess.remove_absolute(path.path_join(filename)) == OK)
	for folder in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(folder))
	assert(DirAccess.remove_absolute(path) == OK)
