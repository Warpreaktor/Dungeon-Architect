class_name BattleState
extends RefCounted

## Независимое от сцены состояние боя. Не управляет камерой и кнопками.
## Фазы управляются BattleFlow; планировщик произвольных цепочек — DA-4.06.
var participants: Dictionary = {} # participant_id -> BattleParticipant
var hero_id: String = "hero"
var enemy_id: String = "enemy"
var is_victory: bool = false
var is_defeat: bool = false
var last_counter_damage: int = 0
var last_blocked_damage: int = 0
var turn_index: int = 0
var events: Array[Dictionary] = []
var flow: BattleFlow = BattleFlow.new()
var tick_policy: BattleTurnPolicy = BattleTurnPolicy.new()
var last_phase_events: Array[Dictionary] = []


static func begin(monster: MonsterDefinition, hero: HeroState = null) -> BattleState:
	var state := BattleState.new()
	state.participants[state.enemy_id] = BattleParticipant.from_monster(monster)
	if hero != null:
		state.participants[state.hero_id] = BattleParticipant.from_hero(hero)
	return state


func get_participant(participant_id: String) -> BattleParticipant:
	return participants.get(participant_id) as BattleParticipant


func get_enemy() -> BattleParticipant:
	return get_participant(enemy_id)


func get_hero() -> BattleParticipant:
	return get_participant(hero_id)


## Полный результат действия с отдельными событиями для будущих анимаций.
func execute_ability(actor_id: String, target_id: String, ability_id: String) -> Dictionary:
	return AbilityExecutor.execute(self, actor_id, target_id, ability_id)


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
	# не разрушая всю фазу. Здесь проверяем только форму цепочки.
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
	if not flow.start_phase():
		return {"success": false, "reason": "Сейчас нельзя запускать фазу", "events": []}
	if enemy_actor.action_chain != enemy_actions:
		enemy_actor.action_chain = enemy_actions.duplicate()
		enemy_actor.action_cursor = 0
	var start_event: int = events.size()
	var hero_actions_done: int = 0
	var hero_rest_finished: bool = false
	while (hero_actions_done < current_hero_chain.size() or not hero_rest_finished) and not is_victory and not is_defeat:
		var hero_step: Dictionary = BattleChainPlanner.next_step(current_hero_chain, hero_actor.action_cursor)
		var enemy_step: Dictionary = BattleChainPlanner.next_step(enemy_actions, enemy_actor.action_cursor)
		hero_actor.action_cursor = int(hero_step["next_cursor"])
		enemy_actor.action_cursor = int(enemy_step["next_cursor"])
		if bool(hero_step["reload"]):
			# Отдых до завершения круга (старый курсор) не закрывает фазу.
			hero_rest_finished = hero_actions_done >= current_hero_chain.size()
		else:
			hero_actions_done += 1
		var tick: int = flow.completed_ticks + 1
		events.append({"type": "tick", "tick": tick, "hero_slot": int(hero_step["slot_index"]),
			"enemy_slot": int(enemy_step["slot_index"]), "hero_reload": bool(hero_step["reload"]),
			"enemy_reload": bool(enemy_step["reload"])})
		# Защитное действие имеет приоритет 0, любая другая категория — 10.
		# При равенстве герой ходит первым; смерть отменяет оставшийся ответ.
		var order: Array[String] = tick_policy.order(hero_id, hero_step, enemy_id, enemy_step)
		for actor_id in order:
			if is_victory or is_defeat:
				break
			var step: Dictionary = hero_step if actor_id == hero_id else enemy_step
			if bool(step["reload"]):
				events.append({"type": "reload", "actor_id": actor_id, "tick": tick,
					"slot_index": -1})
				continue
			var action_id: String = str(step["action_id"])
			events.append({"type": "action_start", "actor_id": actor_id,
				"ability_id": action_id, "slot_index": int(step["slot_index"]), "tick": tick})
			var ability: AbilityDefinition = AbilityCatalog.get_ability(action_id)
			var target_id: String = actor_id
			if ability != null and ability.target == AbilityDefinition.Target.ENEMY:
				target_id = enemy_id if actor_id == hero_id else hero_id
			var outcome: Dictionary = execute_ability(actor_id, target_id, action_id)
			if not bool(outcome.get("success", false)):
				# Неисполненный приём = досрочный отдых. Такт НЕ повторяется,
				# его стоимость не списывается и автоматический блок не даётся.
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
	last_phase_events = events.slice(start_event)
	return {"success": true, "events": last_phase_events, "finished": flow.stage == BattleFlow.Stage.FINISHED,
		"phase_number": flow.phase_number, "hero_hp": hero_actor.health, "ticks": flow.completed_ticks}


func default_chain(participant_id: String) -> Array[String]:
	var participant: BattleParticipant = get_participant(participant_id)
	if participant == null:
		return []
	var defense_id: String = ""
	var attack_id: String = ""
	for action_id in participant.personal_ability_ids + participant.learned_ability_ids:
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
	var enemy: BattleParticipant = get_enemy()
	var hero: BattleParticipant = get_hero()
	is_victory = enemy != null and not enemy.is_alive()
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
	var result: Dictionary = execute_ability(hero_id, enemy_id, "basic_strike")
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
