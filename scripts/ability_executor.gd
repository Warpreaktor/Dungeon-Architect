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
	var last_hit: Dictionary = {}
	for effect in ability.effects:
		var recipient: BattleParticipant = actor if effect.recipient == AbilityEffectDefinition.Recipient.SELF else target
		if recipient == null:
			return _failure("Нет цели эффекта")
		match effect.kind:
			AbilityEffectDefinition.Kind.DAMAGE:
				var raw_damage: int = preview_damage(actor, ability, effect, recipient)
				# Атака опускает собственный поднятый блок, но не меняет
				# уклонение: оно тратится только при входящей атаке.
				actor.block_armor = 0
				actor.block_attack_bonus_percent = 0
				for hit_index in range(effect.hit_count):
					last_hit = apply_damage(actor, recipient, raw_damage, ability_id, state.rng)
					last_hit["hit_index"] = hit_index
					last_hit["hit_count"] = effect.hit_count
					event_list.append(last_hit)
					if not recipient.is_alive():
						break
			AbilityEffectDefinition.Kind.BLOCK:
				recipient.prepare_block(effect.amount)
				event_list.append({"type": "block", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id, "armor": recipient.block_armor,
					"damage_bonus_percent": recipient.block_attack_bonus_percent,
					"hp_after": recipient.health, "hp_max": recipient.max_health})
			AbilityEffectDefinition.Kind.HEAL:
				var healed: int = recipient.restore_health(effect.amount)
				event_list.append({"type": "heal", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id, "healed": healed,
					"hp_after": recipient.health, "hp_max": recipient.max_health})
			AbilityEffectDefinition.Kind.APPLY_STATUS:
				if not recipient.is_alive():
					continue
				if effect.requires_unblocked_hit and (last_hit.is_empty() or bool(last_hit.get("dodged", false)) or bool(last_hit.get("was_blocking", false))):
					continue
				recipient.apply_status(effect, state.flow.completed_ticks + 1)
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
static func preview_damage(actor: BattleParticipant, ability: AbilityDefinition, effect: AbilityEffectDefinition, target: BattleParticipant = null, slot_index: int = -1) -> int:
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
	var multiplier: float = effect.damage_multiplier
	if effect.first_slot_multiplier > 0.0:
		# В редакторе раскладки пользуемся позицией предпросмотра.
		# В ходе исполнения курсор уже сдвинут на следующий слот.
		var first_in_draft: bool = slot_index == 0
		var first_in_execution: bool = slot_index < 0 and actor.action_cursor == 1 \
			and not actor.action_chain.is_empty() and actor.action_chain[0] == ability.ability_id
		if first_in_draft or first_in_execution:
			multiplier = effect.first_slot_multiplier
	if target != null:
		if target.block_armor > 0 and effect.vs_block_multiplier > 0.0:
			multiplier = effect.vs_block_multiplier
		elif target.is_resting and effect.vs_rest_multiplier > 0.0:
			multiplier = effect.vs_rest_multiplier
	return floori(maxf(base * (multiplier + float(actor.block_attack_bonus_percent) / 100.0), 0.0))


static func apply_damage(actor: BattleParticipant, target: BattleParticipant, amount: int, ability_id: String = "", rng: RandomNumberGenerator = null) -> Dictionary:
	var raw: int = maxi(amount, 0)
	# Статусы задают изменения чисел общими эффектами, а не отдельной логикой монстров.
	if actor.statuses.has("attack_down"):
		raw = maxi(raw - int(actor.statuses["attack_down"].get("amount", 0)), 0)
	# Снимок делаем непосредственно в момент удара. В конце фазы HP и
	# прочность уже могут быть другими после следующих действий.
	var shield_before: String = target.equipped_shield_id
	var was_blocking: bool = target.block_armor > 0
	var dodge_percent: int = clampi(target.base_dodge_percent + target.status_modifier(AbilityEffectDefinition.Stat.DODGE_PERCENT), 0, 100)
	var dodged: bool = rng != null and dodge_percent > 0 and rng.randf() < float(dodge_percent) / 100.0
	# Even an avoided attack spends 'next incoming attack' dodge bonuses.
	target.advance_status_clock(AbilityEffectDefinition.Clock.INCOMING_ATTACK)
	var taken: int = 0 if dodged else target.receive_damage(raw)
	var shield_durability_after: int = -1
	if not shield_before.is_empty() and target._hero_snapshot != null:
		shield_durability_after = target._hero_snapshot.current_shield_durability(shield_before)
	return {"type": "attack", "actor_id": actor.participant_id, "target_id": target.participant_id,
		"ability_id": ability_id, "raw_damage": raw, "damage": taken,
		"dodged": dodged, "was_blocking": was_blocking,
		"blocked": 0 if dodged else maxi(raw - taken, 0), "hp_after": target.health,
		"hp_max": target.max_health, "armor_after": target.defense,
		"active_block_after": target.block_armor,
		"shield_durability_after": shield_durability_after,
		"shield_blocked": target.last_shield_blocked, "block_absorbed": target.last_block_absorbed,
		"shield_broken": target.last_shield_broken}


static func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason, "events": []}
