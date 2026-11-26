extends SceneTree


func _initialize() -> void:
	_test_cancel_and_disarm()
	_test_failed_disarm()
	_test_individual_saves_and_replay()
	_test_door_opener()
	_test_door_successful_disarm()
	_test_door_failed_disarm()
	_test_stat_selection()
	call_deferred("_test_dialogue")


func _floor_map(hidden: bool = false) -> DungeonMap:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("trap", 3, 2, {"trap_id": "spikes", "hidden": hidden}))
	return dungeon


func _door_map() -> DungeonMap:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("door", 3, 2))
	assert(dungeon.attach_door_trap(str(dungeon.entities_at(3, 2)[0]["id"]), "door_crossbow"))
	return dungeon


func _seed_for_roll(trap: TrapDefinition, minimum: int, maximum: int) -> int:
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1000):
		rng.seed = seed_value
		var roll: int = rng.randi_range(1, trap.check_die_sides)
		if roll >= minimum and roll <= maximum:
			return seed_value
	assert(false)
	return 0


func _request_choice(session: GameSession) -> Dictionary:
	assert(not session.move_by(1, 0))
	assert(session.has_pending_trap_choice())
	var events: Array[Dictionary] = session.take_message_events()
	assert(events.size() == 1 and events[0]["activation"] == "trap_choice")
	return events[0]


func _test_cancel_and_disarm() -> void:
	var dungeon: DungeonMap = _floor_map()
	var entity: Dictionary = dungeon.entities_at(3, 2)[0]
	var trap: TrapDefinition = TrapCatalog.from_entity(entity)
	var source: String = JSON.stringify(dungeon.to_dict())
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	session.party[1].agility = trap.disarm_difficulty
	session.trap_random.seed = _seed_for_roll(trap, 2, trap.check_die_sides)
	var before: int = session.trap_random.state
	var snapshot: Dictionary = session.party_state_snapshot()
	var event: Dictionary = _request_choice(session)
	assert(event["choices"]["avoid"] == "Проскочить (%s)" % trap.avoidance_stat_label())
	assert(event["actors"].size() == 2)
	assert(not session.move_by(-1, 0))
	assert(session.progress_snapshot().is_empty())
	assert(not session.enter_map(_floor_map()))
	assert(not session.resolve_pending_trap_choice("cancel"))
	assert(not session.has_pending_trap_choice())
	assert(session.party_state_snapshot() == snapshot)
	assert(session.player_pos == Vector2i(2, 2) and session.steps == 0)
	assert(session.trap_random.state == before)
	assert(not session.is_trap_disarmed(entity))
	_request_choice(session)
	var probe := RandomNumberGenerator.new()
	probe.seed = session.trap_random.seed
	probe.state = session.trap_random.state
	probe.randi_range(1, trap.check_die_sides)
	assert(not session.resolve_pending_trap_choice("disarm", 1))
	assert(session.is_trap_disarmed(entity))
	assert(session.trap_random.state == probe.state)
	assert(session.player_pos == Vector2i(2, 2) and session.steps == 0)
	assert(session.take_party_damage_events().is_empty())
	assert(session.take_trap_result_message().contains("обезврежена"))
	assert(not session.resolve_pending_trap_choice("disarm", 1))
	assert(session.move_by(1, 0))
	assert(session.trap_random.state == probe.state)
	assert(JSON.stringify(dungeon.to_dict()) == source)
	var other: DungeonMap = _floor_map()
	assert(session.enter_map(other))
	assert(session.enter_map(dungeon))
	assert(session.is_trap_disarmed(entity))


func _test_failed_disarm() -> void:
	var dungeon: DungeonMap = _floor_map()
	var trap: TrapDefinition = TrapCatalog.get_trap("spikes")
	var entity: Dictionary = dungeon.entities_at(3, 2)[0]
	var session: GameSession = GameSession.start_for(dungeon, "petushan")
	session.hero.agility = trap.disarm_difficulty
	session.trap_random.seed = _seed_for_roll(trap, 1, 1)
	_request_choice(session)
	var probe := RandomNumberGenerator.new()
	probe.seed = session.trap_random.seed
	probe.randi_range(1, trap.check_die_sides)
	probe.randi_range(1, trap.check_die_sides)
	assert(not session.resolve_pending_trap_choice("disarm"))
	assert(session.trap_random.state == probe.state)
	assert(session.is_trap_disarmed(entity))
	assert(session.player_pos == Vector2i(2, 2) and session.steps == 0)
	assert(session.take_trap_result_message().contains("не удалось"))
	assert(not session.resolve_pending_trap_choice("disarm"))
	assert(session.trap_random.state == probe.state)


func _test_individual_saves_and_replay() -> void:
	var dungeon: DungeonMap = _floor_map(true)
	var trap: TrapDefinition = TrapCatalog.get_trap("spikes")
	var ids: Array[String] = ["petushan", "volcha", "burolom", "luma"]
	for seed_value in range(12):
		var first: GameSession = GameSession.start_for_party(dungeon, ids)
		var replay: GameSession = GameSession.start_for_party(dungeon, ids)
		for session in [first, replay]:
			session.trap_random.seed = seed_value
			for i in range(session.party.size()):
				session.party[i].perception = 0
				session.party[i].agility = i * 3
			assert(session.move_by(1, 0))
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		for i in range(first.party.size()):
			var member: HeroState = first.party[i]
			var passed: bool = probe.randi_range(1, trap.check_die_sides) + member.effective_agility() >= trap.avoidance_difficulty
			assert(member.health == member.effective_max_health() - (0 if passed else trap.direct_damage))
			assert(member.overworld_statuses.has(trap.overworld_status_id) == (not passed))
			assert(member.health == replay.party[i].health)
			assert(member.overworld_statuses == replay.party[i].overworld_statuses)
		assert(first.trap_random.state == probe.state and first.trap_random.state == replay.trap_random.state)
		var before: int = first.trap_random.state
		assert(first.move_by(-1, 0) and first.move_by(1, 0))
		assert(first.trap_random.state == before)

	var survivors: GameSession = GameSession.start_for_party(dungeon, ids)
	for member in survivors.party:
		member.perception = 0
		member.agility = trap.avoidance_difficulty
	survivors.party[0].health = 0
	var probe := RandomNumberGenerator.new()
	probe.seed = survivors.trap_random.seed
	probe.state = survivors.trap_random.state
	for i in range(3):
		probe.randi_range(1, trap.check_die_sides)
	assert(survivors.move_by(1, 0))
	assert(survivors.party.size() == 3 and survivors.trap_random.state == probe.state)
	assert(survivors.take_party_damage_events().is_empty())


func _test_door_opener() -> void:
	var dungeon: DungeonMap = _door_map()
	var door: Dictionary = dungeon.entities_at(3, 2)[0]
	var trap: TrapDefinition = TrapCatalog.from_door(door)
	for selected in [false, true]:
		var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
		for member in session.party:
			member.perception = 0
			member.agility = 0
		var original: Array[HeroState] = session.party_members()
		var target: HeroState = original[1]
		if selected:
			session.hero.vision_bonus = 1
			session.hero.vision_phases = 1
		else:
			session.party.reverse()
		var before: int = session.trap_random.state
		assert(not session.move_by(1, 0))
		assert(not session.has_pending_door_trap() and not session.has_pending_trap_choice())
		assert(session.trap_random.state == before)
		assert(session._receive_item("key", 1) == 1)
		if selected:
			_request_choice(session)
			assert(not session.resolve_pending_trap_choice("cancel"))
			assert(int(session.carried_items["key"]) == 1)
			assert(not session.is_entity_removed(door) and not session.is_trap_disarmed(door))
			assert(session.trap_random.state == before)
			_request_choice(session)
			assert(not session.resolve_pending_trap_choice("avoid", 1))
		else:
			assert(not session.move_by(1, 0))
		assert(session.has_pending_door_trap())
		assert(session.trap_random.state == before)
		assert(session.take_message_events()[0]["activation"] == "door_trap")
		assert(session.resolve_pending_door_trap())
		assert(target.health == target.effective_max_health() - trap.direct_damage)
		assert(original[0].health == original[0].effective_max_health())
		assert(session.is_entity_removed(door) and session.is_trap_disarmed(door))
		assert(session.take_message_events()[0]["activation"] == "trap_result")
		assert(not session.resolve_pending_door_trap())


func _test_door_successful_disarm() -> void:
	var dungeon: DungeonMap = _door_map()
	var door: Dictionary = dungeon.entities_at(3, 2)[0]
	var trap: TrapDefinition = TrapCatalog.from_door(door)
	var session: GameSession = GameSession.start_for(dungeon, "petushan")
	session.hero.perception = trap.detection_difficulty
	session.hero.agility = trap.disarm_difficulty
	session.trap_random.seed = _seed_for_roll(trap, 2, trap.check_die_sides)
	assert(session._receive_item("key", 1) == 1)
	assert(not session.move_by(1, 0) and session.last_move_detected_trap)
	_request_choice(session)
	assert(not session.resolve_pending_trap_choice("disarm"))
	assert(session.is_trap_disarmed(door) and not session.is_entity_removed(door))
	assert(int(session.carried_items["key"]) == 1)
	var before: int = session.trap_random.state
	assert(session.move_by(1, 0))
	assert(session.is_entity_removed(door) and not session.has_pending_door_trap())
	assert(session.trap_random.state == before)
	assert(session.take_message_events().is_empty())
	assert(int(session.carried_items.get("key", 0)) == 0)


func _test_door_failed_disarm() -> void:
	var dungeon: DungeonMap = _door_map()
	var door: Dictionary = dungeon.entities_at(3, 2)[0]
	var trap: TrapDefinition = TrapCatalog.from_door(door)
	assert(dungeon.set_message_at(3, 2, "Авторское послание"))
	var session: GameSession = GameSession.start_for(dungeon, "petushan")
	session.hero.perception = trap.detection_difficulty
	session.hero.agility = 0
	assert(session._receive_item("key", 1) == 1)
	assert(not session.move_by(1, 0) and session.last_move_detected_trap)
	_request_choice(session)
	assert(not session.resolve_pending_trap_choice("disarm"))
	assert(session.has_pending_door_trap() and not session.is_trap_disarmed(door))
	assert(int(session.carried_items["key"]) == 1)
	assert(session.take_message_events()[0]["activation"] == "door_trap")
	assert(session.resolve_pending_door_trap())
	assert(session.is_trap_disarmed(door) and session.is_entity_removed(door))
	assert(int(session.carried_items.get("key", 0)) == 0)
	var events: Array[Dictionary] = session.take_message_events()
	assert(events.size() == 1 and events[0]["activation"] == "door_open")
	assert(events[0]["text"] == "Авторское послание")
	assert(str(events[0]["result_text"]).contains("не удалось"))


func _test_stat_selection() -> void:
	var trap: TrapDefinition = TrapCatalog.get_trap("spikes").duplicate() as TrapDefinition
	var member := HeroState.new(HeroCatalog.get_hero("petushan"))
	trap.avoidance_stat = "strength"
	member.strength = trap.avoidance_difficulty
	member.agility = 0
	var probe := RandomNumberGenerator.new()
	assert(trap.avoidance_stat_label() == "Сила")
	assert(trap.check(member, probe))
	trap.disarm_stat = "perception"
	member.perception = trap.disarm_difficulty
	probe.seed = _seed_for_roll(trap, 2, trap.check_die_sides)
	assert(trap.check(member, probe, true))


func _test_dialogue() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	editor.call("_set_map", _floor_map())
	editor.call("_start_play_mode")
	var session: GameSession = editor.get("game_session") as GameSession
	var dialogue: GameDialogueView = editor.get("_game_dialogue") as GameDialogueView
	var before: int = session.trap_random.state
	editor.call("_on_dpad_down", Vector2i.RIGHT)
	assert(dialogue.has_choices() and session.has_pending_trap_choice())
	editor.call("_on_dpad_down", Vector2i.RIGHT)
	editor.call("_advance_held_move")
	assert(session.steps == 0 and session.trap_random.state == before)
	dialogue._cancel_button.pressed.emit()
	assert(not dialogue.visible and not session.has_pending_trap_choice())
	assert(session.steps == 0 and session.trap_random.state == before)
	editor.call("_advance_held_move")
	assert(session.steps == 0)
	editor.call("_on_dpad_down", Vector2i.RIGHT)
	assert(dialogue.has_choices())
	dialogue._avoid_button.pressed.emit()
	await create_timer(0.6).timeout
	assert(session.steps == 1 and session.player_pos == Vector2i(3, 2))
	assert(not dialogue.visible)
	assert(editor.get("_held_dpad_direction") == Vector2i.ZERO)
	editor.queue_free()
	await process_frame
	print("Trap interactions: cancel, disarm, individual saves, opener and UI OK")
	quit()
