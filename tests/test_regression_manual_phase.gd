extends SceneTree


func _participant(id: String, team: String) -> BattleParticipant:
	var actor := BattleParticipant.new()
	actor.participant_id = id
	actor.team_id = team
	actor.max_health = 500
	actor.health = 500
	actor.strength = 2
	actor.agility = 10 if id == "hero" else 1
	actor.action_slot_capacity = 3
	actor.personal_ability_ids = ["basic_strike", "guard"]
	return actor


func _encounter() -> BattleState:
	var battle := BattleState.new()
	battle.rng.seed = 4922
	battle.participants[battle.hero_id] = _participant("hero", "heroes")
	battle.participants[battle.enemy_id] = _participant("enemy", "enemies")
	battle.participants[battle.support_enemy_id] = _participant("enemy_support", "enemies")
	battle.get_enemy().action_chain = ["basic_strike", "guard"]
	battle.get_participant(battle.support_enemy_id).action_chain = ["guard", "basic_strike"]
	return battle


func _initialize() -> void:
	var deck: Array[String] = ["basic_strike", "guard", "basic_strike"]
	var one := _encounter()
	var two := _encounter()
	for battle in [one, two]:
		assert(battle.prepare_manual_combat(deck).success)
		assert(battle.manual_available_slots() == [0, 1, 2])
	var commands: Array[Dictionary] = [
		{"slot": 0, "target": "enemy_support"},
		{"slot": 1, "target": "hero"},
		{"slot": 2, "target": "enemy"},
		{"slot": -1, "target": ""},
	]
	for command in commands:
		var first: Dictionary = one.run_manual_tick(command.slot, command.target)
		var second: Dictionary = two.run_manual_tick(command.slot, command.target)
		assert(first.success and second.success)
		assert(first.events == second.events)
		assert(first.tick_performed and second.tick_performed)
		if command.slot == 0:
			assert(first.events[0].opponent_id == "enemy")
			var hit_support: bool = false
			for event in first.events:
				if event.get("type") == "attack" and event.get("actor_id") == "hero" and event.get("target_id") == "enemy_support":
					hit_support = true
			assert(hit_support)
			var previous_rng: int = one.rng.state
			var previous_events: int = one.events.size()
			assert(not one.run_manual_tick(0, "enemy").success)
			assert(one.events.size() == previous_events and one.rng.state == previous_rng)
	assert(one.get_hero().completed_phases == 1)
	assert(one.manual_available_slots() == [0, 1, 2])
	assert(one.flow.stage == BattleFlow.Stage.BETWEEN_PHASES)
	assert(one.rng.state == two.rng.state)
	assert(one.get_enemy().health == two.get_enemy().health)
	assert(one.get_participant(one.support_enemy_id).health == two.get_participant(two.support_enemy_id).health)
	assert(one.get_enemy().action_cursor == two.get_enemy().action_cursor)
	assert(one.get_participant(one.support_enemy_id).action_cursor == two.get_participant(two.support_enemy_id).action_cursor)
	assert(one.run_manual_tick(0, "enemy").success)
	assert(one.flow.phase_number == 2)
	quit()
