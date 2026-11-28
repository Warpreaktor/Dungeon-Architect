class_name SlidingPlatesDiagnostics
extends RefCounted


static func scope_ids(seed: String, maps: Dictionary, campaigns: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var seen: Dictionary = {}
	var pending: Array[String] = [seed]
	var edges: Dictionary = {}
	for id in maps:
		if maps[id] is DungeonMap:
			edges[id] = []
	for id in edges:
		var data: DungeonMap = maps[id]
		for entity in data.entities:
			var target: String = DungeonMap.exit_target_id(entity)
			if edges.has(target):
				edges[id].append(target)
				edges[target].append(id)
	for campaign in campaigns.values():
		var members: Array[String] = campaign.map_ids
		if members.is_empty():
			continue
		var anchor := ""
		for id in members:
			if edges.has(id):
				anchor = id
				break
		if anchor.is_empty():
			continue
		for id in members:
			if edges.has(id):
				edges[anchor].append(id)
				edges[id].append(anchor)
	while not pending.is_empty():
		var id: String = pending.pop_back()
		if seen.has(id) or not edges.has(id):
			continue
		seen[id] = true
		ids.append(id)
		for neighbor in edges[id]:
			if not seen.has(neighbor):
				pending.append(neighbor)
	ids.sort()
	return ids


static func duplicate_error(ids: Array[String], maps: Dictionary) -> String:
	var names: Array[String] = []
	for id in ids:
		var data: DungeonMap = maps.get(id) as DungeonMap
		if data != null and data.has_sliding_plates_trigger():
			names.append(data.display_name)
	if names.size() <= 1:
		return ""
	return "%s Этажи: %s" % [SlidingPlates.DUPLICATE_ERROR, ", ".join(names)]


static func scope_issues(seed: String, maps: Dictionary, campaigns: Dictionary, skip_geometry_map_id: String = "") -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	var ids: Array[String] = scope_ids(seed, maps, campaigns)
	var duplicate: String = duplicate_error(ids, maps)
	for id in ids:
		var data: DungeonMap = maps[id]
		if not data.has_sliding_plates_trigger():
			continue
		if not duplicate.is_empty():
			issues.append(_issue(data, duplicate, data.find_entity_position(SlidingPlates.TRIGGER)))
		if id != skip_geometry_map_id:
			issues.append_array(analyze_map(data))
		for entity in data.entities:
			var target: String = DungeonMap.exit_target_id(entity)
			if target.is_empty():
				continue
			var destination: DungeonMap = maps.get(target) as DungeonMap
			if destination == null or not DungeonMap.valid_arrival_cell(destination, DungeonMap.exit_target_cell(entity, destination)):
				issues.append(_issue(data, "Недоступна точка входа на связанный этаж.", _cell(entity)))
	return issues


static func launch_error(seed: String, maps: Dictionary, campaigns: Dictionary) -> String:
	var issues: Array[Dictionary] = scope_issues(seed, maps, campaigns)
	if issues.is_empty():
		return ""
	var issue: Dictionary = issues[0]
	var data: DungeonMap = maps[issue["map_id"]]
	var cell: Vector2i = issue["cell"]
	return "%s (%d, %d): %s" % [data.display_name, cell.x, cell.y, issue["message"]]


static func analyze_map(data: DungeonMap) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if not data.has_sliding_plates_trigger():
		return issues
	var trigger: Vector2i = data.find_entity_position(SlidingPlates.TRIGGER)
	var original: DungeonMap = data.copy_for_play()
	var shifted: DungeonMap = data.copy_for_play()
	if original == null or shifted == null or shifted.switch_sliding_plates({}).is_empty():
		issues.append(_issue(data, "Сдвигающиеся плиты: нет допустимой конфигурации Б.", trigger))
		return issues
	if data.sliding_plates_marks().size() < 2:
		issues.append(_issue(data, "Сдвигающиеся плиты: необходимо разметить минимум два участка.", trigger))
	var exits: Array[Vector2i] = []
	for entity in original.entities:
		if entity["type"] == "stairs_down" or (entity["type"] == "portal" and not DungeonMap.exit_target_id(entity).is_empty()):
			exits.append(_cell(entity))
	if exits.is_empty():
		issues.append(_issue(data, "Сдвигающиеся плиты: отсутствует выход.", trigger))
		return issues
	var start: Vector2i = original.find_entity_position("player_spawn")
	if not DungeonMap.valid_arrival_cell(original, start) or not DungeonMap.valid_arrival_cell(shifted, start):
		issues.append(_issue(data, "Сдвигающиеся плиты: недоступна точка входа.", trigger))
		return issues
	var a: Dictionary = DungeonReachability.analyze(original, trigger)
	var b: Dictionary = DungeonReachability.analyze(shifted, trigger)
	_check_configuration(data, original, a, b, exits, trigger, "А", issues)
	_check_configuration(data, shifted, b, a, exits, trigger, "Б", issues)
	if issues.is_empty():
		_check_transition(data, a, shifted, exits, trigger, "А → Б", issues)
		_check_transition(data, b, original, exits, trigger, "Б → А", issues)
	return issues


static func _check_configuration(data: DungeonMap, configuration: DungeonMap, result: Dictionary, other: Dictionary, exits: Array[Vector2i], trigger: Vector2i, label: String, issues: Array[Dictionary]) -> void:
	if not result["complete"]:
		issues.append(_issue(data, "Положение %s: не удалось полностью проверить достижимость." % label, trigger))
		return
	var reachable: Dictionary = result["possible"]
	if not reachable.has(trigger):
		issues.append(_issue(data, "Положение %s: триггер недоступен от входа." % label, trigger))
	for cell in exits:
		if not reachable.has(cell):
			issues.append(_issue(data, "Положение %s: выход или переход недостижим." % label, cell))
	var escape: Dictionary = DungeonReachability.escape_region(configuration, exits)
	var accessible: Dictionary = reachable.duplicate()
	accessible.merge(other["possible"])
	for cell in accessible:
		if configuration.get_terrain(cell.x, cell.y) == "floor" and not escape.has(cell):
			issues.append(_issue(data, "Положение %s: участок отрезан от всех выходов." % label, cell))
			var isolated: Array[Vector2i] = [cell]
			escape.merge(DungeonReachability.escape_region(configuration, isolated))


static func _check_transition(data: DungeonMap, source: Dictionary, target: DungeonMap, exits: Array[Vector2i], trigger: Vector2i, label: String, issues: Array[Dictionary]) -> void:
	var result: Dictionary = DungeonReachability.switching_escape(source, target, trigger, exits)
	if not result["complete"]:
		issues.append(_issue(data, "Переключение %s: проверка маршрутов не завершена." % label, trigger))
	elif not result["safe"]:
		issues.append(_issue(data, "Переключение %s: после срабатывания нет пути к выходу с имеющимися ключами." % label, trigger))


static func _cell(entity: Dictionary) -> Vector2i:
	return Vector2i(int(entity["x"]), int(entity["y"]))


static func _issue(data: DungeonMap, message: String, cell: Vector2i) -> Dictionary:
	return {"severity": "error", "message": message, "icon": "wall", "cell": cell, "map_id": data.map_id}
