class_name BattleClashPlanner
extends RefCounted


static func next_opponent(participants: Dictionary, enemy_ids: Array[String], cursor: int) -> Dictionary:
	if enemy_ids.is_empty():
		return {"actor_id": "", "next_cursor": cursor}
	for offset in range(enemy_ids.size()):
		var index: int = posmod(cursor + offset, enemy_ids.size())
		var actor_id: String = enemy_ids[index]
		var actor: BattleParticipant = participants.get(actor_id) as BattleParticipant
		if actor != null and actor.is_alive():
			return {"actor_id": actor_id, "next_cursor": index + 1}
	return {"actor_id": "", "next_cursor": cursor}
