extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_model()
	_test_wall_marks()
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


func _test_wall_marks() -> void:
	var data := DungeonMap.create_blank(9, 9)
	var wall := Vector2i(4, 4)
	assert(data.set_terrain(wall.x, wall.y, "wall"))
	assert(data.cycle_sliding_plates_mark(wall) == SlidingPlates.MARK_TRIGGER_ERROR)
	assert(data.place_entity(SlidingPlates.TRIGGER, 2, 2))
	var original: Array = data.terrain.duplicate(true)
	for operation in SlidingPlates.MARK_CYCLE:
		assert(data.cycle_sliding_plates_mark(wall).is_empty())
		var marks: Array = data.sliding_plates_marks()
		assert(marks.size() == 1 and marks[0]["operation"] == operation)
		var configuration: Dictionary = data.sliding_plates_configuration(marks)
		assert(configuration["error"].is_empty())
		assert(configuration["changes"][wall] == "floor")
		if operation != SlidingPlates.TOGGLE:
			assert(configuration["changes"].size() == 2)
			assert(configuration["changes"][wall + SlidingPlates.DIRECTIONS[operation]] == "wall")
		else:
			assert(configuration["changes"].size() == 1)
		assert(data.terrain == original)
	assert(data.cycle_sliding_plates_mark(wall).is_empty())
	assert(data.sliding_plates_marks()[0]["operation"] == "right")
	var target := Vector2i(5, 4)
	var before: String = JSON.stringify(data.to_dict())
	assert(data.cycle_sliding_plates_mark(target) == SlidingPlates.MARK_CONFLICT_ERROR)
	assert(not data.place_entity("chest", target.x, target.y))
	assert(not data.set_terrain(target.x, target.y, "wall"))
	assert(not data.move_existing("wall", "", wall, Vector2i(4, 5)))
	assert(data.cycle_sliding_plates_mark(Vector2i(2, 2)) == SlidingPlates.MARK_CELL_ERROR)
	assert(JSON.stringify(data.to_dict()) == before)
	var new_wall := Vector2i(6, 6)
	assert(data.cycle_sliding_plates_mark(new_wall).is_empty())
	var combined: Dictionary = data.sliding_plates_configuration(data.sliding_plates_marks())
	assert(combined["changes"].size() == 3 and combined["changes"][new_wall] == "wall")
	var reversed_marks: Array = data.sliding_plates_marks()
	reversed_marks.reverse()
	assert(data.sliding_plates_configuration(reversed_marks)["changes"] == combined["changes"])
	assert(data.terrain == original)
	var restored: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(data.to_dict())))
	assert(restored != null)
	assert(restored.sliding_plates_configuration(restored.sliding_plates_marks())["changes"] == combined["changes"])
	assert(restored.cycle_sliding_plates_mark(new_wall).is_empty())
	assert(restored.sliding_plates_marks().size() == 1)
	assert(restored.erase_at(wall.x, wall.y))
	assert(restored.get_terrain(wall.x, wall.y) == "wall")
	assert(restored.sliding_plates_marks().is_empty())
	var trigger_id: String = str(data.entities_at(2, 2)[0]["id"])
	assert(not data.move_existing(SlidingPlates.TRIGGER, trigger_id, Vector2i(2, 2), target))
	assert(data.move_existing(SlidingPlates.TRIGGER, trigger_id, Vector2i(2, 2), Vector2i(2, 3)))
	assert(data.sliding_plates_marks().size() == 2)
	assert(data.erase_at(2, 3))
	assert(data.sliding_plates_marks().is_empty())
	assert(data.terrain == original)

	var invalid := DungeonMap.create_blank(9, 9)
	assert(invalid.place_entity(SlidingPlates.TRIGGER, 2, 2))
	assert(invalid.set_terrain(4, 4, "wall"))
	assert(invalid.set_terrain(6, 4, "wall"))
	var left := {"x": 4, "y": 4, "operation": "right"}
	var right := {"x": 6, "y": 4, "operation": "left"}
	assert(invalid.sliding_plates_configuration([left, right])["error"] == SlidingPlates.MARK_CONFLICT_ERROR)
	assert(invalid.sliding_plates_configuration([left, left])["error"] == SlidingPlates.MARK_CONFLICT_ERROR)
	assert(invalid.sliding_plates_configuration([left, {"x": 5, "y": 4, "operation": SlidingPlates.TOGGLE}])["error"] == SlidingPlates.MARK_CONFLICT_ERROR)
	assert(invalid.sliding_plates_configuration([{"x": 0, "y": 4, "operation": "left"}])["error"] == SlidingPlates.MARK_TARGET_ERROR)
	assert(invalid.sliding_plates_configuration([{"x": 3, "y": 3, "operation": "right"}])["error"] == SlidingPlates.MARK_CELL_ERROR)
	assert(invalid.place_entity("chest", 5, 4))
	assert(invalid.sliding_plates_configuration([left])["error"] == SlidingPlates.MARK_TARGET_ERROR)
	assert(invalid.cycle_sliding_plates_mark(Vector2i(4, 4)).is_empty())
	assert(invalid.sliding_plates_marks()[0]["operation"] == "down")
	assert(invalid.cycle_sliding_plates_mark(Vector2i(5, 4)) == SlidingPlates.MARK_CELL_ERROR)
	var broken: Dictionary = invalid.to_dict().duplicate(true)
	for entity in broken["entities"]:
		if entity["type"] == SlidingPlates.TRIGGER:
			entity["properties"]["walls"] = [left, right]
	assert(DungeonMap.from_dict(broken) == null)


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
	assert(menu.get_item_icon(0) == FramedIcon.compose(SlidingPlates.TRIGGER_PLATE_ART))
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
	var wall_cell := Vector2i(4, 4)
	assert(data.set_terrain(wall_cell.x, wall_cell.y, "wall"))
	var wall_point: Vector2 = (Vector2(wall_cell) + Vector2.ONE * 0.5) * DungeonCanvas.TILE_SIZE
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = wall_point
	mouse.pressed = true
	canvas._gui_input(mouse)
	var motion := InputEventMouseMotion.new()
	motion.position = wall_point + Vector2(1, 0)
	canvas._gui_input(motion)
	mouse.pressed = false
	canvas._gui_input(mouse)
	assert(data.sliding_plates_marks()[0]["operation"] == "right")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = wall_point
	touch.pressed = true
	canvas._gui_input(touch)
	assert(data.sliding_plates_marks()[0]["operation"] == "right")
	touch.pressed = false
	canvas._gui_input(touch)
	assert(data.sliding_plates_marks()[0]["operation"] == "down")
	editor.call("_undo_edit")
	assert(data.sliding_plates_marks()[0]["operation"] == "right")
	editor.call("_redo_edit")
	assert(data.sliding_plates_marks()[0]["operation"] == "down")
	canvas.call("_edit_at", wall_point, true)
	canvas.call("_edit_at", wall_point, true)
	canvas.finish_edit_stroke()
	assert(data.sliding_plates_marks().is_empty())
	assert(data.get_terrain(wall_cell.x, wall_cell.y) == "wall")
	editor.call("_undo_edit")
	assert(data.sliding_plates_marks()[0]["operation"] == "down")
	buttons["hand"].pressed.emit()
	assert(canvas.selected_tool == "hand")
	editor.queue_free()
	await process_frame
	storage.cleanup()
