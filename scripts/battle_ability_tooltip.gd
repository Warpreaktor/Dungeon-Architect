class_name BattleAbilityTooltip
extends RefCounted

## Текст подсказок собирается из реальных данных способности и участника.
## Урон показан до защиты цели, с текущим бонусом блока атакующего.
static func describe(ability: AbilityDefinition, participant: BattleParticipant = null, slot_index: int = -1) -> String:
	if ability == null:
		return ""
	var lines: Array[String] = [ability.display_name]
	if not ability.description.strip_edges().is_empty():
		lines.append(ability.description.strip_edges())
	lines.append("Цель: противник" if ability.target == AbilityDefinition.Target.ENEMY else "Цель: на себя")
	for effect in ability.effects:
		match effect.kind:
			AbilityEffectDefinition.Kind.DAMAGE:
				if effect.hit_count > 1:
					lines.append("Попаданий: %d" % effect.hit_count)
				var type_name: String = "ближний" if ability.damage_delivery == AbilityDefinition.DamageDelivery.MELEE else ("дальний" if ability.damage_delivery == AbilityDefinition.DamageDelivery.RANGED else "магический")
				if participant != null:
					var hit_damage: int = AbilityExecutor.preview_damage(participant, ability, effect, null, slot_index)
					if effect.hit_count > 1:
						lines.append("Урон: %d × %d удара (%s, до защиты)" % [hit_damage, effect.hit_count, type_name])
					else:
						lines.append("Урон: %d (%s, до защиты)" % [hit_damage, type_name])
				else:
					lines.append("Мощность приёма: %d (%s) + оружие и характеристика" % [effect.amount, type_name])
			AbilityEffectDefinition.Kind.BLOCK:
				var block: int = maxi(BattleParticipant.BASE_BLOCK_ARMOR, effect.amount)
				if participant != null:
					block = participant.preview_block_armor(block)
				lines.append("Броня блока: %d (на одно попадание)" % block)
				lines.append("+25%% базового урона к следующей атаке за каждый блок (через фазы)")
			AbilityEffectDefinition.Kind.HEAL:
				lines.append("Лечение: %d HP (не выше максимума)" % maxi(effect.amount, 0))
			AbilityEffectDefinition.Kind.APPLY_STATUS:
				lines.append("Эффект «%s»: %d на %d ед. времени" % [effect.status_id, effect.status_modifier, effect.duration_ticks])
			AbilityEffectDefinition.Kind.REMOVE_STATUS:
				lines.append("Снимает эффект «%s»" % effect.status_id)
			AbilityEffectDefinition.Kind.WAIT:
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
