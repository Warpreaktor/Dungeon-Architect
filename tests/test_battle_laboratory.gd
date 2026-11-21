extends SceneTree

func _initialize() -> void:
	var hero_definition: HeroDefinition = HeroCatalog.get_hero("petushan")
	var monster: MonsterDefinition = MonsterCatalog.get_monster("skeleton")
	var first_hero := HeroState.new(hero_definition)
	var second_hero := HeroState.new(hero_definition)
	var first := CombatSession.new(monster, first_hero, monster, 12345)
	var second := CombatSession.new(monster, second_hero, monster, 12345)
	assert(first.battle_state.rng.seed == second.battle_state.rng.seed)
	assert(first.battle_state.initial_enemy_chain == second.battle_state.initial_enemy_chain)
	assert(first.battle_state.support_initial_chain == second.battle_state.support_initial_chain)
	first.battle_state.get_hero().health = 1
	assert(second.battle_state.get_hero().health == second_hero.max_health)
	var sandbox := GameSession.new()
	sandbox.hero = first_hero
	sandbox.carried_items["potion_health_small"] = 2
	assert(sandbox.carried_items["potion_health_small"] == 2)
	assert(first_hero != second_hero)
	quit()
