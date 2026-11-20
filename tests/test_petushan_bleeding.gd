extends SceneTree

## Петушан: стартовые способности, динамический урон и фазы кровотечения.
func _initialize() -> void:
	assert(AbilityCatalog.validate_catalog().is_empty())
	var hero := HeroState.new(HeroCatalog.get_hero("petushan"))
	var state := BattleState.begin(MonsterCatalog.get_monster("hunter"), hero)
	var actor: BattleParticipant = state.get_hero()
	var target: BattleParticipant = state.get_enemy()
	assert(actor.personal_ability_ids == ["petushan_peck_while_hot", "petushan_not_in_brow_but_eye", "petushan_spur_under_rib"])
	var peck: AbilityDefinition = AbilityCatalog.get_ability("petushan_peck_while_hot")
	var eye: AbilityDefinition = AbilityCatalog.get_ability("petushan_not_in_brow_but_eye")
	var spur: AbilityDefinition = AbilityCatalog.get_ability("petushan_spur_under_rib")
	assert(peck.icon != null and eye.icon != null and spur.icon != null)
	assert(AbilityExecutor.preview_damage(actor, peck, peck.effects[0]) == floori(actor.melee_attack_value()))
	assert(AbilityExecutor.preview_damage(actor, eye, eye.effects[0]) == floori(actor.melee_attack_value() * 0.4))
	assert(state.execute_ability("hero", "enemy", eye.ability_id).success)
	assert(target.status_modifier(AbilityEffectDefinition.Stat.ACCURACY) == -20)
	# Повтор того же приёма не увеличивает штраф, но обновляет срок.
	var blind: AbilityEffectDefinition = eye.effects[1]
	assert(blind.effective_stack_policy() == AbilityEffectDefinition.Stack.REFRESH)
	target.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(int(target.statuses["petushan_accuracy_down"].ticks) == 1)
	target.apply_status(blind, state.flow.completed_ticks + 2)
	assert(target.status_modifier(AbilityEffectDefinition.Stat.ACCURACY) == -20)
	assert(int(target.statuses["petushan_accuracy_down"].stacks) == 1)
	assert(int(target.statuses["petushan_accuracy_down"].ticks) == 2)
	# Второй отдых удалит эффект, точность вернётся в исходное состояние.
	target.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	target.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(not target.statuses.has("petushan_accuracy_down"))
	assert(target.status_modifier(AbilityEffectDefinition.Stat.ACCURACY) == 0)
	assert(state.execute_ability("hero", "enemy", spur.ability_id).success)
	assert(target.statuses.has("bleeding"))
	# Эффект может быть наложен посреди уже начатой собственной фазы.
	target.action_cursor = 1
	assert(not bool(target.statuses["bleeding"].get("skip_partial_phase", false)))
	var hp_before: int = target.health
	var first_tick: Array[Dictionary] = target.owner_phase_status_damage_events("enemy")
	assert(first_tick.size() == 1 and int(first_tick[0].damage) == 2)
	assert(target.health == hp_before - 2)
	# Первый отдых может совпадать с тактом наложения.
	target.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, state.flow.completed_ticks + 1)
	assert(int(target.statuses["bleeding"].ticks) == 1)
	var second_tick: Array[Dictionary] = target.owner_phase_status_damage_events("enemy")
	assert(second_tick.size() == 1 and int(second_tick[0].damage) == 2)
	target.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE)
	assert(not target.statuses.has("bleeding"))
	assert(target.health == hp_before - 4)
	quit()
