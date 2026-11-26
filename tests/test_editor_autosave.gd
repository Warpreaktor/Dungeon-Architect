extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _point(canvas: DungeonCanvas, cell: Vector2i) -> Vector2:
	return canvas.camera_offset + (Vector2(cell) + Vector2(0.5, 0.5)) * DungeonCanvas.TILE_SIZE * canvas.zoom


func _touch(canvas: DungeonCanvas, cell: Vector2i, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = pressed
	event.position = _point(canvas, cell)
	canvas._gui_input(event)


func _drag(canvas: DungeonCanvas, cell: Vector2i) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = _point(canvas, cell)
	canvas._gui_input(event)


func _click(canvas: DungeonCanvas, cell: Vector2i) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = _point(canvas, cell)
		canvas._gui_input(event)


func _assert_saved(editor: Node, path: String, dungeon: DungeonMap) -> void:
	assert(not editor.get("is_dirty"))
	assert(FileAccess.file_exists(path))
	assert(not FileAccess.file_exists(path + ".tmp"))
	assert(JSON.parse_string(FileAccess.get_file_as_string(path)) == JSON.parse_string(JSON.stringify(dungeon.to_dict())))


func _run() -> void:
	var storage = preload("res://tests/editor_test_storage.gd").new()
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	storage.configure(editor)
	root.add_child(editor)
	await process_frame
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 1, 1))
	editor.call("_set_map", dungeon)
	await process_frame
	var canvas: DungeonCanvas = editor.get("_canvas")
	canvas.camera_offset = Vector2.ZERO
	canvas.zoom = 1.0
	var path: String = storage.directory.path_join(dungeon.map_id + ".json")
	assert(not FileAccess.file_exists(path))
	editor.call("_set_tool", "wall")
	_touch(canvas, Vector2i(2, 2), true)
	_drag(canvas, Vector2i(3, 2))
	_drag(canvas, Vector2i(4, 2))
	assert(not FileAccess.file_exists(path) and editor.get("_undo_stack").is_empty())
	_touch(canvas, Vector2i(4, 2), false)
	_assert_saved(editor, path, dungeon)
	assert(editor.get("_undo_stack").size() == 1)
	for x in range(2, 5):
		assert(dungeon.get_terrain(x, 2) == "wall")
	var painted: String = FileAccess.get_file_as_string(path)
	_click(canvas, Vector2i(3, 2))
	assert(editor.get("_undo_stack").size() == 1)
	assert(FileAccess.get_file_as_string(path) == painted)
	editor.call("_undo_edit")
	_assert_saved(editor, path, dungeon)
	for x in range(2, 5):
		assert(dungeon.get_terrain(x, 2) == "floor")
	assert(editor.get("_redo_stack").size() == 1)
	editor.call("_save_internal")
	assert(editor.get("_redo_stack").size() == 1)
	editor.call("_redo_edit")
	_assert_saved(editor, path, dungeon)
	assert(FileAccess.get_file_as_string(path) == painted)
	# An aborted write must leave the previous JSON readable.
	assert(DirAccess.make_dir_absolute(path + ".tmp") == OK)
	_click(canvas, Vector2i(5, 2))
	assert(editor.get("is_dirty") and editor.get("_undo_stack").size() == 2)
	assert(FileAccess.get_file_as_string(path) == painted)
	assert(DirAccess.remove_absolute(path + ".tmp") == OK)
	editor.call("_save_internal")
	_assert_saved(editor, path, dungeon)
	assert(editor.get("_undo_stack").size() == 2)
	editor.call("_undo_edit")
	_assert_saved(editor, path, dungeon)
	assert(FileAccess.get_file_as_string(path) == painted)
	# A new edit after Undo invalidates Redo, but saving alone does not.
	editor.call("_on_message_saved", Vector2i(3, 3), "Авторское сообщение")
	_assert_saved(editor, path, dungeon)
	assert(editor.get("_redo_stack").is_empty())
	assert(dungeon.message_at(3, 3).get("properties", {}).get("text", "") == "Авторское сообщение")
	var before_name: String = FileAccess.get_file_as_string(path)
	editor.call("_on_name_changed", "Новое")
	editor.call("_on_name_changed", "Новое имя")
	assert(FileAccess.get_file_as_string(path) == before_name)
	var timer: Timer = editor.get("_name_autosave_timer")
	await timer.timeout
	_assert_saved(editor, path, dungeon)
	assert(dungeon.display_name == "Новое имя")
	var before_test: String = FileAccess.get_file_as_string(path)
	editor.call("_start_play_mode")
	var session: GameSession = editor.get("game_session")
	assert(session != null and session.is_editor_test)
	assert(session.map_data.set_terrain(6, 6, "wall"))
	editor.call("_autosave_map")
	assert(FileAccess.get_file_as_string(path) == before_test)
	editor.call("_stop_play_mode", false)
	_assert_saved(editor, path, dungeon)
	editor.call("_load_from_path", path)
	assert(not (editor.get("_unsaved_dialog") as ConfirmationDialog).visible)
	assert(editor.get("_undo_stack").is_empty() and editor.get("_redo_stack").is_empty())
	editor.call("_create_new_map", 8, 8)
	var created: DungeonMap = editor.get("map_data")
	_assert_saved(editor, storage.directory.path_join(created.map_id + ".json"), created)
	assert(FileAccess.get_file_as_string(path) == before_test)
	editor.queue_free()
	await process_frame
	storage.cleanup()
	print("Editor autosave: strokes, history, write failure, name and test isolation OK")
	quit()
