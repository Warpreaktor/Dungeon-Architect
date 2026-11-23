extends SceneTree


func _initialize() -> void:
	_test_survivor_finishes_encounter()
	_test_last_hero_defeat()
	quit()


func _encounter() -> GameSession:
	var dungeon: DungeonMap = DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("monster", 3, 2, {"monster_id": "skeleton"}))
	var session: GameSession = GameSession.start_for(dungeon)
	assert(session != null)
	assert(session.add_party_member("volcha"))
	assert(not session.move_by(1, 0))
	assert(session.has_pending_encounter())
	return session


func _test_survivor_finishes_encounter() -> void:
	var session: GameSession = _encounter()
	var fallen: HeroState = session.party[0]
	var survivor: HeroState = session.party[1]
	fallen.gold = 17
	assert(session._receive_item("shield", 1) == 1)
	var monster: MonsterDefinition = session.pending_monster_definition()
	var combat: CombatSession = CombatSession.new(monster, fallen, null, 4278, session.party)
	var state: BattleState = combat.battle_state
	assert(state.start_round_combat().get("success", false))
	state.get_participant("hero").receive_damage(9999)
	state.update_outcome()
	assert(not state.is_defeat and not state.is_victory)
	assert(state.living_hero_ids() == ["hero_2"])
	assert(state.prepare_next_round() != "hero")
	assert(state.round_order.has("hero_2"))
	assert(not state.round_order.has("hero"))
	combat.sync_hero_results()
	assert(fallen.health == 0 and survivor.health > 0)
	assert(session.party.size() == 2)
	assert(session.has_pending_encounter())
	state.get_enemy().receive_damage(9999)
	state.update_outcome()
	assert(state.is_victory and not state.is_defeat)
	combat.sync_hero_results()
	assert(session.win_pending_encounter())
	assert(not session.has_pending_encounter())
	assert(session.hero == survivor)
	assert(session.party == [survivor])
	assert(session.fallen_heroes == [fallen])
	assert(session.take_casualty_events() == [fallen])
	assert(session.take_casualty_events().is_empty())
	assert(session.fallen_hero_locations.size() == 1)
	assert(session.fallen_hero_locations[0]["position"] == Vector2i(2, 2))
	assert(session.fallen_hero_locations[0]["map_id"] == session.map_data.map_id)
	assert(not session.ground_container_at(Vector2i(2, 2)).is_empty())
	var dropped_gold: int = 0
	for item in session.ground_container_at(Vector2i(2, 2))["loot"]:
		if item["item_id"] == "gold":
			dropped_gold += int(item["quantity"])
	assert(dropped_gold == 17)
	assert(session.inventory_slot_ids().has("shield"))
	assert(session.carried_items.get("shield", 0) == 1)
	assert(fallen.equipped_shield_id.is_empty())
	assert(not session.win_pending_encounter())
	assert(session.fallen_heroes.size() == 1)
	assert(session.ground_loot_containers.size() == 1)
	assert(session.entities_at(3, 2).is_empty())


func _test_last_hero_defeat() -> void:
	var session: GameSession = _encounter()
	var members: Array[HeroState] = session.party_members()
	members[0].gold = 8
	members[1].gold = 13
	var combat: CombatSession = CombatSession.new(session.pending_monster_definition(), members[0], null, 4279, session.party)
	var state: BattleState = combat.battle_state
	state.get_participant("hero").receive_damage(9999)
	state.update_outcome()
	assert(not state.is_defeat)
	state.get_participant("hero_2").receive_damage(9999)
	state.update_outcome()
	assert(state.is_defeat)
	combat.sync_hero_results()
	assert(session.record_casualties() == members)
	session.abandon_pending_encounter()
	assert(session.is_party_defeated())
	assert(session.hero == null)
	assert(session.take_casualty_events() == members)
	assert(session.record_casualties().is_empty())
	var gold: int = 0
	for entry in session.ground_container_at(Vector2i(2, 2))["loot"]:
		if entry["item_id"] == "gold":
			gold += int(entry["quantity"])
	assert(gold == 21)
	assert(not session.move_by(1, 0))
	assert(not session.win_pending_encounter())
	assert(session.entities_at(3, 2).size() == 1)
