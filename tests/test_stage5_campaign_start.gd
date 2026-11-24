extends SceneTree


func _initialize() -> void:
	_test_campaign_start_and_links()
	print("DA-5.15: campaign entry, branch and foreign links OK")
	quit()


func _map(map_id: String) -> DungeonMap:
	var result: DungeonMap = DungeonMap.create_blank(9, 9)
	result.map_id = map_id
	assert(result.place_entity("player_spawn", 2, 2))
	return result


func _exit(map_ref: DungeonMap, destination: DungeonMap) -> void:
	assert(map_ref.place_entity("stairs_down", 3, 2))
	for entity in map_ref.entities_at(3, 2):
		if str(entity.get("type", "")) == "stairs_down":
			assert(map_ref.set_exit_target(str(entity["id"]), destination.map_id))
			return
	assert(false)


func _test_campaign_start_and_links() -> void:
	var first: DungeonMap = _map("da515_first")
	var second: DungeonMap = _map("da515_second")
	var third: DungeonMap = _map("da515_third")
	var foreign: DungeonMap = _map("da515_foreign")
	_exit(first, second)
	_exit(second, third)
	var maps: Dictionary = {first.map_id: first, second.map_id: second, third.map_id: third, foreign.map_id: foreign}
	var original: Dictionary = {}
	for map_id in maps:
		original[map_id] = JSON.stringify(maps[map_id].to_dict())
	var directory: String = "user://da515_campaigns_%d" % Time.get_ticks_usec()
	var library := CampaignLibrary.new(directory)
	var adventure: CampaignDefinition = library.create_campaign("Три этажа", first.map_id, maps)
	assert(adventure != null)
	assert(library.attach_map(adventure.campaign_id, second.map_id, maps))
	assert(library.attach_map(adventure.campaign_id, third.map_id, maps))
	var other: CampaignDefinition = library.create_campaign("Чужая кампания", foreign.map_id, maps)
	assert(other != null)
	var loaded: Dictionary = library.load_all(maps)
	assert(loaded.size() == 2)
	assert(loaded[adventure.campaign_id].start_map_id == first.map_id)
	assert(loaded[adventure.campaign_id].map_ids.has(third.map_id))
	assert(not loaded[adventure.campaign_id].map_ids.has(foreign.map_id))
	var session: GameSession = GameSession.start_for(first)
	assert(session != null and session.set_campaign(adventure))
	assert(session.campaign_id == adventure.campaign_id)
	assert(session.is_map_in_campaign(third.map_id))
	assert(not session.is_map_in_campaign(foreign.map_id))
	assert(session.move_by(1, 0) and session.is_completed)
	assert(session.can_enter_next_map(second))
	assert(not session.can_enter_next_map(foreign))
	assert(not session.enter_map(foreign))
	assert(session.enter_map(second))
	assert(session.move_by(1, 0) and session.is_completed)
	assert(session.enter_map(third))
	assert(session.map_data.map_id == third.map_id)
	var test_session: GameSession = GameSession.start_for(foreign)
	assert(test_session != null and test_session.campaign_id.is_empty())
	for map_id in maps:
		assert(JSON.stringify(maps[map_id].to_dict()) == original[map_id])
	for campaign_id in loaded:
		var path: String = directory.path_join(str(campaign_id) + CampaignLibrary.FILE_SUFFIX)
		if FileAccess.file_exists(path):
			assert(DirAccess.remove_absolute(path) == OK)
	assert(DirAccess.remove_absolute(directory) == OK)
