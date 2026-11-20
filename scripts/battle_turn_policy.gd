class_name BattleTurnPolicy
extends RefCounted

var block_priority: int = 0
var other_priority: int = 10


func priority(action_id: String) -> int:
	var ability: AbilityDefinition = AbilityCatalog.get_ability(action_id)
	if ability == null:
		return other_priority
	var has_block: bool = false
	for effect in ability.effects:
		if effect.kind == AbilityEffectDefinition.Kind.DAMAGE:
			return other_priority
		if effect.kind == AbilityEffectDefinition.Kind.BLOCK:
			has_block = true
	return block_priority if has_block else other_priority


func order_for_tick(participants: Dictionary, steps: Dictionary, actor_ids: Array[String]) -> Array[String]:
	var sorted_ids: Array[String] = []
	var stable_positions: Dictionary = {}
	for actor_id in actor_ids:
		var participant: BattleParticipant = participants.get(actor_id) as BattleParticipant
		if participant == null or not participant.is_alive() or not steps.has(actor_id):
			continue
		stable_positions[actor_id] = sorted_ids.size()
		sorted_ids.append(actor_id)
	sorted_ids.sort_custom(func(left_id: String, right_id: String) -> bool:
		var left: BattleParticipant = participants[left_id] as BattleParticipant
		var right: BattleParticipant = participants[right_id] as BattleParticipant
		var left_agility: int = left.effective_agility()
		var right_agility: int = right.effective_agility()
		if left_agility != right_agility:
			return left_agility > right_agility
		var left_step: Dictionary = steps[left_id]
		var right_step: Dictionary = steps[right_id]
		var left_reloading: bool = bool(left_step.get("reload", false))
		var right_reloading: bool = bool(right_step.get("reload", false))
		if left_reloading != right_reloading:
			return not left_reloading
		var left_priority: int = priority(str(left_step.get("action_id", "")))
		var right_priority: int = priority(str(right_step.get("action_id", "")))
		if left_priority != right_priority:
			return left_priority < right_priority
		return int(stable_positions[left_id]) < int(stable_positions[right_id])
	)
	return sorted_ids
