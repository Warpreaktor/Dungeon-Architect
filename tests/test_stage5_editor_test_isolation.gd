extends SceneTree

var _root_directory: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_root_directory = "user://da_507_%d" % Time.get_ticks_usec()
	var maps_dir: String = _root_directory.path_join("maps")
	var saves_dir: String = _root_directory.path_join("saves")
	assert(DirAccess.make_dir_recursive_absolute(maps_dir) == OK)

	var first: DungeonMap = DungeonMap.create_blank(8, 8)
	first.map_id = "test_isolation_first"
	assert(first.place_entity("player_spawn", 1, 2))
	assert(first.place_entity("chest", 3, 3))
	assert(first.place_entity("monster", 2, 2, {"monster_id": "skeleton"}))
	assert(first.place_entity("stairs_down", 4, 2))
	var second: DungeonMap = DungeonMap.create_blank(8, 8)
	second.map_id = "test_isolation_second"
	assert(second.place_entity("player_spawn", 2, 2))
	var first_stairs: Dictionary = first.entities_at(4, 2)[0]
	assert(first.set_exit_target(str(first_stairs["id"]), second.map_id))
	var first_json: String = JSON.stringify(first.to_dict())
	var second_json: String = JSON.stringify(second.to_dict())
	_write_map(maps_dir, first)
	_write_map(maps_dir, second)
	var maps: Dictionary = SavedMapLibrary.load_all(maps_dir)
	assert(maps.size() == 2)

	var store := ProgressSaveStore.new(saves_dir)
	var real_game: GameSession = GameSession.start_for(first)
	real_game.steps = 74
	assert(store.save_game(real_game, maps))
	var save_path: String = saves_dir.path_join(ProgressSaveStore.SAVE_FILE)
	var save_bytes: String = FileAccess.get_file_as_string(save_path)

	var editor: Control = load("res://scenes/editor.tscn").instantiate() as Control
	editor.set("_progress_save_store", store)
	editor.set("_progress_maps_directory", maps_dir)
	root.add_child(editor)
	await process_frame
	await process_frame
	editor.call("_set_map", first)
	editor.call("_on_canvas_edited")
	var unsaved: bool = bool(editor.get("is_dirty"))
	var canvas: DungeonCanvas = editor.get("_canvas") as DungeonCanvas
	canvas.zoom = 1.4
	canvas.camera_offset = Vector2(65, -24)
	var original_zoom: float = canvas.zoom
	var original_offset: Vector2 = canvas.camera_offset

	editor.call("_start_play_mode")
	var trial: GameSession = editor.get("game_session") as GameSession
	assert(trial != null and trial.is_editor_test)
	assert(trial.map_data != first)
	assert(trial.map_data.map_id == first.map_id)
	assert(trial.steps == 0 and trial.party.size() >= 1)
	assert(trial.progress_snapshot().is_empty())
	assert(not store.save_game(trial, maps))
	assert(FileAccess.get_file_as_string(save_path) == save_bytes)
	assert(not editor.call("_can_save_progress"))
	editor.call("_open_game_system_menu")
	var test_menu: GameSystemMenu = editor.get("_game_system_menu") as GameSystemMenu
	assert(not test_menu._save_button.visible)
	assert(test_menu._open_map_button.visible)
	editor.call("_save_progress")
	assert(test_menu._save_error.visible)
	editor.call("_close_game_system_menu")

	trial.map_data.entities[0]["properties"]["test_only"] = true
	assert(trial.map_data.set_terrain(5, 5, "wall"))
	assert(JSON.stringify(first.to_dict()) == first_json)
	editor.call("_set_test_open_map", true)
	assert(trial.debug_open_map)
	assert(trial.enter_map(maps[second.map_id]))
	assert(trial.is_editor_test and trial.map_data.map_id == second.map_id)
	assert(trial.map_data != maps[second.map_id])
	trial.map_data.entities[0]["properties"]["visited_by_test"] = true
	assert(JSON.stringify(second.to_dict()) == second_json)
	assert(trial.progress_snapshot().is_empty())
	assert(not store.save_game(trial, maps))
	assert(FileAccess.get_file_as_string(save_path) == save_bytes)
	editor.call("_stop_play_mode", false)
	assert(not editor.get("is_play_mode"))
	assert(editor.get("game_session") == null)
	assert(editor.get("map_data") == first and canvas.map_data == first)
	assert(canvas.mode == "edit")
	assert(canvas.zoom == original_zoom and canvas.camera_offset == original_offset)
	assert(bool(editor.get("is_dirty")) == unsaved)
	assert(JSON.stringify(first.to_dict()) == first_json)
	assert(JSON.stringify(second.to_dict()) == second_json)
	assert(FileAccess.get_file_as_string(save_path) == save_bytes)

	editor.call("_start_play_mode")
	var replay: GameSession = editor.get("game_session") as GameSession
	assert(replay != null and replay.is_editor_test and replay != trial)
	assert(replay.steps == 0 and replay.map_data.get_terrain(5, 5) == "floor")
	assert(not replay.debug_open_map)
	assert(replay.map_data.entities[0]["properties"].get("test_only") == null)
	assert(not replay.move_by(1, 0))
	assert(replay.has_pending_encounter())
	editor.call("_start_combat")
	assert(editor.get("_combat_active"))
	editor.call("_open_game_system_menu")
	editor.call("_leave_from_game_system_menu")
	assert(not editor.get("is_play_mode") and not editor.get("_combat_active"))
	assert(editor.get("_battle_view") == null and editor.get("game_session") == null)
	assert(canvas.map_data == first and canvas.mode == "edit")
	assert(JSON.stringify(first.to_dict()) == first_json)
	assert(FileAccess.get_file_as_string(save_path) == save_bytes)

	editor.set("is_dirty", false)
	editor.call("_start_play_mode")
	var returned: Array[bool] = []
	editor.connect("menu_requested", func() -> void: returned.append(true))
	editor.call("_request_return_to_menu")
	assert(returned.size() == 1)
	assert(editor.get("game_session") == null and not editor.get("is_play_mode"))
	editor.queue_free()
	await process_frame

	var gameplay: Control = load("res://scenes/editor.tscn").instantiate() as Control
	gameplay.call("configure_for_game", maps[first.map_id])
	root.add_child(gameplay)
	await process_frame
	var live_session: GameSession = gameplay.get("game_session") as GameSession
	assert(live_session != null and not live_session.is_editor_test)
	gameplay.call("_open_game_system_menu")
	var game_menu: GameSystemMenu = gameplay.get("_game_system_menu") as GameSystemMenu
	assert(game_menu._save_button.visible)
	assert(not game_menu._open_map_button.visible)
	gameplay.call("_set_test_open_map", true)
	assert(not live_session.debug_open_map)
	gameplay.queue_free()
	await process_frame

	assert(store.load_game(maps).steps == 74)
	assert(FileAccess.get_file_as_string(maps_dir.path_join(first.map_id + ".json")) == first_json)
	assert(FileAccess.get_file_as_string(maps_dir.path_join(second.map_id + ".json")) == second_json)
	_cleanup(saves_dir, [ProgressSaveStore.SAVE_FILE, ProgressSaveStore.BACKUP_FILE, ProgressSaveStore.TEMP_FILE])
	_cleanup(maps_dir, [first.map_id + ".json", second.map_id + ".json"])
	assert(DirAccess.remove_absolute(_root_directory) == OK)
	print("Stage 5 editor test isolation: maps, save, battles, floors and exits OK")
	quit()


func _write_map(directory: String, map_ref: DungeonMap) -> void:
	var file: FileAccess = FileAccess.open(directory.path_join(map_ref.map_id + ".json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(map_ref.to_dict()))
	file = null


func _cleanup(directory: String, filenames: Array[String]) -> void:
	for filename in filenames:
		var path: String = directory.path_join(filename)
		if FileAccess.file_exists(path):
			assert(DirAccess.remove_absolute(path) == OK)
	assert(DirAccess.remove_absolute(directory) == OK)
