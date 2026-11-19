class_name BattleAbilityTooltip
extends RefCounted

## Текст подсказок собирается из реальных данных способности и участника.
## Показываем правила и параметры способности, но не прогноз урона.
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
				lines.append("Защищает от следующего попадания; сила блока зависит от щита")
				lines.append("+25%% базового урона к следующей атаке за каждый блок (через фазы)")
			AbilityEffectDefinition.Kind.HEAL:
				lines.append("Лечение: %d HP (не выше максимума)" % maxi(effect.amount, 0))
			AbilityEffectDefinition.Kind.APPLY_STATUS:
				if effect.tick_damage > 0:
					lines.append("Кровотечение: −%d HP за отдых цели, %d фазы" % [effect.tick_damage, effect.duration_ticks])
				elif effect.effective_status_stat() == AbilityEffectDefinition.Stat.ACCURACY:
					lines.append("Меткость цели: %d%% на %d фазы" % [effect.effective_status_modifier(), effect.duration_ticks])
				elif effect.effective_status_stat() == AbilityEffectDefinition.Stat.DODGE_PERCENT:
					lines.append("Уклонение: %+d%% до следующей входящей атаки" % effect.effective_status_modifier())
				else:
					lines.append("Эффект «%s»: %d на %d ед. времени" % [effect.status_id, effect.effective_status_modifier(), effect.duration_ticks])
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
