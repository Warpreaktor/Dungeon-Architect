class_name AbilityExecutor
extends RefCounted

## Расчёт действия не зависит от сцены, а состояние и события принадлежат вызывающему бою.


static func execute(context: BattleContext, actor_id: String, target_id: String, ability_id: String) -> Dictionary:
	return execute_definition(context, actor_id, target_id, AbilityCatalog.get_ability(ability_id))


## Исполняет определение способности с проверкой владения и правил выбора цели.
static func execute_definition(context: BattleContext, actor_id: String, target_id: String, ability: AbilityDefinition) -> Dictionary:
	var actor: BattleParticipant = context.get_participant(actor_id)
	var target: BattleParticipant = context.get_participant(target_id)
	var ability_id: String = ability.ability_id if ability != null else ""
	if actor == null or not actor.is_alive():
		return _failure("Участник недоступен")
	if ability == null:
		return _failure("Неизвестный приём")
	if not (ability_id in actor.personal_ability_ids
			or ability_id in actor.learned_ability_ids
			or AbilityCatalog.knows_ability(actor, ability_id)):
		return _failure("Приём не изучен")
	var ability_problem: String = ability.validation_error()
	if ability_problem.is_empty():
		ability_problem = ability.unavailable_reason(actor)
	if not ability_problem.is_empty():
		return _failure(ability_problem)
	var targeting_error: String = context.target_error(actor_id, target_id, ability)
	if not targeting_error.is_empty():
		return _failure(targeting_error)
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
	var stance_counter_used: bool = false
	for effect in ability.effects:
		var recipient: BattleParticipant = actor if effect.recipient == AbilityEffectDefinition.Recipient.SELF else target
		if recipient == null:
			return _failure("Нет цели эффекта")
		match effect.kind:
			AbilityEffectDefinition.Kind.DAMAGE:
				var raw_damage: int = preview_damage(actor, ability, effect, recipient)
				# Атака опускает собственный поднятый блок, но не меняет
				# уклонение: оно тратится только при входящей атаке.
				if actor.block_armor > 0:
					event_list.append({"type": "block_consumed", "actor_id": actor_id,
						"target_id": actor_id, "ability_id": ability_id, "armor": 0})
				actor.block_armor = 0
				actor.block_attack_bonus_percent = 0
				for hit_index in range(effect.hit_count):
					var original_target: BattleParticipant = target if effect.recipient == AbilityEffectDefinition.Recipient.TARGET else actor
					recipient = original_target
					var protector_id: String = str(context.redirects.get(recipient.participant_id, ""))
					var protector: BattleParticipant = context.get_participant(protector_id) if not protector_id.is_empty() else null
					if protector != null and protector.is_alive():
						context.redirects.erase(original_target.participant_id)
						recipient = protector
						event_list.append({"type": "attack_intercepted", "actor_id": protector.participant_id,
							"target_id": original_target.participant_id, "ability_id": ability_id})
					var accuracy_offset: int = effect.accuracy_offset_percent
					if actor_id == context.focused_attacker_id and original_target.participant_id == context.focused_target_id:
						accuracy_offset += context.focused_accuracy_bonus
					var saved_block: int = recipient.block_armor if protector != null and recipient == protector else 0
					if protector != null and recipient == protector:
						recipient.block_armor = 0
					last_hit = apply_damage(actor, recipient, raw_damage, ability_id, context.rng,
						effect.armor_pierce_fraction, accuracy_offset)
					if protector != null and recipient == protector:
						recipient.block_armor = saved_block
					last_hit["hit_index"] = hit_index
					last_hit["hit_count"] = effect.hit_count
					event_list.append(last_hit)
					if not stance_counter_used and recipient.is_alive() and actor.is_alive() and recipient != actor:
						for status in recipient.statuses.values():
							var retaliation_multiplier: float = float(status.get("counter_damage_multiplier", 0.0))
							if retaliation_multiplier > 0.0:
								stance_counter_used = true
								var retaliation: Dictionary = apply_damage(recipient, actor,
									floori(recipient.melee_attack_value() * retaliation_multiplier),
									str(status.get("counter_ability_id", "")), context.rng)
								retaliation["type"] = "counter"
								event_list.append(retaliation)
								break
					if protector != null and recipient == protector and protector.is_alive() and actor.is_alive() and context.counter_multiplier > 0.0:
						var counter_damage: int = floori(protector.melee_attack_value() * context.counter_multiplier)
						event_list.append(apply_damage(protector, actor, counter_damage, context.counter_ability_id, context.rng))
					if not recipient.is_alive():
						break
			AbilityEffectDefinition.Kind.BLOCK:
				recipient.prepare_block(effect.amount)
				event_list.append({"type": "block", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id, "armor": recipient.block_armor,
					"damage_bonus_percent": recipient.block_attack_bonus_percent,
					"hp_after": recipient.health, "hp_max": recipient.max_health})
			AbilityEffectDefinition.Kind.HEAL:
				var healed: int = 0
				if effect.heal_if_health_at_most_percent == 0 or (recipient.health * BattleMath.PERCENT_SCALE <= recipient.max_health * effect.heal_if_health_at_most_percent):
					healed = recipient.restore_health(maxi(effect.amount, ceili(float(recipient.max_health) * float(effect.heal_percent_max) / float(BattleMath.PERCENT_SCALE))))
				event_list.append({"type": "heal", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id, "healed": healed,
					"hp_after": recipient.health, "hp_max": recipient.max_health})
			AbilityEffectDefinition.Kind.APPLY_STATUS:
				if not recipient.is_alive():
					continue
				if effect.requires_health_damage and int(last_hit.get("damage", 0)) <= 0:
					continue
				if effect.requires_hit and (last_hit.is_empty() or bool(last_hit.get("dodged", false))):
					continue
				if effect.requires_unblocked_hit and (last_hit.is_empty() or bool(last_hit.get("dodged", false)) or bool(last_hit.get("was_blocking", false))):
					continue
				var before_health: int = recipient.health
				var before_max_health: int = recipient.max_health
				var previous_status: Dictionary = recipient.statuses.get(effect.status_id, {})
				var before_stacks: int = int(previous_status.get("stacks", 0))
				recipient.apply_status(effect, context.current_tick)
				var current_status: Dictionary = recipient.statuses.get(effect.status_id, {})
				if effect.max_health_reduction_percent > 0 and int(current_status.get("stacks", 0)) == before_stacks:
					continue
				event_list.append({"type": "status_applied", "actor_id": actor_id,
					"target_id": recipient.participant_id, "ability_id": ability_id, "status_id": effect.status_id,
					"duration_ticks": effect.duration_ticks, "hp_after": recipient.health, "hp_max": recipient.max_health,
					"dodge_after": recipient.dodge_percent(),
					"effective_dodge_after": recipient.dodge_chance_against(
						context.opponent_for(recipient.participant_id)),
					"accuracy_after": recipient.accuracy_percent()})
				if recipient.max_health != before_max_health:
					event_list.append({"type": "hp_limit_changed", "actor_id": actor_id,
						"target_id": recipient.participant_id, "status_id": effect.status_id,
						"hp_after": recipient.health, "hp_max": recipient.max_health,
						"hp_difference": recipient.health - before_health})
				# Если цель уже отдыхала ранее в этом же такте, кровь тоже
				# должна снять HP за эту фазу. Другой порядок покрыт BattleState.
				if effect.tick_damage > 0 and recipient.last_rest_tick == context.current_tick:
					var instant: Array[Dictionary] = recipient.owner_phase_status_damage_events(recipient.participant_id)
					event_list.append_array(instant)
					var expired: Array[String] = recipient.advance_status_clock(AbilityEffectDefinition.Clock.OWNER_PHASE, context.current_tick)
					for expired_id in expired:
						event_list.append({"type": "status_removed", "actor_id": recipient.participant_id,
							"target_id": recipient.participant_id, "status_id": expired_id, "removed": true})
			AbilityEffectDefinition.Kind.REMOVE_STATUS:
				var before_health: int = recipient.health
				var before_max_health: int = recipient.max_health
				var removed: bool = recipient.remove_status(effect.status_id)
				event_list.append({"type": "status_removed", "actor_id": actor_id,
					"target_id": recipient.participant_id, "ability_id": ability_id, "status_id": effect.status_id,
					"removed": removed})
				if recipient.max_health != before_max_health:
					event_list.append({"type": "hp_limit_changed", "actor_id": actor_id,
						"target_id": recipient.participant_id, "hp_after": recipient.health,
						"hp_max": recipient.max_health, "hp_difference": recipient.health - before_health})
			AbilityEffectDefinition.Kind.WAIT:
				event_list.append({"type": "wait", "actor_id": actor_id, "target_id": recipient.participant_id,
					"ability_id": ability_id})
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
	var multiplier: float = effect.effective_damage_multiplier()
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
	var total: float = maxf(base * (multiplier + float(actor.block_attack_bonus_percent) / float(BattleMath.PERCENT_SCALE)), 0.0)
	if target != null and effect.bonus_vs_damaged_armor_percent > 0 and target.has_damaged_armor():
		total *= 1.0 + float(effect.bonus_vs_damaged_armor_percent) / float(BattleMath.PERCENT_SCALE)
	return maxi(floori(total) + actor.status_modifier(AbilityEffectDefinition.Stat.ATTACK_POWER), 0)


static func apply_damage(actor: BattleParticipant, target: BattleParticipant, amount: int, ability_id: String = "", rng: RandomNumberGenerator = null, armor_pierce_fraction: float = 0.0, accuracy_offset_percent: int = 0) -> Dictionary:
	var raw: int = maxi(amount, 0)
	# Снимок делаем непосредственно в момент удара. В конце фазы HP и
	# прочность уже могут быть другими после следующих действий.
	var shield_before: String = target.equipped_shield_id
	var was_blocking: bool = target.block_armor > 0
	var dodge_percent: int = clampi(target.dodge_chance_against(actor) - accuracy_offset_percent, 0, BattleMath.PERCENT_SCALE)
	var dodged: bool = rng != null and dodge_percent > 0 and rng.randf() < float(dodge_percent) / float(BattleMath.PERCENT_SCALE)
	# Even an avoided attack spends 'next incoming attack' dodge bonuses.
	target.advance_status_clock(AbilityEffectDefinition.Clock.INCOMING_ATTACK)
	var taken: int = 0 if dodged else target.receive_damage(raw, armor_pierce_fraction)
	var shield_durability_after: int = target.shield_durability(shield_before)
	return {"type": "attack", "actor_id": actor.participant_id, "target_id": target.participant_id,
		"ability_id": ability_id, "raw_damage": raw, "damage": taken,
		"dodged": dodged, "dodge_chance": dodge_percent,
		"attacker_accuracy": actor.accuracy_percent(), "target_dodge": target.dodge_percent(),
		"dodge_after": target.dodge_percent(),
		"effective_dodge_after": target.dodge_chance_against(actor),
		"accuracy_after": target.accuracy_percent(),
		"was_blocking": was_blocking,
		"blocked": 0 if dodged else maxi(raw - taken, 0), "hp_after": target.health,
		"hp_max": target.max_health, "armor_after": target.defense,
		"active_block_after": target.block_armor,
		"shield_durability_after": shield_durability_after,
		"shield_blocked": target.last_shield_blocked, "block_absorbed": target.last_block_absorbed,
		"shield_broken": target.last_shield_broken}


static func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason, "events": []}
