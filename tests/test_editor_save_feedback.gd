extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings_path := "user://editor_state.cfg"
	var had_settings := FileAccess.file_exists(settings_path)
	var original_settings := FileAccess.get_file_as_bytes(settings_path) if had_settings else PackedByteArray()
	var maps_dir := "user://da_save_feedback_%d" % Time.get_ticks_usec()
	var editor: Control = load("res://scenes/editor.tscn").instantiate() as Control
	editor.set("_editor_maps_directory", maps_dir)
	root.add_child(editor)
	await process_frame
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	editor.call("_set_map", dungeon)
	var button: Button = editor.get("_save_button") as Button
	var timer: Timer = editor.get("_save_feedback_timer") as Timer
	var normal_icon: Texture2D = button.icon
	var normal_text: String = button.text
	var path: String = maps_dir.path_join(dungeon.map_id + ".json")
	editor.call("_mark_dirty")
	button.pressed.emit()
	assert(FileAccess.file_exists(path))
	assert(not editor.get("is_dirty") and not timer.is_stopped())
	assert(button.icon != normal_icon and button.self_modulate != Color.WHITE)
	assert(button.text == ("Сохранено" if not normal_text.is_empty() else ""))
	editor.call("_apply_editor_panels")
	assert(button.text == ("Сохранено" if not normal_text.is_empty() else ""))
	button.pressed.emit()
	assert(not timer.is_stopped() and timer.time_left > 0.0)
	await timer.timeout
	assert(timer.is_stopped() and button.icon == normal_icon and button.text == normal_text)
	assert(button.self_modulate == Color.WHITE)

	button.pressed.emit()
	editor.call("_mark_dirty")
	assert(timer.is_stopped() and button.icon == normal_icon)
	assert(editor.get("is_dirty"))
	button.pressed.emit()
	editor.call("_set_map", DungeonMap.create_blank(8, 8))
	assert(timer.is_stopped() and button.icon == normal_icon)

	var current: DungeonMap = editor.get("map_data") as DungeonMap
	var blocked_path: String = maps_dir.path_join(current.map_id + ".json")
	assert(DirAccess.make_dir_recursive_absolute(blocked_path) == OK)
	editor.call("_mark_dirty")
	button.pressed.emit()
	assert(editor.get("is_dirty"))
	assert(timer.is_stopped() and button.icon == normal_icon)
	editor.queue_free()
	await process_frame
	DirAccess.remove_absolute(blocked_path)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(maps_dir)
	if had_settings:
		var file := FileAccess.open(settings_path, FileAccess.WRITE)
		assert(file != null)
		file.store_buffer(original_settings)
		file.close()
	elif FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)
	print("Editor save feedback: success, repeated save, reset and failure OK")
	quit()
