class_name BattleState
extends RefCounted

const SUPPORT_ENEMY_ID: String = "enemy_support"

## Независимое от сцены состояние боя. Не управляет камерой и кнопками.
## Фазы управляются BattleFlow, участники адресуются только через ID.
var participants: Dictionary = {}
var positions: Dictionary = {}
var hero_id: String = "hero"
var party_hero_ids: Array[String] = []
var enemy_id: String = "enemy"
var support_enemy_id: String = SUPPORT_ENEMY_ID
var enemy_definition: MonsterDefinition
var current_enemy_profile_id: String = ""
var initial_enemy_chain: Array[String] = []
var locked_hero_arsenal: Array[String] = []
var manual_combat_active: bool = false
var manual_used_slots: Array[int] = []
var _manual_phase_start: int = 0
var enemy_intermission_usage: Dictionary = {}
var support_enemy_definition: MonsterDefinition
var support_initial_chain: Array[String] = []
var support_profile_id: String = ""
var support_intermission_usage: Dictionary = {}
var battle_bond: BattleBondDefinition
var bond_mounted: bool = false
var bond_marked_target_id: String = ""
var intercept_targets: Dictionary = {}
var is_victory: bool = false
var is_defeat: bool = false
var last_counter_damage: int = 0
var last_blocked_damage: int = 0
var turn_index: int = 0
var events: Array[Dictionary] = []
var flow: BattleFlow = BattleFlow.new()
var tick_policy: BattleTurnPolicy = BattleTurnPolicy.new()
var next_enemy_clash_cursor: int = 0
var last_phase_events: Array[Dictionary] = []
## One RNG for reproducible combat decisions.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func begin(monster: MonsterDefinition, hero: HeroState = null, rng_seed: int = -1) -> BattleState:
	var heroes: Array[HeroState] = []
	if hero != null:
		heroes.append(hero)
	return begin_for_party(monster, heroes, rng_seed)


static func begin_for_party(monster: MonsterDefinition, heroes: Array[HeroState], rng_seed: int = -1) -> BattleState:
	var state := BattleState.new()
	if rng_seed < 0:
		state.rng.randomize()
	else:
		state.rng.seed = rng_seed
	state.enemy_definition = monster
	var enemy: BattleParticipant = BattleParticipant.from_monster(monster)
	state.participants[state.enemy_id] = enemy
	if enemy != null:
		enemy.action_chain = MonsterCardDraw.draw(monster, enemy, state.rng)
		state.initial_enemy_chain = enemy.action_chain.duplicate()
	for index in range(heroes.size()):
		var member: HeroState = heroes[index]
		if member == null:
			continue
		var participant_id: String = state.hero_id if index == 0 else "hero_%d" % (index + 1)
		var fighter: BattleParticipant = BattleParticipant.from_hero(member, participant_id)
		fighter.action_chain = member.get_saved_action_slots()
		state.participants[participant_id] = fighter
		state.party_hero_ids.append(participant_id)
	return state


func get_participant(participant_id: String) -> BattleParticipant:
	return participants.get(participant_id) as BattleParticipant


func get_enemy() -> BattleParticipant:
	return get_participant(enemy_id)


func get_hero() -> BattleParticipant:
	return get_participant(hero_id)


func hero_ids() -> Array[String]:
	if party_hero_ids.is_empty() and get_hero() != null:
		return [hero_id]
	return party_hero_ids.duplicate()


func living_hero_ids() -> Array[String]:
	var result: Array[String] = []
	for participant_id in hero_ids():
		var member: BattleParticipant = get_participant(participant_id)
		if member != null and member.is_alive():
			result.append(participant_id)
	return result


func add_support_enemy(definition: MonsterDefinition) -> BattleParticipant:
	if definition == null:
		return null
	var existing: BattleParticipant = get_participant(support_enemy_id)
	if existing != null:
		return existing
	var participant: BattleParticipant = BattleParticipant.from_monster(definition, support_enemy_id)
	participant.action_chain = MonsterCardDraw.draw(definition, participant, rng)
	participants[support_enemy_id] = participant
	support_enemy_definition = definition
	support_initial_chain = participant.action_chain.duplicate()
	return participant


func configure_bond(bond: BattleBondDefinition) -> void:
	battle_bond = bond
	bond_mounted = bond != null
	var commander: BattleParticipant = get_participant(support_enemy_id)
	if commander != null and bond_mounted:
		commander.is_targetable = false


func _bond_swap_cards(actor: BattleParticipant, from_ids: Array, to_ids: Array) -> void:
	for index in range(mini(from_ids.size(), to_ids.size())):
		var old_id: String = str(from_ids[index])
		var new_id: String = str(to_ids[index])
		var slot_index: int = actor.action_chain.find(old_id)
		if slot_index >= 0:
			actor.action_chain[slot_index] = new_id
		actor.personal_ability_ids.erase(old_id)
		if not actor.personal_ability_ids.has(new_id):
			actor.personal_ability_ids.append(new_id)
	events.append({"type": "enemy_chain_changed", "actor_id": actor.participant_id,
		"chain_size": actor.action_chain.size()})


func _bond_change_form(mounted: bool) -> void:
	if battle_bond == null or bond_mounted == mounted:
		return
	var commander: BattleParticipant = get_participant(support_enemy_id)
	if commander == null or not commander.is_alive():
		return
	if mounted:
		_bond_swap_cards(commander,
			[battle_bond.ranged_ability_id, battle_bond.rejoin_ability_id],
			[battle_bond.heal_ability_id, battle_bond.split_ability_id])
	else:
		_bond_swap_cards(commander,
			[battle_bond.heal_ability_id, battle_bond.split_ability_id],
			[battle_bond.ranged_ability_id, battle_bond.rejoin_ability_id])
	bond_mounted = mounted
	commander.is_targetable = not mounted
	events.append({"type": "bond_form_changed", "actor_id": commander.participant_id,
		"mounted": mounted})


func _bond_clear_mark() -> void:
	if battle_bond == null or bond_marked_target_id.is_empty():
		return
	var marked: BattleParticipant = get_participant(bond_marked_target_id)
	if marked != null:
		marked.statuses.erase(battle_bond.marked_status_id)
		events.append({"type": "status_removed", "actor_id": support_enemy_id,
			"target_id": bond_marked_target_id, "status_id": battle_bond.marked_status_id,
			"removed": true})
	bond_marked_target_id = ""


func _bond_after_action(actor_id: String, target_id: String, ability_id: String) -> void:
	if battle_bond == null:
		return
	var guardian: BattleParticipant = get_enemy()
	var commander: BattleParticipant = get_participant(support_enemy_id)
	if guardian == null or commander == null:
		return
	if actor_id == support_enemy_id:
		if ability_id == battle_bond.command_ability_id:
			if bond_marked_target_id != target_id:
				_bond_clear_mark()
			bond_marked_target_id = target_id
			var marked: BattleParticipant = get_participant(target_id)
			if marked != null and not battle_bond.marked_status_id.is_empty():
				marked.statuses[battle_bond.marked_status_id] = {
					"stat": AbilityEffectDefinition.Stat.NONE, "modifier": 0, "stacks": 1,
					"clock": -1, "ticks": -1, "tick_damage": 0
				}
				events.append({"type": "status_applied", "actor_id": actor_id,
					"target_id": target_id, "ability_id": ability_id,
					"status_id": battle_bond.marked_status_id, "duration_ticks": -1,
					"accuracy_after": marked.accuracy_percent(), "dodge_after": marked.dodge_percent()})
			events.append({"type": "bond_marked", "actor_id": actor_id, "target_id": target_id})
		elif ability_id == battle_bond.split_ability_id:
			_bond_change_form(false)
		elif ability_id == battle_bond.rejoin_ability_id and guardian.is_alive():
			_bond_change_form(true)
	elif actor_id == enemy_id and ability_id == battle_bond.protect_ability_id and commander.is_alive():
		intercept_targets[support_enemy_id] = enemy_id
		events.append({"type": "bond_protected", "actor_id": actor_id, "target_id": support_enemy_id})


func _bond_update_life() -> void:
	if battle_bond == null:
		return
	var guardian: BattleParticipant = get_enemy()
	var commander: BattleParticipant = get_participant(support_enemy_id)
	if commander == null or guardian == null:
		return
	if not commander.is_alive():
		_bond_clear_mark()
		intercept_targets.clear()
	elif not guardian.is_alive():
		intercept_targets.clear()
		_bond_change_form(false)
	if not bond_marked_target_id.is_empty():
		var marked: BattleParticipant = get_participant(bond_marked_target_id)
		if marked == null or not marked.is_alive():
			_bond_clear_mark()


func enemy_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in [enemy_id, support_enemy_id]:
		if get_participant(id) != null:
			ids.append(id)
	return ids


func _reconfigure_enemy_for_phase() -> void:
	_reconfigure_enemy_for_actor(enemy_id)


func _reconfigure_enemy_for_actor(actor_id: String) -> void:
	if flow.stage not in [BattleFlow.Stage.PREPARATION, BattleFlow.Stage.BETWEEN_PHASES]:
		return
	var actor: BattleParticipant = get_participant(actor_id)
	if actor == null or not actor.is_alive() or actor.action_cursor != 0:
		return
	var definition: MonsterDefinition = enemy_definition if actor_id == enemy_id else support_enemy_definition
	if definition == null:
		return
	var active_profile: String = current_enemy_profile_id if actor_id == enemy_id else support_profile_id
	var initial_chain: Array[String] = initial_enemy_chain if actor_id == enemy_id else support_initial_chain
	var profile: MonsterTacticProfile = MonsterAiPlanner.choose_profile(definition, actor, active_profile, rng)
	var profile_id: String = profile.profile_id if profile != null else ""
	if profile_id == active_profile and (profile == null or not definition.reconsider_tactics_each_phase):
		return
	var planned: Array[String] = initial_chain.duplicate() if profile == null else MonsterAiPlanner.planned_chain(profile, actor, rng)
	planned = MonsterWeaponStrike.replace_default_card(definition, actor, planned)
	if planned.is_empty():
		return
	if actor_id == enemy_id:
		current_enemy_profile_id = profile_id
	else:
		support_profile_id = profile_id
	if planned == actor.action_chain:
		return
	actor.action_chain = planned
	actor.action_cursor = 0
	events.append({"type": "enemy_chain_changed", "actor_id": actor_id,
		"profile_id": profile_id, "chain_size": planned.size()})


func _run_enemy_intermission() -> void:
	for actor_id in enemy_ids():
		_run_enemy_intermission_for(actor_id)


func _run_enemy_intermission_for(actor_id: String) -> void:
	if flow.stage != BattleFlow.Stage.BETWEEN_PHASES:
		return
	var definition: MonsterDefinition = enemy_definition if actor_id == enemy_id else support_enemy_definition
	var actor: BattleParticipant = get_participant(actor_id)
	if definition == null or actor == null or not actor.is_alive():
		return
	var usage: Dictionary = enemy_intermission_usage if actor_id == enemy_id else support_intermission_usage
	for _action_index in range(definition.max_intermission_actions):
		var action: MonsterIntermissionAction = MonsterAiPlanner.choose_intermission(definition, actor, usage, rng)
		if action == null:
			break
		var ability: AbilityDefinition = AbilityCatalog.get_ability(action.ability_id)
		var target_id: String = create_context().choose_target_id(actor_id, ability)
		if target_id.is_empty():
			break
		var outcome: Dictionary = execute_ability(actor_id, target_id, action.ability_id)
		if not bool(outcome.get("success", false)):
			break
		usage[action.identity()] = int(usage.get(action.identity(), 0)) + 1
		var result_events: Array = outcome.get("events", [])
		events.insert(events.size() - result_events.size(), {
			"type": "enemy_intermission_action", "actor_id": actor_id,
			"ability_id": action.ability_id, "target_id": target_id})
		if is_victory or is_defeat:
			break


func create_context() -> BattleContext:
	return BattleContext.new(participants, rng, flow.completed_ticks + 1, positions,
		intercept_targets, battle_bond.counter_multiplier if battle_bond != null else 0.0,
		battle_bond.protect_ability_id if battle_bond != null else "",
		enemy_id if battle_bond != null else "", bond_marked_target_id,
		battle_bond.marked_accuracy_bonus if battle_bond != null else 0)


func execute_ability(actor_id: String, target_id: String, ability_id: String) -> Dictionary:
	if is_victory or is_defeat:
		return {"success": false, "reason": "Бой уже завершён", "events": []}
	if battle_bond != null and actor_id == support_enemy_id:
		if ability_id == battle_bond.split_ability_id and not bond_mounted:
			return {"success": false, "reason": "Уже отделён", "events": []}
		if ability_id == battle_bond.rejoin_ability_id and (bond_mounted or not get_enemy().is_alive()):
			return {"success": false, "reason": "Нельзя соединиться", "events": []}
	var outcome: Dictionary = _commit_action(AbilityExecutor.execute(create_context(), actor_id, target_id, ability_id))
	if bool(outcome.get("success", false)):
		_bond_after_action(actor_id, target_id, ability_id)
	return outcome


func execute_definition(actor_id: String, target_id: String, ability: AbilityDefinition) -> Dictionary:
	if is_victory or is_defeat:
		return {"success": false, "reason": "Бой уже завершён", "events": []}
	return _commit_action(AbilityExecutor.execute_definition(create_context(), actor_id, target_id, ability))


func _commit_action(outcome: Dictionary) -> Dictionary:
	if bool(outcome.get("success", false)):
		events.append_array(outcome.get("events", []))
		update_outcome()
	return outcome


static func same_arsenal(first: Array[String], second: Array[String]) -> bool:
	if first.size() != second.size():
		return false
	var left: Array[String] = first.duplicate()
	var right: Array[String] = second.duplicate()
	left.sort()
	right.sort()
	return left == right


func configure_hero_chain(actions: Array[String]) -> Dictionary:
	if not (flow.stage in [BattleFlow.Stage.PREPARATION, BattleFlow.Stage.BETWEEN_PHASES]):
		return {"success": false, "reason": "Сейчас нельзя изменить тактику"}
	if get_hero() != null and actions.size() > get_hero().action_slot_capacity:
		return {"success": false, "reason": "Превышено число боевых слотов"}
	if flow.phase_number > 0 and not same_arsenal(actions, locked_hero_arsenal):
		return {"success": false, "reason": "Арсенал зафиксирован на весь бой. Можно менять только порядок приёмов."}
	var hero: BattleParticipant = get_hero()
	# Сохранённую цепочку не выкидываем при временной потере маны,
	# щита или изученного приёма. Такой слот отдохнёт при исполнении.
	if flow.stage == BattleFlow.Stage.BETWEEN_PHASES and hero.action_chain == actions:
		return {"success": true, "reason": ""}
	if flow.phase_number == 0:
		var reason: String = BattleChainPlanner.validate(actions, hero, false) if not actions.is_empty() else ""
		if not reason.is_empty():
			return {"success": false, "reason": reason}
	if flow.stage == BattleFlow.Stage.BETWEEN_PHASES and hero.action_chain != actions:
		# Перенастройка не должна отменять обязательный отдых после круга.
		# После отдыха новый порядок начинается с первого слота.
		var rest_pending: bool = hero.action_cursor >= hero.action_chain.size()
		hero.action_cursor = actions.size() if rest_pending else 0
	hero.action_chain = actions.duplicate()
	return {"success": true, "reason": ""}


func prepare_manual_combat(actions: Array[String]) -> Dictionary:
	if flow.stage != BattleFlow.Stage.PREPARATION or flow.phase_number != 0:
		return {"success": false, "reason": "Подготовка уже завершена"}
	for actor_id in enemy_ids():
		var actor: BattleParticipant = get_participant(actor_id)
		if actor == null or not actor.is_alive():
			continue
		if actor.action_chain.is_empty() or actor.action_chain.size() > actor.action_slot_capacity or actor.action_chain.size() > BattleChainPlanner.MAX_ACTIONS:
			return {"success": false, "reason": "Некорректная цепочка противника"}
	var configured: Dictionary = configure_hero_chain(actions)
	if not bool(configured.get("success", false)):
		return configured
	manual_combat_active = true
	manual_used_slots.clear()
	return {"success": true}


func manual_available_slots() -> Array[int]:
	var available: Array[int] = []
	if not manual_combat_active or flow.stage == BattleFlow.Stage.FINISHED or is_victory or is_defeat:
		return available
	var hero: BattleParticipant = get_hero()
	if hero == null:
		return available
	for slot in range(hero.action_chain.size()):
		if not manual_used_slots.has(slot):
			available.append(slot)
	return available



func manual_next_enemy_step() -> Dictionary:
	if not manual_combat_active or is_victory or is_defeat or flow.stage == BattleFlow.Stage.FINISHED:
		return {}
	var clash: Dictionary = BattleClashPlanner.next_opponent(participants, enemy_ids(), next_enemy_clash_cursor)
	var actor_id: String = str(clash.get("actor_id", ""))
	if actor_id.is_empty():
		return {}
	var opponent: BattleParticipant = get_participant(actor_id)
	var step: Dictionary = BattleChainPlanner.next_step(opponent.action_chain, opponent.action_cursor)
	return {"actor_id": actor_id, "action_id": step["action_id"],
		"slot_index": step["slot_index"], "reload": step["reload"]}


func _begin_manual_phase() -> void:
	_manual_phase_start = get_hero().completed_phases
	flow.start_phase()
	if flow.phase_number == 1:
		locked_hero_arsenal = get_hero().action_chain.duplicate()


func run_manual_tick(slot_index: int, target_id: String = "") -> Dictionary:
	if not manual_combat_active or flow.stage == BattleFlow.Stage.FINISHED:
		return {"success": false, "reason": "Ручной бой не подготовлен", "events": []}
	if flow.stage not in [BattleFlow.Stage.PREPARATION, BattleFlow.Stage.BETWEEN_PHASES, BattleFlow.Stage.EXECUTING]:
		return {"success": false, "reason": "Сейчас нельзя выполнить такт", "events": []}
	var hero: BattleParticipant = get_hero()
	var enemy: BattleParticipant = get_enemy()
	if hero == null or enemy == null or not hero.is_alive() or is_defeat:
		return {"success": false, "reason": "Герой недоступен", "events": []}
	var resting: bool = slot_index == -1
	if resting:
		if target_id.is_empty():
			target_id = hero_id
		if target_id != hero_id:
			return {"success": false, "reason": "Отдых направлен на самого героя", "events": []}
	if not resting:
		if is_victory:
			return {"success": false, "reason": "Необходимо завершить победный отдых", "events": []}
		if slot_index < 0 or slot_index >= hero.action_chain.size() or manual_used_slots.has(slot_index):
			return {"success": false, "reason": "Карта уже использована или отсутствует", "events": []}
		var ability: AbilityDefinition = AbilityCatalog.get_ability(hero.action_chain[slot_index])
		var invalid_target: String = create_context().target_error(hero_id, target_id, ability)
		if not invalid_target.is_empty():
			return {"success": false, "reason": invalid_target, "events": []}
	var start_event: int = events.size()
	if flow.stage != BattleFlow.Stage.EXECUTING:
		_begin_manual_phase()
	var opponent_id: String = ""
	if not is_victory:
		var clash: Dictionary = BattleClashPlanner.next_opponent(participants, enemy_ids(), next_enemy_clash_cursor)
		opponent_id = str(clash.get("actor_id", ""))
		if opponent_id.is_empty():
			update_outcome()
			if not is_victory:
				return {"success": false, "reason": "Нет действующего противника", "events": []}
		else:
			next_enemy_clash_cursor = int(clash.get("next_cursor", next_enemy_clash_cursor))
	var steps: Dictionary = {}
	steps[hero_id] = {"action_id": "" if resting else hero.action_chain[slot_index],
		"slot_index": -1 if resting else slot_index, "reload": resting}
	hero.is_resting = resting
	if not opponent_id.is_empty():
		var opponent: BattleParticipant = get_participant(opponent_id)
		var enemy_step: Dictionary = BattleChainPlanner.next_step(opponent.action_chain, opponent.action_cursor)
		steps[opponent_id] = enemy_step
		opponent.action_cursor = int(enemy_step["next_cursor"])
		opponent.is_resting = bool(enemy_step["reload"])
	if not resting:
		manual_used_slots.append(slot_index)
	hero.action_cursor = 0 if resting else slot_index + 1
	var tick: int = flow.completed_ticks + 1
	_resolve_tick(steps, opponent_id, tick, target_id)
	flow.mark_tick()
	if hero.completed_phases > _manual_phase_start:
		end_phase()
		manual_used_slots.clear()
		if not is_victory and not is_defeat:
			flow.complete_phase()
	if is_defeat or (is_victory and hero.completed_phases > _manual_phase_start):
		flow.finish_battle()
	hero.is_resting = false
	for actor_id in enemy_ids():
		var actor: BattleParticipant = get_participant(actor_id)
		if actor != null:
			actor.is_resting = false
	last_phase_events = events.slice(start_event)
	return {"success": true, "events": last_phase_events,
		"finished": flow.stage == BattleFlow.Stage.FINISHED,
		"awaiting_victory_rest": is_victory and flow.stage != BattleFlow.Stage.FINISHED,
		"phase_number": flow.phase_number, "hero_hp": hero.health,
		"ticks": flow.completed_ticks, "available_slots": manual_available_slots(),
		"tick_performed": true}


func _resolve_tick(steps: Dictionary, opponent_id: String, tick: int, selected_target_id: String = "") -> void:
	var hero_step: Dictionary = steps.get(hero_id, {})
	var enemy_step: Dictionary = steps.get(enemy_id, {})
	var support_step: Dictionary = steps.get(support_enemy_id, {})
	events.append({"type": "tick", "tick": tick, "opponent_id": opponent_id,
		"hero_slot": int(hero_step.get("slot_index", -1)),
		"enemy_slot": int(enemy_step.get("slot_index", -1)),
		"support_slot": int(support_step.get("slot_index", -1)),
		"hero_reload": bool(hero_step.get("reload", false)),
		"enemy_reload": bool(enemy_step.get("reload", false)),
		"support_reload": bool(support_step.get("reload", false))})
	var order: Array[String] = [hero_id]
	if not opponent_id.is_empty():
		order.append(opponent_id)
	for actor_id in order:
		if is_defeat or (is_victory and not (actor_id == hero_id and bool(steps[actor_id].get("reload", false)))):
			break
		if not steps.has(actor_id) or not get_participant(actor_id).is_alive():
			continue
		var step: Dictionary = steps[actor_id]
		if bool(step["reload"]):
			_complete_rest(actor_id, tick)
			continue
		var action_id: String = str(step["action_id"])
		events.append({"type": "action_start", "actor_id": actor_id,
			"ability_id": action_id, "slot_index": int(step["slot_index"]), "tick": tick})
		var ability: AbilityDefinition = AbilityCatalog.get_ability(action_id)
		var context: BattleContext = create_context()
		var target_id: String = ""
		if actor_id == hero_id and not selected_target_id.is_empty():
			target_id = selected_target_id
		elif actor_id == hero_id and context.target_ids(actor_id, ability).has(opponent_id):
			target_id = opponent_id
		else:
			target_id = context.choose_target_id(actor_id, ability)
		var outcome: Dictionary = execute_ability(actor_id, target_id, action_id)
		if not bool(outcome.get("success", false)):
			events.append({"type": "failed", "actor_id": actor_id, "ability_id": action_id,
				"slot_index": int(step["slot_index"]), "tick": tick,
				"reason": outcome.get("reason", "Недоступно")})
			events.append({"type": "rest", "actor_id": actor_id,
				"slot_index": int(step["slot_index"]), "tick": tick, "premature": true})


func _complete_rest(actor_id: String, tick: int) -> void:
	var resting: BattleParticipant = get_participant(actor_id)
	resting.completed_phases += 1
	resting.last_rest_tick = tick
	events.append({"type": "reload", "actor_id": actor_id, "tick": tick, "slot_index": -1, "target_id": actor_id})
	events.append_array(resting.owner_phase_status_damage_events(actor_id))
	var before_health: int = resting.health
	var before_maximum: int = resting.max_health
	for expired_id in resting.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, tick):
		events.append({"type": "status_removed", "actor_id": actor_id,
			"target_id": actor_id, "status_id": expired_id, "removed": true})
	if before_maximum != resting.max_health:
		events.append({"type": "hp_limit_changed", "actor_id": actor_id,
			"target_id": actor_id, "hp_after": resting.health, "hp_max": resting.max_health,
			"hp_difference": resting.health - before_health})
	resting.advance_consumable_phase()
	update_outcome()


func default_chain(participant_id: String) -> Array[String]:
	var participant: BattleParticipant = get_participant(participant_id)
	if participant == null:
		return []
	if participant_id in enemy_ids() and not participant.action_chain.is_empty():
		return participant.action_chain.duplicate()
	var defense_id: String = ""
	var attack_id: String = ""
	for action_id in AbilityCatalog.known_ability_ids(participant):
		if not AbilityCatalog.can_prepare(participant, action_id):
			continue
		var definition: AbilityDefinition = AbilityCatalog.get_ability(action_id)
		if definition.category == AbilityDefinition.Category.DEFENSE and defense_id.is_empty():
			defense_id = action_id
		if definition.category == AbilityDefinition.Category.ATTACK:
			attack_id = action_id
	if attack_id.is_empty():
		attack_id = "basic_strike" if AbilityCatalog.can_prepare(participant, "basic_strike") else ""
	if defense_id.is_empty():
		defense_id = attack_id
	if attack_id.is_empty():
		attack_id = defense_id
	if attack_id.is_empty():
		return []
	return [defense_id, attack_id]


func update_outcome() -> void:
	_bond_update_life()
	var enemy: BattleParticipant = get_enemy()
	var hero: BattleParticipant = get_hero()
	var any_living_enemy: bool = false
	for actor_id in enemy_ids():
		var actor: BattleParticipant = get_participant(actor_id)
		if actor != null and actor.is_alive():
			any_living_enemy = true
	var support: BattleParticipant = get_participant(support_enemy_id)
	if support != null and enemy != null and not enemy.is_alive():
		support.is_targetable = true
	is_defeat = not hero_ids().is_empty() and living_hero_ids().is_empty()
	is_victory = enemy != null and not any_living_enemy and not is_defeat


## Завершение фазы обрабатывает временные эффекты, но не сбрасывает бонус блока.
func end_phase() -> void:
	for participant in participants.values():
		(participant as BattleParticipant).end_phase()


## Совместимость прямых вызовов из старых тестов и режима карты.
## Оба урона рассчитываются тем же обработчиком, что и способности из .tres.
func perform_basic_attack(_legacy_attack_damage: int = 0) -> int:
	if is_victory or is_defeat or get_hero() == null:
		return 0
	last_counter_damage = 0
	last_blocked_damage = 0
	var attack_id: String = "basic_strike" if AbilityCatalog.can_prepare(get_hero(), "basic_strike") else ""
	for id in get_hero().personal_ability_ids + get_hero().learned_ability_ids:
		if not attack_id.is_empty():
			break
		var definition: AbilityDefinition = AbilityCatalog.get_ability(id)
		if definition != null and definition.category == AbilityDefinition.Category.ATTACK:
			attack_id = id
			break
	if attack_id.is_empty():
		return 0
	var result: Dictionary = execute_ability(hero_id, enemy_id, attack_id)
	if not bool(result.get("success", false)):
		return 0
	var damage: int = 0
	for event in result["events"]:
		if event["type"] == "attack":
			damage = int(event["damage"])
	turn_index += 1
	if not is_victory:
		_counterattack()
	elif get_hero().is_alive():
		_complete_rest(hero_id, flow.completed_ticks + 1)
		end_phase()
	return damage


## Временный совместимый ручной вызов блока.
func perform_guard() -> Dictionary:
	if is_victory or is_defeat:
		return {"success": false, "reason": "Бой завершён", "events": []}
	var result: Dictionary = execute_ability(hero_id, hero_id, "guard")
	if not bool(result.get("success", false)):
		return result
	last_counter_damage = 0
	last_blocked_damage = 0
	turn_index += 1
	if not is_victory:
		_counterattack()
	return result


func _counterattack() -> void:
	var hero: BattleParticipant = get_hero()
	var enemy: BattleParticipant = get_enemy()
	if hero == null or enemy == null or not hero.is_alive() or not enemy.is_alive():
		return
	var ability: AbilityDefinition = AbilityCatalog.get_ability("basic_strike")
	if ability == null or ability.effects.is_empty():
		return
	var amount: int = AbilityExecutor.preview_damage(enemy, ability, ability.effects[0])
	enemy.block_attack_bonus_percent = 0
	var hit: Dictionary = AbilityExecutor.apply_damage(enemy, hero, amount, "basic_strike")
	hit["type"] = "counter"
	hit["turn"] = turn_index
	last_counter_damage = int(hit["damage"])
	last_blocked_damage = int(hit["blocked"])
	events.append(hit)
	update_outcome()
