extends SceneTree

## Запуск: godot --headless --path . --script res://tests/test_diagnostics.gd
func _initialize() -> void:
	var no_spawn := DungeonMap.create_blank(8, 5)
	var notices := DungeonDiagnostics.analyze(no_spawn, DungeonReachability.analyze(no_spawn))
	assert(_has_message(notices, "Нет точки старта"))
	assert(_has_message(notices, "Не установлен выход"))

	var accessible := _corridor()
	assert(accessible.place_entity("stairs_down", 6, 2))
	notices = DungeonDiagnostics.analyze(accessible, DungeonReachability.analyze(accessible))
	assert(not _has_message(notices, "Выход недостижим"))
	assert(not _has_message(notices, "Не установлен выход"))

	var locked := _corridor()
	assert(locked.place_entity("door", 3, 2))
	assert(locked.place_entity("stairs_down", 6, 2))
	notices = DungeonDiagnostics.analyze(locked, DungeonReachability.analyze(locked))
	assert(_has_message(notices, "Нет гарантированного ключа"))
	assert(_has_message(notices, "Выход недостижим"))

	var self_locked := _corridor()
	assert(self_locked.place_entity("door", 3, 2))
	assert(self_locked.place_entity("chest", 4, 2))
	assert(self_locked.place_entity("stairs_down", 6, 2))
	var chest: Dictionary = self_locked.entities_at(4, 2)[0]
	assert(self_locked.set_chest_contents(str(chest["id"]), ["key"]))
	notices = DungeonDiagnostics.analyze(self_locked, DungeonReachability.analyze(self_locked))
	assert(_has_message(notices, "Ключ для замка недоступен"))

	assert(locked.place_entity("chest", 2, 2))
	var mixed: Dictionary = locked.entities_at(2, 2)[0]
	assert(locked.set_chest_contents(str(mixed["id"]), ["gold"], 5, true))
	notices = DungeonDiagnostics.analyze(locked, DungeonReachability.analyze(locked))
	assert(_has_message(notices, "Нет гарантированного ключа"))
	assert(locked.set_chest_contents(str(mixed["id"]), ["key"], 5, true))
	notices = DungeonDiagnostics.analyze(locked, DungeonReachability.analyze(locked))
	assert(not _has_message(notices, "Нет гарантированного ключа"))
	assert(not _has_message(notices, "Выход недостижим"))

	print("DA-3.06.2 diagnostics tests passed")
	quit()


func _has_message(issues: Array[Dictionary], needle: String) -> bool:
	for issue in issues:
		if str(issue["message"]).contains(needle):
			return true
	return false


func _corridor() -> DungeonMap:
	var data := DungeonMap.create_blank(8, 5)
	for y in range(data.height):
		for x in range(data.width):
			data.set_terrain(x, y, "wall")
	for x in range(1, 7):
		data.set_terrain(x, 2, "floor")
	assert(data.place_entity("player_spawn", 1, 2))
	return data
