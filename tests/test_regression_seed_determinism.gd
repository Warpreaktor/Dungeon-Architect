extends SceneTree

const UnlockedHeroFixture = preload("res://tests/support/unlocked_hero_fixture.gd")


func _initialize() -> void:
	var first: Dictionary = _play(72631)
	var second: Dictionary = _play(72631)
	assert(first == second)
	assert(first["phases"].size() > 0)
	var scenario := _make_session(72631)
	var independent := _make_session(72631)
	scenario.battle_state.get_hero().health = 1
	assert(independent.battle_state.get_hero().health == independent.hero.max_health)
	assert(scenario.battle_state.initial_enemy_chain == independent.battle_state.initial_enemy_chain)
	assert(scenario.battle_state.support_initial_chain == independent.battle_state.support_initial_chain)
	quit()


func _make_session(seed: int) -> CombatSession:
	var hero := HeroState.new(UnlockedHeroFixture.definition("volcha"))
	var monster: MonsterDefinition = MonsterCatalog.get_monster("skeleton")
	return CombatSession.new(monster, hero, monster, seed)


func _play(seed: int) -> Dictionary:
	var session := _make_session(seed)
	var state: BattleState = session.battle_state
	var hero_chain: Array[String] = ["volcha_wolf_instinct", "volcha_wolf_instinct", "volcha_wolf_instinct"]
	var phases: Array = []
	for index in range(2):
		if state.is_victory or state.is_defeat:
			break
		var outcome: Dictionary = BattlePhaseTestDriver.play_phase(session, hero_chain, state.get_enemy().action_chain)
		assert(bool(outcome.get("success", false)))
		phases.append(outcome["events"].duplicate(true))
	return {
		"phases": phases,
		"hero_hp": state.get_hero().health,
		"enemy_hp": state.get_enemy().health,
		"support_hp": state.get_participant(state.support_enemy_id).health,
		"enemy_cursor": state.get_enemy().action_cursor,
		"support_cursor": state.get_participant(state.support_enemy_id).action_cursor,
		"victory": state.is_victory,
		"defeat": state.is_defeat,
		"seed_state": state.rng.state
	}
