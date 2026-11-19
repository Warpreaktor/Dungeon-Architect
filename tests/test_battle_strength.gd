extends SceneTree

## Сила добавляет половину очка к ближней базе, не к выстрелам.
func _initialize() -> void:
	var wolf := HeroState.new(HeroCatalog.get_hero("volcha"))
	var rooster := HeroState.new(HeroCatalog.get_hero("petushan"))
	assert(wolf.strength == 6 and rooster.strength == 8)
	assert(wolf.melee_attack() == wolf.attack + 3)
	assert(rooster.melee_attack() == rooster.attack + 4)
	var copy: HeroState = wolf.copy_for_battle()
	assert(copy.strength == wolf.strength and copy.melee_attack() == wolf.melee_attack())

	var enemies: Dictionary = {
		"rabbit_symbiont": 4, "hunter": 4, "giant_crab": 6,
		"lobar": 8, "kadavr": 10
	}
	for id in enemies:
		var monster: MonsterDefinition = MonsterCatalog.get_monster(id)
		assert(monster.strength == int(enemies[id]))
		var actor: BattleParticipant = BattleParticipant.from_monster(monster)
		assert(actor.melee_attack() == monster.attack_damage + floori(float(monster.strength) * 0.5))

	var state: BattleState = BattleState.begin(MonsterCatalog.get_monster("hunter"), wolf)
	var actor: BattleParticipant = state.get_hero()
	assert(actor.strength == wolf.strength)
	var punch: Dictionary = state.execute_ability("hero", "enemy", "basic_strike")
	assert(punch.success and punch.events[0].damage == wolf.melee_attack())
	var shot_definition: AbilityDefinition = AbilityCatalog.get_ability("hunter_shot")
	assert(shot_definition.damage_delivery == AbilityDefinition.DamageDelivery.RANGED)
	var hunter: BattleParticipant = state.get_enemy()
	var shot: Dictionary = state.execute_ability("enemy", "hero", "hunter_shot")
	assert(shot.success)
	assert(shot.events[0].damage == hunter.attack + 1)
	assert(shot.events[0].damage != hunter.melee_attack() + 1)
	# Нечётное значение Силы не округляется вверх.
	actor.strength = 5
	assert(actor.melee_attack() == actor.attack + 2)
	# База 10, сила 1 -> 10,5; один блок => 13,125, итог 13.
	var fractional: BattleState = BattleState.begin(MonsterCatalog.get_monster("kadavr"), wolf)
	var f: BattleParticipant = fractional.get_hero()
	f.attack = 10
	f.strength = 1
	assert(fractional.execute_ability("hero", "hero", "guard").success)
	var powered: Dictionary = fractional.execute_ability("hero", "enemy", "basic_strike")
	assert(powered.success and powered.events[0].damage == 13)
	quit()
