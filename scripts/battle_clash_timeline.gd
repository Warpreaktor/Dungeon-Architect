class_name BattleClashTimeline
extends RefCounted


static func group_events(events: Array) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var current: Array[Dictionary] = []
	var is_clash: bool = false
	for value in events:
		var event: Dictionary = value
		if str(event.get("type", "")) == "tick":
			if not current.is_empty():
				groups.append({"is_clash": is_clash, "events": current})
			current = []
			is_clash = true
		current.append(event)
	if not current.is_empty():
		groups.append({"is_clash": is_clash, "events": current})
	return groups
