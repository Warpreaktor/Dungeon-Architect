extends SceneTree


func _initialize() -> void:
	var monster: MonsterDefinition = MonsterCatalog.get_monster("fallen_hero")
	assert(monster != null)
	assert(monster.display_name == "Павший воин")
	assert(monster.max_health == 20 and monster.strength == 6 and monster.agility == 1)
	assert(monster.base_action_slots == 3)
	assert(monster.portrait != null and monster.icon != null)
	var fighter: BattleParticipant = BattleParticipant.from_monster(monster, "fallen")
	assert(BattleMath.accuracy_total(fighter.agility, fighter.accuracy_bonus, 0) == 85)
	var observed: Dictionary = {}
	for seed_value in range(40):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var chain: Array[String] = MonsterCardDraw.draw(monster, fighter, rng)
		assert(chain.size() == 3 and chain[0] == "fallen_hero_dead_strike")
		assert(chain[1] != chain[2])
		for ability_id in chain:
			assert(AbilityCatalog.get_ability(ability_id) != null)
		observed[chain[1]] = true
	assert(observed.size() > 1)
	var target: BattleParticipant = BattleParticipant.from_monster(monster, "target")
	fighter.team_id = "heroes"
	target.team_id = "enemies"
	var context := BattleContext.new({"fallen": fighter, "target": target})
	var bite: AbilityDefinition = AbilityCatalog.get_ability("fallen_hero_rotten_bite")
	assert(bite != null and bite.effects.size() == 2)
	for tick in [1, 3, 5]:
		context.current_tick = tick
		var result: Dictionary = AbilityExecutor.execute(context, "fallen", "target", bite.ability_id)
		assert(result.success)
		var stacks: int = int(target.statuses["fallen_hero_infection"]["stacks"])
		assert(stacks == (tick + 1) / 2)
		assert(target.max_health == 20 - 2 * stacks)
		if tick != 5:
			target.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, tick + 1)
	assert(target.max_health == 14)
	context.current_tick = 7
	assert(AbilityExecutor.execute(context, "fallen", "target", bite.ability_id).success)
	assert(int(target.statuses["fallen_hero_infection"]["stacks"]) == 3)
	var hp_before: int = target.health
	target.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, 8)
	assert(target.max_health == 16)
	assert(target.health == hp_before + 2)
	assert(int(target.statuses["fallen_hero_infection"]["stacks"]) == 2)
	target.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, 9)
	assert(target.max_health == 18)
	target.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, 10)
	assert(not target.statuses.has("fallen_hero_infection"))
	assert(target.max_health == 20)
	var shield: AbilityDefinition = AbilityCatalog.get_ability("fallen_hero_meat_shield")
	assert(shield != null)
	fighter.health = 3
	assert(AbilityExecutor.execute(context, "fallen", "fallen", shield.ability_id).success)
	assert(fighter.health == 3 and fighter.block_armor >= 2)
	fighter.health = 2
	assert(AbilityExecutor.execute(context, "fallen", "fallen", shield.ability_id).success)
	assert(fighter.health == 4)
	var memory: AbilityDefinition = AbilityCatalog.get_ability("fallen_hero_battle_memory")
	assert(memory != null and memory.effects[0].accuracy_offset_percent == -15)
	var normal: int = AbilityExecutor.preview_damage(fighter, memory, memory.effects[0], target)
	target.is_resting = true
	var resting: int = AbilityExecutor.preview_damage(fighter, memory, memory.effects[0], target)
	assert(resting > normal)
	var wounded_hero: HeroState = HeroState.new(HeroCatalog.get_hero("volcha"))
	wounded_hero.max_health = 20
	wounded_hero.health = 20
	BattleStatusRules.apply(wounded_hero.overworld_statuses, bite.effects[1], -1, false)
	wounded_hero.health = mini(wounded_hero.health, wounded_hero.effective_max_health())
	assert(wounded_hero.effective_max_health() == 18)
	assert(wounded_hero.restore_health(100) == 0)
	wounded_hero.reset_exploration_phase()
	for step in range(wounded_hero.exploration_phase_length() * 3):
		wounded_hero.advance_overworld_statuses()
	assert(wounded_hero.effective_max_health() == 20)
	assert(wounded_hero.health == 20)
	assert(wounded_hero.overworld_statuses.is_empty())
	quit()
