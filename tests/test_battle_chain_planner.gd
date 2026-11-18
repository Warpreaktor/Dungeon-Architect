extends SceneTree

## DA-4.06: разная длина цепочек, повторения, блокировка изменений и безопасность.
func _initialize() -> void:
	var hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	var monster: MonsterDefinition = MonsterCatalog.get_monster("lobar")
	var state := BattleState.begin(monster, hero)
	var actor: BattleParticipant = state.get_hero()
	var enemy: BattleParticipant = state.get_enemy()
	assert(actor.action_slot_capacity == 3 and enemy.action_slot_capacity == 3)
	# Будущие артефакты могут расширить предел, но без них максимум три.
	assert(not BattleChainPlanner.validate(["guard", "guard", "guard", "guard"], actor).is_empty())
	enemy.action_slot_capacity = 5
	var short_hero: Array[String] = ["guard"]
	var long_enemy: Array[String] = ["guard", "lobar_brace", "guard", "lobar_brace", "guard"]
	assert(BattleChainPlanner.validate(short_hero, actor).is_empty())
	assert(BattleChainPlanner.validate(long_enemy, enemy).is_empty())
	assert(BattleChainPlanner.phase_length(short_hero, long_enemy) == 5)
	assert(BattleChainPlanner.action_at(short_hero, 4) == "guard")
	assert(BattleChainPlanner.preview(short_hero, long_enemy).size() == 5)
	var result: Dictionary = state.run_phase(short_hero, long_enemy)
	assert(result.success and result.ticks == 5)
	assert(state.flow.completed_ticks == 5)
	assert(state.last_phase_events.size() == 10)
	assert(state.get_hero().action_chain == short_hero)
	assert(short_hero.size() == 1 and long_enemy.size() == 5)

	# В обратную сторону длинная цепочка героя исполняется полностью.
	var second := BattleState.begin(monster, HeroState.new(HeroCatalog.get_hero("petushan")))
	var long_hero: Array[String] = ["guard", "guard", "guard", "guard", "guard"]
	second.get_hero().action_slot_capacity = 5
	var short_enemy: Array[String] = ["lobar_brace", "guard"]
	result = second.run_phase(long_hero, short_enemy)
	assert(result.success and result.ticks == 5)
	assert(second.last_phase_events.size() == 10)
	assert(second.last_phase_events[1].ability_id == "lobar_brace")
	assert(second.last_phase_events[3].ability_id == "guard")
	assert(second.last_phase_events[5].ability_id == "lobar_brace")
	assert(second.last_phase_events[7].ability_id == "guard")
	assert(second.last_phase_events[9].ability_id == "lobar_brace")

	# Во время обычной межфазной паузы изменить цепочку нельзя.
	var changed: Array[String] = ["basic_strike", "guard"]
	assert(not second.configure_hero_chain(changed).success)
	assert(not second.run_phase(changed, short_enemy).success)
	assert(second.flow.phase_number == 1)
	assert(second.get_hero().action_chain == long_hero)
	assert(second.run_phase(long_hero, short_enemy).success)

	# Разрешённая перенастройка обновляет цепочку следующей фазы.
	second.flow.reconfiguration_tokens = 1
	assert(second.flow.request_reconfiguration())
	assert(second.configure_hero_chain(changed).success)
	assert(second.flow.confirm_reconfiguration())
	assert(second.get_hero().action_chain == changed)
	assert(second.run_phase(changed, short_enemy).success)

	# Неверная или пустая цепочка не запускает фазу.
	var invalid := BattleState.begin(monster, HeroState.new(HeroCatalog.get_hero("volcha")))
	var missing: Array[String] = []
	var stranger: Array[String] = ["rooster_crush"]
	assert(not invalid.run_phase(missing, short_enemy).success)
	assert(not invalid.run_phase(stranger, short_enemy).success)
	assert(invalid.flow.phase_number == 0)
	var too_long: Array[String] = ["guard", "guard", "guard", "guard", "guard", "guard", "guard", "guard", "guard"]
	assert(not invalid.run_phase(too_long, short_enemy).success)
	assert(invalid.flow.stage == BattleFlow.Stage.PREPARATION)
	var missing_enemy: Array[String] = []
	assert(not invalid.run_phase(["guard"], missing_enemy).success)

	# Отмена перенастройки возвращает право на будущую попытку.
	var flow := BattleFlow.new()
	assert(flow.start_phase() and flow.complete_phase())
	flow.reconfiguration_tokens = 1
	assert(flow.request_reconfiguration())
	assert(flow.cancel_reconfiguration())
	assert(flow.reconfiguration_tokens == 1)
	assert(flow.request_reconfiguration())
	quit()
