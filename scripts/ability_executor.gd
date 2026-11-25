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
	var energy_before_cast: int = actor.current_energy() + int(ability.resource_costs.get("energy", 0))
	if ability.cooldown_turns > 0:
		actor.energy_cooldowns[ability_id] = ability.cooldown_turns + 1
	if ability.affects_all_enemies:
		event_list.append_array(EnergyAbilityResolver.resolve_area(context, actor, ability, energy_before_cast))
		_finish_action(context, actor, ability, event_list)
		return {"success": true, "reason": "", "events": event_list}
	var last_hit: Dictionary = {}
	var damaged_targets: Dictionary = {}
	var resonance_triggered: bool = false
	var stance_counter_used: bool = false
	for effect in ability.effects:
		var recipient: BattleParticipant = actor if effect.recipient == AbilityEffectDefinition.Recipient.SELF else target
		if recipient == null:
			return _failure("Нет цели эффекта")
		match effect.kind:
			AbilityEffectDefinition.Kind.DAMAGE:
				var hit_count: int = effect.fury_hit_count if actor.is_fury_unleashed() and effect.fury_hit_count > 0 else effect.hit_count
				var attack_targets: Array[String] = _attack_targets(context, actor, recipient, ability, effect, hit_count)
				var raw_by_target: Dictionary = {}
				var damage_target_ids: Array[String] = context.target_ids(actor_id, ability) if effect.repeat_targets else attack_targets
				for id in damage_target_ids:
					if not raw_by_target.has(id):
						raw_by_target[id] = preview_damage(actor, ability, effect, context.get_participant(id), -1, energy_before_cast)
				# Атака опускает собственный поднятый блок, но не меняет
				# уклонение: оно тратится только при входящей атаке.
				if actor.block_armor > 0:
					event_list.append({"type": "block_consumed", "actor_id": actor_id,
						"target_id": actor_id, "ability_id": ability_id, "armor": 0})
				actor.block_armor = 0
				actor.block_attack_bonus_percent = 0
				actor.fury_guard_armed = false
				for hit_index in range(attack_targets.size()):
					if not actor.is_alive():
						break
					var original_target: BattleParticipant = context.get_participant(attack_targets[hit_index])
					if original_target == null or not original_target.is_alive():
						if not effect.repeat_targets:
							continue
						var living: Array[String] = context.target_ids(actor_id, ability)
						if living.is_empty():
							break
						original_target = context.get_participant(living[context.rng.randi_range(0, living.size() - 1)] if context.rng != null else living[0])
					recipient = original_target
					var raw_damage: int = int(raw_by_target.get(original_target.participant_id, 0))
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
					last_hit["hit_count"] = attack_targets.size()
					event_list.append(last_hit)
					if int(last_hit.get("hp_damage", 0)) > 0:
						damaged_targets[recipient.participant_id] = true
					if not resonance_triggered and not bool(last_hit.get("dodged", false)):
						var resonance: Dictionary = EnergyAbilityResolver.on_hit(actor, recipient)
						if not resonance.is_empty():
							resonance_triggered = true
							event_list.append(resonance)
					if not effect.target_status_id.is_empty() and effect.consume_target_status_on_hit and not bool(last_hit.get("dodged", false)):
						if recipient.remove_status(effect.target_status_id):
							event_list.append({"type": "status_removed", "actor_id": actor_id,
								"target_id": recipient.participant_id, "status_id": effect.target_status_id, "removed": true})
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
					if not recipient.is_alive() and effect.distinct_targets == 0:
						break
			AbilityEffectDefinition.Kind.BLOCK:
				var cleared: Array[String] = []
				for status_id in recipient.statuses:
					if int((recipient.statuses[status_id] as Dictionary).get("next_block_penalty", 0)) > 0:
						cleared.append(str(status_id))
				recipient.prepare_block(effect.amount)
				recipient.fury_guard_armed = ability.arms_fury_guard and recipient.fury_rules != null
				for status_id in cleared:
					event_list.append({"type": "status_removed", "actor_id": actor_id,
							"target_id": recipient.participant_id, "status_id": status_id, "removed": true})
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
				if effect.requires_any_health_damage and not damaged_targets.has(recipient.participant_id):
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
			_:
				event_list.append_array(EnergyAbilityResolver.resolve(context, actor, recipient, ability, effect, energy_before_cast))
	_finish_action(context, actor, ability, event_list)
	return {"success": true, "reason": "", "events": event_list}


## Общая формула для движка и подсказок. Урон приёма = урон
## подходящего оружия + (Сила или Ловкость) / 2 + мощность эффекта.
## Бонус блока считается от суммы, дроби обрезаются один раз в самом конце.
static func preview_damage(actor: BattleParticipant, ability: AbilityDefinition, effect: AbilityEffectDefinition, target: BattleParticipant = null, slot_index: int = -1, energy_before: int = -999999) -> int:
	if actor == null or ability == null or effect == null or effect.kind != AbilityEffectDefinition.Kind.DAMAGE:
		return 0
	var equipment_and_stat: float = 0.0
	match ability.damage_delivery:
		AbilityDefinition.DamageDelivery.MELEE:
			equipment_and_stat = actor.melee_attack_value(actor.team_id != "enemies" or MonsterWeaponStrike.is_weapon_strike(ability.ability_id))
		AbilityDefinition.DamageDelivery.RANGED:
			equipment_and_stat = actor.ranged_attack_value(actor.team_id != "enemies" or MonsterWeaponStrike.is_weapon_strike(ability.ability_id))
		# Для магии пока нет характеристики, применяем только мощность эффекта.
	var base: float = equipment_and_stat + float(effect.amount)
	if effect.energy_damage_factor > 0.0:
		var current: int = actor.current_energy() if energy_before == -999999 else energy_before
		base += minf(float(maxi(current, 0)) * effect.energy_damage_factor, float(effect.energy_damage_cap))
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
		if not effect.target_status_id.is_empty() and target.statuses.has(effect.target_status_id) and effect.vs_target_status_multiplier > 0.0:
			multiplier = effect.vs_target_status_multiplier
		if target.block_armor > 0 and effect.vs_block_multiplier > 0.0:
			multiplier = effect.vs_block_multiplier
		elif (target.is_resting or (effect.vs_recent_rest and target.last_round_action_was_rest)) and effect.vs_rest_multiplier > 0.0:
			multiplier = effect.vs_rest_multiplier
	if actor.is_fury_unleashed() and effect.fury_hit_multiplier > 0.0:
		multiplier = effect.fury_hit_multiplier
	var total: float = maxf(base * (multiplier + float(actor.block_attack_bonus_percent) / float(BattleMath.PERCENT_SCALE)), 0.0)
	if ability.damage_delivery == AbilityDefinition.DamageDelivery.MAGIC:
		total *= actor.energy_factor()
	if target != null and effect.bonus_vs_damaged_armor_percent > 0 and target.has_damaged_armor():
		total *= 1.0 + float(effect.bonus_vs_damaged_armor_percent) / float(BattleMath.PERCENT_SCALE)
	total += actor.status_modifier(AbilityEffectDefinition.Stat.ATTACK_POWER)
	if actor.is_fury_unleashed() and ability.damage_delivery != AbilityDefinition.DamageDelivery.MAGIC:
		total *= 1.0 + actor.fury_rules.physical_bonus
	return maxi(floori(total), 0)


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
	var hp_before: int = target.health
	var taken: int = 0 if dodged else target.receive_damage(raw, armor_pierce_fraction)
	var guard_triggered: bool = not dodged and target.fury_guard_armed
	if guard_triggered:
		target.fury_guard_armed = false
	var shield_durability_after: int = target.shield_durability(shield_before)
	return {"type": "attack", "actor_id": actor.participant_id, "target_id": target.participant_id,
		"ability_id": ability_id, "raw_damage": raw, "damage": taken,
		"hp_damage": maxi(hp_before - target.health, 0), "fury_guard_triggered": guard_triggered,
		"dodged": dodged, "dodge_chance": dodge_percent,
		"attacker_accuracy": actor.accuracy_percent(), "target_dodge": target.dodge_percent(),
		"dodge_after": target.dodge_percent(),
		"effective_dodge_after": target.dodge_chance_against(actor),
		"accuracy_after": target.accuracy_percent(),
		"was_blocking": was_blocking,
		"blocked": 0 if dodged else maxi(raw - taken, 0), "hp_after": target.health,
		"hp_max": target.max_health, "armor_after": target.effective_defense(),
		"active_block_after": target.block_armor,
		"shield_durability_after": shield_durability_after,
		"shield_blocked": target.last_shield_blocked, "block_absorbed": target.last_block_absorbed,
		"shield_broken": target.last_shield_broken}


static func _attack_targets(context: BattleContext, actor: BattleParticipant, target: BattleParticipant,
		ability: AbilityDefinition, effect: AbilityEffectDefinition, hit_count: int) -> Array[String]:
	var result: Array[String] = []
	if effect.distinct_targets <= 0:
		for _index in range(hit_count):
			result.append(target.participant_id)
		return result
	var remaining: Array[String] = context.target_ids(actor.participant_id, ability)
	remaining.erase(target.participant_id)
	result.append(target.participant_id)
	var unique_count: int = mini(effect.distinct_targets, hit_count) if effect.repeat_targets else effect.distinct_targets
	while result.size() < unique_count and not remaining.is_empty():
		var index: int = context.rng.randi_range(0, remaining.size() - 1) if context.rng != null and remaining.size() > 1 else 0
		result.append(remaining.pop_at(index))
	if effect.repeat_targets:
		var candidates: Array[String] = result.duplicate()
		while result.size() < hit_count:
			var index: int = context.rng.randi_range(0, candidates.size() - 1) if context.rng != null and candidates.size() > 1 else 0
			result.append(candidates[index])
	return result


static func _finish_action(context: BattleContext, actor: BattleParticipant, ability: AbilityDefinition,
		events: Array[Dictionary]) -> void:
	var health_damage: Dictionary = {}
	var guard_hits: Dictionary = {}
	var outgoing_hits: int = 0
	var all_missed: bool = true
	var all_blocked: bool = true
	var dealt: int = 0
	for event in events:
		if str(event.get("type", "")) not in ["attack", "counter"]:
			continue
		var target_id: String = str(event.get("target_id", ""))
		var hp_damage: int = int(event.get("hp_damage", 0))
		if hp_damage > 0:
			health_damage[target_id] = true
		if bool(event.get("fury_guard_triggered", false)):
			guard_hits[target_id] = true
		if str(event.get("actor_id", "")) != actor.participant_id or str(event.get("ability_id", "")) != ability.ability_id:
			continue
		outgoing_hits += 1
		dealt += hp_damage
		var missed: bool = bool(event.get("dodged", false))
		all_missed = all_missed and missed
		if not missed:
			all_blocked = all_blocked and hp_damage == 0 and int(event.get("block_absorbed", 0)) > 0
	for id in health_damage:
		var target: BattleParticipant = context.get_participant(str(id))
		if target != null and target.fury_rules != null:
			target.gain_fury(target.fury_rules.gain_on_health_damage)
	for id in guard_hits:
		var target: BattleParticipant = context.get_participant(str(id))
		if target != null and target.fury_rules != null:
			target.gain_fury(target.fury_rules.gain_on_guard_hit)
	if actor.fury_rules != null:
		if outgoing_hits > 0:
			if all_missed:
				actor.gain_fury(actor.fury_rules.gain_on_missed_action)
			elif all_blocked:
				actor.gain_fury(actor.fury_rules.gain_on_blocked_action)
		if ability.reset_fury_after_cast:
			actor.spend_fury(actor.fury())
		else:
			actor.spend_fury(ability.fury_spend_after_cast)
	if ability.damage_heal_ratio > 0.0 and dealt > 0 and actor.is_alive():
		var amount: int = mini(floori(float(dealt) * ability.damage_heal_ratio), ability.damage_heal_cap)
		var healed: int = actor.restore_health(amount)
		events.append({"type": "heal", "actor_id": actor.participant_id, "target_id": actor.participant_id,
			"ability_id": ability.ability_id, "healed": healed, "hp_after": actor.health, "hp_max": actor.max_health})


static func _failure(reason: String) -> Dictionary:
	return {"success": false, "reason": reason, "events": []}
