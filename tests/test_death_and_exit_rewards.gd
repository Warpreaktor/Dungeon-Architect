extends SceneTree


func _initialize() -> void:
	_test_heroes_do_not_resurrect()
	_test_floor_rewards()
	print("Permanent death and exit rewards: OK")
	quit()


func _test_heroes_do_not_resurrect() -> void:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("monster", 4, 2, {"monster_id": "hunter"}))
	var original: String = JSON.stringify(dungeon.to_dict())
	var session := GameSession.start_for(dungeon)
	assert(session != null)
	assert(session.add_party_member("volcha"))
	var first: HeroState = session.hero
	first.learned_ability_ids.append("test_ability")
	first.bonus_action_slots = 1
	first.strength += 2
	first.gold = 17
	session._receive_item("shield", 2)
	session.hero.shield_durabilities["shield"] = [1, 2]
	first.health = 0
	var fallen: Array[HeroState] = session.record_casualties()
	assert(fallen.size() == 1 and fallen[0] == first)
	assert(session.fallen_heroes.size() == 1 and session.fallen_heroes[0] == first)
	assert(first.gold == 0 and first.bonus_action_slots == 1)
	assert(session.ground_container_at(session.player_pos)["loot"][0]["quantity"] == 17)
	assert(session.hero.shield_durabilities["shield"] == [1, 2])
	assert(session.carried_items.get("shield", 0) == 2)
	assert(session.inventory_slot_ids().count("shield") == 2)
	assert(first.strength == first.definition.strength + 2)
	assert(first.learned_ability_ids.has("test_ability"))
	assert(session.hero != first and session.hero.health > 0)
	assert(session.party_members().size() == 1)
	assert(session.record_casualties().is_empty())
	assert(session.take_casualty_events() == [first])
	assert(session.take_casualty_events().is_empty())
	assert(session.fallen_hero_locations[0]["position"] == session.player_pos)
	assert(session.fallen_hero_locations[0]["map_id"] == dungeon.map_id)
	assert(session.move_by(1, 0))
	assert(not session.move_by(1, 0))
	assert(session.has_pending_encounter())
	session.abandon_pending_encounter()
	assert(not session.has_pending_encounter())
	assert(session.enter_map(DungeonMap.create_blank(8, 8)) == false)
	session.hero.health = 0
	assert(session.record_casualties().size() == 1)
	assert(session.is_party_defeated() and session.hero == null)
	assert(session.party_members().is_empty())
	assert(session.fallen_heroes.size() == 2)
	assert(not session.add_party_member("petushan"))
	assert(not session.move_by(1, 0))
	assert(JSON.stringify(dungeon.to_dict()) == original)


func _test_floor_rewards() -> void:
	var dungeon := DungeonMap.create_blank(8, 8)
	var next_floor := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(next_floor.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("stairs_down", 3, 2))
	var stairs: Dictionary = dungeon.entities_at(3, 2)[0]
	var stairs_id: String = str(stairs["id"])
	assert(dungeon.set_stairs_target(stairs_id, next_floor.map_id))
	assert(dungeon.set_chest_contents(stairs_id, ["gold", "key"], 19, false, false, {"key": 2}))
	var restored := DungeonMap.from_dict(JSON.parse_string(JSON.stringify(dungeon.to_dict())))
	var session := GameSession.start_for(restored)
	assert(session.move_by(1, 0))
	assert(session.is_completed and session.next_map_id() == next_floor.map_id)
	assert(session.hero.gold == 19 and session.keys == 2)
	assert(session.take_message_events().size() == 1)
	assert(session.enter_map(next_floor))
	assert(session.enter_map(restored))
	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(session.hero.gold == 19 and session.keys == 2)
	assert(session.take_message_events().is_empty())
