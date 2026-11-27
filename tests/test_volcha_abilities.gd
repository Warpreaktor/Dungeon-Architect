extends SceneTree

const UnlockedHeroFixture = preload("res://tests/support/unlocked_hero_fixture.gd")

## Проверки боевых ресурсов, наложения эффектов и собственных часов.
func _initialize() -> void:
	assert(AbilityCatalog.validate_catalog().is_empty())
	var source := HeroState.new(UnlockedHeroFixture.definition("volcha"))
	var battle := BattleState.begin(MonsterCatalog.get_monster("hunter"), source)
	var hero := battle.get_hero()
	var enemy := battle.get_enemy()
	var expected: Array[String] = ["volcha_wolf_lunge", "volcha_strike_and_rebound",
		"volcha_wolf_instinct", "volcha_broken_rhythm", "volcha_cut_tendons",
		"volcha_predator_response", "volcha_find_weakness", "volcha_blade_dance", "volcha_hunting_instinct", "volcha_last_fang"]
	assert(hero.personal_ability_ids == expected)
	assert(hero.block_armor == 0 and enemy.block_armor == 0)
	for id in expected:
		var ability: AbilityDefinition = AbilityCatalog.get_ability(id)
		assert(ability != null and ability.icon != null)
		assert(AbilityCatalog.can_prepare(hero, id))
	assert(AbilityCatalog.get_ability("wolf_feint") == null)
	assert(AbilityCatalog.get_ability("wolf_dodge") == null)
	assert(AbilityCatalog.get_ability("wolf_counter") == null)
	assert(not AbilityCatalog.can_prepare(hero, "wolf_feint"))
	assert(not AbilityCatalog.can_prepare(hero, "guard"))

	var lunge: AbilityDefinition = AbilityCatalog.get_ability(expected[0])
	hero.action_chain = [expected[0], expected[1], expected[2]]
	hero.action_cursor = 1
	var base: int = floori(hero.melee_attack_value())
	assert(AbilityExecutor.preview_damage(hero, lunge, lunge.effects[0], enemy) == base)
	assert(is_equal_approx(lunge.effects[0].armor_pierce_fraction, 0.25))
	hero.action_cursor = 2
	assert(AbilityExecutor.preview_damage(hero, lunge, lunge.effects[0], enemy) == base)

	var rebound: AbilityDefinition = AbilityCatalog.get_ability(expected[1])
	assert(battle.execute_definition("hero", "enemy", rebound).success)
	assert(battle.execute_definition("hero", "enemy", rebound).success)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == 10)
	var instinct: AbilityDefinition = AbilityCatalog.get_ability(expected[2])
	for i in range(3):
		assert(battle.execute_definition("hero", "hero", instinct).success)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == 70)
	hero.base_dodge_percent = 5
	assert(hero.base_dodge_percent + hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == 75)
	battle.rng.seed = 42
	AbilityExecutor.apply_damage(enemy, hero, 1, "test_attack", battle.rng)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == 0)

	# Защитные эффекты остаются после отдыха и собственного бафа.
	hero.resource_amounts["energy"] = hero.max_energy
	assert(battle.execute_definition("hero", "hero", instinct).success)
	var dodge_before_rest: int = hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT)
	hero.end_phase()
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == dodge_before_rest)
	# Блок сохраняется через отдых и поддержку, но опускается при собственной атаке.
	hero.prepare_block(BattleMath.RULES.unarmed_block_armor)
	var block_before_rest: int = hero.block_armor
	hero.end_phase()
	assert(hero.block_armor == block_before_rest)
	var self_heal := AbilityDefinition.new()
	self_heal.ability_id = "test_self_heal"
	self_heal.display_name = "Test heal"
	self_heal.target = AbilityDefinition.Target.SELF
	var healing := AbilityEffectDefinition.new()
	healing.kind = AbilityEffectDefinition.Kind.HEAL
	healing.recipient = AbilityEffectDefinition.Recipient.SELF
	healing.amount = 1
	self_heal.effects.append(healing)
	hero.personal_ability_ids.append(self_heal.ability_id)
	assert(battle.execute_definition("hero", "hero", self_heal).success)
	assert(hero.block_armor == block_before_rest)
	assert(battle.execute_definition("hero", "enemy", lunge).success)
	assert(hero.block_armor == 0)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == dodge_before_rest)
	# Следующая входящая атака потратит уклонение, независимо от исхода броска.
	AbilityExecutor.apply_damage(enemy, hero, 0, "test_attack", battle.rng)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == 0)
	# Уклонение от вражеского удара не расходует поднятый блок.
	hero.prepare_block(BattleMath.RULES.unarmed_block_armor)
	hero.base_dodge_percent = 100
	var avoided: Dictionary = AbilityExecutor.apply_damage(enemy, hero, 1, "test_miss", battle.rng)
	assert(bool(avoided.get("dodged", false)))
	assert(hero.block_armor > 0)
	hero.base_dodge_percent = 0
	AbilityExecutor.apply_damage(enemy, hero, 1, "test_hit", battle.rng)
	assert(hero.block_armor == 0)

	hero.resource_amounts["energy"] = hero.max_energy
	hero.block_attack_bonus_percent = 0
	var rhythm: AbilityDefinition = AbilityCatalog.get_ability("volcha_broken_rhythm")
	var rhythm_effect: AbilityEffectDefinition = rhythm.effects[0]
	assert(rhythm_effect.hit_count == 3)
	assert(AbilityExecutor.preview_damage(hero, rhythm, rhythm_effect, enemy) == floori(float(base) * rhythm_effect.damage_multiplier))
	enemy.is_resting = true
	assert(AbilityExecutor.preview_damage(hero, rhythm, rhythm_effect, enemy) == floori(float(base) * rhythm_effect.vs_rest_multiplier))
	enemy.prepare_block(2)
	assert(AbilityExecutor.preview_damage(hero, rhythm, rhythm_effect, enemy) == floori(float(base) * rhythm_effect.vs_block_multiplier))
	enemy.block_armor = 0
	enemy.is_resting = false

	hero.accuracy_bonus = BattleMath.PERCENT_SCALE
	var tendons: AbilityDefinition = AbilityCatalog.get_ability("volcha_cut_tendons")
	hero.resource_amounts["energy"] = hero.max_energy
	assert(battle.execute_definition("hero", "enemy", tendons).success)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == -2)
	assert(enemy.ranged_attack_value() == float(enemy.agility - 2) * 0.5)
	enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == -2)
	enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == 0)
	# A debuff applied in a partly completed enemy cycle survives that partial rest.
	enemy.action_cursor = 1
	hero.resource_amounts["energy"] = hero.max_energy
	assert(battle.execute_definition("hero", "enemy", tendons).success)
	enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == -2)
	enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == -2)
	enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == 0)
	enemy.action_cursor = 0
	hero.resource_amounts["energy"] = hero.max_energy
	assert(battle.execute_definition("hero", "enemy", tendons).success)
	enemy.prepare_block(2)
	battle.execute_definition("hero", "enemy", tendons)
	assert(enemy.statuses.has("volcha_tendon_cut"))
	assert(enemy.statuses["volcha_tendon_cut"].ticks == 2)
	_test_new_abilities()
	quit()


func _test_new_abilities() -> void:
	var source := HeroState.new(UnlockedHeroFixture.definition("volcha"))
	var battle := BattleState.begin(MonsterCatalog.get_monster("kadavr"), source)
	var hero := battle.get_hero()
	var enemy := battle.get_enemy()
	assert(AbilityCatalog.known_ability_ids(hero).size() == 10)
	assert(source.get_saved_action_slots() == ["volcha_wolf_lunge", "volcha_strike_and_rebound", "volcha_wolf_instinct"])
	var stance: AbilityDefinition = AbilityCatalog.get_ability("volcha_predator_response")
	assert(battle.execute_ability("hero", "hero", stance.ability_id).success)
	assert(hero.statuses.has(stance.ability_id))
	AbilityExecutor.apply_damage(enemy, hero, 0, "test_ranged", null, 0.0, 0, AbilityDefinition.DamageDelivery.RANGED)
	assert(hero.statuses.has(stance.ability_id))
	var incoming: Dictionary = battle.execute_ability("enemy", "hero", "kadavr_curse")
	assert(incoming.success)
	assert(not hero.statuses.has(stance.ability_id))
	assert(incoming.events.any(func(e: Dictionary) -> bool: return e.get("type") == "counter" and e.get("ability_id") == stance.ability_id))
	var weakness: AbilityDefinition = AbilityCatalog.get_ability("volcha_find_weakness")
	var fang: AbilityDefinition = AbilityCatalog.get_ability("volcha_last_fang")
	hero.resource_amounts["energy"] = hero.max_energy
	var normal: int = AbilityExecutor.preview_damage(hero, fang, fang.effects[1], enemy)
	assert(battle.execute_ability("hero", "hero", weakness.ability_id).success)
	assert(is_equal_approx(AbilityExecutor.attack_pierce(hero, fang.effects[0]), float(weakness.effects[0].status_modifier) / 100.0))
	assert(AbilityExecutor.preview_damage(hero, fang, fang.effects[1], enemy) >= normal)
	hero.resource_amounts["energy"] = hero.max_energy
	var result: Dictionary = battle.execute_ability("hero", "enemy", fang.ability_id)
	assert(result.success)
	assert(not hero.statuses.has(weakness.ability_id))
	assert(result.events.filter(func(e: Dictionary) -> bool: return e.get("type") == "attack" and e.get("actor_id") == "hero").size() == 3)
	hero.resource_amounts["energy"] = hero.max_energy
	var dance: AbilityDefinition = AbilityCatalog.get_ability("volcha_blade_dance")
	assert(battle.execute_ability("hero", "hero", dance.ability_id).success)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.ATTACK_POWER) == dance.effects[0].status_modifier)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.ARMOR) == -dance.effects[0].armor_penalty)
	hero.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(hero.statuses.has(dance.ability_id))
	hero.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(not hero.statuses.has(dance.ability_id))
	hero.resource_amounts["energy"] = hero.max_energy
	var hunting: AbilityDefinition = AbilityCatalog.get_ability("volcha_hunting_instinct")
	enemy.health = enemy.max_health
	var full_hp_damage: int = AbilityExecutor.preview_damage(hero, hunting, hunting.effects[0], enemy)
	enemy.health = 1
	assert(AbilityExecutor.preview_damage(hero, hunting, hunting.effects[0], enemy) >= full_hp_damage)
