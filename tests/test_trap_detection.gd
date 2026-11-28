extends SceneTree


func _initialize() -> void:
	_test_threshold_and_equipment()
	_test_personal_knowledge()
	_test_vision_and_visible_traps()
	_test_door()
	_test_discovery_precedes_chest()
	_test_save_and_return()
	call_deferred("_test_held_movement")


func _map(map_id: String, hidden: bool = true) -> DungeonMap:
	var map_ref := DungeonMap.create_blank(8, 8)
	map_ref.map_id = map_id
	assert(map_ref.place_entity("player_spawn", 2, 2))
	assert(map_ref.place_entity("trap", 3, 2, {"trap_id": "spikes", "hidden": hidden}))
	return map_ref


func _assert_stopped(session: GameSession, entity: Dictionary) -> void:
	var state: int = session.trap_random.state
	var steps: int = session.steps
	var position: Vector2i = session.player_pos
	var hp: Array[int] = []
	for member in session.party:
		hp.append(member.health)
	assert(not session.move_by(1, 0))
	assert(session.last_move_detected_trap)
	assert(session.player_pos == position and session.steps == steps)
	assert(session.trap_random.state == state)
	assert(session.is_trap_revealed(entity))
	assert(not session.is_trap_disarmed(entity))
	assert(not session.has_pending_door_trap())
	assert(session.pending_interaction == null)
	assert(session.take_party_damage_events().is_empty())
	assert(session.take_message_events().is_empty())
	for index in range(hp.size()):
		assert(session.party[index].health == hp[index])


func _test_threshold_and_equipment() -> void:
	var map_ref: DungeonMap = _map("detection_threshold")
	var entity: Dictionary = map_ref.entities_at(3, 2)[0]
	var trap: TrapDefinition = TrapCatalog.from_entity(entity)
	var before: String = JSON.stringify(map_ref.to_dict())
	var below: GameSession = GameSession.start_for(map_ref, "petushan")
	below.hero.perception = trap.detection_difficulty - 1
	assert(below.is_entity_hidden_from_hero(entity))
	assert(below.move_by(1, 0))
	assert(not below.last_move_detected_trap and below.is_trap_disarmed(entity))
	assert(not below.is_trap_known_by(entity, below.hero))

	var equal: GameSession = GameSession.start_for(map_ref, "volcha")
	equal.hero.perception = trap.detection_difficulty
	_assert_stopped(equal, entity)
	assert(equal.is_trap_known_by(entity, equal.hero))
	assert(not equal.is_entity_hidden_from_hero(entity))
	assert(equal.revealed_traps.is_empty())
	assert(equal.move_by(-1, 0))
	assert(equal.move_by(1, 0))
	assert(not equal.move_by(1, 0))
	assert(equal.has_pending_trap_choice())
	assert(equal.resolve_pending_trap_choice("avoid"))
	assert(not equal.last_move_detected_trap and equal.is_trap_disarmed(entity))

	var equipped: GameSession = GameSession.start_for(map_ref, "petushan")
	var helmet: ItemDefinition = ItemCatalog.get_item("helmet_miner")
	equipped.hero.perception = trap.detection_difficulty - helmet.perception_bonus
	assert(equipped.hero.effective_perception() < trap.detection_difficulty)
	assert(equipped._receive_item(helmet.item_id, 1) == 1)
	assert(equipped.equip_item(helmet.item_id))
	assert(equipped.hero.effective_perception() == trap.detection_difficulty)
	_assert_stopped(equipped, entity)
	assert(equipped.unequip_item(helmet.item_id))
	assert(equipped.is_trap_known_by(entity, equipped.hero))
	assert(not equipped.is_entity_hidden_from_hero(entity))
	assert(JSON.stringify(map_ref.to_dict()) == before)


func _test_personal_knowledge() -> void:
	var map_ref: DungeonMap = _map("detection_party")
	var entity: Dictionary = map_ref.entities_at(3, 2)[0]
	var difficulty: int = TrapCatalog.from_entity(entity).detection_difficulty
	var session: GameSession = GameSession.start_for(map_ref, "petushan")
	assert(session.add_party_member("petushan"))
	assert(session.add_party_member("volcha"))
	assert(session.add_party_member("burolom"))
	var members: Array[HeroState] = session.party_members()
	members[0].perception = difficulty - 1
	members[1].perception = difficulty
	members[2].perception = difficulty + 1
	members[3].perception = difficulty + 1
	members[3].health = 0
	_assert_stopped(session, entity)
	assert(not session.is_trap_known_by(entity, members[0]))
	assert(session.is_trap_known_by(entity, members[1]))
	assert(session.is_trap_known_by(entity, members[2]))
	assert(not session.is_trap_known_by(entity, members[3]))
	session.party.reverse()
	assert(session.is_trap_known_by(entity, members[1]))
	assert(not session.is_trap_known_by(entity, members[0]))
	assert(session.is_trap_revealed(entity))
	members[1].health = 0
	members[2].health = 0
	assert(not session.is_trap_revealed(entity))
	assert(session.is_entity_hidden_from_hero(entity))
	assert(session.move_by(1, 0))
	assert(session.is_trap_disarmed(entity))


func _test_vision_and_visible_traps() -> void:
	var map_ref: DungeonMap = _map("detection_vision")
	var entity: Dictionary = map_ref.entities_at(3, 2)[0]
	var session: GameSession = GameSession.start_for(map_ref, "petushan")
	session.hero.perception = TrapCatalog.from_entity(entity).detection_difficulty - 1
	session.hero.vision_bonus = 1
	session.hero.vision_phases = 1
	assert(not session.is_entity_hidden_from_hero(entity))
	assert(not session.is_trap_known_by(entity, session.hero))
	session.hero.advance_phase_effects()
	assert(session.is_entity_hidden_from_hero(entity))
	assert(session.move_by(1, 0))
	assert(session.is_trap_disarmed(entity))

	var visible_map: DungeonMap = _map("detection_visible", false)
	var visible: Dictionary = visible_map.entities_at(3, 2)[0]
	var aware: GameSession = GameSession.start_for(visible_map, "burolom")
	assert(not aware.is_entity_hidden_from_hero(visible))
	assert(not aware.move_by(1, 0))
	assert(aware.has_pending_trap_choice())
	assert(aware.resolve_pending_trap_choice("avoid"))
	assert(not aware.last_move_detected_trap and aware.is_trap_disarmed(visible))


func _test_door() -> void:
	var map_ref := DungeonMap.create_blank(8, 8)
	assert(map_ref.place_entity("player_spawn", 2, 2))
	assert(map_ref.place_entity("door", 3, 2))
	var door: Dictionary = map_ref.entities_at(3, 2)[0]
	assert(map_ref.attach_door_trap(str(door["id"]), "door_crossbow"))
	var trap: TrapDefinition = TrapCatalog.from_door(door)
	var session: GameSession = GameSession.start_for_party(map_ref, ["petushan", "burolom"])
	session.party[0].perception = trap.detection_difficulty - 1
	session.party[1].perception = trap.detection_difficulty
	assert(not session.is_door_trap_visible(door))
	assert(not session.move_by(1, 0))
	assert(not session.has_pending_door_trap())
	assert(not session.is_trap_disarmed(door))
	assert(not session.is_entity_removed(door))
	assert(session._receive_item("key", 1) == 1)
	_assert_stopped(session, door)
	assert(session.is_door_trap_visible(door))
	assert(session.is_trap_known_by(door, session.party[1]))
	assert(not session.is_trap_known_by(door, session.party[0]))
	assert(session.carried_items.get("key", 0) == 1)
	assert(not session.is_entity_removed(door))
	assert(not session.move_by(1, 0))
	assert(not session.last_move_detected_trap and session.has_pending_trap_choice())
	assert(session.take_message_events()[0]["activation"] == "trap_choice")
	assert(not session.resolve_pending_trap_choice("avoid"))
	assert(session.has_pending_door_trap())
	assert(session.take_message_events().size() == 1)
	assert(session.resolve_pending_door_trap())
	assert(session.is_trap_disarmed(door) and session.is_entity_removed(door))
	assert(session.carried_items.get("key", 0) == 0)


func _test_discovery_precedes_chest() -> void:
	var map_ref: DungeonMap = _map("detection_chest")
	var entity: Dictionary = map_ref.entities_at(3, 2)[0]
	assert(map_ref.place_entity("chest", 3, 2))
	var chest: Dictionary = map_ref.entities_at(3, 2)[1]
	assert(map_ref.set_chest_contents(str(chest["id"]), ["gold"], 10, false, false, {"gold": 10}))
	var session: GameSession = GameSession.start_for(map_ref, "volcha")
	session.hero.perception = TrapCatalog.from_entity(entity).detection_difficulty
	var gold: int = session.hero.gold
	_assert_stopped(session, entity)
	assert(not session.is_chest_open(chest))
	assert(session.hero.gold == gold)
	assert(not session.move_by(1, 0))
	assert(session.resolve_pending_trap_choice("avoid"))
	assert(session.is_chest_open(chest))
	assert(session.hero.gold == gold + 10)


func _test_save_and_return() -> void:
	var first: DungeonMap = _map("detection_first")
	var second: DungeonMap = _map("detection_second")
	var entity: Dictionary = first.entities_at(3, 2)[0]
	var other_entity: Dictionary = second.entities_at(3, 2)[0]
	other_entity["id"] = entity["id"]
	var session: GameSession = GameSession.start_for_party(first, ["petushan", "volcha"])
	var difficulty: int = TrapCatalog.from_entity(entity).detection_difficulty
	session.party[0].perception = difficulty - 1
	session.party[1].perception = difficulty
	_assert_stopped(session, entity)
	assert(session.enter_map(second))
	assert(not session.is_trap_revealed(other_entity))
	assert(session.enter_map(first))
	assert(session.is_trap_known_by(entity, session.party[1]))
	assert(not session.is_trap_known_by(entity, session.party[0]))
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var maps: Dictionary = {first.map_id: first, second.map_id: second}
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, maps)
	assert(restored != null)
	assert(restored.is_trap_revealed(entity) and not restored.is_trap_disarmed(entity))
	assert(restored.is_trap_known_by(entity, restored.party[1]))
	assert(not restored.is_trap_known_by(entity, restored.party[0]))
	assert(not restored.move_by(1, 0))
	assert(restored.resolve_pending_trap_choice("avoid"))
	assert(not restored.last_move_detected_trap)
	for member in snapshot["party"]["active_heroes"]:
		member.erase("known_traps_by_map")
	var legacy: GameSession = GameSession.from_progress_snapshot(snapshot, maps)
	assert(legacy != null and not legacy.is_trap_revealed(entity))


func _test_held_movement() -> void:
	var editor: Node = load("res://scenes/editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	var map_ref: DungeonMap = _map("detection_input")
	assert(map_ref.place_entity("trap", 2, 3, {"trap_id": "spikes"}))
	editor.call("_set_map", map_ref)
	var hero_ids: Array[String] = ["volcha"]
	editor.set("_test_party_ids", hero_ids)
	editor.call("_start_play_mode")
	var session: GameSession = editor.get("game_session") as GameSession
	assert(session != null)
	session.hero.perception = TrapCatalog.get_trap("spikes").detection_difficulty
	var press := InputEventKey.new()
	press.keycode = KEY_RIGHT
	press.pressed = true
	editor.call("_input", press)
	assert(session.last_move_detected_trap)
	assert(editor.get("_held_move_keys").is_empty())
	assert(editor.get("_held_dpad_direction") == Vector2i.ZERO)
	press.echo = true
	editor.call("_input", press)
	await process_frame
	assert(session.player_pos == Vector2i(2, 2) and session.steps == 0)
	press.echo = false
	press.pressed = false
	editor.call("_input", press)
	editor.call("_on_dpad_down", Vector2i.DOWN)
	assert(session.last_move_detected_trap)
	assert(editor.get("_held_dpad_direction") == Vector2i.ZERO)
	editor.call("_advance_held_move")
	await process_frame
	assert(session.player_pos == Vector2i(2, 2) and session.steps == 0)
	editor.call("_on_dpad_up", Vector2i.DOWN)
	editor.call("_on_dpad_down", Vector2i.DOWN)
	editor.call("_on_dpad_up", Vector2i.DOWN)
	var dialogue: GameDialogueView = editor.get("_game_dialogue") as GameDialogueView
	assert(dialogue.has_choices() and session.has_pending_trap_choice())
	assert(session.player_pos == Vector2i(2, 2))
	dialogue._avoid_button.pressed.emit()
	assert(session.player_pos == Vector2i(2, 3) and session.steps == 1)
	await create_timer(0.6).timeout
	editor.queue_free()
	await process_frame
	print("Trap detection: effective perception, knowledge, doors, saves and held input OK")
	quit()
