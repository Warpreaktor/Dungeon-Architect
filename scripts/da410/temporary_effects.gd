class_name DA410TemporaryEffects
extends RefCounted

## Timed modifiers only. The combat executor owns hit rolls and applies
## damage; this collection owns effect lifetimes and stacking by stable IDs.
## Definition dictionaries are intended to be read from game Resources.

const COUNTER_START: int = 0 # Structural zero: no ticks elapsed / no stack cap.
const COUNTER_STEP: int = 1 # Structural unit: one matching clock event.

const CLOCK_NEXT_ATTACK: StringName = &"next_incoming_attack"
const CLOCK_OWNER_PHASE: StringName = &"owner_phase"
const CLOCK_WORLD_ACTION: StringName = &"world_action"
const CLOCK_BATTLE_END: StringName = &"battle_end"

const STACK_ONCE: StringName = &"once"
const STACK_REFRESH: StringName = &"refresh"
const STACK_ADD: StringName = &"add"

var _active: Array[Dictionary] = []
var _next_instance_id: int = COUNTER_START


func add(definition: Dictionary, source_id: StringName, target_id: StringName, partial_phase_active: bool = false) -> int:
	if source_id.is_empty() or target_id.is_empty():
		return -COUNTER_STEP
	var effect_id: StringName = StringName(str(definition.get("id", "")))
	var group: StringName = StringName(str(definition.get("stack_group", effect_id)))
	var clock: StringName = StringName(str(definition.get("clock", CLOCK_BATTLE_END)))
	var policy: StringName = StringName(str(definition.get("stack_policy", STACK_ONCE)))
	var duration: int = int(definition.get("duration", COUNTER_STEP))
	if effect_id.is_empty() or duration <= COUNTER_START:
		return -COUNTER_STEP
	if not [CLOCK_NEXT_ATTACK, CLOCK_OWNER_PHASE, CLOCK_WORLD_ACTION, CLOCK_BATTLE_END].has(clock):
		return -COUNTER_STEP
	if not [STACK_ONCE, STACK_REFRESH, STACK_ADD].has(policy):
		return -COUNTER_STEP

	var matching: Array[int] = []
	for i in range(_active.size()):
		var existing: Dictionary = _active[i]
		if existing["target_id"] == target_id and existing["source_id"] == source_id and existing["stack_group"] == group:
			matching.append(i)
	if policy == STACK_ONCE and not matching.is_empty():
		return int(_active[matching.front()]["instance_id"])
	if policy == STACK_REFRESH and not matching.is_empty():
		var original: Dictionary = _active[matching.front()]
		original["remaining"] = duration
		original["ignore_partial_phase"] = clock == CLOCK_OWNER_PHASE and partial_phase_active
		_active[matching.front()] = original
		return int(original["instance_id"])
	if policy == STACK_ADD:
		var stack_limit: int = int(definition.get("max_stacks", COUNTER_START))
		if stack_limit > COUNTER_START and matching.size() >= stack_limit:
			return int(_active[matching.front()]["instance_id"])

	_next_instance_id += COUNTER_STEP
	_active.append({
		"instance_id": _next_instance_id,
		"id": effect_id,
		"source_id": source_id,
		"target_id": target_id,
		"stack_group": group,
		"stat": StringName(str(definition.get("stat", ""))),
		"magnitude": float(definition.get("magnitude", COUNTER_START)),
		"clock": clock,
		"remaining": duration,
		"ignore_partial_phase": clock == CLOCK_OWNER_PHASE and partial_phase_active,
	})
	return _next_instance_id


func sum_modifier(target_id: StringName, stat: StringName) -> float:
	var total: float = 0.0 # Additive identity, not a balance constant.
	for effect in _active:
		if effect["target_id"] == target_id and effect["stat"] == stat:
			total += float(effect["magnitude"])
	return total


func list_for(target_id: StringName) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for effect in _active:
		if effect["target_id"] == target_id:
			results.append(effect.duplicate(true))
	return results


## Call AFTER a target's incoming sub-hit has been resolved. This means a
## three-hit ability may consume next-attack dodge on the first sub-hit.
func on_incoming_attack_resolved(target_id: StringName) -> Array[Dictionary]:
	return _advance_clock(target_id, CLOCK_NEXT_ATTACK)


## Call only after the actor's own mandatory rest, not after the hero's rest.
func on_actor_phase_completed(actor_id: StringName) -> Array[Dictionary]:
	return _advance_clock(actor_id, CLOCK_OWNER_PHASE)


func on_world_action_resolved(actor_id: StringName) -> Array[Dictionary]:
	return _advance_clock(actor_id, CLOCK_WORLD_ACTION)


## Remove combat-only effects. Leave world-action effects in GameSession.
func on_battle_end() -> Array[Dictionary]:
	var ended: Array[Dictionary] = []
	for i in range(_active.size() - COUNTER_STEP, -COUNTER_STEP, -COUNTER_STEP):
		if _active[i]["clock"] != CLOCK_WORLD_ACTION:
			ended.append(_active[i].duplicate(true))
			_active.remove_at(i)
	return ended


func _advance_clock(target_id: StringName, clock: StringName) -> Array[Dictionary]:
	var ended: Array[Dictionary] = []
	for i in range(_active.size() - COUNTER_STEP, -COUNTER_STEP, -COUNTER_STEP):
		var effect: Dictionary = _active[i]
		if effect["target_id"] != target_id or effect["clock"] != clock:
			continue
		if clock == CLOCK_OWNER_PHASE and bool(effect["ignore_partial_phase"]):
			effect["ignore_partial_phase"] = false
			_active[i] = effect
			continue
		effect["remaining"] = int(effect["remaining"]) - COUNTER_STEP
		if int(effect["remaining"]) <= COUNTER_START:
			ended.append(effect.duplicate(true))
			_active.remove_at(i)
		else:
			_active[i] = effect
	return ended
