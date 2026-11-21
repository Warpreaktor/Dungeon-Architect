extends SceneTree


func _initialize() -> void:
	var definition: MonsterDefinition = MonsterCatalog.get_monster(MonsterCatalog.list_ids()[0])
	var hero_definition: HeroDefinition = HeroCatalog.get_hero("volcha")
	var source := HeroState.new(hero_definition)
	var seed: int = source.max_health + definition.max_health
	var battle: BattleState = BattleState.begin(definition, source, seed)
	var support: BattleParticipant = battle.add_support_enemy(definition)
	var main: BattleParticipant = battle.get_enemy()
	assert(support != null and main != null)
	assert(main != support and main.action_chain.size() > 0 and support.action_chain.size() > 0)
	assert(battle.enemy_ids() == [battle.enemy_id, battle.support_enemy_id])
	var attack: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
	assert(battle.create_context().target_ids("hero", attack) == [battle.enemy_id, battle.support_enemy_id])
	assert(battle.create_context().target_ids(battle.enemy_id, attack) == [battle.hero_id])
	assert(battle.create_context().target_ids(battle.support_enemy_id, attack) == [battle.hero_id])
	var ally: BattleParticipant = BattleParticipant.from_hero(source, "hero_ally")
	battle.participants[ally.participant_id] = ally
	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = seed
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = seed
	var first_context := BattleContext.new(battle.participants, first_rng)
	var second_context := BattleContext.new(battle.participants, second_rng)
	var candidates: Array[String] = first_context.target_ids(battle.enemy_id, attack)
	assert(candidates.has(battle.hero_id) and candidates.has(ally.participant_id))
	for _try in range(candidates.size()):
		var chosen: String = first_context.choose_target_id(battle.enemy_id, attack)
		assert(candidates.has(chosen))
		assert(chosen == second_context.choose_target_id(battle.enemy_id, attack))
	battle.participants.erase(ally.participant_id)
	var same: BattleState = BattleState.begin(definition, source, seed)
	same.add_support_enemy(definition)
	assert(same.get_enemy().action_chain == main.action_chain)
	assert(same.get_participant(same.support_enemy_id).action_chain == support.action_chain)
	var known: AbilityDefinition = AbilityCatalog.get_ability("volcha_wolf_instinct")
	var hero_chain: Array[String] = []
	for _slot in range(battle.get_hero().action_slot_capacity):
		hero_chain.append(known.ability_id)
	var result: Dictionary = BattlePhaseTestDriver.run_phase(battle, hero_chain, main.action_chain)
	assert(bool(result.get("success", false)))
	var actors: Array[String] = []
	var opponents: Array[String] = []
	var ticks: int = 0
	for event in result.get("events", []):
		if event.get("type", "") == "tick":
			if not actors.is_empty():
				assert(actors.size() == 2)
				assert(actors.has(battle.hero_id))
				assert(actors.has(opponents[-1]))
			actors.clear()
			opponents.append(str(event.get("opponent_id", "")))
			ticks += 1
		elif event.get("type", "") in ["action_start", "reload"]:
			actors.append(str(event.get("actor_id", "")))
	assert(ticks > 0)
	assert(actors.size() == 2 and actors.has(battle.hero_id) and actors.has(opponents[-1]))
	assert(opponents[0] == battle.enemy_id)
	if opponents.size() > 1:
		assert(opponents[1] == battle.support_enemy_id)
	assert(not battle.is_victory)
	main.health = 0
	battle.update_outcome()
	assert(not battle.is_victory)
	assert(support.is_targetable)
	assert(battle.create_context().target_ids("hero", attack) == [battle.support_enemy_id])
	assert(battle.create_context().choose_target_id("hero", attack) == battle.support_enemy_id)
	assert(battle.create_context().target_error("hero", battle.enemy_id, attack) != "")
	support.health = 0
	battle.update_outcome()
	assert(battle.is_victory)
	quit()
