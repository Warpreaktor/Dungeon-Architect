class_name MonsterTacticProfile
extends Resource

@export var profile_id: String = ""
@export var priority: int = 0
@export_range(1, 1000, 1) var weight: int = 1
@export_range(0, 100, 1) var minimum_health_percent: int = 0
@export_range(0, 100, 1) var maximum_health_percent: int = 100
@export var card_ids: Array[String] = []
@export var shuffle_cards: bool = false


func accepts(participant) -> bool:
	if participant == null or not participant.is_alive() or card_ids.is_empty():
		return false
	if participant.max_health <= 0:
		return false
	var ratio: float = float(participant.health) * BattleMath.PERCENT_SCALE / float(participant.max_health)
	if ratio < float(minimum_health_percent) or ratio > float(maximum_health_percent):
		return false
	return true
