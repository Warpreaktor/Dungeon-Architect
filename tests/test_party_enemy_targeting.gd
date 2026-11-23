extends SceneTree


func _fighter(id: String, team: String, agility: int, cards: Array[String]) -> BattleParticipant:
	var fighter := BattleParticipant.new()
	fighter.participant_id = id
	fighter.team_id = team
	fighter.max_health = 1000
	fighter.health = 1000
	fighter.agility = agility
	fighter.strength = 1
	fighter.personal_ability_ids = ["basic_strike", "guard"]
	fighter.action_chain = cards.duplicate()
	return fighter


func _battle(seed: int) -> BattleState:
	var state := BattleState.new()
	state.rng.seed = seed
	state.party_hero_ids = ["hero", "hero_2"]
	state.participants["hero"] = _fighter("hero", "heroes", 6, ["guard"])
	state.participants["hero_2"] = _fighter("hero_2", "heroes", 5, ["guard"])
	state.participants["enemy"] = _fighter("enemy", "enemies", 4, ["basic_strike"])
	state.participants["enemy_support"] = _fighter("enemy_support", "enemies", 3, ["basic_strike"])
	return state


func _target_trace(state: BattleState, turns: int) -> Array[String]:
	var targets: Array[String] = []
	for index in range(turns):
		var turn: Dictionary = state.run_round_turn()
		assert(bool(turn.get("success", false)))
		for event in turn["events"]:
			if str(event.get("type", "")) == "enemy_target_selected":
				var target_id: String = str(event["target_id"])
				assert(target_id in state.living_hero_ids())
				targets.append(target_id)
	return targets


func _initialize() -> void:
	var first: BattleState = _battle(4276)
	var second: BattleState = _battle(4276)
	assert(bool(first.start_round_combat().get("success", false)))
	assert(bool(second.start_round_combat().get("success", false)))
	var targets: Array[String] = _target_trace(first, 36)
	assert(targets == _target_trace(second, 36))
	assert(targets.has("hero") and targets.has("hero_2"))

	var remaining: BattleState = _battle(4276)
	assert(bool(remaining.start_round_combat().get("success", false)))
	remaining.get_participant("hero").health = 0
	remaining.update_outcome()
	assert(not remaining.is_defeat)
	assert(_target_trace(remaining, 12).all(func(id: String) -> bool: return id == "hero_2"))
	assert(remaining.get_participant("hero").health == 0)

	var unavailable: BattleState = _battle(4276)
	assert(bool(unavailable.start_round_combat().get("success", false)))
	unavailable.run_round_turn()
	unavailable.run_round_turn()
	unavailable.get_participant("enemy").action_chain = ["missing_ability"]
	var failed_turn: Dictionary = unavailable.run_round_turn()
	assert(not failed_turn["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "enemy_target_selected"))
	assert(failed_turn["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "failed"))
	assert(not failed_turn["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "attack"))

	var untargetable: BattleState = _battle(4276)
	assert(bool(untargetable.start_round_combat().get("success", false)))
	untargetable.run_round_turn()
	untargetable.run_round_turn()
	untargetable.get_participant("hero").is_targetable = false
	untargetable.get_participant("hero_2").is_targetable = false
	var without_targets: Dictionary = untargetable.run_round_turn()
	assert(not without_targets["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "enemy_target_selected"))
	assert(without_targets["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "failed"))

	var guarded: BattleState = _battle(4276)
	guarded.get_participant("enemy").action_chain = ["guard"]
	assert(bool(guarded.start_round_combat().get("success", false)))
	guarded.run_round_turn()
	guarded.run_round_turn()
	var guard_turn: Dictionary = guarded.run_round_turn()
	assert(not guard_turn["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "enemy_target_selected"))
	assert(guard_turn["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "block" and e.get("target_id") == "enemy"))

	var adaptive: BattleState = _battle(4276)
	var definition := MonsterDefinition.new()
	definition.monster_id = "test_enemy"
	var wounded := MonsterTacticProfile.new()
	wounded.profile_id = "wounded"
	wounded.maximum_health_percent = 50
	wounded.card_ids = ["guard"]
	definition.ai_profiles.append(wounded)
	adaptive.enemy_definition = definition
	adaptive.initial_enemy_chain = ["basic_strike"]
	adaptive.get_participant("enemy").health = 300
	assert(bool(adaptive.start_round_combat().get("success", false)))
	adaptive.run_round_turn()
	adaptive.run_round_turn()
	var adapted_turn: Dictionary = adaptive.run_round_turn()
	assert(adapted_turn["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "enemy_chain_changed"))
	assert(adapted_turn["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "block"))
	assert(not adapted_turn["events"].any(func(e: Dictionary) -> bool: return e.get("type") == "enemy_target_selected"))
	var boss: MonsterDefinition = MonsterCatalog.get_monster("rabbit_symbiont")
	assert(boss != null and boss.battle_bond != null)
	var heroes: Array[HeroState] = [
		HeroState.new(HeroCatalog.get_hero(HeroCatalog.list_ids()[0])),
		HeroState.new(HeroCatalog.get_hero(HeroCatalog.list_ids()[1]))
	]
	var encounter := CombatSession.new(boss, heroes[0], null, 4276, heroes)
	var bonded: BattleState = encounter.battle_state
	var command: AbilityDefinition = AbilityCatalog.get_ability(boss.battle_bond.command_ability_id)
	assert(bonded.create_context().target_ids(bonded.support_enemy_id, command) == ["hero", "hero_2"])
	var marked_target: String = bonded.create_context().choose_target_id(bonded.support_enemy_id, command)
	assert(bool(bonded.execute_ability(bonded.support_enemy_id, marked_target, command.ability_id).get("success")))
	assert(bonded.bond_marked_target_id == marked_target)
	assert(bonded.get_participant(marked_target).statuses.has(boss.battle_bond.marked_status_id))
	quit()
