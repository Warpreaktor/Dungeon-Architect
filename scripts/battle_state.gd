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


## Редактировать цепочку героя разрешено только до первого удара или
## в специальном состоянии перенастройки. Межфазная пауза её не меняет.
func configure_hero_chain(actions: Array[String]) -> Dictionary:
	if flow.stage != BattleFlow.Stage.PREPARATION and flow.stage != BattleFlow.Stage.RECONFIGURING:
		return {"success": false, "reason": "Сейчас нельзя изменить тактику"}
	var reason: String = BattleChainPlanner.validate(actions, get_hero())
	if not reason.is_empty():
		return {"success": false, "reason": reason}
	get_hero().action_chain = actions.duplicate()
	return {"success": true, "reason": ""}


## Каждый такт предоставляет действие обоим бойцам. Короткая цепочка
## повторяется циклически, но исходный список не изменяется.
## Внутри такта пока действует порядок герой -> противник (DA-4.07).
func run_phase(hero_actions: Array[String], enemy_actions: Array[String]) -> Dictionary:
	var hero_actor: BattleParticipant = get_hero()
	var enemy_actor: BattleParticipant = get_enemy()
	if hero_actor == null or enemy_actor == null:
		return {"success": false, "reason": "Нет участников боя", "events": []}
	var current_hero_chain: Array[String] = hero_actor.action_chain
	# Между фазами требования могут измениться (HP, сломанный щит).
	# В таком случае конкретный приём даст событие failed, но бой не зависнет.
	var enemy_reason: String = BattleChainPlanner.validate(enemy_actions, enemy_actor, false)
	if not enemy_reason.is_empty():
		return {"success": false, "reason": enemy_reason, "events": []}
	if flow.stage == BattleFlow.Stage.PREPARATION or flow.stage == BattleFlow.Stage.RECONFIGURING:
		var configured: Dictionary = configure_hero_chain(hero_actions)
		if not bool(configured.get("success", false)):
			return {"success": false, "reason": configured.get("reason", ""), "events": []}
		current_hero_chain = hero_actor.action_chain
	elif flow.stage == BattleFlow.Stage.BETWEEN_PHASES:
		if not BattleChainPlanner.validate(current_hero_chain, hero_actor, false).is_empty():
			return {"success": false, "reason": "Ошибка сохранённой цепочки", "events": []}
		if current_hero_chain != hero_actions:
			return {"success": false, "reason": "Тактика заблокирована до разрешённой перенастройки", "events": []}
	else:
		return {"success": false, "reason": "Сейчас нельзя запускать фазу", "events": []}
	var tick_count: int = BattleChainPlanner.phase_length(current_hero_chain, enemy_actions)
	if tick_count == 0 or not flow.start_phase():
		return {"success": false, "reason": "Сейчас нельзя запускать фазу", "events": []}
	enemy_actor.action_chain = enemy_actions.duplicate()
	var start_event: int = events.size()
	for tick in range(tick_count):
		if is_victory or is_defeat:
			break
		for actor_id in [hero_id, enemy_id]:
			if is_victory or is_defeat:
				break
			var actions: Array[String] = current_hero_chain if actor_id == hero_id else enemy_actions
			var action_id: String = BattleChainPlanner.action_at(actions, tick)
			var ability: AbilityDefinition = AbilityCatalog.get_ability(action_id)
			var target_id: String = actor_id
			if ability != null and ability.target == AbilityDefinition.Target.ENEMY:
				target_id = enemy_id if actor_id == hero_id else hero_id
			var outcome: Dictionary = execute_ability(actor_id, target_id, action_id)
			if not bool(outcome.get("success", false)):
				events.append({"type": "failed", "actor_id": actor_id, "ability_id": action_id,
					"reason": outcome.get("reason", "Недоступно")})
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


## Упорядочение фаз появится в DA-4.05–4.06; здесь явный сброс бонуса.
func end_phase() -> void:
	for participant in participants.values():
		(participant as BattleParticipant).end_phase()


## Совместимость текущего экрана: удар героя, затем один ответ врага.
## Оба урона рассчитываются тем же обработчиком, что и способности из .tres.
func perform_basic_attack(attack_damage: int) -> int:
	if is_victory or is_defeat:
		return 0
	var hero: BattleParticipant = get_hero()
	var enemy: BattleParticipant = get_enemy()
	if enemy == null or not enemy.is_alive():
		return 0
	last_counter_damage = 0
	last_blocked_damage = 0
	var bonus_percent: int = hero.block_attack_bonus_percent if hero != null else 0
	var damage_amount: int = maxi(attack_damage, 0) * (100 + bonus_percent) / 100
	if hero != null:
		hero.block_attack_bonus_percent = 0
	var source: BattleParticipant = hero
	if source == null:
		source = BattleParticipant.new()
		source.participant_id = hero_id
	var hit: Dictionary = AbilityExecutor.apply_damage(source, enemy, damage_amount, "basic_strike")
	turn_index += 1
	hit["turn"] = turn_index
	events.append(hit)
	update_outcome()
	if not is_victory:
		_counterattack()
	return int(hit["damage"])


## Временная ручная кнопка блока: пока цепочки действий не появились.
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
	var hit: Dictionary = AbilityExecutor.apply_damage(enemy, hero, enemy.attack, "basic_strike")
	hit["type"] = "counter" # Старые журналы и экран ожидают ответный удар.
	hit["turn"] = turn_index
	last_counter_damage = int(hit["damage"])
	last_blocked_damage = int(hit["blocked"])
	events.append(hit)
	update_outcome()
