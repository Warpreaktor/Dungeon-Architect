class_name BattleAttributeTooltip
extends RefCounted


static func strength_description() -> String:
	return "Сила: +%s урона ближнего боя за очко" % DescriptionTemplate.number(BattleMath.RULES.melee_strength_factor)


static func agility_description() -> String:
	return "Ловкость: +%s урона дальнего боя за очко" % DescriptionTemplate.number(BattleMath.RULES.ranged_agility_factor)


static func accuracy_description() -> String:
	var per_point: int = BattleMath.accuracy_total(1, 0, 0) - BattleMath.accuracy_total(0, 0, 0)
	return "Меткость: +%d п.п. за каждое очко Ловкости" % per_point
