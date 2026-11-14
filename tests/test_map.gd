extends SceneTree

## Минимальный smoke-test модели. Запускается через Godot --headless --script.
func _initialize() -> void:
	var model := DungeonMap.create_blank(12, 12)
	assert(model.get_terrain(0, 0) == "wall")
	assert(model.get_terrain(1, 1) == "floor")
	assert(model.place_entity("chest", 3, 3))
	assert(model.place_entity("trigger", 3, 3))
	assert(model.entities_at(3, 3).size() == 2)
	assert(model.place_entity("player_spawn", 2, 2))
	assert(model.place_entity("player_spawn", 4, 4))
	var hero_count := 0
	for entity in model.entities:
		if entity["type"] == "player_spawn":
			hero_count += 1
	assert(hero_count == 1)
	var text_json := JSON.stringify(model.to_dict())
	var restored := DungeonMap.from_dict(JSON.parse_string(text_json))
	assert(restored != null)
	assert(restored.width == 12)
	assert(restored.entities_at(3, 3).size() == 2)
	assert(restored.erase_at(3, 3))
	assert(restored.entities_at(3, 3).size() == 1)
	# Минимальная карта тоже должна быть редактируемой и сохраняемой.
	var tiny := DungeonMap.create_blank(1, 1)
	assert(tiny.width == 1 and tiny.height == 1)
	assert(tiny.get_terrain(0, 0) == "floor")
	assert(tiny.place_entity("player_spawn", 0, 0))
	var tiny_restored := DungeonMap.from_dict(JSON.parse_string(JSON.stringify(tiny.to_dict())))
	assert(tiny_restored != null)
	assert(tiny_restored.width == 1 and tiny_restored.height == 1)
	var tiny_session := GameSession.start_for(tiny_restored)
	assert(tiny_session != null)
	assert(not tiny_session.move_by(1, 0))

	# Прямоугольные размеры и границы.
	var rectangular := DungeonMap.create_blank(16, 48)
	assert(rectangular.width == 16 and rectangular.height == 48)
	assert(rectangular.get_terrain(0, 0) == "wall")
	assert(rectangular.get_terrain(1, 1) == "floor")
	assert(DungeonMap.from_dict(JSON.parse_string(JSON.stringify(rectangular.to_dict()))) != null)

	# Новый сундук пуст, содержимое настраивается после размещения.
	var loot_map := DungeonMap.create_blank(8, 8)
	assert(loot_map.place_entity("player_spawn", 2, 2))
	assert(loot_map.place_entity("chest", 3, 2))
	assert(loot_map.place_entity("chest", 2, 3))
	assert(loot_map.place_entity("door", 4, 2))
	var empty_chest: Dictionary = loot_map.entities_at(3, 2)[0]
	var packed_chest: Dictionary = loot_map.entities_at(2, 3)[0]
	assert(DungeonMap.chest_contents(empty_chest).is_empty())
	var packed_id: String = str(packed_chest["id"])
	assert(loot_map.set_chest_contents(packed_id, ["key", "potion"]))
	assert(not loot_map.set_chest_contents(packed_id, ["key", "potion"]))
	assert(DungeonMap.chest_contents(packed_chest) == ["key", "potion"])
	var saved_json := JSON.stringify(loot_map.to_dict())
	var loot_session := GameSession.start_for(loot_map)
	assert(loot_session.move_by(1, 0)) # Пустой сундук не блокирует проход.
	assert(loot_session.keys == 0 and loot_session.potions == 0)
	assert(not loot_session.move_by(1, 0)) # Дверь без ключа закрыта.
	assert(loot_session.move_by(-1, 0))
	assert(not loot_session.move_by(0, 1)) # Сундук с добычей открывается за один шаг.
	assert(loot_session.keys == 1 and loot_session.potions == 1)
	assert(loot_session.is_chest_open(packed_chest))
	assert(loot_session.move_by(0, 1))
	assert(loot_session.keys == 1 and loot_session.potions == 1)
	assert(loot_session.move_by(1, 0) and loot_session.move_by(1, 0))
	assert(loot_session.move_by(0, -1)) # Ключ открывает дверь и расходуется.
	assert(loot_session.keys == 0)
	assert(JSON.stringify(loot_map.to_dict()) == saved_json)
	var another_session := GameSession.start_for(loot_map)
	assert(not another_session.is_chest_open(packed_chest))

	# Существующая карта с полем reward продолжает работать.
	var legacy_map := DungeonMap.from_dict(loot_map.to_dict())
	var legacy_chest: Dictionary = legacy_map.entities_at(3, 2)[0]
	legacy_chest["properties"] = {"reward": "key"}
	assert(DungeonMap.chest_contents(legacy_chest) == ["key"])
	var legacy_session := GameSession.start_for(legacy_map)
	assert(not legacy_session.move_by(1, 0))
	assert(legacy_session.keys == 1)
	assert(legacy_map.set_chest_contents(str(legacy_chest["id"]), []))
	assert(DungeonMap.chest_contents(legacy_chest).is_empty())
	print("DungeonMap smoke tests: OK")
	quit()
