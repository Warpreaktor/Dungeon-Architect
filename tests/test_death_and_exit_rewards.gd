extends SceneTree


func _initialize() -> void:
	_test_defeat_and_recovery()
	_test_floor_rewards()
	_test_no_slot_keeps_inventory()
	print("Death and exit rewards: OK")
	quit()


func _test_defeat_and_recovery() -> void:
	var dungeon := DungeonMap.create_blank(8, 8)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	assert(dungeon.place_entity("monster", 4, 2, {"monster_id": "hunter"}))
	var original: String = JSON.stringify(dungeon.to_dict())
	var session := GameSession.start_for(dungeon)
	var next_floor := DungeonMap.create_blank(8, 8)
	assert(next_floor.place_entity("player_spawn", 2, 2))
	assert(session.move_by(1, 0))
	assert(not session.move_by(1, 0))
	assert(session.has_pending_encounter())
	var original_monster: String = session.encounter_monster_id
	session._receive_item("shield", 2)
	session.hero.shield_durabilities["shield"] = [1, 2]
	session._receive_item("key", 4)
	session._receive_item("gold", 17)
	session.hero.health = 0
	assert(session.record_defeat())
	assert(session.record_defeat())
	assert(session.fallen_encounters.size() == 1)
	assert(session.fallen_encounters[0]["x"] == 3)
	assert(session.fallen_encounters[0]["y"] == 2)
	assert(session.resurrect_party())
	assert(not session.resurrect_party())
	assert(session.player_pos == Vector2i(2, 2))
	assert(session.hero.health == session.hero.max_health)
	assert(session.carried_items.is_empty() and session.hero.gold == 0)
	assert(not session.removed_entities.has(original_monster))
	# Die again at the same cell while attempting to recover the first corpse.
	session._receive_item("gold", 5)
	assert(not session.move_by(1, 0))
	assert(session.pending_monster_definition().monster_id == "skeleton")
	session.hero.health = 0
	# The attacker was on the spawn cell, so use a separate free approach to the corpse.
	assert(session.resurrect_party())
	assert(session.fallen_encounters.size() >= 1)
	# A repeated death on the original cell fills the group, then spills into another cell.
	for index in range(DungeonMap.MAX_MONSTERS_PER_ENCOUNTER + 1):
		session.player_pos = Vector2i(3, 2)
		session.hero.health = 0
		assert(session.resurrect_party())
	for corpse in session.fallen_encounters:
		assert(DungeonMap.monster_party_ids(corpse).size() <= DungeonMap.MAX_MONSTERS_PER_ENCOUNTER)
	assert(session.fallen_encounters.size() > 1)
	assert(session.enter_map(next_floor))
	assert(session.fallen_encounters.is_empty())
	assert(session.enter_map(dungeon))
	assert(session.fallen_encounters.size() > 1)
	assert(not session.move_by(1, 0))
	assert(session.pending_monster_definitions().size() == DungeonMap.MAX_MONSTERS_PER_ENCOUNTER)
	assert(session.win_pending_encounter())
	assert(not session.win_pending_encounter())
	assert(session.carried_items.get("key", 0) == 4)
	assert(session.carried_items.get("shield", 0) == 2)
	assert(session.hero.shield_durabilities["shield"] == [1, 2])
	assert(session.hero.gold >= 17)
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


func _test_no_slot_keeps_inventory() -> void:
	var dungeon := DungeonMap.create_blank(1, 1)
	assert(dungeon.place_entity("player_spawn", 0, 0))
	var session := GameSession.start_for(dungeon)
	for index in range(DungeonMap.MAX_MONSTERS_PER_ENCOUNTER):
		session.hero.health = 0
		assert(session.resurrect_party())
	session._receive_item("gold", 7)
	session.hero.health = 0
	assert(not session.resurrect_party())
	assert(session.hero.gold == 7)
	assert(session.fallen_encounters.size() == 1)
