class_name BattlePlaybackTimeline
extends RefCounted


static func split_events(events: Array) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for group in BattleClashTimeline.group_events(events):
		var current: Array[Dictionary] = []
		var has_action: bool = false
		var tick: int = -1
		for value in group["events"]:
			var event: Dictionary = value
			var kind: String = str(event.get("type", ""))
			if kind == "tick":
				tick = int(event.get("tick", -1))
			if (kind == "action_start" or kind == "reload") and has_action:
				steps.append({"events": current, "tick": tick, "tick_end": false})
				current = []
				has_action = false
			current.append(event)
			if kind == "action_start" or kind == "reload":
				has_action = true
		if not current.is_empty():
			steps.append({"events": current, "tick": tick, "tick_end": true})
	return steps


static func describe_events(events: Array, hero_name: String, enemy_name: String, support_name: String) -> Array[String]:
	var lines: Array[String] = []
	for value in events:
		var event: Dictionary = value
		var line: String = BattleCombatLog.format_event(event, hero_name, enemy_name, support_name)
		if not line.is_empty():
			lines.append(line.strip_edges())
	return lines
