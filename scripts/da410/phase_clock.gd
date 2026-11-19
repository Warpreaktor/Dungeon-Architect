class_name DA410PhaseClock
extends RefCounted

## Independent actor-local phase clocks. A phase consists of editable slots plus
## one mandatory rest. This class has no combat rules or UI dependencies.

const COUNTER_START: int = 0 # Structural zero: no actions / phases occurred.
const COUNTER_STEP: int = 1 # Structural unit: one resolved action / phase.

var _actors: Dictionary = {}
var _round_checkpoints: Dictionary = {}
var round_index: int = COUNTER_START


func register_actor(actor_id: StringName, ability_slots: int) -> void:
	assert(not actor_id.is_empty())
	assert(ability_slots > COUNTER_START)
	_actors[actor_id] = {
		"ability_slots": ability_slots,
		"cursor": COUNTER_START,
		"phases_completed": COUNTER_START,
	}
	_round_checkpoints[actor_id] = COUNTER_START


func unregister_actor(actor_id: StringName) -> void:
	_actors.erase(actor_id)
	_round_checkpoints.erase(actor_id)


func has_actor(actor_id: StringName) -> bool:
	return _actors.has(actor_id)


func has_started_phase(actor_id: StringName) -> bool:
	if not _actors.has(actor_id):
		return false
	return int(_actors[actor_id]["cursor"]) > COUNTER_START


func get_completed_phases(actor_id: StringName) -> int:
	if not _actors.has(actor_id):
		return COUNTER_START
	return int(_actors[actor_id]["phases_completed"])


func get_next_slot(actor_id: StringName) -> int:
	if not _actors.has(actor_id):
		return -COUNTER_STEP
	return int(_actors[actor_id]["cursor"])


## Call exactly once after the actor's scheduled action or mandatory rest.
## Failed abilities still consume their slot; the rest is a distinct extra step.
func advance_actor(actor_id: StringName) -> Dictionary:
	if not _actors.has(actor_id):
		return {"ok": false, "reason": "unknown_actor"}
	var state: Dictionary = _actors[actor_id]
	var slot: int = int(state["cursor"])
	var is_rest: bool = slot == int(state["ability_slots"])
	if is_rest:
		state["cursor"] = COUNTER_START
		state["phases_completed"] = int(state["phases_completed"]) + COUNTER_STEP
	else:
		state["cursor"] = slot + COUNTER_STEP
	_actors[actor_id] = state
	var round_completed: bool = false
	if is_rest:
		round_completed = _try_complete_round()
	return {
		"ok": true,
		"actor_id": actor_id,
		"slot_index": slot,
		"is_rest": is_rest,
		"phase_completed": is_rest,
		"phases_completed": state["phases_completed"],
		"round_completed": round_completed,
		"round_index": round_index,
	}


## Internal-only grouping: a round completes when every still-active actor
## has completed at least one full own phase since the last checkpoint.
func _try_complete_round() -> bool:
	if _actors.is_empty():
		return false
	for actor_id in _actors:
		if int(_actors[actor_id]["phases_completed"]) <= int(_round_checkpoints[actor_id]):
			return false
	for actor_id in _actors:
		_round_checkpoints[actor_id] = int(_actors[actor_id]["phases_completed"])
	round_index += COUNTER_STEP
	return true
