class_name AbilityRequirementDefinition
extends Resource

## Набор условий доступности приёма для участника.
enum Kind { WEAPON, SHIELD, TWO_HANDED_WEAPON, HEALTH_AT_LEAST_PERCENT, EQUIPPED_WEAPON_ID }

@export var kind: Kind = Kind.WEAPON
@export_range(1, 100, 1) var min_health_percent: int = 1
@export var required_weapon_id: String = ""


func validation_error() -> String:
	if kind < Kind.WEAPON or kind > Kind.EQUIPPED_WEAPON_ID:
		return "Неизвестное требование"
	if kind == Kind.HEALTH_AT_LEAST_PERCENT and (min_health_percent < 1 or min_health_percent > 100):
		return "Процент здоровья должен быть от 1 до 100"
	if kind == Kind.EQUIPPED_WEAPON_ID and required_weapon_id.is_empty():
		return "Не указан ID оружия"
	return ""


func is_met(participant: BattleParticipant) -> bool:
	if participant == null or not participant.is_alive():
		return false
	match kind:
		Kind.WEAPON:
			return not participant.equipped_weapon_id.is_empty()
		Kind.SHIELD:
			return not participant.equipped_shield_id.is_empty() and (participant._hero_snapshot == null or
				participant._hero_snapshot.current_shield_durability(participant.equipped_shield_id) > 0)
		Kind.TWO_HANDED_WEAPON:
			var weapon: ItemDefinition = ItemCatalog.get_item(participant.equipped_weapon_id)
			return weapon != null and weapon.two_handed
		Kind.EQUIPPED_WEAPON_ID:
			return participant.equipped_weapon_id == required_weapon_id
		Kind.HEALTH_AT_LEAST_PERCENT:
			return participant.max_health > 0 and participant.health * BattleMath.PERCENT_SCALE >= participant.max_health * min_health_percent
	return false


func failure_reason() -> String:
	match kind:
		Kind.WEAPON:
			return "Нужно оружие"
		Kind.SHIELD:
			return "Нужен целый экипированный щит"
		Kind.TWO_HANDED_WEAPON:
			return "Нужно двуручное оружие"
		Kind.HEALTH_AT_LEAST_PERCENT:
			return "Нужно минимум %d%% HP" % min_health_percent
		Kind.EQUIPPED_WEAPON_ID:
			return "Нужно подходящее оружие"
	return "Требование не выполнено"
