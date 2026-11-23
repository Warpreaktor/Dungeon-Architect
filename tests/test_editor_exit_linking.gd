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
	var path: String = "user://da_501_test_map_%d.json" % Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(destination.to_dict()))
	file.close()
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	editor.queue_free()
	print("Editor exits: spawn arrival, JSON and undo/redo OK")
	quit()
