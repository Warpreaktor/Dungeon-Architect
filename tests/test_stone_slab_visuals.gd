extends SceneTree

const CELL := Vector2i(3, 3)
const TRAP_ID := "stone_slab"


func _initialize() -> void:
	_test_visual_events()
	call_deferred("_test_playback")


func _corridor(axis: Vector2i = Vector2i.RIGHT, trap_id: String = TRAP_ID) -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(7, 7)
	for y in range(dungeon.height):
		for x in range(dungeon.width):
			dungeon.set_terrain(x, y, "wall")
	for offset in range(-2, 3):
		var cell: Vector2i = CELL + axis * offset
		dungeon.set_terrain(cell.x, cell.y, "floor")
	var origin: Vector2i = CELL - axis
	assert(dungeon.place_entity("player_spawn", origin.x, origin.y))
	assert(dungeon.place_entity("trap", CELL.x, CELL.y, {"trap_id": trap_id}))
	return dungeon


func _prepare(session: GameSession, detected: bool = false) -> void:
	var trap: TrapDefinition = TrapCatalog.get_trap(TRAP_ID)
	for member in session.party:
		member.perception = trap.detection_difficulty if detected else 0
		member.agility = 0
	session.trap_random.seed = 19531


func _state(session: GameSession) -> Dictionary:
	var health: Array[int] = []
	for member in session.party:
		health.append(member.health)
	return {"health": health, "position": session.player_pos, "steps": session.steps,
		"rng": session.trap_random.state, "disarmed": session.disarmed_traps.duplicate(true),
		"discharged": session.discharged_traps.duplicate(true), "fallen_count": session.fallen_heroes.size()}


func _test_visual_events() -> void:
	var dungeon: DungeonMap = _corridor()
	var entity: Dictionary = dungeon.entities_at(CELL.x, CELL.y)[0]
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	_prepare(session)
	assert(not session.move_by(1, 0) and session.has_pending_trap_choice())
	assert(not session.has_trap_visual_events())
	assert(session.resolve_pending_trap_choice("forward"))
	var result: Dictionary = _state(session)
	var events: Array[Dictionary] = session.take_trap_visual_events()
	assert(events == [{"effect": "falling_slab", "cell": CELL}])
	assert(_state(session) == result and session.take_trap_visual_events().is_empty())
	var restored: GameSession = GameSession.from_progress_snapshot(JSON.parse_string(JSON.stringify(session.progress_snapshot())), {dungeon.map_id: dungeon})
	assert(restored != null and restored.trap_state(entity) == "discharged")
	assert(not restored.has_trap_visual_events())
	assert(restored.move_by(-1, 0) and not restored.has_trap_visual_events())
	assert(restored.enter_map(_corridor(Vector2i.DOWN)))
	assert(restored.enter_map(dungeon) and not restored.has_trap_visual_events())
	assert(restored.trap_state(entity) == "discharged")
	assert(restored.move_by(1, 0) and not restored.has_trap_visual_events())

	var detected: GameSession = GameSession.start_for(dungeon)
	_prepare(detected, true)
	assert(not detected.move_by(1, 0) and detected.last_move_detected_trap)
	assert(not detected.move_by(1, 0) and detected.has_pending_trap_choice())
	assert(not detected.resolve_pending_trap_choice("disarm"))
	assert(not detected.has_trap_visual_events() and detected.trap_state(entity) == "armed")
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

	var old: GameSession = GameSession.start_for(_corridor(Vector2i.RIGHT, "spikes"))
	_prepare(old)
	assert(old.move_by(1, 0))
	assert(old.take_trap_visual_events() == [{"effect": "spike_burst", "cell": CELL}])


func _test_playback() -> void:
	for axis in [Vector2i.RIGHT, Vector2i.DOWN]:
		for choice in ["back", "forward"]:
			var expected: Dictionary = {}
			var dungeon: DungeonMap = _corridor(axis)
			for playback in ["normal", "fast", "keyboard", "touch"]:
				root.size = Vector2i(1280, 800) if playback == "normal" else Vector2i(720, 480)
				var editor: Node = load("res://scenes/editor.tscn").instantiate()
				root.add_child(editor)
				await process_frame
				editor.call("_set_map", dungeon)
				editor.call("_start_play_mode")
				var session: GameSession = editor.get("game_session")
				_prepare(session)
				var canvas: DungeonCanvas = editor.get("_canvas")
				var dialogue: GameDialogueView = editor.get("_game_dialogue")
				editor.call("_on_dpad_down", axis)
				assert(dialogue.has_choices() and not canvas.is_player_moving())
				if choice == "back":
					dialogue._back_button.pressed.emit()
				else:
					dialogue._forward_button.pressed.emit()
				assert(not dialogue.has_choices() and canvas.is_player_moving())
				assert(editor.get("_trap_playback_active"))
				var resolved: Dictionary = _state(session)
				assert(resolved["position"] == CELL + axis * (-1 if choice == "back" else 1))
				editor.call("_on_dpad_down", axis)
				editor.call("_try_move_player", axis.x, axis.y)
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
				assert(canvas._collapse_progress < 0.0 and canvas._player_visual_cell == Vector2(session.player_pos))
				assert(not session.has_trap_visual_events() and _state(session) == resolved)
				assert(editor.get("_held_dpad_direction") == Vector2i.ZERO)
				if expected.is_empty():
					expected = resolved
				else:
					assert(resolved == expected)
				editor.queue_free()
				await process_frame
	print("Stone slab: visual events, one-shot playback, speed and skip invariance OK")
	quit()
