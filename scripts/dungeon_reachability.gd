class_name DungeonReachability
extends RefCounted

## Анализ редактора. Не создаёт GameSession и не изменяет DungeonMap.
## Закрытые двери расходуют ключи; каждую награду учитываем только один раз.
const STATE_LIMIT := 1500
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func analyze(map_data: DungeonMap) -> Dictionary:
	var start: Vector2i = map_data.find_entity_position("player_spawn")
	if not map_data.contains(start.x, start.y):
		return {"reachable": {}, "possible": {}, "complete": true, "has_spawn": false}
	var certain: Dictionary = _explore(map_data, start, false)
	var possible: Dictionary = _explore(map_data, start, true)
	return {
		"reachable": certain["cells"], "possible": possible["cells"],
		"complete": bool(certain["complete"]) and bool(possible["complete"]),
		"has_spawn": true
	}


static func _explore(map_data: DungeonMap, start: Vector2i, with_conditions: bool) -> Dictionary:
	var entities_by_cell: Dictionary = {}
	for entity in map_data.entities:
		var pos := Vector2i(int(entity["x"]), int(entity["y"]))
		if not entities_by_cell.has(pos):
			entities_by_cell[pos] = []
		entities_by_cell[pos].append(entity)

	var frontier: Array[Dictionary] = [{"opened": {}, "claimed": {}, "keys": {}}]
	var seen: Dictionary = {}
	var overall: Dictionary = {}
	var expansions := 0
	while not frontier.is_empty() and expansions < STATE_LIMIT:
		var state: Dictionary = frontier.pop_back()
		expansions += 1
		# Любая достижимая награда автоматически забирается только один раз.
		var reachable: Dictionary = {}
		var doors_on_edge: Dictionary = {}
		var changed := true
		while changed:
			var region: Dictionary = _flood(map_data, start, state["opened"], entities_by_cell, with_conditions)
			reachable = region["cells"]
			doors_on_edge = region["doors"]
			changed = false
			for pos in reachable:
				for entity in entities_by_cell.get(pos, []):
					var entity_type: String = str(entity["type"])
					if entity_type not in ["chest", "monster", "key", "potion", "gold"]:
						continue
					var entity_id: String = str(entity["id"])
					if state["claimed"].has(entity_id):
						continue
					if entity_type == "monster" and not with_conditions:
						continue
					var props: Dictionary = entity.get("properties", {})
					if entity_type == "chest" and bool(props.get("hidden", false)) and not with_conditions:
						continue
					var rewards: Dictionary = _key_rewards(entity)
					state["claimed"][entity_id] = true
					for key_id in rewards:
						state["keys"][key_id] = int(state["keys"].get(key_id, 0)) + int(rewards[key_id])
					changed = true
		for pos in reachable:
			overall[pos] = true
		var fingerprint: String = _signature(state)
		if seen.has(fingerprint):
			continue
		seen[fingerprint] = true
		for door_id in doors_on_edge:
			var door: Dictionary = doors_on_edge[door_id]
			var required: String = LockCatalog.required_key(door)
			if int(state["keys"].get(required, 0)) < 1:
				continue
			var next: Dictionary = {
				"opened": state["opened"].duplicate(),
				"claimed": state["claimed"].duplicate(),
				"keys": state["keys"].duplicate()
			}
			next["opened"][door_id] = true
			next["keys"][required] = int(next["keys"][required]) - 1
			if not seen.has(_signature(next)):
				frontier.append(next)
	return {"cells": overall, "complete": frontier.is_empty()}


static func _flood(map_data: DungeonMap, start: Vector2i, opened: Dictionary, entities_by_cell: Dictionary, with_conditions: bool) -> Dictionary:
	var cells: Dictionary = {start: true}
	var doors: Dictionary = {}
	var pending: Array[Vector2i] = [start]
	var head := 0
	while head < pending.size():
		var here: Vector2i = pending[head]
		head += 1
		for direction in DIRECTIONS:
			var target: Vector2i = here + direction
			if cells.has(target) or map_data.get_terrain(target.x, target.y) == "wall":
				continue
			var blocked := false
			for entity in entities_by_cell.get(target, []):
				var kind: String = str(entity["type"])
				if kind == "door" and not opened.has(str(entity["id"])):
					doors[str(entity["id"])] = entity
					blocked = true
				if kind == "monster" and not with_conditions:
					blocked = true
			if blocked:
				continue
			cells[target] = true
			pending.append(target)
	return {"cells": cells, "doors": doors}


static func _key_rewards(entity: Dictionary) -> Dictionary:
	var kind: String = str(entity["type"])
	if kind == "key":
		return {"key": 1}
	if kind not in ["chest", "monster"]:
		return {}
	if kind == "chest" and DungeonMap.chest_is_random(entity):
		return {}
	if kind == "monster" and DungeonMap.monster_loot_is_random(entity):
		return {}
	var contents: Array[String] = DungeonMap.chest_contents(entity) if kind == "chest" else DungeonMap.monster_loot_contents(entity)
	var quantities: Dictionary = DungeonMap.chest_item_quantities(entity) if kind == "chest" else DungeonMap.monster_item_quantities(entity)
	var keys: Dictionary = {}
	for item_id in contents:
		var normalized: String = LockCatalog.normalize(item_id)
		if item_id in LockCatalog.LOCK_IDS or item_id == "key_yellow":
			keys[normalized] = int(quantities.get(item_id, 1))
	return keys


static func _signature(state: Dictionary) -> String:
	var opened: Array = state["opened"].keys()
	opened.sort()
	var claimed: Array = state["claimed"].keys()
	claimed.sort()
	var keys: Array = state["keys"].keys()
	keys.sort()
	var counts: Array[String] = []
	for key_id in keys:
		counts.append("%s=%d" % [key_id, int(state["keys"][key_id])])
	return "%s|%s|%s" % [str(opened), str(claimed), ",".join(counts)]
