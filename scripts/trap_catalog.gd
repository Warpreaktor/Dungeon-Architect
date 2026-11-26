class_name TrapCatalog
extends RefCounted

const DEFAULT_TRAP_ID := "spikes"
const DIFFICULTY_FIELDS := ["detection_difficulty", "avoidance_difficulty", "disarm_difficulty"]
const STAT_IDS := ["agility", "strength", "perception"]
const INITIAL_STATES := ["armed", "disarmed", "discharged"]
const OVERRIDE_FIELDS := ["detection_difficulty", "avoidance_difficulty", "disarm_difficulty", "avoidance_stat", "hidden", "initial_state"]
const DEFINITIONS := {
	"spikes": preload("res://traps/spikes.tres"),
	"door_crossbow": preload("res://traps/door_crossbow.tres")
}


static func list_ids(placement: String = "") -> Array[String]:
	var ids: Array[String] = []
	for trap_id in DEFINITIONS:
		var trap: TrapDefinition = DEFINITIONS[trap_id] as TrapDefinition
		if placement.is_empty() or trap.can_attach_to(placement):
			ids.append(str(trap_id))
	ids.sort()
	return ids


static func has(trap_id: String) -> bool:
	return DEFINITIONS.has(trap_id)


static func resolve_id(trap_id: String) -> String:
	return trap_id if DEFINITIONS.has(trap_id) else DEFAULT_TRAP_ID


static func get_trap(trap_id: String) -> TrapDefinition:
	return DEFINITIONS[resolve_id(trap_id)] as TrapDefinition


static func settings(entity: Dictionary) -> Dictionary:
	var kind: String = str(entity.get("type", ""))
	if kind not in ["door", "trap"]:
		return {}
	var properties: Dictionary = entity.get("properties", {})
	var is_door: bool = kind == "door"
	var trap_id: String = DungeonMap.door_trap_id(entity) if is_door else str(properties.get("trap_id", DEFAULT_TRAP_ID))
	if is_door and trap_id.is_empty():
		return {}
	var definition: TrapDefinition = get_trap(trap_id)
	if not definition.can_attach_to("door" if is_door else "floor"):
		return {}
	var source: Dictionary = properties.get("trap", {}) if is_door else properties
	return normalize_settings(definition, source)


static func normalize_settings(definition: TrapDefinition, source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field in DIFFICULTY_FIELDS:
		var value: Variant = source.get(field, definition.get(field))
		result[field] = clampi(int(value), 0, 999) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else int(definition.get(field))
	var stat: String = str(source.get("avoidance_stat", definition.avoidance_stat))
	result["avoidance_stat"] = stat if stat in STAT_IDS else definition.avoidance_stat
	var hidden: Variant = source.get("hidden", definition.hidden_by_default)
	result["hidden"] = hidden if typeof(hidden) == TYPE_BOOL else definition.hidden_by_default
	var initial: String = str(source.get("initial_state", "armed"))
	result["initial_state"] = initial if initial in INITIAL_STATES and (initial != "discharged" or definition.disarm_on_trigger) else "armed"
	return result


static func settings_overrides(definition: TrapDefinition, source: Dictionary) -> Dictionary:
	var values: Dictionary = normalize_settings(definition, source)
	var defaults: Dictionary = normalize_settings(definition, {})
	var result: Dictionary = {}
	for field in OVERRIDE_FIELDS:
		if values[field] != defaults[field]:
			result[field] = values[field]
	return result


static func initial_state(entity: Dictionary) -> String:
	return str(settings(entity).get("initial_state", "armed"))


static func _configured(definition: TrapDefinition, values: Dictionary) -> TrapDefinition:
	if values.is_empty():
		return null
	var overrides: Dictionary = settings_overrides(definition, values)
	overrides.erase("initial_state")
	if overrides.is_empty():
		return definition
	var result: TrapDefinition = definition.duplicate() as TrapDefinition
	for field in DIFFICULTY_FIELDS:
		result.set(field, values[field])
	result.avoidance_stat = str(values["avoidance_stat"])
	result.hidden_by_default = bool(values["hidden"])
	return result


static func from_entity(entity: Dictionary) -> TrapDefinition:
	var properties: Dictionary = entity.get("properties", {})
	return _configured(get_trap(str(properties.get("trap_id", DEFAULT_TRAP_ID))), settings(entity))


static func from_door(door: Dictionary) -> TrapDefinition:
	var trap_id: String = DungeonMap.door_trap_id(door)
	return _configured(get_trap(trap_id), settings(door)) if not trap_id.is_empty() else null
