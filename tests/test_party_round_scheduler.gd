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


func _initialize() -> void:
	var battle: BattleState = _setup()
	assert(bool(battle.start_round_combat().get("success", false)))
	var acted: Array[String] = []
	for i in range(4):
		var turn: Dictionary = battle.run_round_turn()
		assert(bool(turn.get("success", false)))
		acted.append(str(turn["actor_id"]))
		assert(bool(turn["round_finished"]) == (i == 3))
	assert(acted.slice(0, 2) == ["hero", "hero_2"])
	assert(acted.slice(2).has("enemy") and acted.slice(2).has("enemy_support"))
	var first_round: Array[String] = acted.duplicate()
	acted.clear()
	for i in range(4):
		acted.append(str(battle.run_round_turn()["actor_id"]))
	assert(acted == first_round)
	assert(battle.get_participant("hero_2").action_cursor == 0)
	assert(battle.get_participant("hero").action_cursor == 2)
	assert(battle.get_participant("hero_2").completed_phases == 1)
	acted.clear()
	for i in range(4):
		var turn: Dictionary = battle.run_round_turn()
		acted.append(str(turn["actor_id"]))
		if i == 0:
			assert(bool(turn["events"][1].get("reload", false)))
	assert(acted == first_round)
	assert(battle.get_participant("hero").completed_phases == 1)
	assert(battle.get_participant("hero_2").action_cursor == 1)

	var changed: BattleState = _setup()
	assert(bool(changed.start_round_combat().get("success", false)))
	changed.run_round_turn()
	changed.get_participant("enemy").agility = 20
	assert(changed.run_round_turn()["actor_id"] == "hero_2")
	changed.run_round_turn()
	changed.run_round_turn()
	assert(changed.run_round_turn()["actor_id"] == "enemy")

	var dead: BattleState = _setup()
	assert(bool(dead.start_round_combat().get("success", false)))
	dead.run_round_turn()
	dead.get_participant("hero_2").health = 0
	assert(dead.run_round_turn()["actor_id"] in ["enemy", "enemy_support"])
	assert(dead.get_participant("hero_2").action_cursor == 0)
	var remained: Dictionary = dead.run_round_turn()
	assert(bool(remained["round_finished"]))
	assert(dead.run_round_turn()["actor_id"] == "hero")

	var first: BattleState = _setup()
	var second: BattleState = _setup()
	assert(bool(first.start_round_combat().get("success", false)))
	assert(bool(second.start_round_combat().get("success", false)))
	for i in range(12):
		assert(first.run_round_turn() == second.run_round_turn())
	quit()
