extends SceneTree


func _actor(id: String, team: String, agility: int) -> BattleParticipant:
	var actor := BattleParticipant.new()
	actor.participant_id = id
	actor.team_id = team
	actor.max_health = 500
	actor.health = 500
	actor.agility = agility
	actor.strength = 6
	actor.accuracy_bonus = 100
	actor.action_slot_capacity = 3
	actor.personal_ability_ids = ["basic_strike", "guard"]
	return actor


func _battle() -> BattleState:
	var battle := BattleState.new()
	battle.rng.seed = 112233
	battle.participants[battle.hero_id] = _actor("hero", "heroes", 30)
	battle.participants[battle.enemy_id] = _actor("enemy", "enemies", 1)
	battle.participants[battle.support_enemy_id] = _actor("enemy_support", "enemies", 1)
	battle.get_enemy().action_chain = ["basic_strike", "guard", "basic_strike"]
	battle.get_participant(battle.support_enemy_id).action_chain = ["guard", "basic_strike", "guard"]
	return battle


func _has_action(events: Array[Dictionary], actor_id: String, ability_id: String) -> bool:
	for event in events:
		if str(event.get("type", "")) == "action_start" and str(event.get("actor_id", "")) == actor_id and str(event.get("ability_id", "")) == ability_id:
			return true
	return false


func _initialize() -> void:
	var battle: BattleState = _battle()
	assert(not battle.run_manual_tick(0, "enemy").success)
	var prepared: Array[String] = ["basic_strike", "guard", "basic_strike"]
	assert(battle.prepare_manual_combat(prepared).success)
	assert(battle.manual_available_slots() == [0, 1, 2])
	var preview: Dictionary = battle.manual_next_enemy_step()
	assert(preview.actor_id == "enemy" and preview.action_id == "basic_strike")
	assert(not battle.run_phase(prepared, battle.get_enemy().action_chain).success)
	assert(not battle.run_manual_tick(0, "hero").success)
	assert(battle.flow.stage == BattleFlow.Stage.PREPARATION)
	var first: Dictionary = battle.run_manual_tick(1, "hero")
	assert(first.success and first.tick_performed)
	assert(battle.flow.stage == BattleFlow.Stage.EXECUTING)
	assert(battle.flow.completed_ticks == 1)
	assert(_has_action(first.events, "hero", "guard"))
	assert(_has_action(first.events, "enemy", "basic_strike"))
	assert(battle.manual_available_slots() == [0, 2])
	assert(battle.manual_next_enemy_step().actor_id == "enemy_support")
	var rng_before: int = battle.rng.state
	var event_count: int = battle.events.size()
	assert(not battle.run_manual_tick(1, "hero").success)
	assert(battle.rng.state == rng_before and battle.events.size() == event_count)
	assert(battle.flow.completed_ticks == 1)
	var second: Dictionary = battle.run_manual_tick(2, "enemy")
	assert(second.success and second.events[0].opponent_id == "enemy_support")
	assert(second.events[0].hero_slot == 2)
	var attacked_primary: bool = false
	for event in second.events:
		if event.get("type") == "attack" and event.get("actor_id") == "hero" and event.get("target_id") == "enemy":
			attacked_primary = true
	assert(attacked_primary)
	assert(battle.manual_available_slots() == [0])
	assert(battle.run_manual_tick(0, "enemy_support").success)
	assert(battle.manual_available_slots().is_empty())
	var rest: Dictionary = battle.run_manual_tick(-1)
	assert(rest.success and rest.events[0].hero_reload)
	assert(battle.flow.completed_ticks == 4)
	assert(battle.get_hero().completed_phases == 1)
	assert(battle.flow.stage == BattleFlow.Stage.BETWEEN_PHASES)
	assert(battle.manual_available_slots() == [0, 1, 2])
	assert(battle.run_manual_tick(2, "enemy_support").success)
	assert(battle.flow.phase_number == 2 and battle.flow.completed_ticks == 1)
	assert(battle.locked_hero_arsenal == prepared)
	assert(not battle.configure_hero_chain(["guard", "guard", "guard"]).success)

	var early: BattleState = _battle()
	assert(early.prepare_manual_combat(prepared).success)
	assert(early.run_manual_tick(1, "hero").success)
	assert(early.run_manual_tick(-1).success)
	assert(early.flow.stage == BattleFlow.Stage.BETWEEN_PHASES)
	assert(early.manual_available_slots() == [0, 1, 2])

	var replay: BattleState = _battle()
	var identical: BattleState = _battle()
	for session in [replay, identical]:
		assert(session.prepare_manual_combat(prepared).success)
	for item in [{"slot": 1, "target": "hero"}, {"slot": 2, "target": "enemy"}, {"slot": -1, "target": ""}]:
		var r: Dictionary = replay.run_manual_tick(item.slot, item.target)
		var c: Dictionary = identical.run_manual_tick(item.slot, item.target)
		assert(r.success and c.success and r.events == c.events)
	assert(replay.get_enemy().health == identical.get_enemy().health)
	assert(replay.rng.state == identical.rng.state)

	var victory: BattleState = _battle()
	victory.get_participant(victory.support_enemy_id).health = 0
	victory.get_enemy().health = 1
	assert(victory.prepare_manual_combat(prepared).success)
	var killing: Dictionary = victory.run_manual_tick(0, "enemy")
	assert(killing.success and killing.awaiting_victory_rest)
	assert(victory.is_victory and victory.flow.stage == BattleFlow.Stage.EXECUTING)
	assert(not victory.run_manual_tick(2, "enemy").success)
	var closing: Dictionary = victory.run_manual_tick(-1)
	assert(closing.success and closing.finished)
	assert(victory.flow.completed_ticks == 2)
	assert(victory.get_hero().completed_phases == 1)
	assert(victory.flow.stage == BattleFlow.Stage.FINISHED)

	var wounded := HeroState.new(HeroCatalog.get_hero("petushan"))
	wounded.health = 1
	assert(wounded.apply_overworld_status("bleeding", "Кровотечение", 1, 3, wounded.exploration_phase_length()))
	var fatal := BattleState.begin(MonsterCatalog.get_monster("skeleton"), wounded, 445566)
	fatal.get_enemy().health = 1
	fatal.get_hero().agility = 1000
	fatal.get_hero().accuracy_bonus = 100
	var lethal_cards: Array[String] = ["petushan_peck_while_hot", "petushan_not_in_brow_but_eye", "petushan_spur_under_rib"]
	assert(fatal.prepare_manual_combat(lethal_cards).success)
	var pending: Dictionary = fatal.run_manual_tick(0, "enemy")
	assert(pending.success and pending.awaiting_victory_rest)
	assert(fatal.get_hero().health == 1)
	var fatal_rest: Dictionary = fatal.run_manual_tick(-1)
	assert(fatal_rest.success and fatal_rest.finished)
	assert(fatal.is_defeat and not fatal.is_victory)
	assert(fatal.flow.completed_ticks == 2)
	quit()
