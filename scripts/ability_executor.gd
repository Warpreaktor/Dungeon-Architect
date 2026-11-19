class_name AbilityExecutor
extends RefCounted

## Общий обработчик одного приёма. Не зависит от Control, кадров и Tween.
## Возвращает только факты; BattleState хранит события и исход схватки.


static func execute(state, actor_id: String, target_id: String, ability_id: String) -> Dictionary:
	return execute_definition(state, actor_id, target_id, AbilityCatalog.get_ability(ability_id))


## Прямое исполнение ресурса полезно для тестов и будущих изучаемых приёмов.
## Владение приёмом и все ограничения проверяются так же, как при вызове по ID.
static func execute_definition(state, actor_id: String, target_id: String, ability: AbilityDefinition) -> Dictionary:
	var actor: BattleParticipant = state.get_participant(actor_id)
	var target: BattleParticipant = state.get_participant(target_id)
	var ability_id: String = ability.ability_id if ability != null else ""
	if state.is_victory or state.is_defeat:
		return _failure("Бой уже завершён")
	if actor == null or not actor.is_alive():
		return _failure("Участник недоступен")
	if ability == null:
		return _failure("Неизвестный приём")
	if not (ability_id in actor.personal_ability_ids or ability_id in actor.learned_ability_ids):
		return _failure("Приём не изучен")
	var ability_problem: String = ability.validation_error()
	if ability_problem.is_empty():
		ability_problem = ability.unavailable_reason(actor)
	if not ability_problem.is_empty():
		return _failure(ability_problem)
	if ability.target == AbilityDefinition.Target.SELF:
		if target != actor:
			return _failure("Требуется цель: сам участник")
	elif target == null or target == actor or not target.is_alive() or target.team_id == actor.team_id:
		return _failure("Недопустимая цель")
	# Валидация всей операции до первого изменения HP, статуса или запаса.
	for effect in ability.effects:
		if effect == null or effect.validation_error() != "":
			return _failure("Некорректный эффект")
		if effect.recipient == AbilityEffectDefinition.Recipient.TARGET and target == null:
			return _failure("Нет цели эффекта")
	# Атомарное списание: одна стоимость на всё действие, а не на каждый эффект.
	var event_list: Array[Dictionary] = []
	for resource_id in ability.resource_costs:
		var cost: int = int(ability.resource_costs[resource_id])
		var remaining: int = int(actor.resource_amounts.get(resource_id, 0)) - cost
		actor.resource_amounts[resource_id] = remaining
		event_list.append({"type": "resource_spent", "actor_id": actor_id,
			"ability_id": ability_id, "resource_id": resource_id, "amount": cost, "remaining": remaining})
	for effect in ability.effects:
		var recipient: BattleParticipant = actor if effect.recipient == AbilityEffectDefinition.Recipient.SELF else target
		if recipient == null:
			return _failure("Нет цели эффекта")
		match effect.kind:
			AbilityEffectDefinition.Kind.DAMAGE:
				var raw_damage: int = preview_damage(actor, ability, effect)
				actor.block_attack_bonus_percent = 0
				event_list.append(apply_damage(actor, recipient, raw_damage, ability_id))
			AbilityEffectDefinition.Kind.BLOCK:
				recipient.prepare_block(effect.amount)
				event_list.append({"type": "block", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id, "armor": recipient.block_armor,
					"damage_bonus_percent": recipient.block_attack_bonus_percent})
			AbilityEffectDefinition.Kind.HEAL:
				var healed: int = recipient.restore_health(effect.amount)
				event_list.append({"type": "heal", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id, "healed": healed})
			AbilityEffectDefinition.Kind.APPLY_STATUS:
				recipient.statuses[effect.status_id] = {"amount": effect.amount, "ticks": effect.duration_ticks}
				event_list.append({"type": "status_applied", "actor_id": actor_id,
					"target_id": recipient.participant_id, "ability_id": ability_id, "status_id": effect.status_id,
					"duration_ticks": effect.duration_ticks})
			AbilityEffectDefinition.Kind.REMOVE_STATUS:
				var removed: bool = recipient.statuses.has(effect.status_id)
				recipient.statuses.erase(effect.status_id)
				event_list.append({"type": "status_removed", "actor_id": actor_id,
					"target_id": recipient.participant_id, "ability_id": ability_id, "status_id": effect.status_id,
					"removed": removed})
			AbilityEffectDefinition.Kind.WAIT:
				event_list.append({"type": "wait", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id})
	state.events.append_array(event_list)
	state.update_outcome()
	return {"success": true, "reason": "", "events": event_list}


## Общая формула для движка и подсказок. Урон приёма = урон
## подходящего оружия + (Сила или Ловкость) / 2 + мощность эффекта.
## Бонус блока считается от суммы, дроби обрезаются один раз в самом конце.
static func preview_damage(actor: BattleParticipant, ability: AbilityDefinition, effect: AbilityEffectDefinition) -> int:
	if actor == null or ability == null or effect == null or effect.kind != AbilityEffectDefinition.Kind.DAMAGE:
		return 0
	var equipment_and_stat: float = 0.0
	match ability.damage_delivery:
		AbilityDefinition.DamageDelivery.MELEE:
			equipment_and_stat = actor.melee_attack_value()
		AbilityDefinition.DamageDelivery.RANGED:
			equipment_and_stat = actor.ranged_attack_value()
		# Для магии пока нет характеристики, применяем только мощность эффекта.
	var base: float = equipment_and_stat + float(effect.amount)
	return floori(maxf(base * float(100 + actor.block_attack_bonus_percent) / 100.0, 0.0))


static func apply_damage(actor: BattleParticipant, target: BattleParticipant, amount: int, ability_id: String = "") -> Dictionary:
	var raw: int = maxi(amount, 0)
	# Статусы задают изменения чисел общими эффектами, а не отдельной логикой монстров.
	if actor.statuses.has("attack_down"):
		raw = maxi(raw - int(actor.statuses["attack_down"].get("amount", 0)), 0)
	var taken: int = target.receive_damage(raw)
	return {"type": "attack", "actor_id": actor.participant_id, "target_id": target.participant_id,
		"ability_id": ability_id, "damage": taken, "blocked": maxi(raw - taken, 0),
		"shield_blocked": target.last_shield_blocked, "block_absorbed": target.last_block_absorbed,
		"shield_broken": target.last_shield_broken}


static func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason, "events": []}
