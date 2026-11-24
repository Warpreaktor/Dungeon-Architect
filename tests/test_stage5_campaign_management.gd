extends SceneTree

var _dir: String
var _maps_dir: String
var _campaign_dir: String


func _initialize() -> void:
	call_deferred("_run")


func _make_map(id: String) -> DungeonMap:
	var result: DungeonMap = DungeonMap.create_blank(8, 8)
	result.map_id = id
	assert(result.place_entity("player_spawn", 1, 1))
	return result


func _write_map(map: DungeonMap) -> void:
	var path: String = _maps_dir.path_join(map.map_id + ".json")
	var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(writer != null)
	writer.store_string(JSON.stringify(map.to_dict()))
	writer = null


func _run() -> void:
	_dir = "user://da_513_manager_%d" % Time.get_ticks_usec()
	_maps_dir = _dir.path_join("maps")
	_campaign_dir = _dir.path_join("campaigns")
	assert(DirAccess.make_dir_recursive_absolute(_maps_dir) == OK)
	var maps: Dictionary = {}
	for id in ["first", "second", "third", "free", "other"]:
		maps[id] = _make_map(id)
	var first: DungeonMap = maps["first"]
	assert(first.place_entity("stairs_down", 2, 1))
	for entity in first.entities:
		if DungeonMap.is_exit(entity):
			assert(first.set_exit_target(str(entity["id"]), "second"))
	for map_id in maps:
		_write_map(maps[map_id])
	var library := CampaignLibrary.new(_campaign_dir)
	var campaign: CampaignDefinition = library.create_campaign("Башня", "first", maps)
	assert(campaign != null)
	assert(library.attach_map(campaign.campaign_id, "second", maps))
	assert(library.attach_map(campaign.campaign_id, "third", maps))
	assert(library.detach_map(campaign.campaign_id, "first", maps) == false)
	assert(library.detach_map(campaign.campaign_id, "second", maps) == false)
	assert(library.detach_map(campaign.campaign_id, "third", maps))
	assert(library.attach_map(campaign.campaign_id, "third", maps))
	var other: CampaignDefinition = library.create_campaign("Другая", "other", maps)
	assert(other != null)
	assert(not library.attach_map(campaign.campaign_id, "other", maps))
	var editor: Control = load("res://scenes/editor.tscn").instantiate() as Control
	editor.set("_editor_maps_directory", _maps_dir)
	editor.set("_campaign_library", library)
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.call("_set_map", first)
	editor.call("_open_campaign_manager")
	assert((editor.get("_campaign_dialog") as AcceptDialog).visible)
	var name_input: LineEdit = editor.get("_campaign_title_input")
	name_input.text = "Башня мага"
	editor.call("_rename_campaign")
	assert(library.load_campaign(campaign.campaign_id, maps).display_name == "Башня мага")
	var available: OptionButton = editor.get("_campaign_available_choice")
	assert(available.item_count == 1)
	editor.call("_attach_campaign_map")
	assert(library.load_campaign(campaign.campaign_id, maps).map_ids.has("free"))
	var start: OptionButton = editor.get("_campaign_start_choice")
	var member_list: ItemList = editor.get("_campaign_list")
	member_list.select(0)
	editor.call("_request_campaign_detach")
	assert(editor.get("_campaign_pending_remove") == "")
	assert(library.load_campaign(campaign.campaign_id, maps).map_ids.has("first"))
	start.select(1)
	editor.call("_set_campaign_start")
	assert(library.load_campaign(campaign.campaign_id, maps).start_map_id == "second")
	member_list.select(1)
	editor.call("_request_campaign_detach")
	assert(editor.get("_campaign_pending_remove") == "")
	member_list.select(2)
	editor.call("_request_campaign_detach")
	assert(editor.get("_campaign_pending_remove") == "third")
	editor.call("_confirm_campaign_detach")
	assert(not library.load_campaign(campaign.campaign_id, maps).map_ids.has("third"))
	editor.call("_request_campaign_delete")
	editor.call("_confirm_campaign_delete")
	assert(library.load_campaign(campaign.campaign_id, maps) == null)
	assert(library.load_campaign(other.campaign_id, maps) != null)
	assert(SavedMapLibrary.load_all(_maps_dir).size() == 5)
	assert(DungeonMap.exit_target_id((SavedMapLibrary.load_all(_maps_dir)["first"] as DungeonMap).entities_at(2, 1)[0]) == "second")
	editor.queue_free()
	await process_frame
	_cleanup(_dir)
	print("DA-5.13: управление кампанией, исключение, сохранность карт OK")
	quit()


func _cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for filename in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(filename))
	for child in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(child))
	DirAccess.remove_absolute(path)
