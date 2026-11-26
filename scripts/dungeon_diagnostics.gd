class_name DungeonDiagnostics
extends RefCounted

## Статическая диагностика: не изменяет карту и не блокирует сохранение или тест.
## Предупреждения о ключах не доказывают непроходимость при случайной добыче.

static func analyze(map_data: DungeonMap, result: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var certain: Dictionary = result.get("reachable", {})
	var possible: Dictionary = result.get("possible", {})
	var complete: bool = bool(result.get("complete", true))
	var has_spawn: bool = bool(result.get("has_spawn", false))
	var exits: Array[Dictionary] = []
	var doors: Array[Dictionary] = []
	var keys: Dictionary = {}
	for entity in map_data.entities:
		var kind: String = str(entity["type"])
		if kind == "stairs_down" or (kind == "portal" and not DungeonMap.exit_target_id(entity).is_empty()):
			exits.append(entity)
		elif kind == "door":
			doors.append(entity)
		elif kind == "trap":
			var trap: TrapDefinition = TrapCatalog.from_entity(entity)
			if trap != null:
				var error: String = map_data.trap_placement_error(trap, _position(entity))
				if not error.is_empty():
					issues.append(_issue("error", "%s: %s" % [trap.display_name, error], "trap", _position(entity)))
		elif kind == "chest" or kind == "monster":
			var is_random: bool = DungeonMap.chest_is_random(entity) if kind == "chest" else DungeonMap.monster_loot_is_random(entity)
			if not is_random:
				var contents: Array[String] = DungeonMap.chest_contents(entity) if kind == "chest" else DungeonMap.monster_loot_contents(entity)
				for item_id in contents:
					var canonical: String = LockCatalog.normalize(item_id)
					if canonical in LockCatalog.LOCK_IDS:
						if not keys.has(canonical):
							keys[canonical] = []
						keys[canonical].append(entity)
		if kind == "key":
			if not keys.has("key"):
				keys["key"] = []
			keys["key"].append(entity)

	if not has_spawn:
		issues.append(_issue("error", "Нет точки старта героя", "player_spawn", Vector2i(-1, -1)))
	if exits.is_empty():
		issues.append(_issue("error", "Не установлен выход", "stairs_down", Vector2i(-1, -1)))
	elif has_spawn:
		var exit_found := false
		var exit_certain := false
		for exit_entity in exits:
			var pos := _position(exit_entity)
			if possible.has(pos):
				exit_found = true
			if certain.has(pos):
				exit_certain = true
		if not exit_found and complete:
			issues.append(_issue("warning", "Выход недостижим при известных наградах", "stairs_down", _position(exits[0])))
		elif exit_found and not exit_certain:
			issues.append(_issue("info", "Выход требует боя или обнаружения тайника", "stairs_down", _position(exits[0])))
	if not complete:
		issues.append(_issue("warning", "Не все варианты маршрутов проверены", "hand", Vector2i(-1, -1)))

	var reported_locks: Dictionary = {}
	for door in doors:
		var needed: String = LockCatalog.required_key(door)
		if reported_locks.has(needed):
			continue
		reported_locks[needed] = true
		var sources: Array = keys.get(needed, [])
		if sources.is_empty():
			issues.append(_issue("warning", "Нет гарантированного ключа для замка: %s" % LockCatalog.label(needed), "door", _position(door)))
			continue
		var can_reach_source := false
		for source in sources:
			if possible.has(_position(source)):
				can_reach_source = true
		if has_spawn and complete and not can_reach_source:
			issues.append(_issue("warning", "Ключ для замка недоступен (проверь цепочку дверей): %s" % LockCatalog.label(needed), "door", _position(door)))
	return issues


static func _position(entity: Dictionary) -> Vector2i:
	return Vector2i(int(entity["x"]), int(entity["y"]))


static func _issue(severity: String, message: String, icon: String, cell: Vector2i) -> Dictionary:
	return {"severity": severity, "message": message, "icon": icon, "cell": cell}
