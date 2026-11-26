extends SceneTree

const CENTER := Vector2i(3, 3)
const TRAP_ID := "stone_slab"


func _initialize() -> void:
	_test_directions()
	_test_blocked_forward()
	_test_mixed_outcomes_and_save()
	_test_seed_replay()
	_test_party_defeat()
	_test_detected_crossing()
	call_deferred("_test_dialogue")


func _corridor(direction: Vector2i = Vector2i.RIGHT, blocked: String = "") -> DungeonMap:
	var dungeon: DungeonMap = DungeonMap.create_blank(7, 7)
	for y in range(dungeon.height):
		for x in range(dungeon.width):
			dungeon.set_terrain(x, y, "wall")
	for offset in range(-2, 3):
		var cell: Vector2i = CENTER + direction * offset
		assert(dungeon.set_terrain(cell.x, cell.y, "floor"))
	var origin: Vector2i = CENTER - direction
	assert(dungeon.place_entity("player_spawn", origin.x, origin.y))
	assert(dungeon.place_entity("trap", CENTER.x, CENTER.y, {"trap_id": TRAP_ID}))
	var forward: Vector2i = CENTER + direction
	if blocked == "wall":
		assert(dungeon.set_terrain(forward.x, forward.y, "wall"))
	elif not blocked.is_empty():
		assert(dungeon.place_entity(blocked, forward.x, forward.y))
	return dungeon


func _trap(dungeon: DungeonMap) -> Dictionary:
	return dungeon.entities_at(CENTER.x, CENTER.y)[0]


func _prepare(session: GameSession, agility: int) -> void:
	for member in session.party:
		member.perception = 0
		member.agility = agility
	session.trap_random.seed = 123456


func _request(session: GameSession, direction: Vector2i) -> Dictionary:
	var before: int = session.trap_random.state
	var origin: Vector2i = session.player_pos
	assert(not session.move_by(direction.x, direction.y))
	assert(session.has_pending_trap_choice() and session.player_pos == origin)
	assert(session.trap_random.state == before and session.steps == 0)
	var events: Array[Dictionary] = session.take_message_events()
	assert(events.size() == 1 and events[0]["activation"] == "trap_reaction")
	assert(events[0]["choices"].has("back") and events[0]["choices"].has("forward"))
	assert(not events[0]["choices"].has("cancel"))
	assert(session.is_trap_revealed(_trap(session.map_data)))
	assert(session.trap_state(_trap(session.map_data)) == "armed")
	return events[0]


func _expected_state(session: GameSession, count: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = session.trap_random.seed
	rng.state = session.trap_random.state
	for index in count:
		rng.randi_range(1, TrapCatalog.get_trap(TRAP_ID).check_die_sides)
	return rng.state


func _test_directions() -> void:
	var trap: TrapDefinition = TrapCatalog.get_trap(TRAP_ID)
	for direction in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		for choice in ["back", "forward"]:
			var dungeon: DungeonMap = _corridor(direction)
			var session: GameSession = GameSession.start_for(dungeon)
			_prepare(session, trap.avoidance_difficulty)
			var before: int = session.trap_random.state
			var expected: int = _expected_state(session, 1)
			var hp: int = session.hero.health
			var origin: Vector2i = session.player_pos
			var event: Dictionary = _request(session, direction)
			assert(event["disabled_choices"].is_empty())
			assert(not session.resolve_pending_trap_choice("cancel"))
			assert(not session.resolve_pending_trap_choice("avoid"))
			assert(not session.move_by(-direction.x, -direction.y))
			assert(session.progress_snapshot().is_empty())
			assert(not session.enter_map(_corridor()))
			assert(session.trap_random.state == before)
			assert(session.resolve_pending_trap_choice(choice) == (choice == "forward"))
			assert(session.player_pos == (origin if choice == "back" else CENTER + direction))
			assert(session.steps == 1 and session.hero.health == hp)
			assert(session.trap_state(_trap(dungeon)) == "discharged")
			assert(not session.has_pending_trap_choice() and session.trap_random.state == expected)
			assert(not session.resolve_pending_trap_choice(choice))
			var return_direction: Vector2i = direction if choice == "back" else -direction
			assert(session.move_by(return_direction.x, return_direction.y))
			assert(session.player_pos == CENTER and session.trap_random.state == expected)


func _test_blocked_forward() -> void:
	for blocker in ["wall", "door", "monster"]:
		var dungeon: DungeonMap = _corridor(Vector2i.RIGHT, blocker)
		var session: GameSession = GameSession.start_for(dungeon)
		_prepare(session, 100)
		var event: Dictionary = _request(session, Vector2i.RIGHT)
		assert(event["disabled_choices"] == ["forward"])
		var before: int = session.trap_random.state
		assert(not session.resolve_pending_trap_choice("forward"))
		assert(session.has_pending_trap_choice() and session.trap_random.state == before)
		assert(not session.resolve_pending_trap_choice("back"))
		assert(not session.has_pending_trap_choice() and session.player_pos == CENTER - Vector2i.RIGHT)
		assert(session.trap_state(_trap(dungeon)) == "discharged")


func _test_mixed_outcomes_and_save() -> void:
	var dungeon: DungeonMap = _corridor()
	var source: String = JSON.stringify(dungeon.to_dict())
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha", "burolom", "luma"])
	_prepare(session, 100)
	var injured: HeroState = session.party[2]
	var fallen: HeroState = session.party[3]
	injured.agility = 0
	fallen.agility = 0
	fallen.health = 1
	var hp: int = injured.health
	var expected: int = _expected_state(session, 4)
	_request(session, Vector2i.RIGHT)
	assert(session.resolve_pending_trap_choice("forward"))
	assert(session.party.size() == 3 and session.fallen_heroes.has(fallen))
	assert(injured.health < hp and injured.health > 0)
	assert(session.fallen_hero_locations.back()["position"] == CENTER)
	assert(session.player_pos == CENTER + Vector2i.RIGHT and session.trap_random.state == expected)
	assert(session.take_party_damage_events().size() == 2)
	assert(session.trap_state(_trap(dungeon)) == "discharged")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {dungeon.map_id: dungeon})
	assert(restored != null and restored.trap_state(_trap(dungeon)) == "discharged")
	assert(restored.trap_random.state == expected)
	assert(restored.move_by(-1, 0) and restored.player_pos == CENTER)
	assert(restored.trap_random.state == expected)
	assert(restored.enter_map(_corridor(Vector2i.UP)))
	assert(restored.enter_map(dungeon))
	assert(restored.trap_state(_trap(dungeon)) == "discharged")
	assert(restored.move_by(1, 0) and restored.trap_random.state == expected)
	assert(JSON.stringify(dungeon.to_dict()) == source)


func _test_seed_replay() -> void:
	var dungeon: DungeonMap = _corridor()
	var first: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha", "burolom", "luma"])
	var second: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha", "burolom", "luma"])
	var trap: TrapDefinition = TrapCatalog.get_trap(TRAP_ID)
	for session in [first, second]:
		_prepare(session, trap.avoidance_difficulty - 5)
		_request(session, Vector2i.RIGHT)
		assert(session.resolve_pending_trap_choice("forward"))
	assert(first.trap_random.state == second.trap_random.state)
	assert(first.take_trap_result_message() == second.take_trap_result_message())
	assert(first.party.size() == second.party.size())
	for index in first.party.size():
		assert(first.party[index].health == second.party[index].health)


func _test_party_defeat() -> void:
	var dungeon: DungeonMap = _corridor()
	var session: GameSession = GameSession.start_for(dungeon)
	_prepare(session, 0)
	session.hero.health = 1
	_request(session, Vector2i.RIGHT)
	assert(session.resolve_pending_trap_choice("back"))
	assert(session.is_party_defeated() and session.player_pos == CENTER)
	assert(session.trap_state(_trap(dungeon)) == "discharged")
	assert(session.fallen_hero_locations.back()["position"] == CENTER)
	assert(not session.resolve_pending_trap_choice("forward"))


func _test_detected_crossing() -> void:
	var dungeon: DungeonMap = _corridor()
	var session: GameSession = GameSession.start_for(dungeon)
	var trap: TrapDefinition = TrapCatalog.get_trap(TRAP_ID)
	_prepare(session, trap.avoidance_difficulty)
	session.hero.perception = trap.detection_difficulty
	assert(not session.move_by(1, 0) and session.last_move_detected_trap)
	assert(not session.move_by(1, 0) and session.has_pending_trap_choice())
	var event: Dictionary = session.take_message_events()[0]
	assert(event["activation"] == "trap_choice" and event["choices"].has("disarm"))
	assert(session.resolve_pending_trap_choice("avoid"))
	assert(session.player_pos == CENTER and session.trap_state(_trap(dungeon)) == "discharged")


func _test_dialogue() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.call("_set_map", _corridor(Vector2i.RIGHT, "door"))
	editor.call("_start_play_mode")
	var session: GameSession = editor.get("game_session") as GameSession
	_prepare(session, 100)
	var dialogue: GameDialogueView = editor.get("_game_dialogue") as GameDialogueView
	var before: int = session.trap_random.state
	editor.call("_on_dpad_down", Vector2i.RIGHT)
	assert(dialogue.has_choices() and dialogue._reaction_actions.visible)
	assert(dialogue._forward_button.disabled and dialogue._back_button.visible)
	assert(not dialogue._disarm_button.visible and not dialogue._cancel_button.visible and not dialogue._avoid_button.visible)
	assert(not dialogue._actor_portraits.visible)
	dialogue.dismiss_by_player()
	dialogue._forward_button.pressed.emit()
	editor.call("_advance_held_move")
	assert(dialogue.has_choices() and session.trap_random.state == before)
	assert(editor.get("_held_dpad_direction") == Vector2i.ZERO)
	dialogue._back_button.pressed.emit()
	assert(not dialogue.has_choices() and not session.has_pending_trap_choice())
	assert(session.player_pos == CENTER - Vector2i.RIGHT)
	editor.queue_free()
	await process_frame
	print("Stone slab: directional reaction, checks, casualties, save and dialogue OK")
	quit()
