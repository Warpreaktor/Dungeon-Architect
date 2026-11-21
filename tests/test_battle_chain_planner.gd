extends SceneTree

## DA-4.07: перезарядка и фаза по полному кругу действий героя.
func _initialize() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	var monster: MonsterDefinition = MonsterCatalog.get_monster("lobar")
	var state := BattleState.begin(monster, hero)
	var hero_chain: Array[String] = ["basic_strike", "guard", "basic_strike"]
	var enemy_chain: Array[String] = ["guard", "basic_strike"]
	state.get_enemy().action_chain = enemy_chain.duplicate()
	assert(BattleChainPlanner.phase_length(hero_chain, enemy_chain) == 4)
	assert(BattleChainPlanner.action_at(enemy_chain, 0) == "guard")
	assert(BattleChainPlanner.action_at(enemy_chain, 1) == "basic_strike")
	assert(BattleChainPlanner.action_at(enemy_chain, 2) == "")
	assert(BattleChainPlanner.action_at(enemy_chain, 3) == "guard")
	assert(BattleChainPlanner.priority("guard") == 0)
	assert(BattleChainPlanner.priority("basic_strike") > 0)
	var result: Dictionary = BattlePhaseTestDriver.run_phase(state, hero_chain, enemy_chain)
	assert(result.success and result.ticks == 4)
	assert(state.flow.phase_number == 1)
	var ticks: Array[Dictionary] = []
	var actions: Array[String] = []
	for event in state.last_phase_events:
		if event.type == "tick":
			ticks.append(event)
		if event.type == "action_start":
			actions.append(str(event.actor_id) + ":" + str(event.ability_id))
	assert(ticks.size() == 4)
	assert(ticks[0].enemy_slot == 0 and not ticks[0].enemy_reload)
	assert(ticks[1].enemy_slot == 1 and not ticks[1].enemy_reload)
	assert(ticks[2].enemy_reload)
	assert(ticks[3].hero_reload and ticks[3].enemy_slot == 0)
	assert(actions == ["enemy:guard", "hero:basic_strike", "hero:guard", "enemy:basic_strike", "hero:basic_strike", "enemy:guard"])
	# Вторая фаза начинается с первого приёма, отдых завершил прошлую.
	var next: Dictionary = BattlePhaseTestDriver.run_phase(state, hero_chain, enemy_chain)
	assert(next.success and next.ticks == 4)
	ticks.clear()
	for event in state.last_phase_events:
		if event.type == "tick":
			ticks.append(event)
	assert(ticks.size() == 4 and not ticks[0].hero_reload and ticks[3].hero_reload)
	assert(state.get_hero().action_cursor == 0)
	assert(state.get_enemy().action_cursor >= 0)
	# Настройку в паузе без токена менять нельзя.
	assert(not state.configure_hero_chain(["guard"]).success)
	assert(not BattlePhaseTestDriver.run_phase(state, ["guard"], enemy_chain).success)
	assert(not state.configure_hero_chain(["guard", "basic_strike", "guard"]).success)
	assert(BattlePhaseTestDriver.run_phase(state, hero_chain, enemy_chain).success)
	quit()
