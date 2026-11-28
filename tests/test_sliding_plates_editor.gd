extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_model()
	await _test_editor()
	quit()


func _test_model() -> void:
	var data := DungeonMap.create_blank(8, 8)
	var kind: String = SlidingPlates.TRIGGER
	var before: String = JSON.stringify(data.to_dict())
	assert(not data.place_entity(kind, 0, 0))
	assert(not data.place_entity(kind, -1, 2))
	assert(JSON.stringify(data.to_dict()) == before)
	for occupied_kind in DungeonMap.ENTITY_TYPES:
		if occupied_kind == kind:
			continue
		var occupied := DungeonMap.create_blank(8, 8)
		assert(occupied.place_entity(occupied_kind, 2, 2, {"color": "blue"}))
		var snapshot: String = JSON.stringify(occupied.to_dict())
		assert(occupied.sliding_plates_trigger_error(Vector2i(2, 2)) == SlidingPlates.CELL_ERROR)
		assert(not occupied.place_entity(kind, 2, 2))
		assert(JSON.stringify(occupied.to_dict()) == snapshot)
	assert(data.place_entity(kind, 2, 2))
	var entity: Dictionary = data.entities_at(2, 2)[0]
	var id: String = str(entity["id"])
	assert(entity["properties"]["walls"].is_empty())
	assert(data.has_sliding_plates_trigger())
	assert(data.place_entity("chest", 3, 3))
	before = JSON.stringify(data.to_dict())
	assert(data.sliding_plates_trigger_error(Vector2i(4, 4)) == SlidingPlates.DUPLICATE_ERROR)
	assert(not data.place_entity(kind, 4, 4))
	assert(not data.place_entity("player_spawn", 2, 2))
	assert(not data.set_message_at(2, 2, "Message"))
	assert(not data.move_existing(kind, id, Vector2i(2, 2), Vector2i(3, 3)))
	assert(not data.move_existing(kind, id, Vector2i(2, 2), Vector2i(0, 0)))
	assert(JSON.stringify(data.to_dict()) == before)
	assert(data.move_existing(kind, id, Vector2i(2, 2), Vector2i(4, 4)))
	assert(data.entities_at(2, 2).is_empty())
	assert(data.entities_at(4, 4)[0]["id"] == id)
	var restored: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	assert(restored != null and restored.has_sliding_plates_trigger())
	assert(restored.entities_at(4, 4)[0]["id"] == id)
	var invalid: Dictionary = data.to_dict().duplicate(true)
	var duplicate: Dictionary = entity.duplicate(true)
	duplicate["id"] = "duplicate"
	duplicate["x"] = 5
	invalid["entities"].append(duplicate)
	assert(DungeonMap.from_dict(invalid) == null)
	var other := DungeonMap.create_blank(8, 8)
	var maps := {data.map_id: data, other.map_id: other}
	var related: Array[String] = [data.map_id, other.map_id]
	assert(DungeonMap.other_floor_has_sliding_plates(other.map_id, maps, related))
	assert(not DungeonMap.other_floor_has_sliding_plates(data.map_id, maps, related))
	assert(data.erase_at(4, 4))
	assert(not data.has_sliding_plates_trigger())
	assert(not DungeonMap.other_floor_has_sliding_plates(other.map_id, maps, related))
	assert(data.place_entity(kind, 5, 5))


func _test_editor() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	var storage = preload("res://tests/editor_test_storage.gd").new()
	storage.configure(editor)
	editor.set("_campaign_library", CampaignLibrary.new(storage.directory + "_campaigns"))
	root.add_child(editor)
	await process_frame
	var data := DungeonMap.create_blank(8, 8)
	editor.call("_set_map", data)
	await process_frame
	var canvas: DungeonCanvas = editor.get("_canvas")
	var buttons: Dictionary = editor.get("_palette_buttons")
	var button: Button = buttons[SlidingPlates.TOOL]
	var menu: PopupMenu = editor.get("_sliding_plates_menu")
	button.pressed.emit()
	assert(menu.visible)
	assert(menu.item_count == 2)
	menu.id_pressed.emit(0)
	menu.hide()
	assert(canvas.selected_tool == SlidingPlates.TRIGGER)
	canvas.camera_offset = Vector2.ZERO
	canvas.zoom = 1.0
	canvas.call("_edit_at", Vector2(120, 120), false)
	canvas.finish_edit_stroke()
	assert(data.has_sliding_plates_trigger())
	var id: String = str(data.entities_at(2, 2)[0]["id"])
	var history: Array = editor.get("_undo_stack")
	var count: int = history.size()
	canvas.call("_edit_at", Vector2(168, 168), false)
	canvas.finish_edit_stroke()
	assert(history.size() == count)
	editor.call("_undo_edit")
	assert(not data.has_sliding_plates_trigger())
	editor.call("_redo_edit")
	assert(data.entities_at(2, 2)[0]["id"] == id)
	button.pressed.emit()
	assert(menu.visible)
	menu.id_pressed.emit(1)
	menu.hide()
	assert(canvas.selected_tool == SlidingPlates.WALLS_TOOL)
	assert(editor.get("selected_tool") == SlidingPlates.WALLS_TOOL)
	buttons["hand"].pressed.emit()
	assert(canvas.selected_tool == "hand")
	editor.queue_free()
	await process_frame
	storage.cleanup()
