extends SceneTree

const CELL := Vector2i(3, 3)
const TRAP_ID := "door_crossbow"


func _initialize() -> void:
	_test_events()
	call_deferred("_test_playback")


func _door_map(axis: Vector2i) -> DungeonMap:
	var dungeon := DungeonMap.create_blank(8, 8)
	var start: Vector2i = CELL - axis
	assert(dungeon.place_entity("player_spawn", start.x, start.y))
	assert(dungeon.place_entity("door", CELL.x, CELL.y))
	assert(dungeon.attach_door_trap(str(dungeon.entities_at(CELL.x, CELL.y)[0]["id"]), TRAP_ID))
	return dungeon


func _prepare(session: GameSession, avoided: bool) -> void:
	var trap: TrapDefinition = TrapCatalog.get_trap(TRAP_ID)
	for member in session.party:
		member.perception = 0
		member.agility = trap.avoidance_difficulty if avoided else 0
	for seed_value in range(100):
		session.trap_random.seed = seed_value
		if session.trap_random.randi_range(1, trap.check_die_sides) == 1:
			session.trap_random.seed = seed_value
			break
	assert(session._receive_item("key", 1) == 1)


func _state(session: GameSession) -> Dictionary:
	var health: Array[int] = []
	for member in session.party:
		health.append(member.health)
	return {"health": health, "position": session.player_pos, "steps": session.steps,
		"rng": session.trap_random.state, "discharged": session.discharged_traps.duplicate(true),
		"removed": session.removed_entities.duplicate(true), "key": int(session.carried_items.get("key", 0)),
		"fallen": session.fallen_heroes.size()}


func _test_events() -> void:
	for axis in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var dungeon: DungeonMap = _door_map(axis)
		var door: Dictionary = dungeon.entities_at(CELL.x, CELL.y)[0]
		for avoided in [false, true]:
			var session := GameSession.start_for_party(dungeon, ["petushan", "volcha"])
			_prepare(session, avoided)
			var before: Array[int] = [session.party[0].health, session.party[1].health]
			var rng_before: int = session.trap_random.state
			assert(not session.move_by(axis.x, axis.y) and session.has_pending_door_trap())
			assert(not session.has_trap_visual_events() and session.trap_random.state == rng_before)
			assert(session.resolve_pending_door_trap())
			var resolved: Dictionary = _state(session)
			assert(session.take_trap_visual_events() == [{"effect": "crossbow_shot", "cell": CELL,
				"opener_cell": CELL - axis, "avoided": avoided}])
			assert(session.take_trap_visual_events().is_empty() and _state(session) == resolved)
			assert(session.party[1].health == before[1])
			assert((session.party[0].health == before[0]) == avoided)
			assert(session.trap_state(door) == "discharged" and session.player_pos == CELL)
			assert(not session.resolve_pending_door_trap())
			var restored: GameSession = GameSession.from_progress_snapshot(JSON.parse_string(JSON.stringify(session.progress_snapshot())), {dungeon.map_id: dungeon})
			assert(restored != null and not restored.has_trap_visual_events())
			assert(restored.move_by(-axis.x, -axis.y))
			assert(restored.move_by(axis.x, axis.y) and not restored.has_trap_visual_events())

	var lethal := GameSession.start_for(_door_map(Vector2i.RIGHT), "petushan")
	_prepare(lethal, false)
	lethal.hero.health = 1
	assert(not lethal.move_by(1, 0) and lethal.has_pending_door_trap())
	assert(not lethal.resolve_pending_door_trap() and lethal.is_party_defeated())
	assert(lethal.player_pos == CELL - Vector2i.RIGHT)
	assert(lethal.take_trap_visual_events().size() == 1)
	assert(not lethal.resolve_pending_door_trap() and not lethal.has_trap_visual_events())


func _test_playback() -> void:
	var dungeon: DungeonMap = _door_map(Vector2i.RIGHT)
	for avoided in [false, true]:
		var expected: Dictionary = {}
		for playback in ["normal", "fast", "keyboard", "touch"]:
			var editor: Node = load("res://scenes/editor.tscn").instantiate()
			root.add_child(editor)
			await process_frame
			editor.call("_set_map", dungeon)
			editor.call("_start_play_mode")
			var session: GameSession = editor.get("game_session")
			_prepare(session, avoided)
			var canvas: DungeonCanvas = editor.get("_canvas")
			var dialogue: GameDialogueView = editor.get("_game_dialogue")
			editor.call("_on_dpad_down", Vector2i.RIGHT)
			assert(dialogue.visible and session.has_pending_door_trap())
			dialogue.dismiss_by_player()
			assert(canvas.is_player_moving() and editor.get("_trap_playback_active"))
			assert(canvas._player_visual_cell == Vector2(CELL - Vector2i.RIGHT))
			var resolved: Dictionary = _state(session)
			assert(session.player_pos == CELL)
			editor.call("_try_move_player", 1, 0)
			assert(_state(session) == resolved)
			if playback == "keyboard":
				var key := InputEventKey.new()
				key.keycode = KEY_SPACE
				key.pressed = true
				editor.call("_input", key)
			elif playback == "touch":
				var touch := InputEventScreenTouch.new()
				touch.pressed = true
				editor.call("_input", touch)
			else:
				if playback == "fast":
					canvas._trap_playback.set_speed_scale(8.0)
				await canvas.trap_playback_finished
			await process_frame
			assert(not canvas.is_player_moving() and not editor.get("_trap_playback_active"))
			assert(canvas._crossbow_progress < 0.0 and canvas._player_visual_cell == Vector2(CELL))
			assert(not session.has_trap_visual_events() and _state(session) == resolved)
			if expected.is_empty():
				expected = resolved
			else:
				assert(expected == resolved)
			editor.queue_free()
			await process_frame
	print("Door crossbow: shot direction, hit and miss, one-shot playback and skip invariance OK")
	quit()
