extends SceneTree


func _initialize() -> void:
	var available_monsters: Array[String] = MonsterCatalog.list_ids()
	var available_heroes: Array[String] = HeroCatalog.list_ids()
	assert(not available_monsters.is_empty() and not available_heroes.is_empty())
	var definition: MonsterDefinition = MonsterCatalog.get_monster(available_monsters[0])
	var hero_state := HeroState.new(HeroCatalog.get_hero(available_heroes[0]))
	var seed: int = 2187
	var battle: BattleState = BattleState.begin(definition, hero_state, seed)
	var enemy: BattleParticipant = battle.get_enemy()
	var unchanged_chain: Array[String] = enemy.action_chain.duplicate()
	assert(not unchanged_chain.is_empty())
	var dummy: BattleParticipant = battle.add_passive_enemy(definition)
	assert(dummy == battle.add_passive_enemy(definition))
	assert(dummy.is_passive)
	assert(not dummy.is_targetable)
	assert(battle.create_context().target_error("hero", dummy.participant_id, AbilityCatalog.get_ability("basic_strike")) != "")
	assert(battle.create_context().default_target_id("hero", AbilityCatalog.get_ability("basic_strike")) == battle.enemy_id)
	var profile := MonsterTacticProfile.new()
	profile.profile_id = "test_policy"
	profile.card_ids = unchanged_chain.duplicate()
	assert(profile.accepts(enemy))
	var chosen: MonsterTacticProfile = MonsterAiPlanner.choose_profile(_definition_with_profiles(definition, [profile]), enemy, "", battle.rng)
	assert(chosen == profile)
	assert(MonsterAiPlanner.planned_chain(profile, enemy, battle.rng) == unchanged_chain)
	var wounded_profile := MonsterTacticProfile.new()
	wounded_profile.profile_id = "wounded"
	wounded_profile.maximum_health_percent = BattleMath.PERCENT_SCALE / 2
	wounded_profile.card_ids = unchanged_chain.duplicate()
	wounded_profile.card_ids.reverse()
	battle.enemy_definition = _definition_with_profiles(definition, [wounded_profile])
	enemy.health = floori(float(enemy.max_health) * float(wounded_profile.maximum_health_percent) / float(BattleMath.PERCENT_SCALE))
	battle.flow.stage = BattleFlow.Stage.EXECUTING
	battle._reconfigure_enemy_for_phase()
	assert(enemy.action_chain == unchanged_chain)
	battle.flow.stage = BattleFlow.Stage.BETWEEN_PHASES
	enemy.action_cursor = 1
	battle._reconfigure_enemy_for_phase()
	assert(enemy.action_chain == unchanged_chain)
	enemy.action_cursor = 0
	battle._reconfigure_enemy_for_phase()
	assert(enemy.action_chain == wounded_profile.card_ids)
	assert(battle.current_enemy_profile_id == wounded_profile.profile_id)
	enemy.health = enemy.max_health
	battle._reconfigure_enemy_for_phase()
	assert(enemy.action_chain == unchanged_chain)
	battle.enemy_definition = definition
	battle.flow.stage = BattleFlow.Stage.PREPARATION
	var unavailable := MonsterTacticProfile.new()
	unavailable.profile_id = "unknown_card"
	unavailable.card_ids = ["nonexistent_ability"]
	assert(MonsterAiPlanner.choose_profile(_definition_with_profiles(definition, [unavailable]), enemy, "", battle.rng) == null)
	var p1 := MonsterTacticProfile.new()
	p1.profile_id = "first"
	p1.card_ids = unchanged_chain.duplicate()
	var p2 := MonsterTacticProfile.new()
	p2.profile_id = "second"
	p2.card_ids = unchanged_chain.duplicate()
	var weighted: MonsterDefinition = _definition_with_profiles(definition, [p1, p2])
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = seed
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = seed
	for iteration in range(12):
		assert(MonsterAiPlanner.choose_profile(weighted, enemy, "", rng_a).profile_id
			== MonsterAiPlanner.choose_profile(weighted, enemy, "", rng_b).profile_id)
	var intermission := MonsterIntermissionAction.new()
	intermission.ability_id = "rest"
	enemy.learned_ability_ids.append(intermission.ability_id)
	assert(intermission.accepts(enemy, 0))
	assert(not intermission.accepts(enemy, intermission.max_uses_per_battle))
	var with_intermission: MonsterDefinition = _definition_with_profiles(definition, [])
	with_intermission.intermission_actions = [intermission]
	assert(MonsterAiPlanner.choose_intermission(with_intermission, enemy, {}, battle.rng) == intermission)
	assert(MonsterAiPlanner.choose_intermission(with_intermission, enemy,
		{intermission.ability_id: intermission.max_uses_per_battle}, battle.rng) == null)
	var self_heal_battle: BattleState = BattleState.begin(definition, hero_state, seed)
	var self_healer: BattleParticipant = self_heal_battle.get_enemy()
	self_heal_battle.enemy_definition = with_intermission
	self_healer.learned_ability_ids.append(intermission.ability_id)
	self_healer.health = maxi(self_healer.max_health - 1, 1)
	var before_heal: int = self_healer.health
	self_heal_battle.flow.stage = BattleFlow.Stage.BETWEEN_PHASES
	var uses_before: int = int(self_heal_battle.enemy_intermission_usage.get(intermission.ability_id, 0))
	self_heal_battle._run_enemy_intermission()
	assert(self_healer.health >= before_heal)
	assert(int(self_heal_battle.enemy_intermission_usage.get(intermission.ability_id, 0)) > uses_before)
	var event_count: int = self_heal_battle.events.size()
	self_heal_battle._run_enemy_intermission()
	assert(self_heal_battle.events.size() == event_count)
	var hero: BattleParticipant = battle.get_hero()
	var action_id: String = ""
	for candidate_id in AbilityCatalog.known_ability_ids(hero):
		if AbilityCatalog.can_prepare(hero, candidate_id):
			action_id = candidate_id
			break
	assert(not action_id.is_empty())
	var hero_chain: Array[String] = []
	for slot in range(hero.action_slot_capacity):
		hero_chain.append(action_id)
	var result: Dictionary = battle.run_phase(hero_chain, unchanged_chain)
	assert(bool(result.get("success", false)))
	var passive_events: int = 0
	for event in result.get("events", []):
		if str(event.get("actor_id", "")) != dummy.participant_id:
			continue
		assert(event.get("type", "") == "passive_rest")
		passive_events += 1
	assert(passive_events > 0)
	assert(dummy.health == dummy.max_health)
	quit()


func _definition_with_profiles(source: MonsterDefinition, profiles: Array) -> MonsterDefinition:
	var result: MonsterDefinition = source.duplicate() as MonsterDefinition
	var typed_profiles: Array[MonsterTacticProfile] = []
	for profile in profiles:
		typed_profiles.append(profile as MonsterTacticProfile)
	result.ai_profiles = typed_profiles
	return result
