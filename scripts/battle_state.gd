class_name BattleState
extends RefCounted

const SUPPORT_ENEMY_ID: String = "enemy_support"

## Независимое от сцены состояние боя. Не управляет камерой и кнопками.
## Фазы управляются BattleFlow, участники адресуются только через ID.
var participants: Dictionary = {}
var positions: Dictionary = {}
var hero_id: String = "hero"
var enemy_id: String = "enemy"
var support_enemy_id: String = SUPPORT_ENEMY_ID
var enemy_definition: MonsterDefinition
var current_enemy_profile_id: String = ""
var initial_enemy_chain: Array[String] = []
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
var last_phase_events: Array[Dictionary] = []
## One RNG for reproducible combat decisions.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func begin(monster: MonsterDefinition, hero: HeroState = null, rng_seed: int = -1) -> BattleState:
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
	if hero != null:
		state.participants[state.hero_id] = BattleParticipant.from_hero(hero)
	return state


func get_participant(participant_id: String) -> BattleParticipant:
	return participants.get(participant_id) as BattleParticipant


func get_enemy() -> BattleParticipant:
	return get_participant(enemy_id)


func get_hero() -> BattleParticipant:
	return get_participant(hero_id)


func add_support_enemy(definition: MonsterDefinition) -> BattleParticipant:
	if definition == null:
		return null
	var existing: BattleParticipant = get_participant(support_enemy_id)
	if existing != null:
		return existing
	var participant: BattleParticipant = BattleParticipant.from_monster(definition, support_enemy_id)
	participant.is_targetable = false
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
	if flow.stage not in [BattleFlow.Stage.PREPARATION, BattleFlow.Stage.BETWEEN_PHASES, BattleFlow.Stage.RECONFIGURING]:
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


## После каждой законченной фазы игрок может изменить тактику.
## При неизменной цепочке личный курсор продолжает прежний цикл.
func configure_hero_chain(actions: Array[String]) -> Dictionary:
	if not (flow.stage in [BattleFlow.Stage.PREPARATION, BattleFlow.Stage.BETWEEN_PHASES, BattleFlow.Stage.RECONFIGURING]):
		return {"success": false, "reason": "Сейчас нельзя изменить тактику"}
	if get_hero() != null and actions.size() != get_hero().action_slot_capacity:
		return {"success": false, "reason": "Цепочка содержит незаполненные слоты"}
	var hero: BattleParticipant = get_hero()
	# Сохранённую цепочку не выкидываем при временной потере маны,
	# щита или изученного приёма. Такой слот отдохнёт при исполнении.
	if flow.stage == BattleFlow.Stage.BETWEEN_PHASES and hero.action_chain == actions:
		return {"success": true, "reason": ""}
	var reason: String = BattleChainPlanner.validate(actions, hero, false)
	if not reason.is_empty():
		return {"success": false, "reason": reason}
	if flow.stage == BattleFlow.Stage.BETWEEN_PHASES and hero.action_chain != actions:
		# Перенастройка не должна отменять обязательный отдых после круга.
		# После отдыха новый порядок начинается с первого слота.
		var rest_pending: bool = hero.action_cursor >= hero.action_chain.size()
		hero.action_cursor = actions.size() if rest_pending else 0
	hero.action_chain = actions.duplicate()
	return {"success": true, "reason": ""}


## Одна фаза включает полную цепочку ГЕРОЯ И его обязательный отдых.
## Курсоры участников независимы, отдых всегда завершает круг героя.
## Все события уже вычислены до визуального воспроизведения.
func run_phase(hero_actions: Array[String], enemy_actions: Array[String]) -> Dictionary:
	var hero_actor: BattleParticipant = get_hero()
	var enemy_actor: BattleParticipant = get_enemy()
	if hero_actor == null or enemy_actor == null:
		return {"success": false, "reason": "Нет участников боя", "events": []}
	var current_hero_chain: Array[String] = hero_actor.action_chain
	# Устаревший или временно недоступный приём врага даст ранний отдых,
	# не разрушая всю фазу. Колода уже выбрана при создании боя.
	# В ручных тестах состояние может создаваться без MonsterDefinition.
	# В этом случае разрешаем однократную установку колоды перед первым тактом.
	if enemy_actor.action_chain.is_empty() and flow.stage == BattleFlow.Stage.PREPARATION:
		enemy_actor.action_chain = enemy_actions.duplicate()
	enemy_actions = enemy_actor.action_chain.duplicate()
	if enemy_actions.is_empty() or enemy_actions.size() > enemy_actor.action_slot_capacity or enemy_actions.size() > BattleChainPlanner.MAX_ACTIONS:
		return {"success": false, "reason": "Некорректная цепочка противника", "events": []}
	if flow.stage == BattleFlow.Stage.PREPARATION or flow.stage == BattleFlow.Stage.RECONFIGURING:
		var was_reconfiguring: bool = flow.stage == BattleFlow.Stage.RECONFIGURING
		var configured: Dictionary = configure_hero_chain(hero_actions)
		if not bool(configured.get("success", false)):
			return {"success": false, "reason": configured.get("reason", ""), "events": []}
		current_hero_chain = hero_actor.action_chain
		if was_reconfiguring and hero_actor.action_cursor < current_hero_chain.size():
			# Старое разрешённое окно: вне обязательного отдыха начинаем заново.
			hero_actor.action_cursor = 0
	elif flow.stage == BattleFlow.Stage.BETWEEN_PHASES:
		# После каждой фазы разрешена новая раскладка; отказ при пустых
		# слотах остаётся за тем же валидатором, что и на старте боя.
		var configured: Dictionary = configure_hero_chain(hero_actions)
		if not bool(configured.get("success", false)):
			return {"success": false, "reason": configured.get("reason", ""), "events": []}
		current_hero_chain = hero_actor.action_chain
	else:
		return {"success": false, "reason": "Сейчас нельзя запускать фазу", "events": []}
	var start_event: int = events.size()
	if flow.stage == BattleFlow.Stage.BETWEEN_PHASES:
		_run_enemy_intermission()
	if not is_victory and not is_defeat:
		for actor_id in enemy_ids():
			_reconfigure_enemy_for_actor(actor_id)
	enemy_actions = enemy_actor.action_chain.duplicate()
	if not flow.start_phase():
		return {"success": false, "reason": "Сейчас нельзя запускать фазу", "events": []}
	var hero_actions_done: int = 0
	var hero_rest_finished: bool = false
	while (hero_actions_done < current_hero_chain.size() or not hero_rest_finished) and not is_victory and not is_defeat:
		var steps: Dictionary = {}
		for actor_id in [hero_id] + enemy_ids():
			var actor: BattleParticipant = get_participant(actor_id)
			if actor == null or not actor.is_alive():
				continue
			var step: Dictionary = BattleChainPlanner.next_step(actor.action_chain, actor.action_cursor)
			steps[actor_id] = step
			actor.action_cursor = int(step["next_cursor"])
			actor.is_resting = bool(step["reload"])
		var hero_step: Dictionary = steps.get(hero_id, {})
		if bool(hero_step.get("reload", false)):
			hero_rest_finished = hero_actions_done >= current_hero_chain.size()
		else:
			hero_actions_done += 1
		var enemy_step: Dictionary = steps.get(enemy_id, {})
		var support_step: Dictionary = steps.get(support_enemy_id, {})
		var tick: int = flow.completed_ticks + 1
		events.append({"type": "tick", "tick": tick,
			"hero_slot": int(hero_step.get("slot_index", -1)),
			"enemy_slot": int(enemy_step.get("slot_index", -1)),
			"support_slot": int(support_step.get("slot_index", -1)),
			"hero_reload": bool(hero_step.get("reload", false)),
			"enemy_reload": bool(enemy_step.get("reload", false)),
			"support_reload": bool(support_step.get("reload", false))})
		var actor_ids: Array[String] = [hero_id]
		actor_ids.append_array(enemy_ids())
		var order: Array[String] = tick_policy.order_for_tick(participants, steps, actor_ids)
		for actor_id in order:
			if is_victory or is_defeat:
				break
			if not steps.has(actor_id) or not get_participant(actor_id).is_alive():
				continue
			var step: Dictionary = steps[actor_id]
			if bool(step["reload"]):
				var resting: BattleParticipant = get_participant(actor_id)
				resting.completed_phases += 1
				resting.last_rest_tick = tick
				events.append_array(resting.owner_phase_status_damage_events(actor_id))
				update_outcome()
				if is_victory or is_defeat:
					break
				for expired_id in resting.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, tick):
					events.append({"type": "status_removed", "actor_id": actor_id,
						"target_id": actor_id, "status_id": expired_id, "removed": true})
				events.append({"type": "reload", "actor_id": actor_id, "tick": tick, "slot_index": -1})
				continue
			var action_id: String = str(step["action_id"])
			events.append({"type": "action_start", "actor_id": actor_id,
				"ability_id": action_id, "slot_index": int(step["slot_index"]), "tick": tick})
			var ability: AbilityDefinition = AbilityCatalog.get_ability(action_id)
			var target_id: String = create_context().choose_target_id(actor_id, ability)
			var outcome: Dictionary = execute_ability(actor_id, target_id, action_id)
			if not bool(outcome.get("success", false)):
				events.append({"type": "failed", "actor_id": actor_id, "ability_id": action_id,
					"slot_index": int(step["slot_index"]), "tick": tick,
					"reason": outcome.get("reason", "Недоступно")})
				events.append({"type": "rest", "actor_id": actor_id,
					"slot_index": int(step["slot_index"]), "tick": tick, "premature": true})
		flow.mark_tick()
		flow.grant_half_health_reconfiguration(hero_actor.health, hero_actor.max_health)
	if not is_victory and not is_defeat:
		end_phase()
		flow.complete_phase()
	else:
		flow.finish_battle()
	hero_actor.is_resting = false
	enemy_actor.is_resting = false
	var remaining_support: BattleParticipant = get_participant(support_enemy_id)
	if remaining_support != null:
		remaining_support.is_resting = false
	last_phase_events = events.slice(start_event)
	return {"success": true, "events": last_phase_events, "finished": flow.stage == BattleFlow.Stage.FINISHED,
		"phase_number": flow.phase_number, "hero_hp": hero_actor.health, "ticks": flow.completed_ticks}


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
	is_victory = enemy != null and not any_living_enemy
	is_defeat = hero != null and not hero.is_alive() and not is_victory


## Завершение фазы обрабатывает временные эффекты, но не сбрасывает бонус блока.
func end_phase() -> void:
	for participant in participants.values():
		(participant as BattleParticipant).end_phase()


## Совместимость текущего экрана: удар героя, затем один ответ врага.
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
