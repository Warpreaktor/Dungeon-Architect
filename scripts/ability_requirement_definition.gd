class_name AbilityRequirementDefinition
extends Resource

## Требования для формирования алгоритма. Расход ресурсов проверит DA-4.08.
enum Kind { WEAPON, SHIELD, TWO_HANDED_WEAPON, HEALTH_AT_LEAST_PERCENT }

@export var kind: Kind = Kind.WEAPON
@export_range(1, 100, 1) var min_health_percent: int = 1


func validation_error() -> String:
	if kind == Kind.HEALTH_AT_LEAST_PERCENT and (min_health_percent < 1 or min_health_percent > 100):
		return "Процент здоровья должен быть от 1 до 100"
	return ""


func is_met(participant: BattleParticipant) -> bool:
	if participant == null or not participant.is_alive():
		return false
	match kind:
		Kind.WEAPON:
			return not participant.equipped_weapon_id.is_empty()
		Kind.SHIELD:
			return not participant.equipped_shield_id.is_empty()
		Kind.TWO_HANDED_WEAPON:
			var weapon: ItemDefinition = ItemCatalog.get_item(participant.equipped_weapon_id)
			return weapon != null and weapon.two_handed
		Kind.HEALTH_AT_LEAST_PERCENT:
			return participant.max_health > 0 and participant.health * 100 >= participant.max_health * min_health_percent
	return false
