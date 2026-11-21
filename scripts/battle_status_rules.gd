class_name BattleStatusRules
extends RefCounted


static func modifier(statuses: Dictionary, stat: int) -> int:
	var total: int = 0
	for active in statuses.values():
		if int(active.get("stat", AbilityEffectDefinition.Stat.NONE)) == stat:
			total += int(active.get("modifier", 0)) * int(active.get("stacks", 1))
	return total


static func apply(statuses: Dictionary, effect: AbilityEffectDefinition, tick: int, partial_phase: bool) -> void:
	var previous: Dictionary = statuses.get(effect.status_id, {})
	var policy: int = effect.effective_stack_policy()
	if policy == AbilityEffectDefinition.Stack.ONCE and not previous.is_empty():
		return
	var stacks: int = int(previous.get("stacks", 0)) + 1 if policy == AbilityEffectDefinition.Stack.ADD else 1
	statuses[effect.status_id] = {
		"label": previous.get("label", effect.status_id),
		"amount": effect.amount,
		"modifier": effect.effective_status_modifier(),
		"stat": effect.effective_status_stat(),
		"clock": effect.effective_status_clock(),
		"ticks": effect.duration_ticks,
		"stacks": stacks,
		"applied_tick": tick,
		"tick_damage": effect.tick_damage,
		"skip_partial_phase": effect.tick_damage <= 0
			and effect.effective_status_clock() == AbilityEffectDefinition.Clock.OWNER_PHASE
			and partial_phase
	}
	if previous.has("interval_steps"):
		statuses[effect.status_id]["interval_steps"] = previous["interval_steps"]


static func ticking_entries(statuses: Dictionary, clock: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for status_id in statuses:
		var status: Dictionary = statuses[status_id]
		if int(status.get("clock", -1)) != clock or bool(status.get("skip_partial_phase", false)):
			continue
		var damage: int = int(status.get("tick_damage", 0)) * maxi(int(status.get("stacks", 1)), 1)
		if damage > 0:
			entries.append({"status_id": str(status_id), "damage": damage})
	return entries


static func advance(statuses: Dictionary, clock: int, current_tick: int = -1) -> Array[String]:
	var expired: Array[String] = []
	for status_id in statuses.keys():
		var status: Dictionary = statuses[status_id]
		if int(status.get("clock", AbilityEffectDefinition.Clock.LEGACY_HERO_PHASE)) != clock:
			continue
		if current_tick >= 0 and int(status.get("applied_tick", -1)) == current_tick and int(status.get("tick_damage", 0)) <= 0:
			continue
		if clock == AbilityEffectDefinition.Clock.OWNER_PHASE and bool(status.get("skip_partial_phase", false)):
			status["skip_partial_phase"] = false
			statuses[status_id] = status
			continue
		status["ticks"] = int(status.get("ticks", 0)) - 1
		if int(status["ticks"]) <= 0:
			statuses.erase(status_id)
			expired.append(str(status_id))
		else:
			statuses[status_id] = status
	return expired


static func describe(status: Dictionary) -> String:
	var parts: Array[String] = []
	var stacks: int = maxi(int(status.get("stacks", 1)), 1)
	var damage: int = int(status.get("tick_damage", 0)) * stacks
	if damage > 0:
		parts.append("Урон за фазу: %d HP" % damage)
	var value: int = int(status.get("modifier", 0)) * stacks
	if value != 0:
		var label: String = "Модификатор"
		match int(status.get("stat", AbilityEffectDefinition.Stat.NONE)):
			AbilityEffectDefinition.Stat.AGILITY: label = "Ловкость"
			AbilityEffectDefinition.Stat.ACCURACY: label = "Меткость"
			AbilityEffectDefinition.Stat.DODGE_PERCENT: label = "Уклонение"
			AbilityEffectDefinition.Stat.ATTACK_POWER: label = "Атака"
		parts.append("%s: %+d" % [label, value])
	if int(status.get("clock", -1)) == AbilityEffectDefinition.Clock.INCOMING_ATTACK:
		parts.append("Осталось входящих атак: %d" % int(status.get("ticks", 0)))
	else:
		parts.append("Осталось фаз: %d" % int(status.get("ticks", 0)))
	return ". ".join(parts)
