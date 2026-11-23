extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _door_at(map: DungeonMap, x: int, y: int) -> Dictionary:
	for entity in map.entities_at(x, y):
		if str(entity.get("type", "")) == "door":
			return entity
	return {}


func _click(canvas: DungeonCanvas, cell: Vector2i) -> void:
	var position: Vector2 = canvas.camera_offset + (Vector2(cell) + Vector2(0.5, 0.5)) * DungeonCanvas.TILE_SIZE * canvas.zoom
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		canvas._gui_input(event)


func _touch(canvas: DungeonCanvas, cell: Vector2i) -> void:
	var position: Vector2 = canvas.camera_offset + (Vector2(cell) + Vector2(0.5, 0.5)) * DungeonCanvas.TILE_SIZE * canvas.zoom
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = position
		canvas._gui_input(event)


func _run() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame

	var buttons: Dictionary = editor.get("_palette_buttons")
	assert(buttons.has("trap:door_crossbow"))
	var tool_button: Button = buttons["trap:door_crossbow"]
	assert(tool_button.icon == TrapCatalog.get_trap("door_crossbow").icon)
	var map := DungeonMap.create_blank(7, 7)
	assert(map.place_entity("door", 2, 2))
	assert(map.place_entity("door", 3, 2))
	assert(map.set_message_at(2, 2, "Текст двери"))
	var first_id: String = str(_door_at(map, 2, 2)["id"])
	var second_id: String = str(_door_at(map, 3, 2)["id"])
	var canvas: DungeonCanvas = editor.get("_canvas") as DungeonCanvas
	editor.call("_set_map", map)
	await process_frame
	await process_frame
	canvas.camera_offset = Vector2.ZERO
	canvas.zoom = 1.0
	canvas.set_selected_tool("hand")
	assert(str(canvas._configurable_at(Vector2i(2, 2)).get("type", "")) == "door")

	tool_button.pressed.emit()
	assert(str(editor.get("selected_tool")) == "trap:door_crossbow")
	_click(canvas, Vector2i(2, 2))
	assert(DungeonMap.door_trap_id(_door_at(map, 2, 2)) == "door_crossbow")
	assert(str(editor.get("selected_tool")) == "trap:door_crossbow")
	_touch(canvas, Vector2i(3, 2))
	assert(DungeonMap.door_trap_id(_door_at(map, 3, 2)) == "door_crossbow")
	var history: Array = editor.get("_undo_stack")
	assert(history.size() == 2)
	_click(canvas, Vector2i(3, 2))
	_click(canvas, Vector2i(1, 1))
	history = editor.get("_undo_stack")
	assert(history.size() == 2)

	editor.call("_undo_edit")
	assert(DungeonMap.door_trap_id(_door_at(map, 3, 2)).is_empty())
	assert(DungeonMap.door_trap_id(_door_at(map, 2, 2)) == "door_crossbow")
	editor.call("_redo_edit")
	assert(DungeonMap.door_trap_id(_door_at(map, 3, 2)) == "door_crossbow")

	editor.call("_set_tool", "hand")
	editor.call("_on_door_tapped", first_id)
	var popup: DoorPropertiesPopup = editor.get("_door_popup") as DoorPropertiesPopup
	var text_box: TextEdit = popup.get("_trap_message") as TextEdit
	assert(text_box.visible)
	assert(text_box.text.is_empty())
	assert(not text_box.placeholder_text.is_empty())
	text_box.text = "Осторожно!"
	popup.call("_save")
	assert(DungeonMap.door_trap_message(_door_at(map, 2, 2)) == "Осторожно!")
	history = editor.get("_undo_stack")
	assert(history.size() == 3)
	editor.call("_undo_edit")
	assert(DungeonMap.door_trap_message(_door_at(map, 2, 2)) == TrapCatalog.get_trap("door_crossbow").trigger_message)
	editor.call("_redo_edit")
	assert(DungeonMap.door_trap_message(_door_at(map, 2, 2)) == "Осторожно!")

	editor.call("_on_door_tapped", first_id)
	popup.call("_mark_trap_for_removal")
	popup.call("_save")
	assert(DungeonMap.door_trap_id(_door_at(map, 2, 2)).is_empty())
	assert(DungeonMap.door_trap_id(_door_at(map, 3, 2)) == "door_crossbow")
	assert(str(map.message_at(2, 2).get("properties", {}).get("text", "")) == "Текст двери")
	editor.call("_undo_edit")
	assert(DungeonMap.door_trap_id(_door_at(map, 2, 2)) == "door_crossbow")
	assert(DungeonMap.door_trap_message(_door_at(map, 2, 2)) == "Осторожно!")

	var loaded := DungeonMap.from_dict(JSON.parse_string(JSON.stringify(map.to_dict())))
	assert(loaded != null)
	assert(DungeonMap.door_trap_id(_door_at(loaded, 2, 2)) == "door_crossbow")
	assert(DungeonMap.door_trap_id(_door_at(loaded, 3, 2)) == "door_crossbow")
	assert(str(_door_at(loaded, 2, 2)["id"]) == first_id)
	assert(str(_door_at(loaded, 3, 2)["id"]) == second_id)
	var configured_json: String = JSON.stringify(map.to_dict())
	for i in range(3):
		editor.call("_undo_edit")
	assert(DungeonMap.door_trap_id(_door_at(map, 2, 2)).is_empty())
	assert(DungeonMap.door_trap_id(_door_at(map, 3, 2)).is_empty())
	assert(str(map.message_at(2, 2).get("properties", {}).get("text", "")) == "Текст двери")
	for i in range(3):
		editor.call("_redo_edit")
	assert(JSON.stringify(map.to_dict()) == configured_json)
	assert(DungeonMap.door_trap_message(_door_at(map, 2, 2)) == "Осторожно!")
	assert(DungeonMap.door_trap_id(_door_at(map, 3, 2)) == "door_crossbow")
	var restored: DungeonMap = DungeonMap.from_dict(JSON.parse_string(configured_json))
	assert(restored != null)
	assert(JSON.stringify(restored.to_dict()) == configured_json)
	editor.queue_free()
	print("Editor door crossbow: palette, attachment, properties and undo/redo OK")
	quit()
