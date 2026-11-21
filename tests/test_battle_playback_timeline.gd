extends SceneTree

func _initialize() -> void:
	var events: Array[Dictionary] = [
		{"type": "tick", "tick": 1},
		{"type": "action_start", "actor_id": "hero", "ability_id": "basic_strike"},
		{"type": "attack", "actor_id": "hero", "damage": 2},
		{"type": "action_start", "actor_id": "enemy", "ability_id": "basic_strike"},
		{"type": "attack", "actor_id": "enemy", "damage": 1},
		{"type": "tick", "tick": 2},
		{"type": "reload", "actor_id": "hero"},
		{"type": "action_start", "actor_id": "enemy", "ability_id": "basic_strike"},
		{"type": "attack", "actor_id": "enemy", "damage": 1}
	]
	var steps := BattlePlaybackTimeline.split_events(events)
	assert(steps.size() == 4)
	assert(not bool(steps[0]["tick_end"]))
	assert(bool(steps[1]["tick_end"]))
	assert(not bool(steps[2]["tick_end"]))
	assert(bool(steps[3]["tick_end"]))
	var reconstructed: Array[Dictionary] = []
	for step in steps:
		reconstructed.append_array(step["events"])
	assert(reconstructed == events)
	quit()
