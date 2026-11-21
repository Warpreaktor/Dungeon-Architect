class_name BattleClashPlanner
extends RefCounted


static func ordered_actors(participants: Dictionary, actor_ids: Array[String]) -> Array[String]:
	var ordered: Array[String] = actor_ids.duplicate()
	ordered.sort_custom(func(left_id: String, right_id: String) -> bool:
		var left: BattleParticipant = participants.get(left_id) as BattleParticipant
		var right: BattleParticipant = participants.get(right_id) as BattleParticipant
		var left_agility: int = left.effective_agility() if left != null else -2147483648
		var right_agility: int = right.effective_agility() if right != null else -2147483648
		if left_agility != right_agility:
			return left_agility > right_agility
		return left_id < right_id
	)
	return ordered


static func next_actor(participants: Dictionary, actor_ids: Array[String], cursor: int) -> Dictionary:
	var ordered: Array[String] = ordered_actors(participants, actor_ids)
	if ordered.is_empty():
		return {"actor_id": "", "next_cursor": cursor}
	for offset in range(ordered.size()):
		var index: int = posmod(cursor + offset, ordered.size())
		var actor_id: String = ordered[index]
		var actor: BattleParticipant = participants.get(actor_id) as BattleParticipant
		if actor != null and actor.is_alive():
			return {"actor_id": actor_id, "next_cursor": index + 1}
	return {"actor_id": "", "next_cursor": cursor}


static func ordered_opponents(participants: Dictionary, enemy_ids: Array[String]) -> Array[String]:
	return ordered_actors(participants, enemy_ids)


static func next_opponent(participants: Dictionary, enemy_ids: Array[String], cursor: int) -> Dictionary:
	return next_actor(participants, enemy_ids, cursor)
