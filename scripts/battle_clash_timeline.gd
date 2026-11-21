class_name BattleClashTimeline
extends RefCounted


static func group_events(events: Array, split_actions: bool = false) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var current: Array[Dictionary] = []
	var is_clash: bool = false
	var action_started: bool = false
	for value in events:
		var event: Dictionary = value
		var kind: String = str(event.get("type", ""))
		if kind == "tick" or (split_actions and (
				(kind == "counter" and not current.is_empty())
				or (action_started and kind in ["action_start", "reload"]))):
			if not current.is_empty():
				groups.append({"is_clash": is_clash, "events": current})
			current = []
			is_clash = true
			action_started = false
		if kind in ["action_start", "reload", "counter"]:
			action_started = true
		current.append(event)
	if not current.is_empty():
		groups.append({"is_clash": is_clash, "events": current})
	return groups
