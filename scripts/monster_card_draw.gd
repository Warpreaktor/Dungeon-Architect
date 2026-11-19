class_name MonsterCardDraw
extends RefCounted

## Формирует колоду монстра один раз на бой. Нет повторов карт:
## обязательные берутся в заданном порядке, остальные случайно из пула.
## RNG передаётся извне, чтобы боевые тесты могли задавать seed.
static func draw(definition: MonsterDefinition, participant: BattleParticipant, rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	if definition == null or participant == null or rng == null:
		return result
	var capacity: int = mini(participant.action_slot_capacity, BattleChainPlanner.MAX_ACTIONS)
	var fixed: Array[String] = definition.guaranteed_card_ids.duplicate()
	if fixed.is_empty() and not definition.personal_ability_ids.is_empty():
		# Обратная совместимость: первая карта в старых монстрах обязательная.
		fixed.append(definition.personal_ability_ids[0])
	for ability_id in fixed:
		if result.size() >= capacity:
			break
		if not result.has(ability_id) and AbilityCatalog.can_prepare(participant, ability_id):
			result.append(ability_id)
	var candidates: Array[String] = []
	for ability_id in definition.personal_ability_ids:
		if not result.has(ability_id) and not candidates.has(ability_id) and AbilityCatalog.can_prepare(participant, ability_id):
			candidates.append(ability_id)
	# Перемешивание Fisher-Yates с общим генератором текущего боя.
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var replacement: String = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = replacement
	var count: int = mini(definition.random_card_count, mini(capacity - result.size(), candidates.size()))
	for i in range(count):
		result.append(candidates[i])
	return result
