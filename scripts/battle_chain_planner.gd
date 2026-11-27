class_name BattleChainPlanner
extends RefCounted

## Планировщик не зависит от боевой сцены и длительности анимаций.
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
		if ability == null or ability.passive or not AbilityCatalog.knows_ability(participant, action_id) or AbilityCatalog.is_personal_ability_locked(participant, action_id):
			return "Недоступный приём: %s" % action_id
		if not ability.validation_error().is_empty():
			return "Некорректный приём: %s" % action_id
		if check_requirements:
			var unavailable: String = ability.unavailable_reason(participant)
			if not unavailable.is_empty():
				return "Приём %s недоступен: %s" % [action_id, unavailable]
	return ""


static func next_step(chain: Array[String], cursor: int) -> Dictionary:
	if chain.is_empty():
		return {"action_id": "", "slot_index": -1, "next_cursor": 0}
	cursor = posmod(cursor, chain.size())
	return {"action_id": chain[cursor], "slot_index": cursor, "next_cursor": (cursor + 1) % chain.size()}


static func phase_length(hero_actions: Array[String], _enemy_actions: Array[String]) -> int:
	return hero_actions.size()


static func action_at(chain: Array[String], tick: int) -> String:
	return chain[tick % chain.size()] if not chain.is_empty() and tick >= 0 else ""


static func preview(hero_actions: Array[String], enemy_actions: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for tick in range(phase_length(hero_actions, enemy_actions)):
		rows.append({"tick": tick + 1, "hero": action_at(hero_actions, tick),
			"enemy": action_at(enemy_actions, tick)})
	return rows


## Блок всегда опережает любое другое действие; при равенстве герой первый.
static func priority(action_id: String) -> int:
	var ability: AbilityDefinition = AbilityCatalog.get_ability(action_id)
	if ability != null:
		var has_block: bool = false
		for effect in ability.effects:
			if effect.kind == AbilityEffectDefinition.Kind.DAMAGE:
				return 10
			if effect.kind == AbilityEffectDefinition.Kind.BLOCK:
				has_block = true
		if has_block:
			return 0
	return 10
