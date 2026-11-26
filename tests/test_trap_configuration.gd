extends SceneTree


func _initialize() -> void:
	_test_author_settings()
	_test_progress()
	_test_door_overrides()
	_test_repeatable_mechanism()
	call_deferred("_test_editor")


func _map(map_id: String) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	dungeon.map_id = map_id
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return dungeon


func _at(dungeon: DungeonMap, x: int, y: int) -> Dictionary:
	return dungeon.entities_at(x, y)[0]


func _json(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value))


func _test_author_settings() -> void:
	var dungeon: DungeonMap = _map("trap_settings")
	var base: TrapDefinition = TrapCatalog.get_trap("spikes")
	assert(dungeon.place_entity("trap", 3, 2, {"trap_id": "spikes", "detection_difficulty": 1, "initial_state": "disarmed"}))
	assert(dungeon.place_entity("trap", 4, 2, {"trap_id": "spikes"}))
	assert(not dungeon.place_entity("trap", 5, 2, {"trap_id": "door_crossbow"}))
	var entity: Dictionary = _at(dungeon, 3, 2)
	var other: Dictionary = _at(dungeon, 4, 2)
	assert(DungeonMap.is_entity_hidden(entity) and DungeonMap.is_entity_hidden(other))
	assert(not entity["properties"].has("detection_difficulty"))
	assert(not entity["properties"].has("initial_state"))
	assert(not dungeon.set_trap_configuration(entity["id"], {"avoidance_difficulty": 0, "avoidance_stat": "strength"}))
	assert(dungeon.set_trap_configuration(entity["id"], {"hidden": false, "disarm_difficulty": 0}))
	assert(TrapCatalog.from_entity(entity) == base and TrapCatalog.from_entity(other) == base)
	assert(not DungeonMap.is_entity_hidden(entity) and DungeonMap.is_entity_hidden(other))
	assert(dungeon.place_entity("door", 3, 3))
	var door: Dictionary = _at(dungeon, 3, 3)
	assert(not dungeon.attach_door_trap(door["id"], "spikes"))
	assert(dungeon.attach_door_trap(door["id"], "door_crossbow"))
	assert(not dungeon.attach_door_trap(door["id"], "door_crossbow"))
	assert(dungeon.set_door_trap_message(door["id"], "Авторское сообщение"))
	assert(TrapCatalog.settings(door)["hidden"])
	assert(dungeon.set_trap_configuration(door["id"], {"hidden": false}))
	var clean: Dictionary = _json(dungeon.to_dict())
	var legacy: Dictionary = _json(clean)
	for entry in legacy["entities"]:
		var properties: Dictionary = entry["properties"]
		if entry["type"] == "door":
			properties = properties["trap"]
		elif entry["type"] != "trap":
			continue
		properties.merge({"detection_difficulty": 0, "avoidance_difficulty": 0, "disarm_difficulty": 0, "avoidance_stat": "strength", "initial_state": "disarmed"}, true)
	var restored: DungeonMap = DungeonMap.from_dict(legacy)
	assert(restored != null and _json(restored.to_dict()) == clean)
	var session: GameSession = GameSession.start_for(restored, "petushan")
	assert(session.is_door_trap_visible(_at(restored, 3, 3)))
	assert(session.trap_state(_at(restored, 3, 3)) == "armed")
	assert(session.trap_state(_at(restored, 3, 2)) == "armed")
	assert(TrapCatalog.from_door(_at(restored, 3, 3)) == TrapCatalog.get_trap("door_crossbow"))
	assert(DungeonMap.door_trap_message(_at(restored, 3, 3)) == "Авторское сообщение")
	assert(dungeon.set_trap_configuration(entity["id"], {"hidden": true}))
	assert(not dungeon.set_trap_configuration(entity["id"], {"hidden": true}))


func _seed_for_disarm(definition: TrapDefinition) -> int:
	var rng := RandomNumberGenerator.new()
	for value in range(100):
		rng.seed = value
		if rng.randi_range(1, definition.check_die_sides) > 1:
			return value
	assert(false)
	return 0


func _test_progress() -> void:
	var first: DungeonMap = _map("trap_progress_one")
	var second: DungeonMap = _map("trap_progress_two")
	assert(first.place_entity("trap", 3, 2, {"trap_id": "spikes"}))
	assert(first.place_entity("trap", 4, 2, {"trap_id": "spikes", "hidden": false}))
	assert(second.place_entity("trap", 3, 2, {"trap_id": "spikes"}))
	var first_trap: Dictionary = _at(first, 3, 2)
	var raw_second: Dictionary = _json(second.to_dict())
	for entity in raw_second["entities"]:
		if entity["type"] == "trap":
			entity["id"] = first_trap["id"]
	second = DungeonMap.from_dict(raw_second)
	var other_trap: Dictionary = _at(second, 3, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 121
	var session: GameSession = GameSession.start_for_party(first, ["petushan", "volcha"], false, rng)
	session.party[0].perception = 0
	session.party[1].perception = TrapCatalog.get_trap("spikes").detection_difficulty
	for member in session.party:
		member.agility = TrapCatalog.get_trap("spikes").disarm_difficulty
	assert(not session.move_by(1, 0) and session.last_move_detected_trap)
	assert(not session.is_trap_known_by(first_trap, session.party[0]))
	assert(session.is_trap_known_by(first_trap, session.party[1]))
	assert(not session.move_by(1, 0))
	assert(session.resolve_pending_trap_choice("avoid"))
	assert(session.trap_state(first_trap) == "discharged")
	var next: Dictionary = _at(first, 4, 2)
	assert(not session.move_by(1, 0) and session.has_pending_trap_choice())
	var previous_rng: int = session.trap_random.state
	assert(not session.resolve_pending_trap_choice("cancel"))
	assert(session.trap_random.state == previous_rng)
	session.trap_random.seed = _seed_for_disarm(TrapCatalog.from_entity(next))
	assert(not session.move_by(1, 0) and session.has_pending_trap_choice())
	assert(not session.resolve_pending_trap_choice("disarm"))
	assert(session.trap_state(next) == "disarmed")
	assert(session.enter_map(second))
	assert(session.trap_state(other_trap) == "armed")
	assert(not session.is_trap_known_by(other_trap, session.party[1]))
	var maps: Dictionary = {first.map_id: first, second.map_id: second}
	var snapshot: Dictionary = _json(session.progress_snapshot())
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, maps)
	assert(restored != null and _json(restored.progress_snapshot()) == snapshot)
	assert(restored.enter_map(first))
	assert(restored.trap_state(first_trap) == "discharged" and restored.trap_state(next) == "disarmed")
	assert(restored.is_trap_known_by(first_trap, restored.party[1]))
	assert(not restored.is_trap_known_by(first_trap, restored.party[0]))
	var saved_rng: int = restored.trap_random.state
	for i in range(3):
		assert(restored.move_by(1, 0))
	assert(restored.trap_random.state == saved_rng and restored.take_party_damage_events().is_empty())
	for floor in snapshot["floors"].values():
		floor.erase("discharged_traps")
		floor.erase("revealed_traps")
	for member in snapshot["party"]["active_heroes"]:
		member.erase("known_traps_by_map")
	var legacy: GameSession = GameSession.from_progress_snapshot(snapshot, maps)
	assert(legacy != null and legacy.enter_map(first))
	assert(legacy.is_trap_disarmed(first_trap) and legacy.is_trap_disarmed(next))
	assert(not legacy.is_trap_known_by(first_trap, legacy.party[1]))


func _test_door_overrides() -> void:
	var dungeon: DungeonMap = _map("trap_door_settings")
	assert(dungeon.place_entity("door", 3, 2))
	var door: Dictionary = _at(dungeon, 3, 2)
	assert(dungeon.attach_door_trap(door["id"], "door_crossbow"))
	assert(dungeon.set_trap_configuration(door["id"], {"hidden": false, "avoidance_difficulty": 0, "avoidance_stat": "perception"}))
	var source: Dictionary = _json(dungeon.to_dict())
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	var before_rng: int = session.trap_random.state
	assert(not session.move_by(1, 0))
	assert(not session.has_pending_trap_choice() and not session.has_pending_door_trap())
	assert(session.trap_random.state == before_rng)
	assert(session._receive_item("key", 1) == 1)
	assert(not session.move_by(1, 0) and session.has_pending_trap_choice())
	assert(session.take_message_events()[0]["choices"]["avoid"].contains(TrapCatalog.get_trap("door_crossbow").avoidance_stat_label()))
	session.party[1].agility = TrapCatalog.get_trap("door_crossbow").avoidance_difficulty
	var probe := RandomNumberGenerator.new()
	probe.seed = session.trap_random.seed
	probe.state = session.trap_random.state
	probe.randi_range(1, TrapCatalog.from_door(door).check_die_sides)
	assert(not session.resolve_pending_trap_choice("avoid", 1))
	assert(session.has_pending_door_trap())
	assert(session.resolve_pending_door_trap())
	assert(session.is_entity_removed(door) and session.trap_state(door) == "discharged")
	assert(session.trap_random.state == probe.state)
	assert(session.take_party_damage_events().is_empty())
	var restored: GameSession = GameSession.from_progress_snapshot(_json(session.progress_snapshot()), {dungeon.map_id: dungeon})
	assert(restored != null and restored.trap_state(door) == "discharged")
	assert(restored.move_by(-1, 0) and restored.move_by(1, 0))
	assert(restored.trap_random.state == probe.state)
	assert(_json(dungeon.to_dict()) == source)


func _test_repeatable_mechanism() -> void:
	var dungeon: DungeonMap = _map("trap_repeatable")
	assert(dungeon.place_entity("trap", 3, 2))
	var entity: Dictionary = _at(dungeon, 3, 2)
	var definition: TrapDefinition = TrapCatalog.from_entity(entity).duplicate() as TrapDefinition
	definition.disarm_on_trigger = false
	definition.avoidance_difficulty = 999
	var session: GameSession = GameSession.start_for(dungeon, "petushan")
	var hp: int = session.hero.health
	for i in range(2):
		session._activate_trap(definition, entity["id"])
		assert(session.trap_state(entity) == "armed")
		assert(session.is_trap_revealed(entity))
	assert(session.hero.health == hp - 2 * definition.direct_damage)


func _test_editor() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	var storage = preload("res://tests/editor_test_storage.gd").new()
	storage.configure(editor)
	root.add_child(editor)
	await process_frame
	var dungeon: DungeonMap = _map("trap_editor")
	assert(dungeon.place_entity("trap", 3, 2, {"trap_id": "spikes"}))
	assert(dungeon.place_entity("door", 4, 2))
	var door: Dictionary = _at(dungeon, 4, 2)
	assert(dungeon.attach_door_trap(door["id"], "door_crossbow"))
	editor.call("_set_map", dungeon)
	var before: Dictionary = _json(dungeon.to_dict())
	var canvas: DungeonCanvas = editor.get("_canvas")
	canvas.set_selected_tool("hand")
	assert(canvas._configurable_at(Vector2i(3, 2))["type"] == "trap")
	canvas.set_selected_tool("trap:spikes")
	assert(canvas._selected_tool_has_properties())
	assert(canvas._configurable_at(Vector2i(3, 2))["type"] == "trap")
	canvas.camera_offset = Vector2.ZERO
	canvas.zoom = 1.0
	var point: Vector2 = (Vector2(3, 2) + Vector2(0.5, 0.5)) * DungeonCanvas.TILE_SIZE
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		canvas._gui_input(event)
	var popup: TrapPropertiesPopup = editor.get("_trap_popup")
	assert(popup.visible)
	var fields: TrapConfigurationFields = popup.get("_trap_fields")
	assert(fields.get_child_count() == 1 and not fields._visible.button_pressed)
	fields._visible.button_pressed = true
	popup.call("_save")
	assert(TrapCatalog.from_entity(_at(dungeon, 3, 2)) == TrapCatalog.get_trap("spikes"))
	assert(not DungeonMap.is_entity_hidden(_at(dungeon, 3, 2)))
	var changed: Dictionary = _json(dungeon.to_dict())
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.pressed = pressed
		event.position = point
		canvas._gui_input(event)
	assert(popup.visible)
	assert(fields._visible.button_pressed)
	fields._visible.button_pressed = false
	popup.hide()
	assert(_json(dungeon.to_dict()) == changed)
	editor.call("_undo_edit")
	assert(_json(dungeon.to_dict()) == before)
	editor.call("_redo_edit")
	assert(_json(dungeon.to_dict()) == changed)
	editor.call("_on_door_tapped", _at(dungeon, 4, 2)["id"])
	var door_popup: DoorPropertiesPopup = editor.get("_door_popup")
	var door_fields: TrapConfigurationFields = door_popup.get("_trap_fields")
	assert(door_fields.get_child_count() == 1 and not door_fields._visible.button_pressed)
	door_fields._visible.button_pressed = true
	(door_popup.get("_trap_message") as TextEdit).text = "Авторский текст"
	door_popup.call("_save")
	assert(not TrapCatalog.settings(_at(dungeon, 4, 2))["hidden"])
	assert(DungeonMap.door_trap_message(_at(dungeon, 4, 2)) == "Авторский текст")
	editor.call("_undo_edit")
	assert(_json(dungeon.to_dict()) == changed)
	editor.call("_redo_edit")
	assert(not TrapCatalog.settings(_at(dungeon, 4, 2))["hidden"])
	var author_map: Dictionary = _json(dungeon.to_dict())
	editor.call("_set_tool", "hand")
	editor.call("_start_play_mode")
	var session: GameSession = editor.get("game_session")
	assert(session != null and session.is_editor_test)
	assert(session.map_data != dungeon)
	assert(not session.move_by(1, 0) and session.has_pending_trap_choice())
	assert(session.resolve_pending_trap_choice("avoid"))
	assert(session.trap_state(_at(session.map_data, 3, 2)) == "discharged")
	assert(session.progress_snapshot().is_empty())
	assert(_json(dungeon.to_dict()) == author_map)
	editor.queue_free()
	await process_frame
	storage.cleanup()
	print("Trap configuration: visibility, resource defaults, legacy saves, floor states, editor history and isolation OK")
	quit()
