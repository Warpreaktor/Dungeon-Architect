extends SceneTree


func _initialize() -> void:
	_check_catalog()
	_check_stances()
	_check_whirlwind()
	_check_cry_and_charge()
	_check_passive_and_finisher()
	quit()


func _fighters(hero_health: int = -1) -> BattleContext:
	var source := HeroState.new(HeroCatalog.get_hero("petushan"))
	if hero_health >= 0:
		source.health = hero_health
	var hero := BattleParticipant.from_hero(source)
	var enemy := BattleParticipant.from_monster(MonsterCatalog.get_monster("hunter"))
	return BattleContext.new({"hero": hero, "enemy": enemy})


func _events_of(outcome: Dictionary, kind: String) -> Array:
	assert(outcome.success, str(outcome.get("reason", "")))
	return outcome.events.filter(func(event: Dictionary) -> bool: return event.get("type", "") == kind)


func _check_catalog() -> void:
	var context := _fighters()
	var hero := context.get_participant("hero")
	var expected: Array[String] = ["petushan_peck_while_hot", "petushan_not_in_brow_but_eye",
		"petushan_spur_under_rib", "petushan_feathers_up", "petushan_rooster_whirlwind",
		"petushan_battle_cry", "petushan_chest_charge", "petushan_red_comb",
		"petushan_wrong_opponent", "petushan_last_crow"]
	assert(hero.personal_ability_ids == expected)
	for id in expected:
		var ability: AbilityDefinition = AbilityCatalog.get_ability(id)
		assert(ability != null and ability.icon != null, id)
		assert(ability.validation_error().is_empty(), id)
		assert(DescriptionTemplate.unresolved_tokens(ability.get_description()).is_empty(), id)
		assert(AbilityCatalog.can_prepare(hero, id) != ability.passive, id)
	assert(not AbilityExecutor.execute(context, "hero", "hero", "petushan_red_comb").success)
	assert(hero.current_energy() == hero.max_energy)
	assert(not BattleChainPlanner.validate(["petushan_red_comb"], hero, false).is_empty())


func _check_stances() -> void:
	for id in ["petushan_feathers_up", "petushan_wrong_opponent"]:
		var context := _fighters()
		var hero := context.get_participant("hero")
		var ability: AbilityDefinition = AbilityCatalog.get_ability(id)
		var effect: AbilityEffectDefinition = ability.effects[0]
		assert(AbilityExecutor.execute(context, "hero", "hero", id).success)
		assert(hero.statuses.has(id))
		assert(AbilityExecutor.execute(context, "hero", "hero", id).success)
		assert(int(hero.statuses[id].stacks) == 1)
		var outcome := AbilityExecutor.execute(context, "enemy", "hero", "basic_strike")
		var attacks := _events_of(outcome, "attack")
		var counters := _events_of(outcome, "counter")
		assert(counters.size() == 1 and counters[0].actor_id == "hero")
		assert(int(attacks[0].damage) == floori(float(attacks[0].raw_damage) * (1.0 - float(effect.incoming_damage_reduction_percent) / BattleMath.PERCENT_SCALE)))
		assert(not hero.statuses.has(id))
		assert(_events_of(AbilityExecutor.execute(context, "enemy", "hero", "basic_strike"), "counter").is_empty())
	var ranged := _fighters()
	assert(AbilityExecutor.execute(ranged, "hero", "hero", "petushan_feathers_up").success)
	assert(_events_of(AbilityExecutor.execute(ranged, "enemy", "hero", "hunter_shot"), "counter").is_empty())
	assert(not ranged.get_participant("hero").statuses.has("petushan_feathers_up"))


func _check_whirlwind() -> void:
	var context := _fighters()
	var hero := context.get_participant("hero")
	var opponent := HeroState.new(HeroCatalog.get_hero("volcha"))
	var shield: ItemDefinition = ItemCatalog.get_item("wooden_shield")
	opponent.register_shield(shield)
	opponent.equip_shield(shield)
	var enemy := BattleParticipant.from_hero(opponent, "enemy")
	enemy.team_id = "enemies"
	context.participants["enemy"] = enemy
	enemy.prepare_block(2)
	var ability: AbilityDefinition = AbilityCatalog.get_ability("petushan_rooster_whirlwind")
	var second: int = AbilityExecutor.preview_damage(hero, ability, ability.effects[1], enemy)
	var attacks := _events_of(AbilityExecutor.execute(context, "hero", "enemy", ability.ability_id), "attack")
	assert(attacks.size() == 2)
	assert(bool(attacks[0].armor_damaged))
	assert(int(attacks[1].raw_damage) == floori(float(second) * (1.0 + float(ability.effects[1].bonus_after_armor_damage_percent) / BattleMath.PERCENT_SCALE)))
	assert(hero.current_energy() == hero.max_energy - int(ability.resource_costs.energy))
	var no_shield := _fighters()
	var unboosted := _events_of(AbilityExecutor.execute(no_shield, "hero", "enemy", ability.ability_id), "attack")
	assert(unboosted.size() == 2 and unboosted[0].raw_damage == unboosted[1].raw_damage)


func _check_cry_and_charge() -> void:
	var context := _fighters()
	var hero := context.get_participant("hero")
	var enemy := context.get_participant("enemy")
	var cry: AbilityDefinition = AbilityCatalog.get_ability("petushan_battle_cry")
	assert(AbilityExecutor.execute(context, "hero", "enemy", cry.ability_id).success)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.ATTACK_POWER) == cry.effects[0].status_modifier)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.ARMOR) == -cry.effects[1].armor_penalty)
	assert(not enemy.has_damaged_armor())
	for _turn in range(cry.effects[0].duration_ticks):
		hero.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(not hero.statuses.has(cry.effects[0].status_id))
	enemy.prepare_block(2)
	var charge: AbilityDefinition = AbilityCatalog.get_ability("petushan_chest_charge")
	assert(AbilityExecutor.execute(context, "hero", "enemy", charge.ability_id).success)
	assert(enemy.block_armor == 0 and enemy.block_attack_bonus_percent == 0)
	assert(enemy.has_damaged_armor())
	for _turn in range(charge.effects[1].duration_ticks):
		enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(not enemy.has_damaged_armor())


func _check_passive_and_finisher() -> void:
	var context := _fighters()
	var hero := context.get_participant("hero")
	var passive: AbilityDefinition = AbilityCatalog.get_ability("petushan_red_comb")
	assert(is_equal_approx(AbilityCatalog.passive_damage_multiplier(hero), 1.0))
	var wounded := _fighters(10)
	var wounded_hero := wounded.get_participant("hero")
	assert(AbilityCatalog.passive_damage_multiplier(wounded_hero) > 1.0)
	assert(AbilityCatalog.passive_damage_multiplier(wounded_hero) <= 1.0 + float(passive.passive_max_damage_bonus_percent) / BattleMath.PERCENT_SCALE)
	var finisher: AbilityDefinition = AbilityCatalog.get_ability("petushan_last_crow")
	var enemy := wounded.get_participant("enemy")
	enemy.health = 1
	var before: int = wounded_hero.health
	var result := AbilityExecutor.execute(wounded, "hero", "enemy", finisher.ability_id)
	assert(_events_of(result, "heal").size() == 1)
	assert(wounded_hero.health == before + ceili(float(wounded_hero.max_health) * float(finisher.heal_on_kill_percent) / BattleMath.PERCENT_SCALE))
	var nonlethal := _fighters(30)
	assert(_events_of(AbilityExecutor.execute(nonlethal, "hero", "enemy", finisher.ability_id), "heal").is_empty())
