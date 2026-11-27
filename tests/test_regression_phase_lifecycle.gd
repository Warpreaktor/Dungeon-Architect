extends SceneTree

const UnlockedHeroFixture = preload("res://tests/support/unlocked_hero_fixture.gd")


func _initialize() -> void:
	var definition: HeroDefinition = UnlockedHeroFixture.definition("petushan")
	var hero := HeroState.new(definition)
	var duration: int = 3
	assert(hero.apply_overworld_status("bleeding", "Кровотечение", 1, duration, hero.exploration_phase_length()))
	for index in range(hero.exploration_phase_length() - 1):
		assert(hero.advance_overworld_statuses().is_empty())
	var enemy: MonsterDefinition = MonsterCatalog.get_monster("rabbit_symbiont")
	var combat := CombatSession.new(enemy, hero, null, 1427)
	combat.battle_state.get_enemy().health = 1
	var before: int = int(combat.battle_state.get_hero().statuses["bleeding"]["ticks"])
	assert(before == duration)
	var chain: Array[String] = ["petushan_peck_while_hot", "petushan_not_in_brow_but_eye", "petushan_spur_under_rib"]
	var result: Dictionary = BattlePhaseTestDriver.play_phase(combat, chain, combat.battle_state.get_enemy().action_chain)
	assert(bool(result.get("success", false)))
	assert(combat.is_victory and not combat.is_defeat)
	assert(combat.battle_state.get_hero().completed_phases == 0)
	assert(int(hero.overworld_statuses["bleeding"]["ticks"]) == before)
	var battle_again := BattleState.begin(enemy, hero, 1427)
	assert(int(battle_again.get_hero().statuses["bleeding"]["ticks"]) == before)
	var nearly_dead := HeroState.new(definition)
	assert(nearly_dead.apply_overworld_status("bleeding", "Кровотечение", 1, duration, nearly_dead.exploration_phase_length()))
	nearly_dead.health = 1
	var fatal := BattleState.begin(enemy, nearly_dead, 1427)
	fatal.get_enemy().health = 1
	assert(bool(BattlePhaseTestDriver.run_phase(fatal, chain, fatal.get_enemy().action_chain).get("success", false)))
	assert(fatal.is_victory and not fatal.is_defeat)
	quit()
