extends SceneTree

const CELL := Vector2i(3, 2)
const TRAP_ID := "spikes"


func _initialize() -> void:
	_test_visual_events()
	call_deferred("_test_playback")


func _floor_map(trap_id: String = TRAP_ID) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(7, 5)
	for y in range(dungeon.height):
		for x in range(dungeon.width):
			dungeon.set_terrain(x, y, "floor")
	assert(dungeon.place_entity("player_spawn", CELL.x - 1, CELL.y))
	assert(dungeon.place_entity("trap", CELL.x, CELL.y, {"trap_id": trap_id}))
	return dungeon


func _prepare(session: GameSession, detected: bool = false) -> void:
	var trap: TrapDefinition = TrapCatalog.get_trap(TRAP_ID)
	for member in session.party:
		member.perception = trap.detection_difficulty if detected else 0
		member.agility = 0
	session.trap_random.seed = 24151


func _state(session: GameSession) -> Dictionary:
	var health: Array[int] = []
	for member in session.party:
		health.append(member.health)
	return {
		"health": health,
		"position": session.player_pos,
		"steps": session.steps,
		"rng": session.trap_random.state,
		"disarmed": session.disarmed_traps.duplicate(true),
		"discharged": session.discharged_traps.duplicate(true),
		"fallen_count": session.fallen_heroes.size()
	}


func _test_visual_events() -> void:
	var dungeon: DungeonMap = _floor_map()
	var entity: Dictionary = dungeon.entities_at(CELL.x, CELL.y)[0]
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	_prepare(session)
	assert(session.move_by(1, 0))
	var result: Dictionary = _state(session)
	var events: Array[Dictionary] = session.take_trap_visual_events()
	assert(events == [{"effect": "spike_burst", "cell": CELL}])
	assert(_state(session) == result and session.take_trap_visual_events().is_empty())
	var restored: GameSession = GameSession.from_progress_snapshot(JSON.parse_string(JSON.stringify(session.progress_snapshot())), {dungeon.map_id: dungeon})
	assert(restored != null and restored.trap_state(entity) == "discharged")
	assert(not restored.has_trap_visual_events())
	assert(restored.move_by(-1, 0) and not restored.has_trap_visual_events())
	assert(restored.move_by(1, 0) and not restored.has_trap_visual_events())

	var detected: GameSession = GameSession.start_for(dungeon)
	_prepare(detected, true)
	assert(not detected.move_by(1, 0) and detected.last_move_detected_trap)
	assert(not detected.move_by(1, 0) and detected.has_pending_trap_choice())
	assert(detected.resolve_pending_trap_choice("avoid"))
	assert(detected.take_trap_visual_events() == events)

	var safe: GameSession = GameSession.start_for(dungeon)
	_prepare(safe, true)
	var trap: TrapDefinition = TrapCatalog.get_trap(TRAP_ID)
	safe.hero.agility = trap.disarm_difficulty
	for seed_value in range(100):
		safe.trap_random.seed = seed_value
		if safe.trap_random.randi_range(1, trap.check_die_sides) > 1:
			safe.trap_random.seed = seed_value
			break
	assert(not safe.move_by(1, 0) and safe.last_move_detected_trap)
	assert(not safe.move_by(1, 0) and safe.has_pending_trap_choice())
	assert(not safe.resolve_pending_trap_choice("disarm"))
	assert(safe.trap_state(entity) == "disarmed" and not safe.has_trap_visual_events())
	assert(safe.move_by(1, 0) and not safe.has_trap_visual_events())


func _test_playback() -> void:
	var expected: Dictionary = {}
	for playback in ["normal", "fast", "keyboard", "touch"]:
		root.size = Vector2i(1280, 800) if playback == "normal" else Vector2i(720, 480)
		var editor: Node = load("res://scenes/editor.tscn").instantiate()
		root.add_child(editor)
		await process_frame
		editor.call("_set_map", _floor_map())
		editor.call("_start_play_mode")
		var session: GameSession = editor.get("game_session")
		_prepare(session)
		var canvas: DungeonCanvas = editor.get("_canvas")
		editor.call("_on_dpad_down", Vector2i.RIGHT)
		await process_frame
		assert(canvas.is_player_moving() and editor.get("_trap_playback_active"))
		var resolved: Dictionary = _state(session)
		assert(resolved["position"] == CELL)
		editor.call("_on_dpad_down", Vector2i.RIGHT)
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
		assert(canvas._spike_burst_progress < 0.0 and canvas._player_visual_cell == Vector2(session.player_pos))
		assert(not session.has_trap_visual_events() and _state(session) == resolved)
		if expected.is_empty():
			expected = resolved
		else:
			assert(resolved == expected)
		editor.queue_free()
		await process_frame
	print("Spikes: visual events, playback speed and skip invariance OK")
	quit()
