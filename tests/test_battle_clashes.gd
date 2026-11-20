extends SceneTree


func _fighter(id: String, team: String, agility: int) -> BattleParticipant:
	var actor := BattleParticipant.new()
	actor.participant_id = id
	actor.team_id = team
	actor.max_health = BattleMath.PERCENT_SCALE * 3
	actor.health = actor.max_health
	actor.agility = agility
	actor.strength = agility
	actor.accuracy_bonus = BattleMath.PERCENT_SCALE
	actor.action_slot_capacity = 3
	actor.personal_ability_ids = ["basic_strike", "guard"]
	return actor


func _battle() -> BattleState:
	var battle := BattleState.new()
	battle.rng.seed = BattleMath.PERCENT_SCALE
	battle.participants[battle.hero_id] = _fighter(battle.hero_id, "heroes", 3)
	battle.participants[battle.enemy_id] = _fighter(battle.enemy_id, "enemies", 4)
	battle.participants[battle.support_enemy_id] = _fighter(battle.support_enemy_id, "enemies", 4)
	battle.get_enemy().action_chain = ["basic_strike", "basic_strike", "basic_strike"]
	battle.get_participant(battle.support_enemy_id).action_chain = ["basic_strike", "basic_strike", "basic_strike"]
	return battle


func _clash_events(events: Array[Dictionary], index: int) -> Array[Dictionary]:
	var groups: Array[Dictionary] = BattleClashTimeline.group_events(events)
	return groups[index]["events"]


func _event_index(events: Array[Dictionary], kind: String, actor_id: String) -> int:
	for index in range(events.size()):
		if str(events[index].get("type", "")) == kind and str(events[index].get("actor_id", "")) == actor_id:
			return index
	return -1


func _initialize() -> void:
	var battle: BattleState = _battle()
	var actions: Array[String] = ["basic_strike", "guard", "basic_strike"]
	var result: Dictionary = battle.run_phase(actions, battle.get_enemy().action_chain)
	assert(bool(result.get("success", false)))
	var groups: Array[Dictionary] = BattleClashTimeline.group_events(result.get("events", []))
	assert(groups.size() == BattleChainPlanner.phase_length(actions, []))
	var opponents: Array[String] = []
	for group in groups:
		assert(bool(group.get("is_clash", false)))
		var entries: Array[Dictionary] = group["events"]
		assert(str(entries[0].get("type", "")) == "tick")
		opponents.append(str(entries[0].get("opponent_id", "")))
	assert(opponents == [battle.enemy_id, battle.support_enemy_id, battle.enemy_id, battle.support_enemy_id])
	var first: Array[Dictionary] = _clash_events(result["events"], 0)
	assert(_event_index(first, "attack", battle.enemy_id) >= 0)
	assert(_event_index(first, "attack", battle.hero_id) > _event_index(first, "attack", battle.enemy_id))
	var second: Array[Dictionary] = _clash_events(result["events"], 1)
	assert(_event_index(second, "block", battle.hero_id) >= 0)
	assert(_event_index(second, "attack", battle.support_enemy_id) > _event_index(second, "block", battle.hero_id))
	assert(battle.get_enemy().action_cursor == 2)
	assert(battle.get_participant(battle.support_enemy_id).action_cursor == 2)

	var repeat: BattleState = _battle()
	var replay: Dictionary = repeat.run_phase(actions, repeat.get_enemy().action_chain)
	assert(replay.get("events", []) == result.get("events", []))

	var targeting: BattleState = _battle()
	targeting.get_participant(targeting.support_enemy_id).is_targetable = true
	var targeted: Dictionary = targeting.run_phase(["basic_strike", "basic_strike", "guard"], targeting.get_enemy().action_chain)
	var second_target: Array[Dictionary] = _clash_events(targeted["events"], 1)
	var targeted_support: bool = false
	for event in second_target:
		if event.get("type", "") == "attack" and event.get("actor_id", "") == targeting.hero_id and event.get("target_id", "") == targeting.support_enemy_id:
			targeted_support = true
	assert(targeted_support)

	var dead: BattleState = _battle()
	dead.get_enemy().health = 0
	assert(BattleClashPlanner.next_opponent(dead.participants, dead.enemy_ids(), 0)["actor_id"] == dead.support_enemy_id)
	assert(BattleClashPlanner.next_opponent(dead.participants, dead.enemy_ids(), 1)["actor_id"] == dead.support_enemy_id)
	dead.get_participant(dead.support_enemy_id).health = 0
	assert(str(BattleClashPlanner.next_opponent(dead.participants, dead.enemy_ids(), 0)["actor_id"]).is_empty())

	var prepared: Array = [
		{"type": "enemy_chain_changed", "actor_id": "enemy"},
		{"type": "tick", "tick": 1},
		{"type": "action_start", "actor_id": "hero"},
		{"type": "attack", "actor_id": "enemy"},
		{"type": "tick", "tick": 2},
		{"type": "block", "actor_id": "hero"}
	]
	var divided: Array[Dictionary] = BattleClashTimeline.group_events(prepared)
	assert(divided.size() == 3)
	assert(not divided[0]["is_clash"] and divided[1]["is_clash"] and divided[2]["is_clash"])
	var collected: Array[Dictionary] = []
	for group in divided:
		collected.append_array(group["events"])
	assert(collected == prepared)
	quit()
