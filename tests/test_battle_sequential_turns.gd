extends SceneTree


func _fighter(actor_id: String, team: String, agility: int) -> BattleParticipant:
	var participant := BattleParticipant.new()
	participant.participant_id = actor_id
	participant.team_id = team
	participant.max_health = 500
	participant.health = 500
	participant.strength = 4
	participant.agility = agility
	participant.accuracy_bonus = 100
	participant.action_slot_capacity = 3
	participant.personal_ability_ids = ["basic_strike", "guard"]
	return participant


func _actor_order(events: Array) -> Array[String]:
	var result: Array[String] = []
	for event in events:
		if str(event.get("type", "")) in ["action_start"]:
			result.append(str(event.get("actor_id", "")))
	return result


func _initialize() -> void:
	var battle := BattleState.new()
	battle.rng.seed = 18442
	battle.participants[battle.hero_id] = _fighter("hero", "heroes", 1)
	battle.participants[battle.enemy_id] = _fighter("enemy", "enemies", 4)
	battle.participants[battle.support_enemy_id] = _fighter("enemy_support", "enemies", 9)
	battle.get_enemy().action_chain = ["basic_strike"]
	battle.get_participant(battle.support_enemy_id).action_chain = ["basic_strike"]
	var cards: Array[String] = ["basic_strike", "guard", "basic_strike"]
	assert(battle.prepare_manual_combat(cards).success)
	assert(battle.manual_next_enemy_step().actor_id == "enemy_support")
	var first: Dictionary = battle.run_manual_tick(0, "enemy")
	assert(first.success)
	assert(_actor_order(first.events) == ["hero", "enemy_support"])
	assert(battle.manual_next_enemy_step().actor_id == "enemy")
	var second: Dictionary = battle.run_manual_tick(1, "hero")
	assert(second.success)
	assert(_actor_order(second.events) == ["hero", "enemy"])
	assert(battle.manual_next_enemy_step().actor_id == "enemy_support")
	assert(battle.manual_available_slots() == [2])
	var frames: Array[Dictionary] = BattleClashTimeline.group_events(first.events, true)
	assert(frames.size() == 2)
	assert(_actor_order(frames[0].events) == ["hero"])
	assert(_actor_order(frames[1].events) == ["enemy_support"])
	var recovered: Array[Dictionary] = []
	for frame in frames:
		recovered.append_array(frame.events)
	assert(recovered == first.events)

	var ally: BattleParticipant = _fighter("hero_support", "heroes", 4)
	battle.participants[ally.participant_id] = ally
	var hero_team: Array[String] = ["hero", "hero_support"]
	var allied_first: Dictionary = BattleClashPlanner.next_actor(battle.participants, hero_team, 0)
	var allied_second: Dictionary = BattleClashPlanner.next_actor(battle.participants, hero_team, allied_first.next_cursor)
	assert(allied_first.actor_id == "hero_support" and allied_second.actor_id == "hero")
	var single_team: Array[String] = ["hero"]
	assert(BattleClashPlanner.next_actor(battle.participants, single_team, 0).actor_id == "hero")
	assert(BattleClashPlanner.next_actor(battle.participants, single_team, 1).actor_id == "hero")

	battle.get_enemy().agility = 9
	battle.get_participant(battle.support_enemy_id).agility = 9
	var ordered: Array[String] = BattleClashPlanner.ordered_opponents(battle.participants, battle.enemy_ids())
	assert(ordered == ["enemy", "enemy_support"])
	battle.get_enemy().health = 0
	assert(BattleClashPlanner.next_opponent(battle.participants, battle.enemy_ids(), 0).actor_id == "enemy_support")

	var solo := BattleState.new()
	solo.rng.seed = 42
	solo.participants[solo.hero_id] = _fighter("hero", "heroes", 1)
	solo.participants[solo.enemy_id] = _fighter("enemy", "enemies", 99)
	solo.get_enemy().action_chain = ["basic_strike"]
	assert(solo.prepare_manual_combat(cards).success)
	var lone: Dictionary = solo.run_manual_tick(0, "enemy")
	assert(lone.success and _actor_order(lone.events) == ["hero", "enemy"])
	quit()
