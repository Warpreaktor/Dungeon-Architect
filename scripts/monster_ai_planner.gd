class_name MonsterAiPlanner
extends RefCounted


static func choose_profile(definition: MonsterDefinition, participant: BattleParticipant, current_id: String, rng: RandomNumberGenerator) -> MonsterTacticProfile:
	if definition == null or participant == null or rng == null:
		return null
	var best_priority: int = 0
	var candidates: Array[MonsterTacticProfile] = []
	for profile in definition.ai_profiles:
		if profile == null or not profile.accepts(participant) or not BattleChainPlanner.validate(profile.card_ids, participant).is_empty():
			continue
		if candidates.is_empty() or profile.priority > best_priority:
			best_priority = profile.priority
			candidates.clear()
		if profile.priority == best_priority:
			candidates.append(profile)
	if candidates.is_empty():
		return null
	if not definition.reconsider_tactics_each_phase:
		for profile in candidates:
			if profile.profile_id == current_id:
				return profile
	var total_weight: int = 0
	for profile in candidates:
		total_weight += maxi(profile.weight, 1)
	var draw: int = rng.randi_range(1, total_weight)
	for profile in candidates:
		draw -= maxi(profile.weight, 1)
		if draw <= 0:
			return profile
	return candidates.back()


static func planned_chain(profile: MonsterTacticProfile, participant: BattleParticipant, rng: RandomNumberGenerator) -> Array[String]:
	if profile == null or participant == null or rng == null or not profile.accepts(participant):
		return []
	var chain: Array[String] = profile.card_ids.duplicate()
	if profile.shuffle_cards:
		for index in range(chain.size() - 1, 0, -1):
			var swap_index: int = rng.randi_range(0, index)
			var entry: String = chain[index]
			chain[index] = chain[swap_index]
			chain[swap_index] = entry
	return chain if BattleChainPlanner.validate(chain, participant).is_empty() else []


static func choose_intermission(definition: MonsterDefinition, participant: BattleParticipant, usage: Dictionary, rng: RandomNumberGenerator) -> MonsterIntermissionAction:
	if definition == null or participant == null or rng == null:
		return null
	var highest: int = 0
	var candidates: Array[MonsterIntermissionAction] = []
	for action in definition.intermission_actions:
		if action == null or not action.accepts(participant, int(usage.get(action.identity(), 0))) or not AbilityCatalog.can_prepare(participant, action.ability_id):
			continue
		if action.chance_percent < BattleMath.PERCENT_SCALE and rng.randi_range(1, BattleMath.PERCENT_SCALE) > action.chance_percent:
			continue
		if candidates.is_empty() or action.priority > highest:
			highest = action.priority
			candidates.clear()
		if action.priority == highest:
			candidates.append(action)
	return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else null
