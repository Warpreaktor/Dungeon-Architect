extends SceneTree


func _initialize() -> void:
	var map := DungeonMap.create_blank(7, 5)
	map.map_id = "traps_level_one"
	assert(map.place_entity("player_spawn", 1, 2))
	assert(map.place_entity("trap", 2, 2, {"trap_id": "spikes"}))
	var trap: Dictionary = map.entities_at(2, 2)[0]
	assert(DungeonMap.is_entity_hidden(trap))
	var session := GameSession.start_for(map, "petushan")
	session.hero.perception = TrapCatalog.get_trap("spikes").detection_difficulty - 1
	assert(session.is_entity_hidden_from_hero(trap))
	assert(not session.is_trap_revealed(trap))
	assert(session.move_by(1, 0))
	assert(session.is_trap_revealed(trap))
	assert(not session.is_entity_hidden_from_hero(trap))
	assert(session.is_trap_disarmed(trap))
	session.disarmed_traps.erase(str(trap.get("id", "")))
	assert(not session.is_trap_disarmed(trap))
	assert(session.is_trap_revealed(trap))

	var second := DungeonMap.create_blank(7, 5)
	second.map_id = "traps_level_two"
	assert(second.place_entity("player_spawn", 1, 1))
	assert(session.enter_map(second))
	assert(session.enter_map(map))
	assert(session.is_trap_revealed(trap))
	assert(not session.is_entity_hidden_from_hero(trap))

	var never_hidden := {"type": "trap", "properties": {"hidden": false}}
	assert(not DungeonMap.is_entity_hidden(never_hidden))
	assert(DungeonMap.is_entity_hidden({"type": "trap", "properties": {}}))
	quit()
