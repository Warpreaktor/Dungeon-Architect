class_name BattleChainPlanner
extends RefCounted

## DA-4.06. Планировщик не зависит от боевой сцены и длительности анимаций.
## Верхняя граница защищает от случайной бесконечной фазы в редакторе цепочки.
const MAX_ACTIONS: int = 8
## По боевым правилам после полного круга идёт ровно один обязательный такт отдыха.
const REST_TICKS: int = 1


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
		if check_requirements:
			var unavailable: String = ability.unavailable_reason(participant)
			if not unavailable.is_empty():
				return "Приём %s недоступен: %s" % [action_id, unavailable]
	return ""


## После каждого полного круга участник один такт отдыхает.
## Курсор равный длине цепочки обозначает именно этот отдых.
static func next_step(chain: Array[String], cursor: int) -> Dictionary:
	if chain.is_empty():
		return {"action_id": "", "slot_index": -1, "reload": true, "next_cursor": 0}
	if cursor >= chain.size() or cursor < 0:
		return {"action_id": "", "slot_index": -1, "reload": true, "next_cursor": 0}
	return {"action_id": chain[cursor], "slot_index": cursor, "reload": false,
		"next_cursor": cursor + 1}


## Фаза включает все приёмы героя и отдельный завершающий такт отдыха.
static func phase_length(hero_actions: Array[String], _enemy_actions: Array[String]) -> int:
	return hero_actions.size() + REST_TICKS if not hero_actions.is_empty() else 0


## Только для предпросмотра одной непрерывной временной шкалы, не modulo N.
static func action_at(chain: Array[String], tick: int) -> String:
	if chain.is_empty() or tick < 0:
		return ""
	var cursor: int = tick % (chain.size() + REST_TICKS)
	return chain[cursor] if cursor < chain.size() else ""


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
