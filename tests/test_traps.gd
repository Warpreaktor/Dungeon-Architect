extends SceneTree


func _initialize() -> void:
	assert(TrapCatalog.has("spikes"))
	var trap: TrapDefinition = TrapCatalog.get_trap("spikes")
	assert(trap != null)
	assert(trap.direct_damage == 2)
	assert(trap.overworld_status_id == "bleeding")
	assert(trap.overworld_status_ticks == 2)
	assert(trap.overworld_status_interval_steps == 4)

	var dungeon := DungeonMap.create_blank(10, 5)
	for y in range(dungeon.height):
		for x in range(dungeon.width):
			if y != 2:
				dungeon.set_terrain(x, y, "wall")
	assert(dungeon.place_entity("player_spawn", 1, 2))
	assert(dungeon.place_entity("trap", 2, 2, {"trap_id": "spikes"}))
	var trap_entity: Dictionary = dungeon.entities_at(2, 2)[0]
	assert(DungeonMap.trap_id(trap_entity) == "spikes")
	var saved_json := JSON.stringify(dungeon.to_dict())
	var restored: DungeonMap = DungeonMap.from_dict(JSON.parse_string(saved_json))
	assert(restored != null)
	var restored_trap: Dictionary = restored.entities_at(2, 2)[0]
	assert(DungeonMap.trap_id(restored_trap) == "spikes")
	assert(JSON.stringify(restored.to_dict()) == saved_json)

	var session := GameSession.start_for(restored)
	assert(session != null)
	var max_hp: int = session.hero.max_health
	assert(session.move_by(1, 0))
	assert(session.player_pos == Vector2i(2, 2))
	assert(session.hero.health == max_hp - 2)
	assert(session.is_trap_disarmed(restored_trap))
	assert(session.hero.active_effects_summary().contains("Кровотечение"))
	assert(session.last_event_message.contains("Ловушка"))

	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(session.move_by(-1, 0))
	assert(session.hero.health == max_hp - 2)
	assert(session.move_by(1, 0))
	assert(session.hero.health == max_hp - 4)
	assert(session.last_event_message.contains("Кровотечение"))

	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(session.move_by(-1, 0))
	assert(session.hero.health == max_hp - 4)
	assert(session.move_by(1, 0))
	assert(session.hero.health == max_hp - 6)
	assert(not session.hero.active_effects_summary().contains("Кровотечение"))

	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(session.move_by(-1, 0))
	assert(session.move_by(1, 0))
	assert(session.hero.health == max_hp - 6)

	print("Trap tests passed")
	quit()
