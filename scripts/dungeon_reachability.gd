class_name DungeonReachability
extends RefCounted

## Анализ редактора. Не создаёт GameSession и не изменяет DungeonMap.
## Закрытые двери расходуют ключи; каждую награду учитываем только один раз.
const STATE_LIMIT := 1500
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func analyze(map_data: DungeonMap, watch_cell: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var start: Vector2i = map_data.find_entity_position("player_spawn")
	if not map_data.contains(start.x, start.y):
		return {"reachable": {}, "possible": {}, "complete": true, "has_spawn": false}
	var certain: Dictionary = _explore(map_data, start, false)
	var possible: Dictionary = _explore(map_data, start, true, {}, watch_cell)
	return {
		"reachable": certain["cells"], "possible": possible["cells"],
		"complete": bool(certain["complete"]) and bool(possible["complete"]),
		"has_spawn": true, "watched": possible["watched"]
	}


static func _explore(map_data: DungeonMap, start: Vector2i, with_conditions: bool, initial_state: Dictionary = {}, watch_cell: Vector2i = Vector2i(-1, -1), limit: int = STATE_LIMIT) -> Dictionary:
	var entities_by_cell: Dictionary = {}
	for entity in map_data.entities:
		var pos := Vector2i(int(entity["x"]), int(entity["y"]))
		if not entities_by_cell.has(pos):
			entities_by_cell[pos] = []
		entities_by_cell[pos].append(entity)

	var frontier: Array[Dictionary] = [{"opened": {}, "claimed": {}, "keys": {}} if initial_state.is_empty() else initial_state.duplicate(true)]
	var watched: Array[Dictionary] = []
	var seen: Dictionary = {}
	var overall: Dictionary = {}
	var expansions := 0
	while not frontier.is_empty() and expansions < limit:
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
		if reachable.has(watch_cell):
			watched.append(state.duplicate(true))
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
	return {"cells": overall, "complete": frontier.is_empty(), "watched": watched, "expansions": expansions}


static func _flood(map_data: DungeonMap, start: Vector2i, opened: Dictionary, entities_by_cell: Dictionary, with_conditions: bool) -> Dictionary:
	if map_data.get_terrain(start.x, start.y) != "floor":
		return {"cells": {}, "doors": {}}
	var cells: Dictionary = {start: true}
	var doors: Dictionary = {}
	var pending: Array[Vector2i] = [start]
	var head := 0
	while head < pending.size():
		var here: Vector2i = pending[head]
		head += 1
		var neighbors: Array[Vector2i] = []
		for direction in DIRECTIONS:
			neighbors.append(here + direction)
		for entity in entities_by_cell.get(here, []):
			if str(entity["type"]) == "portal_local":
				var paired: Vector2i = map_data.local_portal_destination(str(entity["id"]))
				if DungeonMap.valid_arrival_cell(map_data, paired):
					neighbors.append(paired)
		for target in neighbors:
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


static func escape_region(map_data: DungeonMap, exits: Array[Vector2i]) -> Dictionary:
	var entities_by_cell: Dictionary = {}
	var opened: Dictionary = {}
	for entity in map_data.entities:
		var cell := Vector2i(int(entity["x"]), int(entity["y"]))
		if not entities_by_cell.has(cell):
			entities_by_cell[cell] = []
		entities_by_cell[cell].append(entity)
		if entity["type"] == "door":
			opened[str(entity["id"])] = true
	var cells: Dictionary = {}
	for cell in exits:
		if not cells.has(cell):
			cells.merge(_flood(map_data, cell, opened, entities_by_cell, true)["cells"])
	return cells


static func switching_escape(before: Dictionary, target: DungeonMap, trigger: Vector2i, exits: Array[Vector2i]) -> Dictionary:
	var budget: int = STATE_LIMIT
	for state in before["watched"]:
		if budget <= 0:
			return {"safe": false, "complete": false}
		var after: Dictionary = _explore(target, trigger, true, state, Vector2i(-1, -1), budget)
		budget -= int(after["expansions"])
		var can_exit := false
		for cell in exits:
			if after["cells"].has(cell):
				can_exit = true
				break
		if not can_exit:
			return {"safe": false, "complete": bool(after["complete"])}
	return {"safe": not before["watched"].is_empty(), "complete": bool(before["complete"])}
