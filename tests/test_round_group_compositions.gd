extends SceneTree


func _fighter(id: String, team: String, agility: int) -> BattleParticipant:
	var actor := BattleParticipant.new()
	actor.participant_id = id
	actor.team_id = team
	actor.max_health = 1000
	actor.health = 1000
	actor.agility = agility
	actor.personal_ability_ids = ["guard", "basic_strike"]
	actor.action_chain = ["guard"]
	return actor


func _battle(hero_count: int, enemy_count: int, seed: int) -> BattleState:
	var state := BattleState.new()
	state.rng.seed = seed
	for index in range(hero_count):
		var id: String = "hero" if index == 0 else "hero_%d" % (index + 1)
		state.participants[id] = _fighter(id, "heroes", 12 - index)
		state.party_hero_ids.append(id)
	for index in range(enemy_count):
		var id: String = "enemy" if index == 0 else ("enemy_support" if index == 1 else "enemy_%d" % (index + 1))
		state.participants[id] = _fighter(id, "enemies", 8 - index)
	return state


func _exercise(hero_count: int, enemy_count: int) -> void:
	var first := _battle(hero_count, enemy_count, 4279)
	var replay := _battle(hero_count, enemy_count, 4279)
	assert(first.start_round_combat().get("success", false))
	assert(replay.start_round_combat().get("success", false))
	var expected_count: int = hero_count + enemy_count
	var expected_ids: Array[String] = first.hero_ids() + first.enemy_ids()
	var first_round: Array[String] = []
	for round_index in range(2):
		var seen: Array[String] = []
		for index in range(expected_count):
			var actor_id: String = first.prepare_next_round()
			assert(actor_id == replay.prepare_next_round())
			assert(not actor_id.is_empty() and not seen.has(actor_id))
			var ability: String = "rest" if actor_id in first.hero_ids() else ""
			var turn: Dictionary = first.run_round_turn(actor_id if not ability.is_empty() else "", ability)
			var repeat_turn: Dictionary = replay.run_round_turn(actor_id if not ability.is_empty() else "", ability)
			assert(turn == repeat_turn)
			assert(turn.get("success", false))
			assert(turn.get("actor_id") == actor_id)
			assert(turn.get("round_finished", false) == (index == expected_count - 1))
			seen.append(actor_id)
		assert(seen.size() == expected_count)
		for id in expected_ids:
			assert(seen.has(id))
		if round_index == 0:
			first_round = seen.duplicate()
		else:
			assert(seen == first_round)
	assert(first.round_turn_count == expected_count * 2)
	for id in first.hero_ids():
		assert(first.get_participant(id).action_cursor == 0)


func _initialize() -> void:
	for hero_count in range(1, 5):
		for enemy_count in range(1, 5):
			_exercise(hero_count, enemy_count)
	print("Group compositions 1–4 heroes against 1–4 enemies: OK")
	quit()
