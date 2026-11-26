extends SceneTree

const TRAP_ID := "stone_slab"
const CENTER := Vector2i(3, 3)


func _initialize() -> void:
	_test_geometry()
	_test_existing_trap()
	_test_discovery_and_disarm()
	call_deferred("_test_editor")


func _corridor(axis: Vector2i) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(7, 7)
	for y in range(dungeon.height):
		for x in range(dungeon.width):
			dungeon.set_terrain(x, y, "wall")
	for offset in range(-2, 3):
		var cell: Vector2i = CENTER + axis * offset
		assert(dungeon.set_terrain(cell.x, cell.y, "floor"))
	var start: Vector2i = CENTER - axis
	assert(dungeon.place_entity("player_spawn", start.x, start.y))
	return dungeon


func _place(dungeon: DungeonMap, cell: Vector2i = CENTER) -> bool:
	return dungeon.place_entity("trap", cell.x, cell.y, {"trap_id": TRAP_ID})


func _test_geometry() -> void:
	var definition: TrapDefinition = TrapCatalog.get_trap(TRAP_ID)
	assert(TrapCatalog.has(TRAP_ID) and TRAP_ID in TrapCatalog.list_ids("floor"))
	assert(TRAP_ID not in TrapCatalog.list_ids("door"))
	assert(definition.icon != null and definition.placement_constraint == "narrow_passage")
	assert(definition.avoidance_stat == "agility" and definition.direct_damage > 0)
	assert(definition.disarm_on_trigger and not definition.blocks_path and definition.hidden_by_default)
	for axis in [Vector2i.RIGHT, Vector2i.DOWN]:
		var dungeon: DungeonMap = _corridor(axis)
		assert(dungeon.narrow_passage_axis(CENTER) == axis)
		assert(_place(dungeon))
		assert(not _place(dungeon, CENTER + axis * 2))
		assert(not _place(dungeon, CENTER + Vector2i(1, 1)))
		var trap: Dictionary = dungeon.entities_at(CENTER.x, CENTER.y)[0]
		assert(DungeonMap.is_entity_hidden(trap))
		assert(trap["properties"] == {"trap_id": TRAP_ID})
		var restored: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(dungeon.to_dict())))
		assert(restored != null and restored.narrow_passage_axis(CENTER) == axis)
		assert(restored.entities_at(CENTER.x, CENTER.y)[0]["id"] == trap["id"])
	var open_room: DungeonMap = DungeonMap.create_blank(7, 7)
	assert(not _place(open_room))
	assert(open_room.place_entity("trap", CENTER.x, CENTER.y, {"trap_id": "spikes"}))
	for side in [Vector2i.UP, Vector2i.DOWN]:
		var dungeon: DungeonMap = _corridor(Vector2i.RIGHT)
		dungeon.set_terrain(CENTER.x + side.x, CENTER.y + side.y, "floor")
		assert(not _place(dungeon))
		dungeon.set_terrain(CENTER.x - 1, CENTER.y, "wall")
		assert(not _place(dungeon))
		dungeon.set_terrain(CENTER.x - side.x, CENTER.y - side.y, "floor")
		dungeon.set_terrain(CENTER.x - 1, CENTER.y, "floor")
		assert(not _place(dungeon))


func _has_geometry_issue(dungeon: DungeonMap, cell: Vector2i) -> bool:
	for issue in DungeonDiagnostics.analyze(dungeon, DungeonReachability.analyze(dungeon)):
		if issue["cell"] == cell and str(issue["message"]).contains(TrapCatalog.get_trap(TRAP_ID).display_name):
			return true
	return false


func _test_existing_trap() -> void:
	var dungeon: DungeonMap = _corridor(Vector2i.RIGHT)
	assert(_place(dungeon))
	var trap: Dictionary = dungeon.entities_at(CENTER.x, CENTER.y)[0]
	var entity_id: String = trap["id"]
	assert(not _has_geometry_issue(dungeon, CENTER))
	var invalid: Vector2i = CENTER + Vector2i(2, 0)
	var before: Dictionary = dungeon.to_dict().duplicate(true)
	assert(not dungeon.move_existing("trap", entity_id, CENTER, invalid))
	assert(dungeon.to_dict() == before)
	var valid: Vector2i = CENTER + Vector2i.RIGHT
	assert(dungeon.move_existing("trap", entity_id, CENTER, valid))
	assert(dungeon.entities_at(valid.x, valid.y)[0]["id"] == entity_id)
	assert(dungeon.set_terrain(valid.x, valid.y - 1, "floor"))
	assert(_has_geometry_issue(dungeon, valid))
	assert(dungeon.set_terrain(valid.x, valid.y, "wall"))
	assert(dungeon.entities_at(valid.x, valid.y)[0]["id"] == entity_id)
	assert(_has_geometry_issue(dungeon, valid))
	var restored: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(dungeon.to_dict())))
	assert(restored != null and _has_geometry_issue(restored, valid))
	assert(restored.entities_at(valid.x, valid.y)[0]["id"] == entity_id)
	assert(restored.set_terrain(valid.x, valid.y, "floor"))
	assert(restored.set_terrain(valid.x, valid.y - 1, "wall"))
	assert(not _has_geometry_issue(restored, valid))


func _test_discovery_and_disarm() -> void:
	var dungeon: DungeonMap = _corridor(Vector2i.RIGHT)
	assert(_place(dungeon))
	var trap: Dictionary = dungeon.entities_at(CENTER.x, CENTER.y)[0]
	var definition: TrapDefinition = TrapCatalog.from_entity(trap)
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	session.party[0].perception = 0
	session.party[1].perception = definition.detection_difficulty
	for member in session.party:
		member.agility = definition.disarm_difficulty
	var rng_before: int = session.trap_random.state
	assert(not session.move_by(1, 0) and session.last_move_detected_trap)
	assert(session.player_pos == CENTER - Vector2i.RIGHT and session.trap_state(trap) == "armed")
	assert(not session.is_trap_known_by(trap, session.party[0]) and session.is_trap_known_by(trap, session.party[1]))
	assert(session.trap_random.state == rng_before)
	assert(not session.move_by(1, 0) and session.has_pending_trap_choice())
	assert(not session.resolve_pending_trap_choice("cancel"))
	assert(session.trap_random.state == rng_before)
	for seed_value in range(100):
		session.trap_random.seed = seed_value
		if session.trap_random.randi_range(1, definition.check_die_sides) > 1:
			session.trap_random.seed = seed_value
			break
	assert(not session.move_by(1, 0) and session.has_pending_trap_choice())
	assert(not session.resolve_pending_trap_choice("disarm", 1))
	assert(session.trap_state(trap) == "disarmed")
	assert(session.move_by(1, 0) and session.player_pos == CENTER)


func _click(canvas: DungeonCanvas, cell: Vector2i, touch: bool = false) -> void:
	var point: Vector2 = canvas.camera_offset + (Vector2(cell) + Vector2(0.5, 0.5)) * DungeonCanvas.TILE_SIZE * canvas.zoom
	for pressed in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = point
			event.pressed = pressed
			canvas._gui_input(event)
		else:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = point
			event.pressed = pressed
			canvas._gui_input(event)


func _test_editor() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	var storage = preload("res://tests/editor_test_storage.gd").new()
	storage.configure(editor)
	root.add_child(editor)
	await process_frame
	var dungeon: DungeonMap = _corridor(Vector2i.RIGHT)
	editor.call("_set_map", dungeon)
	var canvas: DungeonCanvas = editor.get("_canvas")
	var buttons: Dictionary = editor.get("_palette_buttons")
	var tool: Button = buttons["trap:" + TRAP_ID]
	assert(tool.icon == TrapCatalog.get_trap(TRAP_ID).icon)
	tool.pressed.emit()
	canvas.camera_offset = Vector2.ZERO
	canvas.zoom = 1.0
	var before: Dictionary = canvas.capture_edit_state()
	_click(canvas, CENTER + Vector2i(0, 1))
	assert(canvas.capture_edit_state() == before)
	assert(editor.get("_undo_stack").is_empty())
	var notice: GameNotice = editor.get("_game_notice")
	assert(notice.visible and notice._panel.visible)
	assert(notice._label.text == "Установите ловушку в узком проходе")
	_click(canvas, CENTER, true)
	assert(dungeon.entities_at(CENTER.x, CENTER.y).size() == 1)
	assert(editor.get("_undo_stack").size() == 1)
	var after: Dictionary = canvas.capture_edit_state()
	editor.call("_undo_edit")
	assert(canvas.capture_edit_state() == before)
	editor.call("_redo_edit")
	assert(canvas.capture_edit_state() == after)
	editor.queue_free()
	await process_frame
	storage.cleanup()
	quit()
