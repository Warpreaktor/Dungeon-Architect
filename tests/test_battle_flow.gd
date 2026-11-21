extends SceneTree

## DA-4.05. Проверяем границы фаз без сцены, кнопок и Tween.
func _initialize() -> void:
	var flow := BattleFlow.new()
	assert(flow.stage == BattleFlow.Stage.PREPARATION)
	assert(flow.can_use_item())
	assert(not flow.complete_phase())
	assert(not flow.request_reconfiguration())
	assert(flow.start_phase())
	assert(flow.phase_number == 1 and flow.can_execute())
	assert(not flow.start_phase()) # Нельзя запустить фазу повторно.
	assert(not flow.can_use_item()) # Запрещено расходовать предметы во время исполнения.
	assert(flow.mark_tick() and flow.mark_tick())
	assert(flow.completed_ticks == 2)
	assert(flow.complete_phase())
	assert(not flow.complete_phase())
	assert(flow.can_use_item())
	assert(flow.request_reconfiguration()) # Бесплатная перестановка после каждой фазы.
	assert(flow.can_use_item())
	assert(not flow.request_reconfiguration())
	assert(flow.cancel_reconfiguration())
	flow.grant_half_health_reconfiguration(20, 40) # Ровно 50% не даёт разрешение.
	assert(flow.reconfiguration_tokens == 0)
	flow.grant_half_health_reconfiguration(19, 40)
	assert(flow.reconfiguration_tokens == 1)
	flow.grant_half_health_reconfiguration(10, 40)
	assert(flow.reconfiguration_tokens == 1)
	assert(flow.request_reconfiguration())
	assert(not flow.request_reconfiguration())
	assert(flow.stage == BattleFlow.Stage.RECONFIGURING)
	assert(flow.can_use_item())
	assert(flow.confirm_reconfiguration())
	assert(not flow.confirm_reconfiguration())
	assert(flow.start_phase() and flow.phase_number == 2)
	assert(flow.finish_battle())
	assert(not flow.finish_battle())
	assert(not flow.start_phase() and not flow.mark_tick() and not flow.can_use_item())

	# Подготовленные приёмы реально исполняются внутри фаз, бонус блока
	# сохраняется до следующей атаки даже после границы фазы.
	var hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	hero.learned_ability_ids.append_array(["guard", "basic_strike"])
	var enemy: MonsterDefinition = MonsterCatalog.get_monster("lobar")
	var battle := BattleState.begin(enemy, hero)
	var hero_chain: Array[String] = ["guard", "basic_strike", "guard"]
	var enemy_chain: Array[String] = ["guard", "basic_strike"]
	battle.get_enemy().action_chain = enemy_chain.duplicate()
	var result: Dictionary = battle.run_phase(hero_chain, enemy_chain)
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
	assert(battle.run_phase(hero_chain, enemy_chain).success)
	assert(battle.flow.phase_number == 2)

	# Нельзя запустить пустую цепочку, и состояние не меняется.
	var bad := BattleState.begin(enemy, HeroState.new(HeroCatalog.get_hero("petushan")))
	var empty: Array[String] = []
	assert(not bad.run_phase(empty, enemy_chain).success)
	assert(bad.flow.stage == BattleFlow.Stage.PREPARATION)

	# Смертельный удар пропускает оставшиеся карты, но не обязательный отдых.
	var finisher := BattleState.begin(MonsterCatalog.get_monster("rabbit_symbiont"), hero)
	finisher.get_enemy().health = 1
	var killing_chain: Array[String] = ["petushan_peck_while_hot", "petushan_not_in_brow_but_eye", "petushan_spur_under_rib"]
	var killing: Dictionary = finisher.run_phase(killing_chain, enemy_chain)
	assert(killing.success and finisher.is_victory)
	assert(finisher.flow.stage == BattleFlow.Stage.FINISHED)
	assert(finisher.flow.completed_ticks == 1 + BattleChainPlanner.REST_TICKS)
	assert(finisher.get_hero().completed_phases == 1)
	assert(not finisher.run_phase(killing_chain, enemy_chain).success)
	var attacks: int = 0
	for event in finisher.last_phase_events:
		if event.type == "attack":
			attacks += 1
	assert(attacks == 1)
	var wounded := HeroState.new(HeroCatalog.get_hero("petushan"))
	assert(wounded.apply_overworld_status("bleeding", "Кровотечение", 1, 3, wounded.exploration_phase_length()))
	for step in range(wounded.exploration_phase_length() - 1):
		assert(wounded.advance_overworld_statuses().is_empty())
	var encounter := BattleState.begin(MonsterCatalog.get_monster("rabbit_symbiont"), wounded)
	encounter.get_enemy().health = 1
	assert(int(encounter.get_hero().statuses["bleeding"]["ticks"]) == 3)
	assert(encounter.run_phase(killing_chain, enemy_chain).success)
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
	assert(fatal.run_phase(killing_chain, enemy_chain).success)
	assert(fatal.is_defeat and not fatal.is_victory)
	quit()
