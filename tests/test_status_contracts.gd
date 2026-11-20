extends SceneTree


func _initialize() -> void:
	_check_clock_and_policies()
	_check_periodic_damage()
	quit()


func _check_clock_and_policies() -> void:
	var effect := AbilityEffectDefinition.new()
	effect.kind = AbilityEffectDefinition.Kind.APPLY_STATUS
	effect.status_id = "contract_accuracy"
	effect.status_stat = AbilityEffectDefinition.Stat.ACCURACY
	effect.status_modifier = -BattleMath.PERCENT_SCALE
	effect.status_clock = AbilityEffectDefinition.Clock.OWNER_PHASE
	effect.duration_ticks = BattleChainPlanner.MAX_ACTIONS
	var statuses: Dictionary = {}
	BattleStatusRules.apply(statuses, effect, 0, false)
	assert(BattleStatusRules.modifier(statuses, effect.status_stat) == effect.status_modifier)
	BattleStatusRules.advance(statuses, effect.status_clock)
	assert(int(statuses[effect.status_id]["ticks"]) == effect.duration_ticks - 1)
	BattleStatusRules.apply(statuses, effect, 0, false)
	assert(int(statuses[effect.status_id]["ticks"]) == effect.duration_ticks)
	assert(BattleStatusRules.modifier(statuses, effect.status_stat) == effect.status_modifier)
	effect.stack_policy = AbilityEffectDefinition.Stack.ADD
	BattleStatusRules.apply(statuses, effect, 0, false)
	assert(BattleStatusRules.modifier(statuses, effect.status_stat) == effect.status_modifier * int(statuses[effect.status_id]["stacks"]))
	for _phase in range(effect.duration_ticks):
		BattleStatusRules.advance(statuses, effect.status_clock)
	assert(not statuses.has(effect.status_id))
	BattleStatusRules.apply(statuses, effect, 0, true)
	var first_ticks: int = int(statuses[effect.status_id]["ticks"])
	BattleStatusRules.advance(statuses, effect.status_clock)
	assert(int(statuses[effect.status_id]["ticks"]) == first_ticks)
	BattleStatusRules.advance(statuses, effect.status_clock)
	assert(int(statuses[effect.status_id]["ticks"]) < first_ticks)


func _check_periodic_damage() -> void:
	var monster: MonsterDefinition = MonsterCatalog.get_monster(MonsterCatalog.DEFAULT_MONSTER_ID)
	var participant: BattleParticipant = BattleParticipant.from_monster(monster)
	var effect := AbilityEffectDefinition.new()
	effect.kind = AbilityEffectDefinition.Kind.APPLY_STATUS
	effect.status_id = "contract_bleeding"
	effect.status_clock = AbilityEffectDefinition.Clock.OWNER_PHASE
	effect.duration_ticks = BattleChainPlanner.MAX_ACTIONS
	effect.tick_damage = maxi(1, monster.max_health / effect.duration_ticks)
	participant.apply_status(effect, 0)
	var hp_before: int = participant.health
	var events: Array[Dictionary] = participant.owner_phase_status_damage_events(participant.participant_id)
	assert(not events.is_empty())
	assert(events.front()["status_id"] == effect.status_id)
	assert(hp_before - participant.health == mini(effect.tick_damage, hp_before))
	assert(participant.block_armor == 0)
	var expired: Array[String] = []
	for _phase in range(effect.duration_ticks):
		expired.append_array(participant.advance_status_clock(effect.status_clock))
	assert(expired.has(effect.status_id))
	assert(not participant.statuses.has(effect.status_id))
