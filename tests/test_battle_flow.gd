extends SceneTree

const UnlockedHeroFixture = preload("res://tests/support/unlocked_hero_fixture.gd")

## DA-4.05. Проверяем границы фаз без сцены, кнопок и Tween.
func _initialize() -> void:
	var flow := BattleFlow.new()
	assert(flow.stage == BattleFlow.Stage.PREPARATION)
	assert(flow.can_use_item())
	assert(not flow.complete_phase())
	assert(flow.start_phase())
	assert(flow.phase_number == 1 and flow.can_execute())
	assert(not flow.start_phase()) # Нельзя запустить фазу повторно.
	assert(not flow.can_use_item()) # Запрещено расходовать предметы во время исполнения.
	assert(flow.mark_tick() and flow.mark_tick())
	assert(flow.completed_ticks == 2)
	assert(flow.complete_phase())
	assert(not flow.complete_phase())
	assert(flow.can_use_item())
	assert(flow.can_use_item())
	assert(flow.start_phase() and flow.phase_number == 2)
	assert(flow.finish_battle())
	assert(not flow.finish_battle())
	assert(not flow.start_phase() and not flow.mark_tick() and not flow.can_use_item())

	# Подготовленные приёмы реально исполняются внутри фаз, бонус блока
	# сохраняется до следующей атаки даже после границы фазы.
	var hero := HeroState.new(UnlockedHeroFixture.definition("petushan"))
	hero.learned_ability_ids.append_array(["guard", "basic_strike"])
	var enemy: MonsterDefinition = MonsterCatalog.get_monster("lobar")
	var battle := BattleState.begin(enemy, hero)
	var hero_chain: Array[String] = ["guard", "basic_strike", "guard"]
	var enemy_chain: Array[String] = ["guard", "basic_strike"]
	battle.get_enemy().action_chain = enemy_chain.duplicate()
	var result: Dictionary = BattlePhaseTestDriver.run_phase(battle, hero_chain, enemy_chain)
	assert(result.success)
	assert(battle.flow.phase_number == 1)
	assert(battle.flow.completed_ticks == 4)
	assert(battle.flow.stage == BattleFlow.Stage.BETWEEN_PHASES)
	assert(battle.get_hero().block_attack_bonus_percent == 25)
	assert(battle.get_enemy().block_attack_bonus_percent == 0)
	assert(battle.last_phase_events.size() >= 4)
	var effects: Array[String] = []
	for event in battle.last_phase_events:
		if event.type in ["block", "attack"]:
			effects.append(event.type)
	assert(effects == ["block", "block", "attack", "attack", "block", "block"])
	# Отдельный запуск фазы, новая пара действий, никакого повторного начала во время исполнения.
	assert(BattlePhaseTestDriver.run_phase(battle, hero_chain, enemy_chain).success)
	assert(battle.flow.phase_number == 2)

	# Нельзя запустить пустую цепочку, и состояние не меняется.
	var bad := BattleState.begin(enemy, HeroState.new(UnlockedHeroFixture.definition("petushan")))
	var empty: Array[String] = []
	assert(not BattlePhaseTestDriver.run_phase(bad, empty, enemy_chain).success)
	assert(bad.flow.stage == BattleFlow.Stage.PREPARATION)

	# Смертельный удар пропускает оставшиеся карты, но не обязательный отдых.
	var finisher := BattleState.begin(MonsterCatalog.get_monster("rabbit_symbiont"), hero)
	finisher.get_enemy().health = 1
	var killing_chain: Array[String] = ["petushan_peck_while_hot", "petushan_not_in_brow_but_eye", "petushan_spur_under_rib"]
	var killing: Dictionary = BattlePhaseTestDriver.run_phase(finisher, killing_chain, enemy_chain)
	assert(killing.success and finisher.is_victory)
	assert(finisher.flow.stage == BattleFlow.Stage.FINISHED)
	assert(finisher.flow.completed_ticks == 1 + BattleChainPlanner.REST_TICKS)
	assert(finisher.get_hero().completed_phases == 1)
	assert(not BattlePhaseTestDriver.run_phase(finisher, killing_chain, enemy_chain).success)
	var attacks: int = 0
	for event in finisher.last_phase_events:
		if event.type == "attack":
			attacks += 1
	assert(attacks == 1)
	var wounded := HeroState.new(UnlockedHeroFixture.definition("petushan"))
	assert(wounded.apply_overworld_status("bleeding", "Кровотечение", 1, 3, wounded.exploration_phase_length()))
	for step in range(wounded.exploration_phase_length() - 1):
		assert(wounded.advance_overworld_statuses().is_empty())
	var encounter := BattleState.begin(MonsterCatalog.get_monster("rabbit_symbiont"), wounded)
	encounter.get_enemy().health = 1
	assert(int(encounter.get_hero().statuses["bleeding"]["ticks"]) == 3)
	assert(BattlePhaseTestDriver.run_phase(encounter, killing_chain, enemy_chain).success)
	assert(encounter.is_victory)
	encounter.get_hero().commit_hero_result(wounded)
	assert(int(wounded.overworld_statuses["bleeding"]["ticks"]) == 2)
	for step in range(wounded.exploration_phase_length() - 1):
		assert(wounded.advance_overworld_statuses().is_empty())
	assert(wounded.advance_overworld_statuses().size() == 1)
	assert(int(wounded.overworld_statuses["bleeding"]["ticks"]) == 1)
	wounded.health = 1
	var fatal := BattleState.begin(MonsterCatalog.get_monster("rabbit_symbiont"), wounded)
	fatal.get_enemy().health = 1
	assert(BattlePhaseTestDriver.run_phase(fatal, killing_chain, enemy_chain).success)
	assert(fatal.is_defeat and not fatal.is_victory)
	quit()
