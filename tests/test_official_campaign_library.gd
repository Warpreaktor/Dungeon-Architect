extends SceneTree

const CAMPAIGN_ID := "official_varg"
const SOURCE_ID := "map_varg_01_dead_garrison_treasury"


func _initialize() -> void:
	_test_bundled_campaign()
	_test_linked_chapters()
	print("Official campaigns: bundled content, editor isolation, saves and chapter links OK")
	quit()


func _test_bundled_campaign() -> void:
	var path: String = OfficialCampaignLibrary.DIRECTORY.path_join("maps").path_join(SOURCE_ID + ".json")
	var original: String = FileAccess.get_file_as_string(path)
	var source: DungeonMap = DungeonMap.from_dict(JSON.parse_string(original))
	assert(source != null and source.map_id == SOURCE_ID)
	var root_dir: String = "user://official_campaign_test_%d" % Time.get_ticks_usec()
	var maps_dir: String = root_dir.path_join("maps")
	assert(DirAccess.make_dir_recursive_absolute(maps_dir) == OK)
	var source_path: String = maps_dir.path_join(SOURCE_ID + ".json")
	_write_json(source_path, source.to_dict())
	var editable: Dictionary = SavedMapLibrary.load_all(maps_dir)
	assert(editable.size() == 1 and editable.has(SOURCE_ID))
	assert(SavedMapLibrary.load_all(OfficialCampaignLibrary.DIRECTORY.path_join("maps")).is_empty())
	var maps: Dictionary = SavedMapLibrary.load_for_game(maps_dir)
	var library := CampaignLibrary.new(root_dir.path_join("campaigns"))
	assert(library.load_all(editable).is_empty())
	var campaigns: Dictionary = library.load_for_game(maps)
	var campaign: CampaignDefinition = campaigns.get(CAMPAIGN_ID)
	assert(campaign != null and campaign.has_valid_maps(maps))
	assert(not campaign.cover_image.is_empty())
	assert(MainMenu.campaign_cover(campaign).resource_path == campaign.cover_image)
	var copy: CampaignDefinition = CampaignDefinition.from_dict(campaign.to_dict())
	assert(copy != null and copy.cover_image == campaign.cover_image)
	copy.cover_image = "res://assets/campaigns/nonexistent.png"
	assert(MainMenu.campaign_cover(copy) == MainMenu.DEFAULT_CAMPAIGN_COVER)
	copy.cover_image = campaign.cover_image
	copy.campaign_id = "campaign_user"
	assert(MainMenu.campaign_cover(copy) == MainMenu.DEFAULT_CAMPAIGN_COVER)
	var start: DungeonMap = maps[campaign.start_map_id]
	assert(start.map_id == OfficialCampaignLibrary.ID_PREFIX + SOURCE_ID)
	assert(start.width == source.width and start.height == source.height)
	assert(start.terrain == source.terrain)
	assert(start.find_entity_position("player_spawn") == source.find_entity_position("player_spawn"))
	assert(not library.save_campaign(campaign, maps))
	assert(MainMenu.unassigned_maps(maps, campaigns).size() == 1)
	assert(MainMenu.unassigned_maps(maps, campaigns)[0].map_id == SOURCE_ID)
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	assert(editor.call("_read_map", path) == null)
	assert(editor.call("_read_map", ProjectSettings.globalize_path(path)) == null)
	assert(editor.call("_read_map", source_path) != null)
	var protected_copy: String = maps_dir.path_join("protected_copy.json")
	_write_json(protected_copy, start.to_dict())
	assert(editor.call("_read_map", protected_copy) == null)
	assert(not editor.call("_write_map_data", start, source_path))
	assert(not editor.call("_write_map_data", source, path))
	assert(SavedMapLibrary.load_all(maps_dir).size() == 1)
	var session: GameSession = GameSession.start_for_party(start, ["volcha"])
	assert(session != null and session.set_campaign(campaign))
	assert(not session.is_map_in_campaign(SOURCE_ID))
	var personal_session: GameSession = GameSession.start_for(source)
	assert(personal_session != null and not personal_session.is_map_in_campaign(start.map_id))
	var store := ProgressSaveStore.new(root_dir.path_join("saves"), library.directory)
	assert(store.save_game(session, maps))
	var restored: GameSession = store.load_game(SavedMapLibrary.load_for_game(maps_dir))
	assert(restored != null and restored.campaign_id == CAMPAIGN_ID)
	assert(restored.map_data.map_id == start.map_id)
	assert(FileAccess.get_file_as_string(path) == original)
	editor.free()
	assert(DirAccess.remove_absolute(source_path) == OK)
	assert(DirAccess.remove_absolute(protected_copy) == OK)
	assert(DirAccess.remove_absolute(maps_dir) == OK)
	assert(DirAccess.remove_absolute(store.directory.path_join(ProgressSaveStore.SAVE_FILE)) == OK)
	assert(DirAccess.remove_absolute(store.directory) == OK)
	assert(DirAccess.remove_absolute(root_dir) == OK)


func _test_linked_chapters() -> void:
	var directory: String = "user://official_link_test_%d" % Time.get_ticks_usec()
	var maps_dir: String = directory.path_join("maps")
	assert(DirAccess.make_dir_recursive_absolute(maps_dir) == OK)
	var first: DungeonMap = DungeonMap.create_blank(9, 9)
	first.map_id = "chapter_one"
	assert(first.place_entity("player_spawn", 2, 2))
	assert(first.place_entity("stairs_down", 3, 2))
	var second: DungeonMap = DungeonMap.create_blank(9, 9)
	second.map_id = "chapter_two"
	assert(second.place_entity("player_spawn", 2, 2))
	for entity in first.entities_at(3, 2):
		if DungeonMap.is_exit(entity):
			assert(first.set_exit_target(str(entity["id"]), second.map_id))
	var definition: CampaignDefinition = CampaignDefinition.create("Две главы", first.map_id)
	definition.campaign_id = "official_test"
	assert(definition.add_map(second.map_id))
	_write_json(directory.path_join("index.json"), {"schema_version": 1, "campaigns": [definition.to_dict()]})
	_write_json(maps_dir.path_join(first.map_id + ".json"), first.to_dict())
	_write_json(maps_dir.path_join(second.map_id + ".json"), second.to_dict())
	var maps: Dictionary = OfficialCampaignLibrary.load_maps(directory)
	var campaigns: Dictionary = OfficialCampaignLibrary.load_campaigns(maps, directory)
	assert(maps.size() == 2 and campaigns.size() == 1)
	var campaign: CampaignDefinition = campaigns[definition.campaign_id]
	var start: DungeonMap = maps[campaign.start_map_id]
	var destination: DungeonMap = maps[OfficialCampaignLibrary.ID_PREFIX + second.map_id]
	var session: GameSession = GameSession.start_for(start)
	assert(session != null and session.set_campaign(campaign))
	assert(session.move_by(1, 0) and session.is_completed)
	assert(session.next_map_id() == destination.map_id)
	assert(session.can_enter_next_map(destination))
	assert(not session.can_enter_next_map(second))
	assert(session.enter_map(destination))
	assert(session.map_data.map_id == destination.map_id)
	assert(DirAccess.remove_absolute(maps_dir.path_join(first.map_id + ".json")) == OK)
	assert(DirAccess.remove_absolute(maps_dir.path_join(second.map_id + ".json")) == OK)
	assert(DirAccess.remove_absolute(maps_dir) == OK)
	assert(DirAccess.remove_absolute(directory.path_join("index.json")) == OK)
	assert(DirAccess.remove_absolute(directory) == OK)


func _write_json(path: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value))
	file.close()
