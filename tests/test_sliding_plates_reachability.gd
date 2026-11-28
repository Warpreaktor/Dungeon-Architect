extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_configurations()
	_test_spent_keys()
	_test_scope()
	await _test_editor_files()
	print("Sliding plates: reachability in both configurations, scope and import checks OK")
	quit()


func _safe_map() -> DungeonMap:
	var data := DungeonMap.create_blank(9, 9)
	assert(data.place_entity("player_spawn", 1, 1))
	assert(data.place_entity(SlidingPlates.TRIGGER, 2, 2))
	assert(data.place_entity("stairs_down", 7, 7))
	assert(data.cycle_sliding_plates_mark(Vector2i(4, 4)).is_empty())
	assert(data.cycle_sliding_plates_mark(Vector2i(5, 5)).is_empty())
	return data


func _corridor() -> DungeonMap:
	var data := DungeonMap.create_blank(9, 7)
	for y in range(data.height):
		for x in range(data.width):
			data.set_terrain(x, y, "wall")
	for x in range(1, 8):
		assert(data.set_terrain(x, 2, "floor"))
	assert(data.place_entity("player_spawn", 1, 2))
	assert(data.place_entity(SlidingPlates.TRIGGER, 2, 2))
	assert(data.place_entity("stairs_down", 7, 2))
	return data


func _toggle_wall(data: DungeonMap, cell: Vector2i) -> void:
	for index in range(SlidingPlates.MARK_CYCLE.size()):
		assert(data.cycle_sliding_plates_mark(cell).is_empty())
		for mark in data.sliding_plates_marks():
			if SlidingPlates.mark_cell(mark) == cell and mark["operation"] == SlidingPlates.TOGGLE:
				return
	assert(false)



func _has_issue(issues: Array[Dictionary], fragment: String, cell: Vector2i = Vector2i(-1, -1)) -> bool:
	for issue in issues:
		if str(issue["message"]).contains(fragment) and (cell == Vector2i(-1, -1) or issue["cell"] == cell):
			return true
	return false


func _test_configurations() -> void:
	var safe := _safe_map()
	var snapshot: String = JSON.stringify(safe.to_dict())
	assert(SlidingPlatesDiagnostics.analyze_map(safe).is_empty())
	assert(JSON.stringify(safe.to_dict()) == snapshot)
	assert(not safe.sliding_plates_is_shifted())
	var blocked := _corridor()
	assert(blocked.cycle_sliding_plates_mark(Vector2i(4, 2)).is_empty())
	_toggle_wall(blocked, Vector2i(1, 5))
	var issues: Array[Dictionary] = SlidingPlatesDiagnostics.analyze_map(blocked)
	assert(_has_issue(issues, "Положение Б: выход", Vector2i(7, 2)))
	assert(_has_issue(DungeonDiagnostics.analyze(blocked, DungeonReachability.analyze(blocked)), "Положение Б: выход"))
	assert(blocked.place_entity("portal_local", 3, 2, {"color": "blue"}))
	assert(blocked.place_entity("portal_local", 5, 2, {"color": "blue"}))
	assert(SlidingPlatesDiagnostics.analyze_map(blocked).is_empty())

	var island := _corridor()
	for y in range(3, 6):
		assert(island.set_terrain(4, y, "floor"))
	assert(island.cycle_sliding_plates_mark(Vector2i(4, 3)).is_empty())
	_toggle_wall(island, Vector2i(1, 5))
	issues = SlidingPlatesDiagnostics.analyze_map(island)
	assert(_has_issue(issues, "Положение Б: участок отрезан"))
	assert(not _has_issue(issues, "Положение Б: выход"))

	var reverse := _corridor()
	assert(reverse.set_terrain(4, 4, "floor"))
	assert(reverse.set_terrain(4, 5, "floor"))
	_toggle_wall(reverse, Vector2i(4, 3))
	_toggle_wall(reverse, Vector2i(1, 5))
	assert(_has_issue(SlidingPlatesDiagnostics.analyze_map(reverse), "Положение А: участок отрезан"))


func _test_spent_keys() -> void:
	var data := _corridor()
	for x in range(4, 7):
		assert(data.set_terrain(x, 1, "floor"))
	for cell in [Vector2i(1, 3), Vector2i(2, 3), Vector2i(2, 4)]:
		assert(data.set_terrain(cell.x, cell.y, "floor"))
	assert(data.place_entity("key", 1, 3))
	assert(data.place_entity("door", 2, 3))
	assert(data.place_entity("door", 5, 2))
	assert(data.cycle_sliding_plates_mark(Vector2i(5, 1)).is_empty())
	_toggle_wall(data, Vector2i(7, 5))
	var issues: Array[Dictionary] = SlidingPlatesDiagnostics.analyze_map(data)
	assert(_has_issue(issues, "Переключение А → Б", Vector2i(2, 2)))
	assert(not _has_issue(issues, "Положение Б: выход"))


func _link(source: DungeonMap, target: DungeonMap) -> void:
	var cell: Vector2i = source.find_entity_position("stairs_down")
	assert(source.set_exit_target(str(source.entities_at(cell.x, cell.y)[0]["id"]), target.map_id))


func _test_scope() -> void:
	var a := _safe_map()
	var b := _safe_map()
	var bridge := DungeonMap.create_blank(9, 9)
	assert(bridge.place_entity("player_spawn", 1, 1))
	assert(bridge.place_entity("stairs_down", 7, 7))
	var maps := {a.map_id: a, b.map_id: b, bridge.map_id: bridge}
	assert(SlidingPlatesDiagnostics.launch_error(a.map_id, maps, {}).is_empty())
	var membership: CampaignDefinition = CampaignDefinition.create("Общие этажи", a.map_id)
	assert(membership.add_map(b.map_id))
	var campaigns := {membership.campaign_id: membership}
	assert(not SlidingPlatesDiagnostics.launch_error(a.map_id, maps, campaigns).is_empty())
	_link(a, bridge)
	_link(bridge, b)
	var ids: Array[String] = SlidingPlatesDiagnostics.scope_ids(b.map_id, maps, {})
	assert(ids.size() == 3)
	assert(not SlidingPlatesDiagnostics.duplicate_error(ids, maps).is_empty())
	assert(not SlidingPlatesDiagnostics.launch_error(bridge.map_id, maps, {}).is_empty())
	var separate := _safe_map()
	maps[separate.map_id] = separate
	assert(SlidingPlatesDiagnostics.launch_error(separate.map_id, maps, {}).is_empty())
	var directory: String = "user://da_sliding_campaign_%d" % Time.get_ticks_usec()
	var library := CampaignLibrary.new(directory)
	var campaign: CampaignDefinition = library.create_campaign("Раздельные этажи", separate.map_id, maps)
	assert(campaign != null)
	assert(not library.attach_map(campaign.campaign_id, a.map_id, maps))
	assert(library.load_campaign(campaign.campaign_id, maps).map_ids == [separate.map_id])
	for filename in DirAccess.get_files_at(directory):
		assert(DirAccess.remove_absolute(directory.path_join(filename)) == OK)
	assert(DirAccess.remove_absolute(directory) == OK)


func _test_editor_files() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	var storage = preload("res://tests/editor_test_storage.gd").new()
	storage.configure(editor)
	editor.set("_campaign_library", CampaignLibrary.new(storage.directory + "_campaigns"))
	root.add_child(editor)
	await process_frame
	var a := _safe_map()
	var b := _safe_map()
	assert(editor.call("_ensure_maps_dir"))
	var a_path: String = storage.directory.path_join(a.map_id + ".json")
	var b_path: String = storage.directory.path_join(b.map_id + ".json")
	assert(editor.call("_write_saved_map", a, a_path))
	assert(editor.call("_write_saved_map", b, b_path))
	editor.call("_set_map", a)
	var original: String = FileAccess.get_file_as_string(a_path)
	var copy: DungeonMap = DungeonMap.from_dict(a.to_dict())
	copy.map_id = "copied_floor"
	_link(copy, a)
	var copy_path: String = storage.directory.path_join(copy.map_id + ".json")
	assert(not editor.call("_write_saved_map", copy, copy_path))
	assert(not FileAccess.file_exists(copy_path))
	var imported: DungeonMap = DungeonMap.from_dict(b.to_dict())
	_link(imported, a)
	var import_path: String = "user://da_sliding_import_%d.json" % Time.get_ticks_usec()
	var file: FileAccess = FileAccess.open(import_path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(imported.to_dict()))
	file.close()
	editor.call("_load_from_path_confirmed", import_path)
	assert(editor.get("map_data") == a)
	assert(FileAccess.get_file_as_string(a_path) == original)
	var blocked := _corridor()
	assert(blocked.cycle_sliding_plates_mark(Vector2i(4, 2)).is_empty())
	_toggle_wall(blocked, Vector2i(1, 5))
	editor.call("_set_map", blocked)
	editor.call("_start_play_mode")
	assert(not editor.get("is_play_mode"))
	assert(editor.get("_reachability_enabled"))
	assert(DirAccess.remove_absolute(import_path) == OK)
	editor.queue_free()
	await process_frame
	storage.cleanup()
