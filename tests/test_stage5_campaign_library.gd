extends SceneTree

var _directory: String


func _initialize() -> void:
	_directory = "user://da_510_campaigns_%d" % Time.get_ticks_usec()
	_test_creation_and_editing()
	_test_invalid_links_and_ownership()
	_test_backup_and_incomplete_write()
	_cleanup(_directory)
	print("DA-5.10: campaign library, map ownership, file recovery and source maps OK")
	quit()


func _map(map_id: String) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	dungeon.map_id = map_id
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return dungeon


func _maps() -> Dictionary:
	var result: Dictionary = {}
	for map_id in ["da510_first", "da510_second", "da510_third", "da510_fourth"]:
		result[map_id] = _map(map_id)
	return result


func _write(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file = null


func _test_creation_and_editing() -> void:
	var maps: Dictionary = _maps()
	var source: Dictionary = {}
	for map_id in maps:
		source[map_id] = JSON.stringify(maps[map_id].to_dict())
	var library := CampaignLibrary.new(_directory)
	assert(library.load_all(maps).is_empty())
	var campaign: CampaignDefinition = library.create_campaign("Башня мага", "da510_first", maps)
	assert(campaign != null)
	assert(campaign.campaign_id.begins_with("campaign_"))
	assert(campaign.map_ids == ["da510_first"])
	assert(library.load_campaign(campaign.campaign_id, maps).start_map_id == "da510_first")
	var first_id: String = campaign.campaign_id
	assert(campaign.rename("Башня архимага"))
	assert(campaign.add_map("da510_second"))
	assert(campaign.add_map("da510_third"))
	assert(not campaign.add_map("da510_second"))
	assert(campaign.set_start_map("da510_second"))
	assert(campaign.remove_map("da510_first"))
	assert(not campaign.remove_map("da510_second"))
	assert(library.save_campaign(campaign, maps))
	var another_reader := CampaignLibrary.new(_directory)
	var loaded: CampaignDefinition = another_reader.load_campaign(first_id, maps)
	assert(loaded != null)
	assert(loaded.campaign_id == first_id)
	assert(loaded.display_name == "Башня архимага")
	assert(loaded.start_map_id == "da510_second")
	assert(loaded.map_ids == ["da510_second", "da510_third"])
	assert(another_reader.campaign_for_map("da510_second", maps).campaign_id == first_id)
	assert(another_reader.campaign_for_map("da510_first", maps) == null)
	assert(loaded.to_dict() == JSON.parse_string(JSON.stringify(loaded.to_dict())))
	for map_id in maps:
		assert(JSON.stringify(maps[map_id].to_dict()) == source[map_id])


func _test_invalid_links_and_ownership() -> void:
	var maps: Dictionary = _maps()
	var library := CampaignLibrary.new(_directory)
	var loaded: Dictionary = library.load_all(maps)
	assert(loaded.size() == 1)
	var campaign: CampaignDefinition = loaded.values()[0]
	var other: CampaignDefinition = library.create_campaign("Другое приключение", "da510_first", maps)
	assert(other != null)
	assert(not other.add_map("da510_first"))
	assert(other.add_map("da510_third"))
	assert(not library.save_campaign(other, maps))
	assert(not library.last_error.is_empty())
	assert(library.load_campaign(other.campaign_id, maps).map_ids == ["da510_first"])
	var invalid: CampaignDefinition = CampaignDefinition.create("Ошибочный", "missing_map")
	assert(invalid != null)
	assert(not library.save_campaign(invalid, maps))
	assert(not library.create_campaign("Тоже ошибочный", "missing_map", maps))
	var snapshot: Dictionary = campaign.to_dict()
	assert(CampaignDefinition.from_dict(JSON.parse_string(JSON.stringify(snapshot))) != null)
	snapshot["map_ids"].append("da510_third")
	assert(CampaignDefinition.from_dict(snapshot) == null)
	snapshot = campaign.to_dict()
	snapshot["schema_version"] = 900
	assert(CampaignDefinition.from_dict(snapshot) == null)
	snapshot = campaign.to_dict()
	snapshot["campaign_id"] = "../outside"
	assert(CampaignDefinition.from_dict(snapshot) == null)
	snapshot = campaign.to_dict()
	snapshot["map_ids"] = ["da510_second", 12]
	assert(CampaignDefinition.from_dict(snapshot) == null)
	assert(library.load_all({"da510_first": maps["da510_first"]}).is_empty())
	assert(not library.last_error.is_empty())
	assert(library.load_all(maps).size() == 2)


func _test_backup_and_incomplete_write() -> void:
	var maps: Dictionary = _maps()
	var library := CampaignLibrary.new(_directory)
	var campaign: CampaignDefinition = library.campaign_for_map("da510_second", maps)
	assert(campaign != null)
	var main_path: String = _directory.path_join(campaign.campaign_id + CampaignLibrary.FILE_SUFFIX)
	var backup_path: String = _directory.path_join(campaign.campaign_id + CampaignLibrary.BACKUP_SUFFIX)
	var temp_path: String = _directory.path_join(campaign.campaign_id + CampaignLibrary.TEMP_SUFFIX)
	var original: String = FileAccess.get_file_as_string(main_path)
	assert(campaign.rename("Башня архимага после обновления"))
	assert(library.save_campaign(campaign, maps))
	assert(FileAccess.file_exists(backup_path))
	assert(FileAccess.get_file_as_string(backup_path) == original)
	_write(temp_path, "incomplete write")
	assert(library.load_campaign(campaign.campaign_id, maps).display_name == "Башня архимага после обновления")
	_write(main_path, "broken JSON")
	assert(library.load_campaign(campaign.campaign_id, maps).display_name == "Башня архимага")
	assert(campaign.rename("После восстановления"))
	assert(library.save_campaign(campaign, maps))
	assert(library.load_campaign(campaign.campaign_id, maps).display_name == "После восстановления")
	assert(FileAccess.get_file_as_string(backup_path) == original)
	_write(main_path, "invalid")
	_write(backup_path, "also invalid")
	var broken_main: String = FileAccess.get_file_as_string(main_path)
	assert(not library.save_campaign(campaign, maps))
	assert(FileAccess.get_file_as_string(main_path) == broken_main)
	assert(not library.last_error.is_empty())
	var bad_directory: String = _directory.path_join("not_a_directory")
	_write(bad_directory, "ordinary file")
	var failed := CampaignLibrary.new(bad_directory)
	assert(failed.create_campaign("Ошибка записи", "da510_fourth", maps) == null)
	assert(not failed.last_error.is_empty())


func _cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for filename in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(filename))
	for child in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(child))
	DirAccess.remove_absolute(path)
