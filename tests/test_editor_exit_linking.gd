extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _exit_at(dungeon: DungeonMap, position: Vector2i) -> Dictionary:
	for entity in dungeon.entities_at(position.x, position.y):
		if DungeonMap.is_exit(entity):
			return entity
	return {}


func _run() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	var first: DungeonMap = DungeonMap.create_blank(7, 7)
	var destination: DungeonMap = DungeonMap.create_blank(7, 7)
	assert(first.place_entity("player_spawn", 1, 1))
	assert(first.place_entity("portal", 2, 1))
	assert(destination.place_entity("player_spawn", 4, 4))
	var entity: Dictionary = _exit_at(first, Vector2i(2, 1))
	var entity_id: String = str(entity["id"])
	var directory: String = "user://da_511_old_link_%d" % Time.get_ticks_usec()
	var maps_dir: String = directory.path_join("maps")
	var campaigns_dir: String = directory.path_join("campaigns")
	assert(DirAccess.make_dir_recursive_absolute(maps_dir) == OK)
	var path: String = maps_dir.path_join(destination.map_id + ".json")
	for dungeon in [first, destination]:
		var map_file: FileAccess = FileAccess.open(maps_dir.path_join(dungeon.map_id + ".json"), FileAccess.WRITE)
		assert(map_file != null)
		map_file.store_string(JSON.stringify(dungeon.to_dict()))
		map_file = null
	var campaigns := CampaignLibrary.new(campaigns_dir)
	assert(campaigns.create_campaign("Исходная кампания", first.map_id, SavedMapLibrary.load_all(maps_dir)) != null)
	editor.set("_campaign_library", campaigns)
	editor.set("_editor_maps_directory", maps_dir)
	editor.call("_set_map", first)
	await process_frame
	editor.call("_on_exit_tapped", entity_id)
	var list: ItemList = editor.get("_load_list") as ItemList
	list.clear()
	list.add_item(destination.display_name)
	list.select(0)
	var paths: Array[String] = [path]
	editor.set("_load_paths", paths)
	editor.call("_link_selected_exit")
	assert(DungeonMap.exit_target_id(entity) == destination.map_id)
	assert(DungeonMap.exit_target_cell(entity, destination) == Vector2i(4, 4))
	assert(editor.get("_undo_stack").size() == 1)
	editor.call("_undo_edit")
	assert(DungeonMap.exit_target_id(entity).is_empty())
	editor.call("_redo_edit")
	assert(DungeonMap.exit_target_cell(entity, destination) == Vector2i(4, 4))
	var json: String = JSON.stringify(first.to_dict())
	var clone: DungeonMap = DungeonMap.from_dict(JSON.parse_string(json))
	assert(clone != null)
	assert(DungeonMap.exit_target_cell(_exit_at(clone, Vector2i(2, 1)), destination) == Vector2i(4, 4))
	editor.call("_on_exit_tapped", entity_id)
	editor.call("_unlink_selected_exit")
	assert(DungeonMap.exit_target_id(entity).is_empty())
	editor.call("_undo_edit")
	assert(DungeonMap.exit_target_id(entity) == destination.map_id)
	editor.queue_free()
	for filename in DirAccess.get_files_at(maps_dir):
		assert(DirAccess.remove_absolute(maps_dir.path_join(filename)) == OK)
	for filename in DirAccess.get_files_at(campaigns_dir):
		assert(DirAccess.remove_absolute(campaigns_dir.path_join(filename)) == OK)
	assert(DirAccess.remove_absolute(maps_dir) == OK)
	assert(DirAccess.remove_absolute(campaigns_dir) == OK)
	assert(DirAccess.remove_absolute(directory) == OK)
	print("Editor exits: spawn arrival, JSON and undo/redo OK")
	quit()
