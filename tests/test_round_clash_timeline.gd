extends SceneTree


func _initialize() -> void:
	var round_events: Array[Dictionary] = [
		{"type": "round_started", "round": 1},
		{"type": "turn", "actor_id": "hero_2", "round": 1, "slot_index": 0},
		{"type": "action_start", "actor_id": "hero_2", "ability_id": "basic_strike"},
		{"type": "attack", "actor_id": "hero_2", "target_id": "enemy", "damage": 4},
		{"type": "round_finished", "round": 1},
		{"type": "turn", "actor_id": "enemy", "round": 2, "slot_index": 1},
		{"type": "action_start", "actor_id": "enemy", "ability_id": "basic_strike"},
		{"type": "attack", "actor_id": "enemy", "target_id": "hero", "damage": 3}
	]
	var grouped: Array[Dictionary] = BattleClashTimeline.group_events(round_events, true)
	assert(grouped.size() == 3)
	assert(not bool(grouped[0]["is_clash"]))
	for index in [1, 2]:
		assert(bool(grouped[index]["is_clash"]))
		var events: Array[Dictionary] = grouped[index]["events"]
		assert(events[0]["type"] == "turn")
		assert(events[1]["type"] == "action_start")
		assert(events.any(func(event: Dictionary) -> bool: return event.get("type") == "attack"))
	var collected: Array[Dictionary] = []
	for group in grouped:
		collected.append_array(group["events"])
	assert(collected == round_events)

	var blocked: Array[Dictionary] = [
		{"type": "turn", "actor_id": "hero", "slot_index": 0},
		{"type": "action_start", "actor_id": "hero", "ability_id": "guard"},
		{"type": "block", "actor_id": "hero", "target_id": "hero", "armor": 2}
	]
	var defense_groups: Array[Dictionary] = BattleClashTimeline.group_events(blocked, true)
	assert(defense_groups.size() == 1)
	assert(bool(defense_groups[0]["is_clash"]))

	var resting: Array[Dictionary] = [
		{"type": "turn", "actor_id": "enemy_support", "reload": true},
		{"type": "reload", "actor_id": "enemy_support"}
	]
	var rest_groups: Array[Dictionary] = BattleClashTimeline.group_events(resting, true)
	assert(rest_groups.size() == 1)
	assert(bool(rest_groups[0]["is_clash"]))
	quit()
