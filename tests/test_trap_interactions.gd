extends SceneTree


func _initialize() -> void:
	_test_cancel_and_disarm()
	_test_failed_disarm()
	_test_lethal_failed_disarm()
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
	var dungeon: DungeonMap = _floor_map(true)
	var trap: TrapDefinition = TrapCatalog.get_trap("spikes")
	var entity: Dictionary = dungeon.entities_at(3, 2)[0]
	var source: String = JSON.stringify(dungeon.to_dict())
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha", "burolom", "luma"])
	for member in session.party:
		member.agility = trap.disarm_difficulty
		member.perception = trap.detection_difficulty
	var actor: HeroState = session.party[2]
	var health_before: int = actor.health
	session.trap_random.seed = _seed_for_roll(trap, 1, 1)
	assert(not session.move_by(1, 0) and session.last_move_detected_trap)
	assert(_request_choice(session)["choices"].has("disarm"))
	var probe := RandomNumberGenerator.new()
	probe.seed = session.trap_random.seed
	probe.state = session.trap_random.state
	probe.randi_range(1, trap.check_die_sides)
	assert(not session.resolve_pending_trap_choice("disarm", 2))
	assert(session.trap_random.state == probe.state)
	assert(session.trap_state(entity) == "armed" and session.is_trap_revealed(entity))
	assert(not session.can_disarm_trap(entity))
	assert(session.player_pos == Vector2i(2, 2) and session.steps == 0)
	assert(actor.health == health_before - trap.direct_damage)
	assert(actor.overworld_statuses.has(trap.overworld_status_id))
	for member in session.party:
		if member != actor:
			assert(member.health == member.effective_max_health() and member.overworld_statuses.is_empty())
	var damage: Array[Dictionary] = session.take_party_damage_events()
	assert(damage.size() == 1 and damage[0]["hero_index"] == 2)
	assert(session.take_trap_result_message().contains("не удалось"))
	assert(not session.has_pending_trap_choice())
	var event: Dictionary = _request_choice(session)
	assert(not event["choices"].has("disarm") and not event["select_actor"])
	assert(not session.resolve_pending_trap_choice("disarm", 1))
	assert(session.has_pending_trap_choice() and session.trap_random.state == probe.state)
	assert(not session.resolve_pending_trap_choice("cancel"))
	assert(session.trap_random.state == probe.state and session.take_party_damage_events().is_empty())
	assert(JSON.stringify(dungeon.to_dict()) == source)

	var other: DungeonMap = _floor_map()
	var raw: Dictionary = other.to_dict()
	for other_entity in raw["entities"]:
		if other_entity["type"] == "trap":
			other_entity["id"] = entity["id"]
	other = DungeonMap.from_dict(raw)
	assert(session.enter_map(other))
	assert(session.can_disarm_trap(other.entities_at(3, 2)[0]))
	var maps: Dictionary = {dungeon.map_id: dungeon, other.map_id: other}
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, maps)
	assert(restored != null and restored.enter_map(dungeon))
	assert(restored.trap_state(entity) == "armed" and restored.is_trap_revealed(entity))
	assert(not restored.can_disarm_trap(entity))
	assert(restored.trap_random.state == probe.state)
	assert(not _request_choice(restored)["choices"].has("disarm"))
	for member in restored.party:
		member.agility = trap.avoidance_difficulty
		probe.randi_range(1, trap.check_die_sides)
	assert(restored.resolve_pending_trap_choice("avoid"))
	assert(restored.trap_state(entity) == "discharged" and restored.trap_random.state == probe.state)
	assert(restored.take_party_damage_events().is_empty())

	for floor in snapshot["floors"].values():
		floor.erase("failed_trap_disarms")
	var legacy: GameSession = GameSession.from_progress_snapshot(snapshot, maps)
	assert(legacy != null and legacy.enter_map(dungeon))
	assert(legacy.can_disarm_trap(entity))


func _test_lethal_failed_disarm() -> void:
	var dungeon: DungeonMap = _floor_map()
	var entity: Dictionary = dungeon.entities_at(3, 2)[0]
	var trap: TrapDefinition = TrapCatalog.from_entity(entity)
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	var actor: HeroState = session.party[1]
	actor.health = 1
	session.trap_random.seed = _seed_for_roll(trap, 1, 1)
	_request_choice(session)
	assert(not session.resolve_pending_trap_choice("disarm", 1))
	assert(session.party.size() == 1 and session.take_casualty_events().size() == 1)
	assert(session.hero.health == session.hero.effective_max_health())
	assert(session.trap_state(entity) == "armed" and not session.can_disarm_trap(entity))
	assert(not _request_choice(session)["choices"].has("disarm"))
	assert(not session.resolve_pending_trap_choice("cancel"))


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
	var session: GameSession = GameSession.start_for_party(dungeon, ["petushan", "volcha"])
	session.hero.perception = trap.detection_difficulty
	var actor: HeroState = session.party[1]
	actor.agility = trap.disarm_difficulty
	session.trap_random.seed = _seed_for_roll(trap, 1, 1)
	var before: int = actor.health
	assert(session._receive_item("key", 1) == 1)
	assert(not session.move_by(1, 0) and session.last_move_detected_trap)
	_request_choice(session)
	assert(not session.resolve_pending_trap_choice("disarm", 1))
	assert(not session.has_pending_door_trap() and session.trap_state(door) == "armed")
	assert(not session.is_entity_removed(door) and not session.can_disarm_trap(door))
	assert(session.is_door_trap_visible(door) and session.player_pos == Vector2i(2, 2))
	assert(int(session.carried_items["key"]) == 1 and session.steps == 0)
	assert(actor.health == before - trap.direct_damage and session.hero.health == session.hero.effective_max_health())
	assert(session.take_message_events().is_empty())
	assert(session.take_trap_result_message().contains("не удалось"))
	var saved_rng: int = session.trap_random.state
	var event: Dictionary = _request_choice(session)
	assert(not event["choices"].has("disarm") and event["select_actor"])
	assert(not session.resolve_pending_trap_choice("disarm", 0))
	assert(session.trap_random.state == saved_rng and session.has_pending_trap_choice())
	actor.agility = trap.avoidance_difficulty
	assert(not session.resolve_pending_trap_choice("avoid", 1))
	assert(session.take_message_events()[0]["activation"] == "door_trap")
	assert(session.resolve_pending_door_trap())
	assert(session.trap_state(door) == "discharged" and session.is_entity_removed(door))
	assert(actor.health == before - trap.direct_damage)
	assert(int(session.carried_items.get("key", 0)) == 0)
	var events: Array[Dictionary] = session.take_message_events()
	assert(events.size() == 1 and events[0]["activation"] == "door_open")
	assert(events[0]["text"] == "Авторское послание")
	assert(str(events[0]["result_text"]).contains("избежал"))


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


func _test_portrait_choices() -> void:
	var session: GameSession = GameSession.start_for_party(_floor_map(), ["petushan", "volcha"])
	var event: Dictionary = _request_choice(session)
	var dialogue: GameDialogueView = load("res://scenes/game_dialogue_view.tscn").instantiate()
	root.add_child(dialogue)
	dialogue.show_event(event)
	assert(dialogue.has_choices() and dialogue._actor_buttons.size() == 2)
	assert(dialogue._choice_prompt.text == "Кто обезвреживает ловушку?")
	for index in dialogue._actor_buttons.size():
		var button: Button = dialogue._actor_buttons[index]
		var portrait: TextureRect = button.find_child("Portrait", true, false) as TextureRect
		var hp: Label = button.find_child("HP", true, false) as Label
		assert(portrait != null and portrait.texture == session.party[index].definition.portrait)
		assert(hp != null and hp.get_theme_font_size("font_size") == 13)
		assert(hp.has_theme_color_override("font_color"))
	dialogue._actor_buttons[1].pressed.emit()
	assert(dialogue._selected_actor_index == 1)
	assert(dialogue._actor_caption.text == session.party[1].definition.display_name)
	var selected: Array[int] = []
	dialogue.choice_selected.connect(func(_choice: String, index: int) -> void: selected.append(index))
	dialogue._disarm_button.pressed.emit()
	assert(selected == [1])
	event["choices"].erase("disarm")
	event["select_actor"] = false
	dialogue.show_event(event)
	assert(not dialogue._actor_portraits.visible and dialogue._actor_buttons.is_empty())
	assert(not dialogue._disarm_button.visible)
	dialogue.queue_free()


func _test_dialogue() -> void:
	_test_portrait_choices()
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
	assert(dialogue.has_choices() and dialogue._disarm_button.visible)
	session.trap_random.seed = _seed_for_roll(TrapCatalog.get_trap("spikes"), 1, 1)
	dialogue._disarm_button.pressed.emit()
	assert(not dialogue.visible and session.steps == 0)
	editor.call("_on_dpad_down", Vector2i.RIGHT)
	assert(dialogue.has_choices() and not dialogue._disarm_button.visible)
	assert(dialogue._cancel_button.visible and dialogue._avoid_button.visible)
	var after_failure: int = session.trap_random.state
	dialogue._disarm_button.pressed.emit()
	assert(dialogue.has_choices() and session.trap_random.state == after_failure)
	for member in session.party:
		member.agility = TrapCatalog.get_trap("spikes").avoidance_difficulty
	dialogue._avoid_button.pressed.emit()
	await create_timer(0.6).timeout
	assert(session.steps == 1 and session.player_pos == Vector2i(3, 2))
	assert(not dialogue.visible)
	assert(editor.get("_held_dpad_direction") == Vector2i.ZERO)
	editor.queue_free()
	await process_frame
	print("Trap interactions: cancel, disarm, individual saves, opener and UI OK")
	quit()
