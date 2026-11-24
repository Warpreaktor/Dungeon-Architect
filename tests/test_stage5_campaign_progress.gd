extends SceneTree


func _initialize() -> void:
	_test_campaign_roundtrip_and_legacy()
	print("DA-5.16: campaign restore, legacy saves, foreign floors and incompatible files OK")
	quit()


func _map(map_id: String) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(9, 9)
	dungeon.map_id = map_id
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return dungeon


func _exit(map_ref: DungeonMap, destination: DungeonMap) -> void:
	assert(map_ref.place_entity("stairs_down", 3, 2))
	for entity in map_ref.entities_at(3, 2):
		if str(entity.get("type", "")) == "stairs_down":
			assert(map_ref.set_exit_target(str(entity["id"]), destination.map_id))
			return
	assert(false)


func _write(path: String, snapshot: Dictionary) -> void:
	var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(writer != null)
	writer.store_string(JSON.stringify(snapshot, "\t"))
	writer = null


func _test_campaign_roundtrip_and_legacy() -> void:
	var first: DungeonMap = _map("da516_first")
	var second: DungeonMap = _map("da516_second")
	var third: DungeonMap = _map("da516_third")
	var foreign: DungeonMap = _map("da516_foreign")
	_exit(first, second)
	_exit(second, third)
	var maps: Dictionary = {first.map_id: first, second.map_id: second, third.map_id: third, foreign.map_id: foreign}
	var root: String = "user://da516_%d" % Time.get_ticks_usec()
	var library := CampaignLibrary.new(root.path_join("campaigns"))
	var store := ProgressSaveStore.new(root.path_join("saves"), library.directory)
	var campaign: CampaignDefinition = library.create_campaign("Исследование", first.map_id, maps)
	assert(campaign != null)
	assert(library.attach_map(campaign.campaign_id, second.map_id, maps))
	assert(library.attach_map(campaign.campaign_id, third.map_id, maps))
	campaign = library.load_campaign(campaign.campaign_id, maps)
	assert(campaign != null)
	var other: CampaignDefinition = library.create_campaign("Чужой этаж", foreign.map_id, maps)
	assert(other != null)
	var original_maps: Dictionary = {}
	for map_id in maps:
		original_maps[map_id] = JSON.stringify(maps[map_id].to_dict())
	var session: GameSession = GameSession.start_for_party(first, ["petushan", "volcha"])
	assert(session != null and session.set_campaign(campaign))
	assert(session.move_by(1, 0))
	assert(session.enter_map(second))
	assert(session.move_by(1, 0))
	assert(session.enter_map(third))
	session.party[1].health -= 3
	var expected: Dictionary = session.progress_snapshot()
	assert(expected["version"] == 2)
	assert(expected["campaign_id"] == campaign.campaign_id)
	assert(store.save_game(session, maps))
	var path: String = store.directory.path_join(ProgressSaveStore.SAVE_FILE)
	var bytes_before: String = FileAccess.get_file_as_string(path)
	var restored: GameSession = store.load_game(maps)
	assert(restored != null)
	assert(restored.campaign_id == campaign.campaign_id)
	assert(restored.map_data.map_id == third.map_id)
	assert(restored.party[1].health == session.party[1].health)
	assert(JSON.stringify(restored.progress_snapshot()) == JSON.stringify(expected))
	assert(not restored.can_enter_next_map(foreign))
	var tampered: Dictionary = expected.duplicate(true)
	tampered["campaign_id"] = other.campaign_id
	assert(GameSession.from_progress_snapshot(tampered, maps, library.load_all(maps)) == null)
	tampered = expected.duplicate(true)
	tampered["floors"][foreign.map_id] = tampered["floors"][third.map_id].duplicate(true)
	assert(GameSession.from_progress_snapshot(tampered, maps, library.load_all(maps)) == null)
	tampered = expected.duplicate(true)
	tampered["stairs_history"][0]["to"] = foreign.map_id
	assert(GameSession.from_progress_snapshot(tampered, maps, library.load_all(maps)) == null)
	assert(FileAccess.get_file_as_string(path) == bytes_before)
	var legacy: Dictionary = expected.duplicate(true)
	legacy["version"] = 1
	legacy.erase("campaign_id")
	_write(path, legacy)
	var legacy_text: String = FileAccess.get_file_as_string(path)
	var migrated: GameSession = store.load_game(maps)
	assert(migrated != null and migrated.campaign_id == campaign.campaign_id)
	assert(migrated.map_data.map_id == third.map_id)
	assert(FileAccess.get_file_as_string(path) == legacy_text)
	assert(store.save_game(migrated, maps))
	assert(JSON.parse_string(FileAccess.get_file_as_string(path))["version"] == 2)
	assert(JSON.parse_string(FileAccess.get_file_as_string(path))["campaign_id"] == campaign.campaign_id)
	var changed: CampaignDefinition = library.load_campaign(campaign.campaign_id, maps)
	assert(changed.remove_map(third.map_id))
	assert(library.save_campaign(changed, maps))
	assert(store.load_game(maps) == null)
	var unchanged: String = FileAccess.get_file_as_string(path)
	assert(not store.save_game(session, maps))
	assert(FileAccess.get_file_as_string(path) == unchanged)
	var future: Dictionary = expected.duplicate(true)
	future["version"] = 999
	_write(path, future)
	var future_text: String = FileAccess.get_file_as_string(path)
	assert(not store.save_game(session, maps))
	assert(FileAccess.get_file_as_string(path) == future_text)
	for map_id in maps:
		assert(JSON.stringify(maps[map_id].to_dict()) == original_maps[map_id])
	_cleanup(root)


func _cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for filename in DirAccess.get_files_at(path):
		assert(DirAccess.remove_absolute(path.path_join(filename)) == OK)
	for folder in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(folder))
	assert(DirAccess.remove_absolute(path) == OK)
