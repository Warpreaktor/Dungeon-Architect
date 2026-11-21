extends SceneTree


func _initialize() -> void:
	var ability: AbilityDefinition = AbilityCatalog.get_ability("petushan_feathers_up")
	assert(ability != null)
	assert(ability.target == AbilityDefinition.Target.SELF)
	assert(is_equal_approx(ability.effects[0].counter_damage_multiplier, 0.8))
	var hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	var battle := BattleState.begin(MonsterCatalog.get_monster("hunter"), hero, 1234)
	var user: BattleParticipant = battle.get_hero()
	var enemy: BattleParticipant = battle.get_enemy()
	assert(battle.execute_ability("hero", "hero", ability.ability_id).success)
	assert(user.statuses.has("petushan_feathers_up"))
	var result: Dictionary = battle.execute_ability("enemy", "hero", "basic_strike")
	assert(result.success)
	var counters: Array[Dictionary] = []
	for event in result.events:
		if event.get("type", "") == "counter":
			counters.append(event)
	assert(counters.size() == 1)
	var event_kinds: Array[String] = []
	for event in result.events:
		event_kinds.append(str(event.get("type", "")))
	assert(event_kinds.find("attack") < event_kinds.find("counter"))
	assert(BattleClashTimeline.group_events(result.events, true).size() >= 2)
	assert(counters[0].actor_id == "hero")
	assert(counters[0].target_id == "enemy")
	assert(counters[0].raw_damage == floori(user.melee_attack_value() * ability.effects[0].counter_damage_multiplier))
	user.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(user.statuses.has("petushan_feathers_up"))
	var second: Dictionary = battle.execute_ability("enemy", "hero", "basic_strike")
	assert(second.success)
	var counter_count: int = 0
	for event in second.events:
		if event.get("type", "") == "counter":
			counter_count += 1
	assert(counter_count == 1)
	user.commit_hero_result(hero)
	assert(not hero.overworld_statuses.has("petushan_feathers_up"))
	assert(enemy.health <= enemy.max_health)
	quit()
