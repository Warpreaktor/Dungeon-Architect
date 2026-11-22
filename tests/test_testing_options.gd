extends SceneTree

## DA-3.06.3: отладочные флаги не изменяют JSON и не влияют на обычный запуск.
func _initialize() -> void:
	var dungeon := DungeonMap.create_blank(12, 12)
	assert(dungeon.place_entity("player_spawn", 2, 2))
	var original_json := JSON.stringify(dungeon.to_dict())

	var default_session := GameSession.start_for(dungeon)
	assert(default_session != null)
	assert(default_session.is_revealed(2, 2))
	assert(not default_session.is_revealed(9, 9))
	assert(not default_session.is_visible(9, 9))

	var test_session := GameSession.start_for(dungeon, HeroCatalog.DEFAULT_HERO_ID, true)
	assert(test_session != null)
	assert(test_session.debug_open_map)
	assert(test_session.is_revealed(9, 9))
	assert(test_session.is_visible(9, 9))
	assert(test_session.move_by(1, 0))
	assert(test_session.is_revealed(9, 9))
	assert(test_session.is_visible(9, 9))

	var pair: Array[String] = ["volcha", "petushan"]
	var party_session := GameSession.start_for_party(dungeon, pair)
	assert(party_session != null)
	assert(party_session.party_members().size() == 2)
	assert(party_session.hero == party_session.party_members()[0])
	assert(party_session.party_members()[0].definition.hero_id == "volcha")
	assert(party_session.party_members()[1].definition.hero_id == "petushan")
	assert(party_session.party_members()[0] != party_session.party_members()[1])
	assert(not party_session.debug_open_map)
	assert(GameSession.start_for_party(dungeon, []) == null)
	assert(GameSession.start_for_party(dungeon, ["unknown"]) == null)
	assert(JSON.stringify(dungeon.to_dict()) == original_json)

	var next_normal_session := GameSession.start_for(dungeon)
	assert(not next_normal_session.debug_open_map)
	assert(not next_normal_session.is_revealed(9, 9))
	assert(JSON.stringify(dungeon.to_dict()) == original_json)
	print("DA-3.06.3: testing options OK")
	quit()
