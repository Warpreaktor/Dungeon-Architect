extends SceneTree

var _root_dir: String
var _maps_dir: String
var _campaigns_dir: String


func _initialize() -> void:
	call_deferred("_run")


func _make_map(id: String) -> DungeonMap:
	var map_ref: DungeonMap = DungeonMap.create_blank(8, 8)
	map_ref.map_id = id
	assert(map_ref.place_entity("player_spawn", 1, 1))
	return map_ref


func _link(source: DungeonMap, target_id: String, cell: Vector2i) -> void:
	assert(source.place_entity("stairs_down", cell.x, cell.y))
	for entity in source.entities_at(cell.x, cell.y):
		if DungeonMap.is_exit(entity):
			assert(source.set_exit_target(str(entity["id"]), target_id))
			return
	assert(false)


func _write_map(map_ref: DungeonMap) -> void:
	var path: String = _maps_dir.path_join(map_ref.map_id + ".json")
	var writer: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(writer != null)
	writer.store_string(JSON.stringify(map_ref.to_dict()))
	writer = null


func _run() -> void:
	_root_dir = "user://da_514_legacy_%d" % Time.get_ticks_usec()
	_maps_dir = _root_dir.path_join("maps")
	_campaigns_dir = _root_dir.path_join("campaigns")
	assert(DirAccess.make_dir_recursive_absolute(_maps_dir) == OK)
	var maps: Dictionary = {}
	for id in ["floor_1", "floor_2", "floor_3", "branch", "single", "foreign", "another", "ui_free"]:
		maps[id] = _make_map(id)
	_link(maps["floor_1"], "floor_2", Vector2i(2, 1))
	_link(maps["floor_2"], "floor_3", Vector2i(2, 1))
	_link(maps["floor_2"], "branch", Vector2i(3, 1))
	_link(maps["floor_3"], "floor_1", Vector2i(3, 1))
	for id in maps:
		_write_map(maps[id])
	var saved_before: Dictionary = {}
	for id in maps:
		saved_before[id] = FileAccess.get_file_as_string(_maps_dir.path_join(id + ".json"))
	var save_path: String = _root_dir.path_join("old_progress.json")
	var save_file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	assert(save_file != null)
	save_file.store_string("{\"old_save\":true}")
	save_file = null
	var library := CampaignLibrary.new(_campaigns_dir)
	var discovered: Array[String] = library.legacy_linked_maps("floor_3", maps)
	assert(discovered == ["branch", "floor_1", "floor_2", "floor_3"])
	assert(library.legacy_linked_maps("single", maps) == ["single"])
	assert(library.assemble_legacy_campaign("Incomplete", "floor_1", ["floor_1", "floor_2"], maps) == null)
	assert(not DirAccess.dir_exists_absolute(_campaigns_dir))
	var selected: Array[String] = ["floor_1", "floor_2", "floor_3", "branch"]
	var campaign: CampaignDefinition = library.assemble_legacy_campaign("Старые этажи", "floor_2", selected, maps)
	assert(campaign != null)
	assert(campaign.start_map_id == "floor_2")
	assert(campaign.map_ids.size() == 4)
	assert(library.assemble_legacy_campaign("Wrong", "single", ["floor_1", "single"], maps) == null)
	var other: CampaignDefinition = library.create_campaign("Чужая", "foreign", maps)
	assert(other != null)
	assert(library.assemble_legacy_campaign("Invalid", "single", ["single", "foreign"], maps) == null)
	assert(library.assemble_legacy_campaign("Invalid", "foreign", ["foreign"], maps, campaign.campaign_id) == null)
	var expanded: CampaignDefinition = library.assemble_legacy_campaign("", campaign.start_map_id, ["single"], maps, campaign.campaign_id)
	assert(expanded != null and expanded.map_ids.has("single"))
	assert(library.load_campaign(campaign.campaign_id, maps).start_map_id == "floor_2")
	var free: CampaignDefinition = library.assemble_legacy_campaign("Отдельная", "another", ["another"], maps)
	assert(free != null)
	for id in saved_before:
		assert(FileAccess.get_file_as_string(_maps_dir.path_join(id + ".json")) == saved_before[id])
	assert(FileAccess.get_file_as_string(save_path) == "{\"old_save\":true}")
	var editor: Control = load("res://scenes/editor.tscn").instantiate() as Control
	editor.set("_editor_maps_directory", _maps_dir)
	editor.set("_campaign_library", library)
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.call("_set_map", maps["ui_free"])
	editor.call("_open_campaign_manager")
	assert((editor.get("_legacy_campaign_dialog") as ConfirmationDialog).visible)
	assert((editor.get("_legacy_campaign_start") as OptionButton).item_count == 1)
	(editor.get("_legacy_campaign_dialog") as ConfirmationDialog).hide()
	assert(library.campaign_for_map("ui_free", maps) == null)
	editor.call("_open_campaign_manager")
	(editor.get("_legacy_campaign_name") as LineEdit).text = "Новая карта"
	editor.call("_confirm_legacy_campaign")
	assert(library.campaign_for_map("ui_free", maps) != null)
	assert(FileAccess.get_file_as_string(_maps_dir.path_join("ui_free.json")) == saved_before["ui_free"])
	editor.queue_free()
	await process_frame
	_cleanup(_root_dir)
	print("DA-5.14: старые связи, выбор старта, защита кампаний и сохранений OK")
	quit()


func _cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for filename in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(filename))
	for child in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(child))
	DirAccess.remove_absolute(path)
