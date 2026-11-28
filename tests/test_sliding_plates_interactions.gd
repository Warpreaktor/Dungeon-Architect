extends SceneTree

const START := Vector2i(2, 2)
const PLATE := Vector2i(3, 2)
const WALL := Vector2i(4, 4)
const DESTINATION := Vector2i(5, 4)
const NEW_WALL := Vector2i(6, 6)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_discovery_cancel_and_control()
	_test_hidden_entry()
	_test_failed_disarm_and_crossing()
	_test_blocked_activation()
	_test_saved_controlled_state()
	_test_floor_roundtrips()
	await _test_held_input()
	await _test_visual_playback()
	print("Sliding plates: interactions, floor saves, knowledge and visual playback OK")
	quit()


func _map() -> DungeonMap:
	var data := DungeonMap.create_blank(9, 9)
	assert(data.place_entity("player_spawn", START.x, START.y))
	assert(data.place_entity("stairs_down", 7, 7))
	assert(data.set_terrain(WALL.x, WALL.y, "wall"))
	assert(data.place_entity(SlidingPlates.TRIGGER, PLATE.x, PLATE.y))
	assert(data.cycle_sliding_plates_mark(WALL).is_empty())
	assert(data.cycle_sliding_plates_mark(NEW_WALL).is_empty())
	assert(not data.place_entity("trap", 2, 3, {"trap_id": SlidingPlates.TRIGGER}))
	return data


func _entity(data: DungeonMap) -> Dictionary:
	return data.entities_at(PLATE.x, PLATE.y)[0]


func _definition() -> TrapDefinition:
	return TrapCatalog.get_trap(SlidingPlates.TRIGGER)


func _session(data: DungeonMap, detected: bool = true) -> GameSession:
	var session := GameSession.start_for(data, "volcha")
	assert(session != null)
	session.hero.perception = _definition().detection_difficulty if detected else 0
	return session


func _assert_configuration(session: GameSession, shifted: bool) -> void:
	assert(session.map_data.sliding_plates_is_shifted() == shifted)
	assert(session.can_enter(WALL) == shifted)
	assert(session.can_enter(DESTINATION) != shifted)
	assert(session.can_enter(NEW_WALL) != shifted)
	assert(session.can_enter(PLATE))


func _seed_for_disarm(success: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1000):
		rng.seed = seed_value
		if (rng.randi_range(1, _definition().check_die_sides) > 1) == success:
			return seed_value
	assert(false)
	return 0


func _discover(session: GameSession) -> void:
	var result := session.execute(GameAction.move(Vector2i.RIGHT))
	assert(result.discovered_trap and not result.moved)
	assert(result.terrain_changes.is_empty() and result.messages.is_empty() and result.trap_visuals.is_empty())
	assert(session.player_pos == START and session.steps == 0)
	assert(session.is_trap_known_by(_entity(session.map_data), session.hero))
	assert(not session.is_entity_hidden_from_hero(_entity(session.map_data)))
	_assert_configuration(session, false)


func _request_choice(session: GameSession) -> Dictionary:
	var result := session.execute(GameAction.move(Vector2i.RIGHT))
	assert(not result.moved and not result.discovered_trap)
	assert(result.status == GameActionResult.Status.AWAITING_INPUT)
	assert(result.messages.size() == 1)
	var event: Dictionary = result.messages[0]
	assert(event["activation"] == "trap_choice" and event["icon_id"] == SlidingPlates.TRIGGER)
	assert(event["choices"].has("cancel") and event["choices"].has("avoid"))
	return event


func _choose(session: GameSession, choice: String, actor: int = -1) -> GameActionResult:
	return session.execute(GameAction.choose(session.pending_interaction.id, choice, actor))


func _disarm(session: GameSession) -> void:
	_discover(session)
	_request_choice(session)
	session.hero.agility = _definition().disarm_difficulty
	session.trap_random.seed = _seed_for_disarm(true)
	var result := _choose(session, "disarm")
	assert(result.accepted and not result.moved and result.damage.is_empty())
	assert(result.terrain_changes.is_empty() and result.trap_visuals.is_empty() and session.player_pos == START)
	assert(session.trap_state(_entity(session.map_data)) == "controlled")
	assert(not session.can_disarm_trap(_entity(session.map_data)))
	_assert_configuration(session, false)


func _test_discovery_cancel_and_control() -> void:
	var data := _map()
	var original := JSON.stringify(data.to_dict())
	var session := _session(data)
	var entity := _entity(data)
	assert(TrapCatalog.from_entity(entity) == _definition())
	assert(SlidingPlates.TRIGGER in TrapCatalog.list_ids("floor"))
	assert(SlidingPlates.TRIGGER not in TrapCatalog.list_ids("floor", false))
	assert(session.is_entity_hidden_from_hero(entity))
	var rng_before := session.trap_random.state
	_discover(session)
	assert(session.trap_random.state == rng_before)
	var event := _request_choice(session)
	assert(event["choices"]["disarm"] == "Да" and event["choices"]["cancel"] == "Нет")
	var before := session.floor_state_snapshot()
	var party_before := session.party_state_snapshot()
	var cancelled := _choose(session, "cancel")
	assert(cancelled.accepted and not cancelled.moved and session.pending_interaction == null and cancelled.trap_visuals.is_empty())
	assert(session.floor_state_snapshot() == before and session.party_state_snapshot() == party_before)
	assert(session.trap_random.state == rng_before and session.steps == 0)
	assert(not session.execute(GameAction.switch_sliding_plates(str(entity["id"]))).accepted)
	_request_choice(session)
	session.hero.agility = _definition().disarm_difficulty
	session.trap_random.seed = _seed_for_disarm(true)
	assert(_choose(session, "disarm").accepted)
	assert(session.trap_state(entity) == "controlled")
	_assert_configuration(session, false)
	assert(not session.execute(GameAction.switch_sliding_plates(str(entity["id"]))).accepted)
	rng_before = session.trap_random.state
	for index in range(12):
		var result := session.execute(GameAction.move(Vector2i.RIGHT))
		assert(result.accepted and result.moved and result.stop_movement)
		assert(result.terrain_changes.size() == 3 and result.damage.is_empty())
		_assert_switch_event(result, index % 2 == 0)
		_assert_configuration(session, index % 2 == 0)
		assert(session.trap_state(entity) == "controlled" and session.pending_interaction == null)
		assert(session.execute(GameAction.move(Vector2i.LEFT)).moved)
	assert(session.trap_random.state == rng_before)
	assert(JSON.stringify(data.to_dict()) == original and JSON.stringify(session.map_data.to_dict()) == original)
	assert(session.execute(GameAction.move(Vector2i.RIGHT)).moved)
	assert(session.execute(GameAction.switch_sliding_plates(str(entity["id"]))).accepted)
	_assert_configuration(session, false)


func _test_hidden_entry() -> void:
	var data := _map()
	var session := _session(data, false)
	var entity := _entity(data)
	session.hero.agility = _definition().avoidance_difficulty
	var health: int = session.hero.health
	var rng_before := session.trap_random.state
	var result := session.execute(GameAction.move(Vector2i.RIGHT))
	assert(result.moved and not result.discovered_trap and result.terrain_changes.size() == 3)
	_assert_switch_event(result, true)
	assert(result.damage.is_empty() and session.trap_random.state == rng_before)
	assert(session.hero.health == health)
	assert(session.trap_state(entity) == "discharged" and session.is_trap_revealed(entity))
	assert(not session.is_trap_known_by(entity, session.hero))
	_assert_configuration(session, true)
	assert(not session.execute(GameAction.switch_sliding_plates(str(entity["id"]))).accepted)
	assert(session.execute(GameAction.move(Vector2i.LEFT)).moved)
	result = session.execute(GameAction.move(Vector2i.RIGHT))
	assert(result.moved and result.terrain_changes.is_empty() and session.pending_interaction == null and result.trap_visuals.is_empty())
	_assert_configuration(session, true)


func _test_failed_disarm_and_crossing() -> void:
	var data := _map()
	var session := GameSession.start_for_party(data, ["petushan", "volcha"])
	assert(session != null)
	var entity := _entity(data)
	var trap := _definition()
	session.party[0].perception = 0
	session.party[1].perception = trap.detection_difficulty
	var detection := session.execute(GameAction.move(Vector2i.RIGHT))
	assert(detection.discovered_trap and not detection.moved)
	assert(not session.is_trap_known_by(entity, session.party[0]))
	assert(session.is_trap_known_by(entity, session.party[1]))
	_request_choice(session)
	for member in session.party:
		member.agility = trap.disarm_difficulty + trap.avoidance_difficulty
	var health: int = session.party[1].health
	session.trap_random.seed = _seed_for_disarm(false)
	var failed := _choose(session, "disarm", 1)
	assert(failed.accepted and not failed.moved and failed.damage.is_empty() and failed.trap_visuals.is_empty())
	assert(session.party[1].health == health and session.trap_state(entity) == "armed")
	assert(not session.can_disarm_trap(entity) and session.is_trap_revealed(entity))
	_assert_configuration(session, false)
	var event := _request_choice(session)
	assert(not event["choices"].has("disarm"))
	var pending_id: int = session.pending_interaction.id
	var rng_before := session.trap_random.state
	assert(not session.execute(GameAction.choose(pending_id, "disarm", 0)).accepted)
	assert(session.pending_interaction.id == pending_id and session.trap_random.state == rng_before)
	var avoided := _choose(session, "avoid")
	assert(avoided.moved and avoided.terrain_changes.is_empty() and avoided.damage.is_empty() and avoided.trap_visuals.is_empty())
	assert(session.trap_state(entity) == "armed")
	_assert_configuration(session, false)
	assert(session.execute(GameAction.move(Vector2i.LEFT)).moved)
	session.party[0].agility = 0
	_request_choice(session)
	var triggered := _choose(session, "avoid")
	assert(triggered.moved and triggered.terrain_changes.size() == 3 and triggered.damage.is_empty())
	assert(session.trap_state(entity) == "discharged")
	_assert_configuration(session, true)


func _test_blocked_activation() -> void:
	var data := _map()
	var session := _session(data, false)
	var entity := _entity(data)
	var loot: Array[Dictionary] = [{"item_id": "gold", "quantity": 1}]
	session._append_ground_loot(DESTINATION, loot)
	var blocked := session.execute(GameAction.move(Vector2i.RIGHT))
	assert(blocked.moved and blocked.terrain_changes.is_empty() and blocked.trap_visuals.is_empty())
	assert(session.trap_state(entity) == "armed" and not session.is_trap_disarmed(entity))
	_assert_configuration(session, false)
	var container := session.ground_container_at(DESTINATION)
	session.player_pos = DESTINATION
	assert(session.take_ground_loot(str(container["id"]), 0) == 1)
	session.player_pos = START
	_request_choice(session)
	session.hero.agility = 0
	assert(_choose(session, "avoid").terrain_changes.size() == 3)
	assert(session.trap_state(entity) == "discharged")
	_assert_configuration(session, true)

	var controlled := _session(data)
	_disarm(controlled)
	controlled._append_ground_loot(DESTINATION, loot)
	blocked = controlled.execute(GameAction.move(Vector2i.RIGHT))
	assert(blocked.moved and blocked.stop_movement and blocked.terrain_changes.is_empty() and blocked.trap_visuals.is_empty())
	assert(controlled.trap_state(entity) == "controlled")
	_assert_configuration(controlled, false)


func _test_saved_controlled_state() -> void:
	var data := _map()
	var session := _session(data)
	_disarm(session)
	assert(session.execute(GameAction.move(Vector2i.RIGHT)).moved)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored := GameSession.from_progress_snapshot(snapshot, {data.map_id: data})
	assert(restored != null and restored.player_pos == PLATE and not restored.has_trap_visual_events())
	var entity := _entity(restored.map_data)
	assert(restored.trap_state(entity) == "controlled")
	assert(restored.is_trap_known_by(entity, restored.hero))
	_assert_configuration(restored, true)
	assert(restored.execute(GameAction.move(Vector2i.LEFT)).moved)
	assert(restored.execute(GameAction.move(Vector2i.RIGHT)).terrain_changes.size() == 3)
	_assert_configuration(restored, false)


func _test_held_input() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	var storage = preload("res://tests/editor_test_storage.gd").new()
	storage.configure(editor)
	editor.set("_campaign_library", CampaignLibrary.new(storage.directory + "_campaigns"))
	root.add_child(editor)
	await process_frame
	var data := _map()
	editor.call("_set_map", data)
	var ids: Array[String] = ["volcha"]
	editor.set("_test_party_ids", ids)
	editor.call("_start_play_mode")
	var session: GameSession = editor.get("game_session")
	assert(session != null)
	session.hero.perception = _definition().detection_difficulty
	var press := InputEventKey.new()
	press.keycode = KEY_RIGHT
	press.pressed = true
	editor.call("_input", press)
	assert(session.last_move_detected_trap and editor.get("_held_move_keys").is_empty())
	press.echo = true
	editor.call("_input", press)
	await process_frame
	assert(session.player_pos == START and session.steps == 0)
	press.echo = false
	press.pressed = false
	editor.call("_input", press)
	editor.call("_on_dpad_down", Vector2i.RIGHT)
	var dialogue: GameDialogueView = editor.get("_game_dialogue")
	assert(dialogue.has_choices() and session.has_pending_trap_choice())
	assert(editor.get("_held_dpad_direction") == Vector2i.ZERO)
	session.hero.agility = _definition().disarm_difficulty
	session.trap_random.seed = _seed_for_disarm(true)
	dialogue._disarm_button.pressed.emit()
	assert(session.trap_state(_entity(session.map_data)) == "controlled")
	editor.call("_on_dpad_up", Vector2i.RIGHT)
	editor.call("_on_dpad_down", Vector2i.RIGHT)
	assert(session.player_pos == PLATE and session.map_data.sliding_plates_is_shifted())
	assert(editor.get("_held_dpad_direction") == Vector2i.ZERO)
	var canvas: DungeonCanvas = editor.get("_canvas")
	assert(editor.get("_trap_playback_active"))
	await create_timer(0.6).timeout
	editor.call("_advance_held_move")
	assert(session.player_pos == PLATE and session.steps == 1)
	if editor.get("_trap_playback_active"):
		await canvas.trap_playback_finished
	editor.call("_on_dpad_up", Vector2i.RIGHT)
	editor.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	storage.cleanup()


func _assert_switch_event(result: GameActionResult, shifted: bool) -> void:
	assert(result.trap_visuals.size() == 1)
	var event: Dictionary = result.trap_visuals[0]
	assert(event["effect"] == "sliding_plates" and event["cell"] == PLATE)
	assert(event["changes"] == result.terrain_changes)
	assert(event["movements"] == [
		{"from": WALL if shifted else DESTINATION, "to": DESTINATION if shifted else WALL},
		{"from": NEW_WALL, "to": NEW_WALL, "appearing": shifted}
	])


func _test_floor_roundtrips() -> void:
	for status in ["armed_unattempted", "armed", "controlled_a", "controlled_b", "discharged"]:
		var first: DungeonMap = _map()
		var second := DungeonMap.create_blank(9, 9)
		assert(second.place_entity("player_spawn", START.x, START.y))
		assert(first.place_entity("stairs_down", 2, 3))
		for stair in first.entities_at(2, 3):
			assert(first.set_exit_target(str(stair["id"]), second.map_id))
		var original: String = JSON.stringify(first.to_dict())
		first = DungeonMap.from_dict(JSON.parse_string(original))
		assert(first != null)
		original = JSON.stringify(first.to_dict())
		var maps: Dictionary = {first.map_id: first, second.map_id: second}
		var session := GameSession.start_for_party(first, ["petushan", "volcha"])
		var entity := _entity(first)
		var trigger_id: String = entity["id"]
		var trap := _definition()
		var shifted: bool = status in ["controlled_b", "discharged"]
		var controlled: bool = status in ["controlled_a", "controlled_b"]
		session.party[0].perception = 0
		session.party[1].perception = trap.detection_difficulty
		if status == "discharged":
			session.party[1].perception = 0
			_assert_switch_event(session.execute(GameAction.move(Vector2i.RIGHT)), true)
			assert(session.execute(GameAction.move(Vector2i.LEFT)).moved)
		else:
			assert(session.execute(GameAction.move(Vector2i.RIGHT)).discovered_trap)
			if status != "armed_unattempted":
				_request_choice(session)
				session.party[1].agility = trap.disarm_difficulty
				session.trap_random.seed = _seed_for_disarm(controlled)
				assert(_choose(session, "disarm", 1).trap_visuals.is_empty())
			if shifted:
				_assert_switch_event(session.execute(GameAction.move(Vector2i.RIGHT)), true)
				assert(session.execute(GameAction.move(Vector2i.LEFT)).moved)
		var expected_state: String = "controlled" if controlled else ("armed" if status.begins_with("armed") else status)
		assert(session.trap_state(entity) == expected_state)
		assert(session.execute(GameAction.move(Vector2i.DOWN)).moved)
		assert(session.execute(GameAction.enter_floor(second)).accepted)
		assert(session.map_data.map_id == second.map_id and not session.has_trap_visual_events())
		var directory: String = "user://da_sliding_save_%s_%d" % [status, Time.get_ticks_usec()]
		var store := ProgressSaveStore.new(directory, directory.path_join("campaigns"))
		assert(store.save_game(session, maps), store.last_error)
		var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(ProgressSaveStore.SAVE_FILE)))
		assert(snapshot["floors"][first.map_id]["sliding_plates_trigger_id"] == trigger_id)
		assert(not snapshot["floors"][second.map_id].has("sliding_plates_trigger_id"))
		var invalid: Dictionary = snapshot.duplicate(true)
		invalid["floors"][first.map_id]["sliding_plates_trigger_id"] = "unknown_trigger"
		assert(GameSession.from_progress_snapshot(invalid, maps) == null)
		var legacy: Dictionary = snapshot.duplicate(true)
		legacy["floors"][first.map_id].erase("sliding_plates_trigger_id")
		assert(GameSession.from_progress_snapshot(legacy, maps) != null)
		var loaded: GameSession = store.load_game(maps)
		assert(loaded != null and loaded.map_data.map_id == second.map_id)
		assert(not loaded.is_trap_known_by(entity, loaded.party[1]))
		assert(loaded.execute(GameAction.move(Vector2i.LEFT)).moved)
		assert(loaded.execute(GameAction.move(Vector2i.RIGHT)).moved and loaded.has_stairs_up())
		var returned: GameActionResult = loaded.execute(GameAction.enter_floor(first))
		assert(returned.accepted and returned.trap_visuals.is_empty() and returned.terrain_changes.is_empty())
		assert(loaded.player_pos == Vector2i(2, 3))
		_assert_configuration(loaded, shifted)
		assert(loaded.trap_state(entity) == expected_state)
		assert(loaded.can_disarm_trap(entity) == (status == "armed_unattempted"))
		assert(not loaded.is_trap_known_by(entity, loaded.party[0]))
		assert(loaded.is_trap_known_by(entity, loaded.party[1]) == (status != "discharged"))
		assert(loaded.failed_trap_disarms.has(trigger_id) == (status == "armed"))
		assert(loaded.execute(GameAction.move(Vector2i.UP)).moved)
		if controlled:
			_assert_switch_event(loaded.execute(GameAction.move(Vector2i.RIGHT)), not shifted)
			_assert_configuration(loaded, not shifted)
		elif status == "discharged":
			assert(loaded.execute(GameAction.move(Vector2i.RIGHT)).trap_visuals.is_empty())
			_assert_configuration(loaded, true)
		else:
			assert(_request_choice(loaded)["choices"].has("disarm") == (status == "armed_unattempted"))
			assert(_choose(loaded, "cancel").trap_visuals.is_empty())
			_assert_configuration(loaded, false)
		assert(JSON.stringify(first.to_dict()) == original and not first.sliding_plates_is_shifted())
		assert(DirAccess.remove_absolute(directory.path_join(ProgressSaveStore.SAVE_FILE)) == OK)
		assert(DirAccess.remove_absolute(directory) == OK)


func _test_visual_playback() -> void:
	for playback in ["normal", "fast", "skip", "cancel"]:
		var data := _map()
		var vanished := Vector2i(2, 5)
		assert(data.set_terrain(vanished.x, vanished.y, "wall"))
		for operation in SlidingPlates.MARK_CYCLE:
			assert(data.cycle_sliding_plates_mark(vanished).is_empty())
		var session := _session(data, false)
		session.debug_open_map = true
		session._refresh_visibility()
		var canvas := DungeonCanvas.new()
		root.add_child(canvas)
		canvas.size = Vector2(800, 600)
		canvas.set_game_session(session)
		await process_frame
		var result := session.execute(GameAction.move(Vector2i.RIGHT))
		assert(result.trap_visuals.size() == 1 and result.terrain_changes.size() == 4)
		var event: Dictionary = result.trap_visuals[0]
		assert(event["movements"].has({"from": vanished, "to": vanished, "appearing": false}))
		assert(event["movements"].has({"from": NEW_WALL, "to": NEW_WALL, "appearing": true}))
		assert(event["movements"].has({"from": WALL, "to": DESTINATION}))
		assert(session.can_enter(vanished))
		var expected: Dictionary = session.progress_snapshot()
		assert(canvas.play_trap_visuals(result.trap_visuals, result.position))
		assert(canvas.is_player_moving() and canvas._sliding_progress == 0.0)
		assert(canvas._sliding_changes == result.terrain_changes)
		assert(not canvas.play_trap_visuals(result.trap_visuals, result.position))
		_assert_configuration(session, true)
		if playback == "skip":
			canvas.skip_trap_playback()
		elif playback == "cancel":
			canvas.set_map(data)
		else:
			if playback == "fast":
				canvas._trap_playback.set_speed_scale(8.0)
			await canvas.trap_playback_finished
			assert(canvas._sliding_sound != null and canvas._sliding_sound.bus == &"SFX")
		assert(not canvas.is_player_moving() and canvas._sliding_changes.is_empty() and canvas._sliding_progress < 0.0)
		assert(canvas._sliding_sound == null or not canvas._sliding_sound.playing)
		assert(session.progress_snapshot() == expected and not session.has_trap_visual_events())
		canvas.queue_free()
		await process_frame
		await create_timer(0.15).timeout
