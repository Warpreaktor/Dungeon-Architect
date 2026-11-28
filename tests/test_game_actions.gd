extends SceneTree


func _initialize() -> void:
	_test_portal_and_floor()
	_test_battle_completion()
	_test_trap_choices()
	print("Game actions: exploration, choices, combat and save boundaries OK")
	quit()


func _map() -> DungeonMap:
	var dungeon := DungeonMap.create_blank(9, 9)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	return dungeon


func _session(dungeon: DungeonMap) -> GameSession:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4277
	return GameSession.start_for(dungeon, "volcha", false, rng)


func _test_portal_and_floor() -> void:
	var dungeon := _map()
	var next_floor := _map()
	assert(dungeon.place_entity("chest", 2, 3))
	var chest: Dictionary = dungeon.entities_at(2, 3)[0]
	assert(dungeon.set_chest_contents(str(chest["id"]), ["gold"], 13))
	assert(dungeon.place_entity("portal_local", 3, 2, {"color": "blue"}))
	assert(dungeon.place_entity("portal_local", 6, 6, {"color": "blue"}))
	assert(dungeon.place_entity("stairs_down", 7, 6))
	var stairs: Dictionary = dungeon.entities_at(7, 6)[0]
	assert(dungeon.set_stairs_target(str(stairs["id"]), next_floor.map_id))
	var session := _session(dungeon)
	var chest_result: GameActionResult = session.execute(GameAction.move(Vector2i.DOWN))
	assert(chest_result.accepted and session.is_chest_open(chest) and session.hero.gold == 13)
	assert(chest_result.messages.size() == 1 and session.take_message_events().is_empty())
	assert(session.execute(GameAction.move(Vector2i.UP)).accepted)
	var portal: GameActionResult = session.execute(GameAction.move(Vector2i.RIGHT))
	assert(portal.status == GameActionResult.Status.AWAITING_INPUT and portal.moved)
	assert(portal.messages[0]["interaction_id"] == portal.interaction_id)
	var steps: int = session.steps
	var rng_state: int = session.trap_random.state
	assert(not session.execute(GameAction.move(Vector2i.RIGHT)).accepted)
	assert(not session.execute(GameAction.choose(portal.interaction_id + 1, "enter_portal")).accepted)
	assert(not session.execute(GameAction.choose(portal.interaction_id, "invalid")).accepted)
	assert(session.progress_snapshot().is_empty())
	assert(session.steps == steps and session.trap_random.state == rng_state)
	var cancel: GameActionResult = session.execute(GameAction.choose(portal.interaction_id, "cancel"))
	assert(cancel.accepted and not cancel.moved and session.player_pos == Vector2i(3, 2))
	assert(session.execute(GameAction.move(Vector2i.LEFT)).accepted)
	var again: GameActionResult = session.execute(GameAction.move(Vector2i.RIGHT))
	assert(again.interaction_id != portal.interaction_id)
	assert(not session.execute(GameAction.choose(portal.interaction_id, "enter_portal")).accepted)
	var arrival: GameActionResult = session.execute(GameAction.choose(again.interaction_id, "enter_portal"))
	assert(arrival.accepted and arrival.moved and session.player_pos == Vector2i(6, 6))
	assert(session.steps == steps + 2 and session.pending_interaction == null)
	assert(session.execute(GameAction.move(Vector2i.RIGHT)).status == GameActionResult.Status.FLOOR_EXIT)
	assert(session.execute(GameAction.enter_floor(next_floor)).accepted)
	assert(session.map_data == next_floor and session.hero.gold == 13)
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(session.progress_snapshot()))
	var restored: GameSession = GameSession.from_progress_snapshot(snapshot, {dungeon.map_id: dungeon, next_floor.map_id: next_floor})
	assert(restored != null and restored.hero.gold == 13)
	assert(restored.floor_state_snapshot(dungeon.map_id)["chests"].has(str(chest["id"])))


func _test_battle_completion() -> void:
	var dungeon := _map()
	assert(dungeon.place_entity("monster", 3, 2, {"monster_id": "skeleton"}))
	var monster: Dictionary = dungeon.entities_at(3, 2)[0]
	assert(dungeon.set_monster_loot(str(monster["id"]), ["gold"], 17, false))
	var session := _session(dungeon)
	assert(session._receive_item("sword", 1) == 1)
	session.hero.strength = 200
	session.hero.agility = 200
	var encounter: GameActionResult = session.execute(GameAction.move(Vector2i.RIGHT))
	assert(encounter.status == GameActionResult.Status.BATTLE_STARTED)
	assert(session.active_combat != null and session.progress_snapshot().is_empty())
	var combat: CombatSession = session.active_combat
	assert(session.execute(GameAction.new(GameAction.Kind.BATTLE_PREPARE)).accepted)
	var ability: String = MonsterWeaponStrike.ability_id(session.hero.equipped_weapon_id)
	var completion: GameActionResult
	for index in range(20):
		var prepared: GameActionResult = session.execute(GameAction.new(GameAction.Kind.BATTLE_NEXT))
		if prepared.battle_finished:
			completion = prepared
			break
		var turn: GameActionResult = session.execute(GameAction.battle_turn("enemy", ability) if prepared.battle_next_actor == "hero" else GameAction.battle_turn("", ""))
		assert(turn.accepted)
		if turn.battle_finished:
			completion = turn
			break
	assert(completion != null and combat.is_victory)
	assert(session.active_combat == null and not session.has_pending_encounter())
	assert(session.is_entity_removed(monster) and session.hero.gold == 17)
	assert(session.player_pos == Vector2i(3, 2) and session.loot_victories == 1)
	assert(not session.execute(GameAction.battle_turn("enemy", ability)).accepted)
	assert(session.hero.gold == 17 and session.loot_victories == 1)


func _test_trap_choices() -> void:
	var dungeon := _map()
	assert(dungeon.place_entity("trap", 3, 2, {"trap_id": "spikes", "hidden": false}))
	var session := _session(dungeon)
	var pending: GameActionResult = session.execute(GameAction.move(Vector2i.RIGHT))
	assert(pending.status == GameActionResult.Status.AWAITING_INPUT)
	assert(not session.execute(GameAction.choose(pending.interaction_id, "disarm", 99)).accepted)
	assert(session.pending_interaction.id == pending.interaction_id)
	assert(session.execute(GameAction.choose(pending.interaction_id, "cancel")).accepted)
	assert(session.steps == 0 and session.pending_interaction == null)
	assert(not session.execute(GameAction.choose(pending.interaction_id, "cancel")).accepted)
