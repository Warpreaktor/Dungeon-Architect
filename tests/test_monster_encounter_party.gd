extends SceneTree


func _initialize() -> void:
	var available: Array[String] = MonsterCatalog.list_ids()
	assert(not available.is_empty())
	var first_id: String = available[0]
	var second_id: String = available[1] if available.size() > 1 else first_id
	var dungeon := DungeonMap.create_blank()
	var start := Vector2i(2, 2)
	var monster_cell := start + Vector2i.RIGHT
	assert(dungeon.place_entity("player_spawn", start.x, start.y))
	assert(dungeon.place_entity("monster", monster_cell.x, monster_cell.y, {"monster_id": first_id}))
	var entity: Dictionary = dungeon.entities_at(monster_cell.x, monster_cell.y)[0]
	var entity_id: String = str(entity["id"])
	assert(DungeonMap.monster_party_ids(entity) == [first_id])
	assert(not dungeon.set_monster_party(entity_id, []))
	assert(not dungeon.set_monster_party(entity_id, [first_id, "invalid_monster_id"]))
	assert(not dungeon.set_monster_party(entity_id, [first_id, second_id, first_id]))
	assert(dungeon.set_monster_party(entity_id, [first_id, second_id]))
	assert(not dungeon.set_monster_party(entity_id, [first_id, second_id]))
	assert(DungeonMap.monster_party_ids(entity) == [first_id, second_id])
	assert(str(entity["properties"]["monster_id"]) == first_id)
	assert(dungeon.set_monster_loot(entity_id, ["gold"], 1))
	var loot: Array[String] = DungeonMap.monster_loot_contents(entity)
	var serialized: String = JSON.stringify(dungeon.to_dict())
	var restored: DungeonMap = DungeonMap.from_dict(JSON.parse_string(serialized))
	assert(restored != null)
	var restored_entity: Dictionary = restored.entities_at(monster_cell.x, monster_cell.y)[0]
	assert(DungeonMap.monster_party_ids(restored_entity) == [first_id, second_id])
	assert(DungeonMap.monster_loot_contents(restored_entity) == loot)
	assert(JSON.stringify(restored.to_dict()) == serialized)
	var play: GameSession = GameSession.start_for(restored)
	assert(not play.move_by(Vector2i.RIGHT.x, Vector2i.RIGHT.y))
	assert(play.has_pending_encounter())
	var definitions: Array[MonsterDefinition] = play.pending_monster_definitions()
	assert(definitions.size() == DungeonMap.monster_party_ids(restored_entity).size())
	assert(definitions[0].monster_id == first_id)
	assert(definitions[1].monster_id == second_id)
	var battle := CombatSession.new(definitions[0], play.hero, definitions[1])
	assert(battle.battle_state.enemy_ids().size() == definitions.size())
	assert(battle.battle_state.get_participant(battle.battle_state.support_enemy_id) != null)
	assert(dungeon.set_monster_party(entity_id, [first_id]))
	assert(not entity["properties"].has("monster_ids"))
	assert(DungeonMap.monster_party_ids(entity) == [first_id])
	var legacy: DungeonMap = DungeonMap.from_dict(JSON.parse_string(JSON.stringify(dungeon.to_dict())))
	assert(legacy != null)
	assert(DungeonMap.monster_party_ids(legacy.entities_at(monster_cell.x, monster_cell.y)[0]) == [first_id])
	quit()
