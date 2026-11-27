extends SceneTree


func _fighter(id: String, team: String, agility: int, actions: Array[String]) -> BattleParticipant:
	var actor := BattleParticipant.new()
	actor.participant_id = id
	actor.team_id = team
	actor.max_health = 1000
	actor.health = 1000
	actor.agility = agility
	actor.personal_ability_ids = ["guard", "basic_strike"]
	actor.action_chain = actions.duplicate()
	return actor


func _setup(seed: int = 4275) -> BattleState:
	var battle := BattleState.new()
	battle.rng.seed = seed
	battle.party_hero_ids = ["hero", "hero_2"]
	battle.participants["hero"] = _fighter("hero", "heroes", 5, ["guard", "guard"])
	battle.participants["hero_2"] = _fighter("hero_2", "heroes", 4, ["guard"])
	battle.participants["enemy"] = _fighter("enemy", "enemies", 3, ["guard"])
	battle.participants["enemy_support"] = _fighter("enemy_support", "enemies", 3, ["guard"])
	return battle


func _turn(state: BattleState, action: String = "guard") -> Dictionary:
	var actor_id: String = state.prepare_next_round()
	return state.run_round_turn(actor_id if actor_id in state.hero_ids() else "", action if actor_id in state.hero_ids() else "")


func _initialize() -> void:
	var battle: BattleState = _setup()
	assert(bool(battle.start_round_combat().get("success", false)))
	assert(battle.prepare_next_round() == "hero")
	var before_events: int = battle.events.size()
	var missing: Dictionary = battle.run_round_turn()
	assert(not bool(missing.get("success", false)))
	assert(battle.round_turn_count == 0)
	assert(battle.events.size() == before_events)
	var acted: Array[String] = []
	for i in range(4):
		var turn: Dictionary = _turn(battle)
		assert(bool(turn.get("success", false)))
		acted.append(str(turn["actor_id"]))
		assert(bool(turn["round_finished"]) == (i == 3))
	assert(acted.slice(0, 2) == ["hero", "hero_2"])
	assert(acted.slice(2).has("enemy") and acted.slice(2).has("enemy_support"))
	var first_round: Array[String] = acted.duplicate()
	acted.clear()
	for i in range(4):
		acted.append(str(_turn(battle)["actor_id"]))
	assert(acted == first_round)
	assert(battle.get_participant("hero").action_cursor == 0)
	assert(battle.get_participant("hero_2").action_cursor == 0)
	assert(battle.get_participant("hero").completed_phases == 0)
	assert(not battle.run_round_turn("", "rest").success)
	assert(_turn(battle).success)
	assert(battle.get_participant("hero").action_cursor == 0)

	var changed: BattleState = _setup()
	assert(bool(changed.start_round_combat().get("success", false)))
	_turn(changed)
	changed.get_participant("enemy").agility = 20
	assert(_turn(changed)["actor_id"] == "hero_2")
	_turn(changed)
	_turn(changed)
	assert(_turn(changed)["actor_id"] == "enemy")

	var dead: BattleState = _setup()
	assert(bool(dead.start_round_combat().get("success", false)))
	_turn(dead)
	dead.get_participant("hero_2").health = 0
	assert(_turn(dead)["actor_id"] in ["enemy", "enemy_support"])
	assert(dead.get_participant("hero_2").action_cursor == 0)
	assert(bool(_turn(dead)["round_finished"]))
	assert(_turn(dead)["actor_id"] == "hero")

	var first: BattleState = _setup()
	var second: BattleState = _setup()
	assert(bool(first.start_round_combat().get("success", false)))
	assert(bool(second.start_round_combat().get("success", false)))
	for i in range(12):
		assert(_turn(first) == _turn(second))
	quit()
