class_name BattleAbilityTooltip
extends RefCounted

## Текст подсказок собирается из реальных данных способности и участника.
## Показываем правила и параметры способности, но не прогноз урона.
static func describe(ability: AbilityDefinition, participant: BattleParticipant = null, slot_index: int = -1) -> String:
	if ability == null:
		return ""
	var lines: Array[String] = [ability.display_name]
	var description: String = ability.get_description().strip_edges()
	if not description.is_empty():
		lines.append(description)
	if ability.passive:
		return "\n".join(lines)
	match ability.target:
		AbilityDefinition.Target.SELF:
			lines.append("Цель: на себя")
		AbilityDefinition.Target.ENEMY:
			lines.append("Цель: противник")
		AbilityDefinition.Target.ALLY:
			lines.append("Цель: союзник")
	for effect in ability.effects:
		match effect.kind:
			AbilityEffectDefinition.Kind.DAMAGE:
				var type_name: String = "ближняя" if ability.damage_delivery == AbilityDefinition.DamageDelivery.MELEE else ("дальняя" if ability.damage_delivery == AbilityDefinition.DamageDelivery.RANGED else "магическая")
				lines.append("Атака: %s" % type_name)
				if participant != null:
					var damage: int = AbilityExecutor.preview_damage(participant, ability, effect, null, slot_index)
					lines.append("Урон: %d" % damage)
				if effect.bonus_vs_damaged_armor_percent > 0:
					lines.append("Усиление против повреждённой брони")
				if effect.hit_count > 1:
					lines.append("Ударов: %d" % effect.hit_count)
			AbilityEffectDefinition.Kind.BLOCK:
				if participant != null and participant.fury_rules != null:
					lines.append("Блок: %d" % participant.preview_block_armor(effect.amount))
				else:
					lines.append("Защищает от следующего попадания или до собственной атаки; сила блока зависит от щита")
				lines.append("После атакующего приёма блок пропадает")
				lines.append("+%d%% базового урона к следующей атаке за каждый блок (через фазы)" % BattleMath.RULES.block_attack_bonus_percent)
			AbilityEffectDefinition.Kind.HEAL:
				if effect.heal_percent_max > 0:
					lines.append("Лечение: %d%% максимального HP цели" % effect.heal_percent_max)
				else:
					lines.append("Лечение: %d HP (не выше максимума)" % maxi(effect.amount, 0))
				if effect.heal_if_health_at_most_percent > 0:
					lines.append("При HP не выше %d%%" % effect.heal_if_health_at_most_percent)
			AbilityEffectDefinition.Kind.APPLY_STATUS:
				if effect.max_health_reduction_percent > 0:
					lines.append("Максимум HP: −%d%% за стек; максимум стеков: %d; %s" % [effect.max_health_reduction_percent, effect.max_stacks, effect.status_duration_description()])
				elif effect.tick_damage > 0:
					lines.append("Кровотечение: −%d HP, %s" % [effect.tick_damage, effect.status_duration_description()])
				elif effect.effective_status_stat() == AbilityEffectDefinition.Stat.ACCURACY:
					lines.append("Меткость цели: %+d п.п. %s" % [effect.effective_status_modifier(), effect.status_duration_description()])
				elif effect.effective_status_stat() == AbilityEffectDefinition.Stat.DODGE_PERCENT:
					lines.append("Уклонение: %+d п.п. %s" % [effect.effective_status_modifier(), effect.status_duration_description()])
				elif effect.effective_status_stat() == AbilityEffectDefinition.Stat.ATTACK_POWER:
					lines.append("Мощность атак: %+d %s" % [effect.effective_status_modifier(), effect.status_duration_description()])
				elif effect.effective_status_stat() == AbilityEffectDefinition.Stat.MELEE_DODGE_PERCENT:
					lines.append("Уклонение от ближней атаки: %+d п.п. %s" % [effect.effective_status_modifier(), effect.status_duration_description()])
				elif effect.effective_status_stat() == AbilityEffectDefinition.Stat.ARMOR_PIERCE_PERCENT:
					lines.append("Пробитие брони и блока: %d%% %s" % [effect.effective_status_modifier(), effect.status_duration_description()])
				elif effect.effective_status_stat() == AbilityEffectDefinition.Stat.AGILITY:
					lines.append("Ловкость: %+d %s" % [effect.effective_status_modifier(), effect.status_duration_description()])
				else:
					lines.append("Эффект «%s»: %d %s" % [effect.status_id, effect.effective_status_modifier(), effect.status_duration_description()])
				if effect.incoming_damage_reduction_percent > 0:
					lines.append("Снижение входящего урона: %d%%" % effect.incoming_damage_reduction_percent)
				if effect.armor_penalty > 0:
					lines.append("Броня: −%d %s" % [effect.armor_penalty, effect.status_duration_description()])
			AbilityEffectDefinition.Kind.REMOVE_STATUS:
				lines.append("Снимает эффект «%s»" % effect.status_id)
			AbilityEffectDefinition.Kind.WAIT:
				if description.is_empty():
					lines.append("Пропуск действия")
	for requirement in ability.requirements:
		match requirement.kind:
			AbilityRequirementDefinition.Kind.WEAPON:
				lines.append("Требуется оружие")
			AbilityRequirementDefinition.Kind.SHIELD:
				lines.append("Требуется щит")
			AbilityRequirementDefinition.Kind.TWO_HANDED_WEAPON:
				lines.append("Требуется двуручное оружие")
			AbilityRequirementDefinition.Kind.HEALTH_AT_LEAST_PERCENT:
				lines.append("Требуется минимум %d%% HP" % requirement.min_health_percent)
	if participant != null:
		var unavailable: String = ability.unavailable_reason(participant)
		if not unavailable.is_empty():
			lines.append("Недоступно: " + unavailable)
	for resource_id in ability.resource_costs:
		lines.append("Стоимость: %d × %s" % [int(ability.resource_costs[resource_id]), resource_id])
	return "\n".join(lines)
