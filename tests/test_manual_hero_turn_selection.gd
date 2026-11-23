extends SceneTree


func _actor(id: String, team: String, agility: int) -> BattleParticipant:
	var participant := BattleParticipant.new()
	participant.participant_id = id
	participant.team_id = team
	participant.health = 1000
	participant.max_health = 1000
	participant.agility = agility
	participant.personal_ability_ids = ["guard", "basic_strike"]
	participant.action_chain = ["basic_strike"]
	return participant


func _battle() -> BattleState:
	var state := BattleState.new()
	state.rng.seed = 27427
	state.party_hero_ids = ["hero", "hero_2"]
	state.participants["hero"] = _actor("hero", "heroes", 5)
	state.participants["hero_2"] = _actor("hero_2", "heroes", 4)
	state.participants["enemy"] = _actor("enemy", "enemies", 3)
	state.participants["enemy_support"] = _actor("enemy_support", "enemies", 3)
	assert(bool(state.start_round_combat().get("success", false)))
	return state


func _initialize() -> void:
	var state := _battle()
	assert(state.prepare_next_round() == "hero")
	var initial: int = state.events.size()
	assert(not bool(state.run_round_turn().get("success", false)))
	assert(not bool(state.run_round_turn("enemy", "nonexistent").get("success", false)))
	assert(not bool(state.run_round_turn("hero", "guard").get("success", false)))
	assert(state.round_turn_count == 0)
	assert(state.events.size() == initial)
	assert(state.next_round_actor_id() == "hero")
	var block: Dictionary = state.run_round_turn("hero", "guard")
	assert(bool(block.get("success", false)))
	assert(block["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "block" and e.get("actor_id") == "hero"))
	assert(state.get_participant("hero").action_cursor == 0)
	assert(state.prepare_next_round() == "hero_2")
	var rest: Dictionary = state.run_round_turn("", "rest")
	assert(bool(rest.get("success", false)))
	assert(rest["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "rest"))
	assert(state.get_participant("hero_2").action_cursor == 0)
	assert(state.prepare_next_round() == "enemy")
	var enemy_turn: Dictionary = state.run_round_turn()
	assert(bool(enemy_turn.get("success", false)))
	assert(enemy_turn["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "enemy_target_selected"))
	assert(state.prepare_next_round() == "enemy_support")
	assert(bool(state.run_round_turn().get("success", false)))
	assert(state.prepare_next_round() == "hero")
	var strike: Dictionary = state.run_round_turn("enemy", "basic_strike")
	assert(bool(strike.get("success", false)))
	assert(strike["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "action_start" and e.get("ability_id") == "basic_strike"))
	assert(state.get_participant("hero").action_cursor == 0)
	quit()
