extends SceneTree

## DA-4.09: характеристики считаются вместе с оружием, без постоянной атаки.
func _initialize() -> void:
	var wolf := HeroState.new(HeroCatalog.get_hero("volcha"))
	var rooster := HeroState.new(HeroCatalog.get_hero("petushan"))
	assert(wolf.strength == wolf.definition.strength and wolf.agility == wolf.definition.agility)
	assert(rooster.strength == rooster.definition.strength and rooster.agility == rooster.definition.agility)
	assert(wolf.melee_attack_value() == float(wolf.strength) * 0.5)
	assert(wolf.ranged_attack_value() == float(wolf.agility) * 0.5)
	var copy: HeroState = wolf.copy_for_battle()
	assert(copy.strength == wolf.strength and copy.agility == wolf.agility)
	assert(copy.melee_attack_value() == wolf.melee_attack_value())

	for id in MonsterCatalog.DEFINITIONS:
		var monster: MonsterDefinition = MonsterCatalog.get_monster(id)
		var actor: BattleParticipant = BattleParticipant.from_monster(monster)
		assert(actor.melee_attack_value() == float(monster.strength) * 0.5)
		assert(actor.ranged_attack_value() == float(monster.agility) * 0.5)

	var state: BattleState = BattleState.begin(MonsterCatalog.get_monster("hunter"), rooster)
	var actor: BattleParticipant = state.get_hero()
	var enemy: BattleParticipant = state.get_enemy()
	var strike: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
	assert(AbilityExecutor.preview_damage(actor, strike, strike.effects[0]) == floori(float(rooster.strength) * 0.5 + 1))
	var punch: Dictionary = state.execute_ability("hero", "enemy", "basic_strike")
	assert(punch.success and punch.events[0].damage == maxi(floori(actor.melee_attack_value() + 1) - enemy.defense, 0))
	var shot_definition: AbilityDefinition = AbilityCatalog.get_ability("hunter_shot")
	assert(shot_definition.damage_delivery == AbilityDefinition.DamageDelivery.RANGED)
	assert(AbilityExecutor.preview_damage(enemy, shot_definition, shot_definition.effects[0]) == floori(float(enemy.agility) * 0.5 + 2))
	var other_base: float = enemy.melee_attack_value()
	enemy.agility += 2
	assert(enemy.melee_attack_value() == other_base)
	assert(AbilityExecutor.preview_damage(enemy, shot_definition, shot_definition.effects[0]) == floori(float(enemy.agility) * 0.5 + 2))

	# Дробь обрезается только после % бонуса: 2.5 + 1 = 3.5, затем ×1.25 -> 4.
	var fractional: BattleState = BattleState.begin(MonsterCatalog.get_monster("kadavr"), rooster)
	var f: BattleParticipant = fractional.get_hero()
	f.strength = 5
	assert(fractional.execute_ability("hero", "hero", "guard").success)
	assert(AbilityExecutor.preview_damage(f, strike, strike.effects[0]) == 4)
	quit()
