extends SceneTree

## DA-4.10: actual new Wolf resources, chance stacking and independent clocks.
func _initialize() -> void:
	assert(AbilityCatalog.validate_catalog().is_empty())
	var source := HeroState.new(HeroCatalog.get_hero("volcha"))
	var battle := BattleState.begin(MonsterCatalog.get_monster("hunter"), source)
	var hero := battle.get_hero()
	var enemy := battle.get_enemy()
	var expected: Array[String] = ["volcha_wolf_lunge", "volcha_strike_and_rebound",
		"volcha_wolf_instinct", "volcha_broken_rhythm", "volcha_cut_tendons"]
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
	assert(AbilityExecutor.preview_damage(hero, lunge, lunge.effects[0], enemy) == floori(float(base) * 1.25))
	hero.action_cursor = 2
	assert(AbilityExecutor.preview_damage(hero, lunge, lunge.effects[0], enemy) == base)

	var rebound: AbilityDefinition = AbilityCatalog.get_ability(expected[1])
	assert(AbilityExecutor.execute_definition(battle, "hero", "enemy", rebound).success)
	assert(AbilityExecutor.execute_definition(battle, "hero", "enemy", rebound).success)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == 10)
	var instinct: AbilityDefinition = AbilityCatalog.get_ability(expected[2])
	for i in range(3):
		assert(AbilityExecutor.execute_definition(battle, "hero", "hero", instinct).success)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == 70)
	hero.base_dodge_percent = 5
	assert(hero.base_dodge_percent + hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == 75)
	battle.rng.seed = 42
	AbilityExecutor.apply_damage(enemy, hero, 1, "test_attack", battle.rng)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == 0)

	# Защитные эффекты остаются после отдыха и собственного бафа.
	assert(AbilityExecutor.execute_definition(battle, "hero", "hero", instinct).success)
	var dodge_before_rest: int = hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT)
	hero.end_phase()
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == dodge_before_rest)
	# Блок сохраняется через отдых и поддержку, но опускается при собственной атаке.
	hero.prepare_block(BattleParticipant.BASE_BLOCK_ARMOR)
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
	assert(AbilityExecutor.execute_definition(battle, "hero", "hero", self_heal).success)
	assert(hero.block_armor == block_before_rest)
	assert(AbilityExecutor.execute_definition(battle, "hero", "enemy", lunge).success)
	assert(hero.block_armor == 0)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == dodge_before_rest)
	# Следующая входящая атака потратит уклонение, независимо от исхода броска.
	AbilityExecutor.apply_damage(enemy, hero, 0, "test_attack", battle.rng)
	assert(hero.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT) == 0)
	# Уклонение от вражеского удара не расходует поднятый блок.
	hero.prepare_block(BattleParticipant.BASE_BLOCK_ARMOR)
	hero.base_dodge_percent = 100
	var avoided: Dictionary = AbilityExecutor.apply_damage(enemy, hero, 1, "test_miss", battle.rng)
	assert(bool(avoided.get("dodged", false)))
	assert(hero.block_armor > 0)
	hero.base_dodge_percent = 0
	AbilityExecutor.apply_damage(enemy, hero, 1, "test_hit", battle.rng)
	assert(hero.block_armor == 0)

	var rhythm: AbilityDefinition = AbilityCatalog.get_ability(expected[3])
	var rhythm_effect: AbilityEffectDefinition = rhythm.effects[0]
	assert(rhythm_effect.hit_count == 3)
	assert(AbilityExecutor.preview_damage(hero, rhythm, rhythm_effect, enemy) == floori(float(base) * 0.25))
	enemy.is_resting = true
	assert(AbilityExecutor.preview_damage(hero, rhythm, rhythm_effect, enemy) == floori(float(base) * 0.4))
	enemy.prepare_block(2)
	assert(AbilityExecutor.preview_damage(hero, rhythm, rhythm_effect, enemy) == floori(float(base) * 0.15))
	enemy.block_armor = 0
	enemy.is_resting = false

	var tendons: AbilityDefinition = AbilityCatalog.get_ability(expected[4])
	assert(AbilityExecutor.execute_definition(battle, "hero", "enemy", tendons).success)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == -2)
	assert(enemy.ranged_attack_value() == float(enemy.agility - 2) * 0.5)
	enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == -2)
	enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == 0)
	# A debuff applied in a partly completed enemy cycle survives that partial rest.
	enemy.action_cursor = 1
	assert(AbilityExecutor.execute_definition(battle, "hero", "enemy", tendons).success)
	enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == -2)
	enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == -2)
	enemy.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(enemy.status_modifier(AbilityEffectDefinition.Stat.AGILITY) == 0)
	enemy.action_cursor = 0
	assert(AbilityExecutor.execute_definition(battle, "hero", "enemy", tendons).success)
	enemy.prepare_block(2)
	AbilityExecutor.execute_definition(battle, "hero", "enemy", tendons)
	assert(enemy.statuses.has("volcha_tendon_cut"))
	assert(enemy.statuses["volcha_tendon_cut"].ticks == 2)
	quit()
