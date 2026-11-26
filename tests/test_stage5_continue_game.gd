extends SceneTree

var _root_dir: String


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_root_dir = "user://da_506_%d" % Time.get_ticks_usec()
	var maps_dir: String = _root_dir.path_join("maps")
	var saves_dir: String = _root_dir.path_join("saves")
	assert(DirAccess.make_dir_recursive_absolute(maps_dir) == OK)
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	dungeon.map_id = "resume_test_floor"
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var original_map: String = JSON.stringify(dungeon.to_dict())
	var writer: FileAccess = FileAccess.open(maps_dir.path_join(dungeon.map_id + ".json"), FileAccess.WRITE)
	assert(writer != null)
	writer.store_string(original_map)
	writer = null
	var maps: Dictionary = SavedMapLibrary.load_all(maps_dir)
	assert(maps.size() == 1 and maps.has(dungeon.map_id))
	var store := ProgressSaveStore.new(saves_dir)
	var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate() as MainMenu
	menu._maps_directory = maps_dir
	menu._save_store = store
	menu._campaign_library = CampaignLibrary.new(_root_dir.path_join("campaigns"))
	root.add_child(menu)
	await process_frame
	assert(menu._home.visible and not menu._play_actions.visible)
	assert(menu._home.get_child_count() == 2)
	assert(not menu._continue_game_button.is_visible_in_tree())
	var editor_requests: Array[bool] = []
	menu.editor_requested.connect(func() -> void: editor_requests.append(true))
	(menu.get_node("%EditorButton") as Button).pressed.emit()
	assert(editor_requests.size() == 1)
	(menu.get_node("%PlayButton") as Button).pressed.emit()
	assert(not menu._home.visible and menu._play_actions.visible)
	assert(not menu._continue_game_button.visible)
	(menu.get_node("%CampaignButton") as Button).pressed.emit()
	assert(menu._library.visible and not menu._play_actions.visible)
	assert(menu._library_mode == MainMenu.LIBRARY_CAMPAIGNS)
	(menu.get_node("%BackButton") as Button).pressed.emit()
	assert(menu._play_actions.visible and not menu._library.visible)
	(menu.get_node("%PersonalMapsButton") as Button).pressed.emit()
	assert(menu._library.visible and not menu._play_actions.visible)
	assert(menu._library_mode == MainMenu.LIBRARY_PERSONAL)
	assert(menu._map_list.item_count == 1)
	menu._start_button.pressed.emit()
	assert(menu._hero_selection.visible and not menu._library.visible)
	assert(not menu.get_node("SafeArea").visible)
	menu._hero_selection.back_requested.emit()
	assert(menu._library.visible and not menu._hero_selection.visible)
	assert(menu.get_node("SafeArea").visible)
	(menu.get_node("%BackButton") as Button).pressed.emit()
	assert(menu._play_actions.visible and not menu._library.visible)
	(menu.get_node("%PlayBackButton") as Button).pressed.emit()
	assert(menu._home.visible and not menu._play_actions.visible)
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	assert(session != null)
	session.steps = 19
	session.party[1].health -= 5
	assert(session._receive_item("shield", 2, [4, 12]) == 2)
	assert(store.save_game(session, maps))
	(menu.get_node("%PlayButton") as Button).pressed.emit()
	assert(menu._continue_game_button.visible and not menu._continue_game_button.disabled)
	var resumed: Array[GameSession] = []
	menu.continue_game_requested.connect(func(game: GameSession) -> void: resumed.append(game))
	menu._continue_game_button.pressed.emit()
	assert(resumed.size() == 1)
	assert(resumed[0] != session and resumed[0].steps == 19)
	assert(resumed[0].party.size() == 2 and resumed[0].party[1].health == session.party[1].health)
	assert(resumed[0].inventory_slot_ids() == session.inventory_slot_ids())
	var new_game: GameSession = GameSession.start_for(dungeon)
	assert(new_game != resumed[0] and new_game.steps == 0)
	assert(store.load_game(maps).steps == 19)
	menu.queue_free()
	await process_frame

	var game: Control = load("res://scenes/editor.tscn").instantiate() as Control
	game.call("configure_for_resume", resumed[0])
	game.set("_progress_save_store", store)
	game.set("_progress_maps_directory", maps_dir)
	root.add_child(game)
	await process_frame
	assert(game.get("standalone_game"))
	assert(game.get("game_session") == resumed[0])
	var game_session: GameSession = game.get("game_session") as GameSession
	assert(game_session.steps == 19)
	game.call("_open_game_system_menu")
	var system_menu: GameSystemMenu = game.get("_game_system_menu") as GameSystemMenu
	assert(system_menu._save_button.visible and not system_menu._save_button.disabled)
	game.set("_combat_active", true)
	assert(not game.call("_can_save_progress"))
	game.set("_combat_active", false)
	game_session.steps = 27
	system_menu.save_requested.emit()
	assert(not system_menu.visible)
	assert(store.load_game(maps).steps == 27)
	game.set("_progress_maps_directory", _root_dir.path_join("missing"))
	game.call("_open_game_system_menu")
	system_menu.save_requested.emit()
	assert(system_menu._save_error.visible)
	assert(store.load_game(maps).steps == 27)
	game.queue_free()
	await process_frame

	var test_editor: Control = load("res://scenes/editor.tscn").instantiate() as Control
	test_editor.set("_progress_save_store", store)
	test_editor.set("_progress_maps_directory", maps_dir)
	root.add_child(test_editor)
	await process_frame
	test_editor.call("_set_map", dungeon)
	test_editor.call("_start_play_mode")
	assert(not test_editor.get("standalone_game"))
	test_editor.call("_open_game_system_menu")
	var test_menu: GameSystemMenu = test_editor.get("_game_system_menu") as GameSystemMenu
	assert(not test_menu._save_button.visible)
	test_editor.call("_save_progress")
	assert(store.load_game(maps).steps == 27)
	test_editor.queue_free()
	await process_frame

	var primary_path: String = saves_dir.path_join(ProgressSaveStore.SAVE_FILE)
	var broken: FileAccess = FileAccess.open(primary_path, FileAccess.WRITE)
	assert(broken != null)
	broken.store_string("invalid JSON")
	broken = null
	var restored_backup: GameSession = store.load_game(maps)
	assert(restored_backup != null and restored_backup.steps == 19)
	var backup_menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate() as MainMenu
	backup_menu._maps_directory = maps_dir
	backup_menu._save_store = store
	root.add_child(backup_menu)
	await process_frame
	assert(not backup_menu._continue_game_button.is_visible_in_tree())
	(backup_menu.get_node("%PlayButton") as Button).pressed.emit()
	assert(backup_menu._continue_game_button.is_visible_in_tree())
	backup_menu.queue_free()
	await process_frame
	var broken_backup: FileAccess = FileAccess.open(saves_dir.path_join(ProgressSaveStore.BACKUP_FILE), FileAccess.WRITE)
	assert(broken_backup != null)
	broken_backup.store_string("invalid backup")
	broken_backup = null
	var invalid_menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate() as MainMenu
	invalid_menu._maps_directory = maps_dir
	invalid_menu._save_store = store
	root.add_child(invalid_menu)
	await process_frame
	(invalid_menu.get_node("%PlayButton") as Button).pressed.emit()
	assert(not invalid_menu._continue_game_button.is_visible_in_tree())
	invalid_menu.queue_free()
	await process_frame
	assert(FileAccess.get_file_as_string(maps_dir.path_join(dungeon.map_id + ".json")) == original_map)
	_cleanup(saves_dir, [ProgressSaveStore.SAVE_FILE, ProgressSaveStore.BACKUP_FILE, ProgressSaveStore.TEMP_FILE])
	_cleanup(maps_dir, [dungeon.map_id + ".json"])
	DirAccess.remove_absolute(_root_dir)
	print("Stage 5: main-menu continuation, in-game save, test isolation, backup and unchanged map OK")
	quit()


func _cleanup(directory: String, names: Array[String]) -> void:
	for filename in names:
		var path: String = directory.path_join(filename)
		if FileAccess.file_exists(path):
			assert(DirAccess.remove_absolute(path) == OK)
	assert(DirAccess.remove_absolute(directory) == OK)
