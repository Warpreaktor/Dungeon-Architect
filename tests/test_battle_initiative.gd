extends SceneTree


func _fighter(id: String, team: String, agility: int = 0) -> BattleParticipant:
	var actor := BattleParticipant.new()
	actor.participant_id = id
	actor.team_id = team
	actor.max_health = BattleMath.PERCENT_SCALE
	actor.health = actor.max_health
	actor.agility = agility
	actor.personal_ability_ids = ["basic_strike", "guard"]
	return actor


func _step(action_id: String, reloading: bool = false) -> Dictionary:
	return {"action_id": action_id, "reload": reloading}


func _initiative_order(battle: BattleState, steps: Dictionary) -> Array[String]:
	var ids: Array[String] = [battle.hero_id]
	ids.append_array(battle.enemy_ids())
	return battle.tick_policy.order_for_tick(battle.participants, steps, ids)


func _initialize() -> void:
	var battle := BattleState.new()
	var hero: BattleParticipant = _fighter(battle.hero_id, "heroes")
	var enemy: BattleParticipant = _fighter(battle.enemy_id, "enemies", hero.agility + 1)
	var support: BattleParticipant = _fighter(battle.support_enemy_id, "enemies", enemy.agility + 1)
	battle.participants[hero.participant_id] = hero
	battle.participants[enemy.participant_id] = enemy
	battle.participants[support.participant_id] = support
	var ids: Array[String] = [battle.hero_id, battle.enemy_id, battle.support_enemy_id]
	var steps: Dictionary = {
		battle.hero_id: _step("guard"),
		battle.enemy_id: _step("guard"),
		battle.support_enemy_id: _step("guard")
	}

	var expected: Array[String] = [support.participant_id, enemy.participant_id, hero.participant_id]
	assert(_initiative_order(battle, steps) == expected)
	assert(_initiative_order(battle, steps) == expected)

	var penalty := AbilityEffectDefinition.new()
	penalty.kind = AbilityEffectDefinition.Kind.APPLY_STATUS
	penalty.status_id = "initiative_agility_penalty"
	penalty.status_stat = AbilityEffectDefinition.Stat.AGILITY
	penalty.status_modifier = -(support.agility - hero.agility)
	penalty.duration_ticks = 1
	penalty.status_clock = AbilityEffectDefinition.Clock.INCOMING_ATTACK
	support.apply_status(penalty, 0)
	assert(support.effective_agility() == hero.effective_agility())
	assert(_initiative_order(battle, steps) == [enemy.participant_id, hero.participant_id, support.participant_id])
	support.advance_status_clock(AbilityEffectDefinition.Clock.INCOMING_ATTACK)
	assert(_initiative_order(battle, steps) == expected)

	hero.agility = enemy.agility
	support.agility = enemy.agility
	steps[battle.hero_id] = _step("basic_strike")
	steps[battle.enemy_id] = _step("guard")
	steps[battle.support_enemy_id] = _step("basic_strike")
	assert(_initiative_order(battle, steps) == [enemy.participant_id, hero.participant_id, support.participant_id])
	steps[battle.enemy_id] = _step("basic_strike")
	assert(_initiative_order(battle, steps) == ids)
	steps[battle.hero_id] = _step("guard")
	steps[battle.enemy_id] = _step("basic_strike")
	steps[battle.support_enemy_id] = _step("basic_strike")
	hero.agility = 1
	enemy.agility = 9
	support.agility = 8
	assert(_initiative_order(battle, steps)[0] == hero.participant_id)
	hero.agility = enemy.agility
	support.agility = enemy.agility
	steps[battle.hero_id] = _step("guard", true)
	assert(_initiative_order(battle, steps) == [enemy.participant_id, support.participant_id, hero.participant_id])

	enemy.health = 0
	assert(_initiative_order(battle, steps) == [support.participant_id, hero.participant_id])
	battle.participants.erase(battle.enemy_id)
	assert(_initiative_order(battle, steps) == [support.participant_id, hero.participant_id])

	var repeat := BattleState.new()
	var h: BattleParticipant = _fighter(repeat.hero_id, "heroes")
	var e: BattleParticipant = _fighter(repeat.enemy_id, "enemies", h.agility + 1)
	var s: BattleParticipant = _fighter(repeat.support_enemy_id, "enemies", e.agility + 1)
	repeat.participants[h.participant_id] = h
	repeat.participants[e.participant_id] = e
	repeat.participants[s.participant_id] = s
	var hero_chain: Array[String] = []
	for slot in range(h.action_slot_capacity):
		hero_chain.append("guard")
	e.action_chain = ["guard"]
	s.action_chain = ["guard"]
	var result: Dictionary = BattlePhaseTestDriver.run_phase(repeat, hero_chain, e.action_chain)
	assert(bool(result.get("success", false)))
	var first_tick_actors: Array[String] = []
	var found_first_tick: bool = false
	for event in result.get("events", []):
		if str(event.get("type", "")) == "tick":
			if found_first_tick:
				break
			found_first_tick = true
		elif found_first_tick and str(event.get("type", "")) in ["action_start", "reload"]:
			first_tick_actors.append(str(event.get("actor_id", "")))
	assert(first_tick_actors == [e.participant_id, h.participant_id])

	var lethal := BattleState.new()
	var victim: BattleParticipant = _fighter(lethal.hero_id, "heroes")
	var attacker: BattleParticipant = _fighter(lethal.enemy_id, "enemies", victim.agility + 1)
	victim.health = 1
	attacker.strength = victim.max_health
	lethal.participants[victim.participant_id] = victim
	lethal.participants[attacker.participant_id] = attacker
	attacker.action_chain = ["basic_strike"]
	var victim_chain: Array[String] = []
	for slot in range(victim.action_slot_capacity):
		victim_chain.append("basic_strike")
	assert(bool(BattlePhaseTestDriver.run_phase(lethal, victim_chain, attacker.action_chain).get("success", false)))
	assert(lethal.is_defeat)
	for event in lethal.last_phase_events:
		assert(not (event.get("type", "") == "action_start" and event.get("actor_id", "") == victim.participant_id))
	quit()
