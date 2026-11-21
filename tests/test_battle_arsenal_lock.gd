extends SceneTree


func _initialize() -> void:
	var first: Array[String] = ["a", "b", "a"]
	assert(BattleState.same_arsenal(first, ["a", "a", "b"]))
	assert(not BattleState.same_arsenal(first, ["a", "b", "b"]))
	assert(not BattleState.same_arsenal(first, ["a", "b"]))
	assert(first == ["a", "b", "a"])

	var hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	hero.learned_ability_ids.append("basic_strike")
	hero.max_health = 500
	hero.health = 500
	var battle := BattleState.begin(MonsterCatalog.get_monster("skeleton"), hero, 112233)
	battle.get_enemy().max_health = 500
	battle.get_enemy().health = 500
	var selected: Array[String] = ["basic_strike", "petushan_peck_while_hot", "basic_strike"]
	var reordered: Array[String] = ["petushan_peck_while_hot", "basic_strike", "basic_strike"]
	var replacement: Array[String] = ["basic_strike", "petushan_peck_while_hot", "petushan_not_in_brow_but_eye"]
	assert(battle.configure_hero_chain(replacement).success)
	assert(battle.configure_hero_chain(selected).success)
	assert(battle.locked_hero_arsenal.is_empty())
	assert(BattlePhaseTestDriver.run_phase(battle, selected, battle.get_enemy().action_chain).success)
	assert(battle.flow.phase_number == 1)
	assert(battle.locked_hero_arsenal == selected)
	assert(battle.flow.stage == BattleFlow.Stage.BETWEEN_PHASES)
	assert(not battle.configure_hero_chain(replacement).success)
	assert(not BattlePhaseTestDriver.run_phase(battle, replacement, battle.get_enemy().action_chain).success)
	assert(battle.flow.phase_number == 1)
	assert(battle.get_hero().action_chain == selected)
	assert(battle.configure_hero_chain(reordered).success)
	assert(battle.get_hero().action_chain == reordered)
	assert(battle.locked_hero_arsenal == selected)
	assert(BattlePhaseTestDriver.run_phase(battle, reordered, battle.get_enemy().action_chain).success)
	assert(battle.flow.phase_number == 2)
	assert(battle.locked_hero_arsenal == selected)
	quit()
