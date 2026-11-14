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
	print("DungeonMap smoke tests: OK")
	quit()
