class_name MonsterIntermissionAction
extends Resource

@export var action_id: String = ""
@export var ability_id: String = ""
@export var priority: int = 0
@export_range(0, 100, 1) var maximum_health_percent: int = 100
@export_range(0, 100, 1) var minimum_health_percent: int = 0
@export_range(0, 100, 1) var chance_percent: int = 100
@export_range(0, 1000, 1) var max_uses_per_battle: int = 1


func identity() -> String:
	return action_id if not action_id.is_empty() else ability_id


func accepts(participant, uses: int) -> bool:
	if participant == null or not participant.is_alive() or participant.max_health <= 0:
		return false
	if max_uses_per_battle > 0 and uses >= max_uses_per_battle:
		return false
	var ratio: float = float(participant.health) * BattleMath.PERCENT_SCALE / float(participant.max_health)
	if ratio < float(minimum_health_percent) or ratio > float(maximum_health_percent):
		return false
	return not ability_id.is_empty()
