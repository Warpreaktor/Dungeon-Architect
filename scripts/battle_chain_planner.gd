class_name BattleChainPlanner
extends RefCounted

## DA-4.06. Планировщик не зависит от боевой сцены и длительности анимаций.
## Верхняя граница защищает от случайной бесконечной фазы в редакторе цепочки.
const MAX_ACTIONS: int = 8


static func validate(chain: Array[String], participant: BattleParticipant, check_requirements: bool = true) -> String:
	if participant == null or not participant.is_alive():
		return "Участник боя недоступен"
	if chain.is_empty():
		return "Добавьте хотя бы один приём"
	if chain.size() > MAX_ACTIONS:
		return "Слишком длинная цепочка (максимум %d действий)" % MAX_ACTIONS
	if chain.size() > participant.action_slot_capacity:
		return "Участнику доступно только %d слота" % participant.action_slot_capacity
	for action_id in chain:
		var ability: AbilityDefinition = AbilityCatalog.get_ability(action_id)
		if ability == null or not (action_id in participant.personal_ability_ids or action_id in participant.learned_ability_ids):
			return "Недоступный приём: %s" % action_id
		if not ability.validation_error().is_empty():
			return "Некорректный приём: %s" % action_id
		if check_requirements and not ability.requirements_met(participant):
			return "Не выполнены требования приёма: %s" % action_id
	return ""


static func phase_length(hero_actions: Array[String], enemy_actions: Array[String]) -> int:
	if hero_actions.is_empty() or enemy_actions.is_empty():
		return 0
	return maxi(hero_actions.size(), enemy_actions.size())


static func action_at(chain: Array[String], tick: int) -> String:
	if chain.is_empty() or tick < 0:
		return ""
	return chain[tick % chain.size()]


static func preview(hero_actions: Array[String], enemy_actions: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for tick in range(phase_length(hero_actions, enemy_actions)):
		rows.append({"tick": tick + 1, "hero": action_at(hero_actions, tick),
			"enemy": action_at(enemy_actions, tick)})
	return rows
