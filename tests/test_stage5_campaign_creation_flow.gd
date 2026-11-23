extends SceneTree

var _directory: String
var _maps_dir: String
var _campaigns_dir: String


func _initialize() -> void:
	call_deferred("_run")


func _create_map(id: String, spawn: Vector2i) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	dungeon.map_id = id
	assert(dungeon.place_entity("player_spawn", spawn.x, spawn.y))
	return dungeon


func _write_map(dungeon: DungeonMap) -> void:
	var writer: FileAccess = FileAccess.open(_maps_dir.path_join(dungeon.map_id + ".json"), FileAccess.WRITE)
	assert(writer != null)
	writer.store_string(JSON.stringify(dungeon.to_dict()))
	writer = null


func _exit_id(dungeon: DungeonMap, at: Vector2i) -> String:
	for entity in dungeon.entities_at(at.x, at.y):
		if DungeonMap.is_exit(entity):
			return str(entity["id"])
	return ""


func _select_map(editor: Node, map_id: String) -> void:
	var list: ItemList = editor.get("_load_list") as ItemList
	var paths: Array[String] = editor.get("_load_paths")
	var path: String = _maps_dir.path_join(map_id + ".json")
	var index: int = paths.find(path)
	assert(index >= 0)
	list.select(index)


func _campaign_count(library: CampaignLibrary) -> int:
	return library.load_all(SavedMapLibrary.load_all(_maps_dir)).size()


func _run() -> void:
	var settings_path: String = "user://editor_state.cfg"
	var had_settings: bool = FileAccess.file_exists(settings_path)
	var original_settings: PackedByteArray = FileAccess.get_file_as_bytes(settings_path) if had_settings else PackedByteArray()
	_directory = "user://da_511_creation_%d" % Time.get_ticks_usec()
	_maps_dir = _directory.path_join("maps")
	_campaigns_dir = _directory.path_join("campaigns")
	assert(DirAccess.make_dir_recursive_absolute(_maps_dir) == OK)
	var source: DungeonMap = _create_map("da511_source", Vector2i(1, 1))
	var destination: DungeonMap = _create_map("da511_destination", Vector2i(3, 3))
	var extra: DungeonMap = _create_map("da511_extra", Vector2i(2, 3))
	assert(source.place_entity("stairs_down", 2, 1))
	var stairs_id: String = _exit_id(source, Vector2i(2, 1))
	assert(not stairs_id.is_empty())
	_write_map(destination)
	_write_map(extra)
	var library := CampaignLibrary.new(_campaigns_dir)
	var editor: Control = load("res://scenes/editor.tscn").instantiate() as Control
	editor.set("_editor_maps_directory", _maps_dir)
	editor.set("_campaign_library", library)
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.call("_set_map", source)
	editor.call("_on_canvas_edited")
	assert(not FileAccess.file_exists(_maps_dir.path_join(source.map_id + ".json")))

	editor.call("_on_exit_tapped", stairs_id)
	assert(not DirAccess.dir_exists_absolute(_campaigns_dir))
	assert((editor.get("_stairs_reward_button") as Button).visible)
	editor.call("_cancel_exit_link_selection")
	assert(not DirAccess.dir_exists_absolute(_campaigns_dir))

	editor.call("_on_exit_tapped", stairs_id)
	_select_map(editor, destination.map_id)
	editor.call("_link_selected_exit")
	assert(editor.get("_pending_campaign_destination_path") == _maps_dir.path_join(destination.map_id + ".json"))
	assert(not DirAccess.dir_exists_absolute(_campaigns_dir))
	editor.call("_cancel_campaign_creation")
	(editor.get("_campaign_creation_dialog") as ConfirmationDialog).hide()
	assert(editor.get("_linking_exit_id") == "")
	assert(not DirAccess.dir_exists_absolute(_campaigns_dir))
	assert(DungeonMap.exit_target_id(source.entities_at(2, 1)[0]).is_empty())

	editor.call("_on_exit_tapped", stairs_id)
	_select_map(editor, destination.map_id)
	editor.call("_link_selected_exit")
	var name_input: LineEdit = editor.get("_campaign_name_input") as LineEdit
	name_input.text = "  "
	editor.call("_confirm_campaign_creation")
	assert(not DirAccess.dir_exists_absolute(_campaigns_dir))
	assert(DungeonMap.exit_target_id(source.entities_at(2, 1)[0]).is_empty())
	name_input.text = "Пещеры архимага"
	editor.call("_confirm_campaign_creation")
	assert(_campaign_count(library) == 1)
	var campaign: CampaignDefinition = library.campaign_for_map(source.map_id, SavedMapLibrary.load_all(_maps_dir))
	assert(campaign != null)
	assert(campaign.display_name == "Пещеры архимага")
	assert(campaign.map_ids == [source.map_id])
	assert(campaign.start_map_id == source.map_id)
	assert(FileAccess.file_exists(_maps_dir.path_join(source.map_id + ".json")))
	var persisted_source: DungeonMap = DungeonMap.from_dict(JSON.parse_string(FileAccess.get_file_as_string(_maps_dir.path_join(source.map_id + ".json"))))
	assert(persisted_source != null and persisted_source.map_id == source.map_id)
	assert(DungeonMap.exit_target_id(source.entities_at(2, 1)[0]).is_empty())
	assert(editor.get("_pending_campaign_destination_path") == "")
	assert((editor.get("_load_dialog") as ConfirmationDialog).visible)
	assert(editor.call("_selected_library_path") == _maps_dir.path_join(destination.map_id + ".json"))
	editor.call("_link_selected_exit")
	assert(DungeonMap.exit_target_id(source.entities_at(2, 1)[0]) == destination.map_id)
	assert(editor.get("_undo_stack").size() == 1)
	editor.call("_undo_edit")
	assert(DungeonMap.exit_target_id(source.entities_at(2, 1)[0]).is_empty())
	editor.call("_redo_edit")
	assert(DungeonMap.exit_target_id(source.entities_at(2, 1)[0]) == destination.map_id)

	assert(source.place_entity("portal", 3, 1))
	editor.call("_on_canvas_edited")
	var portal_id: String = _exit_id(source, Vector2i(3, 1))
	editor.call("_on_exit_tapped", portal_id)
	_select_map(editor, extra.map_id)
	editor.call("_link_selected_exit")
	assert(DungeonMap.exit_target_id(source.entities_at(3, 1)[0]) == extra.map_id)
	assert(_campaign_count(library) == 1)
	assert(editor.get("_pending_campaign_destination_path") == "")
	assert(library.load_campaign(campaign.campaign_id, SavedMapLibrary.load_all(_maps_dir)).map_ids == [source.map_id])
	editor.call("_save_internal")
	var saved_source: DungeonMap = DungeonMap.from_dict(JSON.parse_string(FileAccess.get_file_as_string(_maps_dir.path_join(source.map_id + ".json"))))
	assert(saved_source != null)
	assert(DungeonMap.exit_target_id(saved_source.entities_at(2, 1)[0]) == destination.map_id)
	assert(DungeonMap.exit_target_id(saved_source.entities_at(3, 1)[0]) == extra.map_id)

	var independent: DungeonMap = _create_map("da511_portal_source", Vector2i(1, 1))
	assert(independent.place_entity("portal", 2, 1))
	editor.call("_set_map", independent)
	editor.call("_on_canvas_edited")
	var independent_portal: String = _exit_id(independent, Vector2i(2, 1))
	editor.call("_on_exit_tapped", independent_portal)
	_select_map(editor, extra.map_id)
	editor.call("_link_selected_exit")
	assert(_campaign_count(library) == 1)
	name_input.text = "Особая башня"
	editor.call("_confirm_campaign_creation")
	assert(_campaign_count(library) == 2)
	assert(editor.call("_selected_library_path") == _maps_dir.path_join(extra.map_id + ".json"))
	editor.call("_link_selected_exit")
	assert(DungeonMap.exit_target_id(independent.entities_at(2, 1)[0]) == extra.map_id)
	var other_campaign: CampaignDefinition = library.campaign_for_map(independent.map_id, SavedMapLibrary.load_all(_maps_dir))
	assert(other_campaign != null and other_campaign.start_map_id == independent.map_id)
	assert(library.campaign_for_map(source.map_id, SavedMapLibrary.load_all(_maps_dir)).campaign_id == campaign.campaign_id)

	editor.call("_save_internal")
	assert(DungeonMap.from_dict(JSON.parse_string(FileAccess.get_file_as_string(_maps_dir.path_join(independent.map_id + ".json")))) != null)
	editor.queue_free()
	await process_frame
	for filename in DirAccess.get_files_at(_maps_dir):
		assert(DirAccess.remove_absolute(_maps_dir.path_join(filename)) == OK)
	for filename in DirAccess.get_files_at(_campaigns_dir):
		assert(DirAccess.remove_absolute(_campaigns_dir.path_join(filename)) == OK)
	assert(DirAccess.remove_absolute(_maps_dir) == OK)
	assert(DirAccess.remove_absolute(_campaigns_dir) == OK)
	assert(DirAccess.remove_absolute(_directory) == OK)
	if had_settings:
		var settings_writer: FileAccess = FileAccess.open(settings_path, FileAccess.WRITE)
		assert(settings_writer != null)
		settings_writer.store_buffer(original_settings)
		settings_writer = null
	elif FileAccess.file_exists(settings_path):
		assert(DirAccess.remove_absolute(settings_path) == OK)
	print("DA-5.11: first campaign, cancel, resumed destination choice, saved map and repeat linking OK")
	quit()
