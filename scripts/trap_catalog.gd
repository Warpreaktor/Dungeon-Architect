class_name TrapCatalog
extends RefCounted

const DEFAULT_TRAP_ID := "spikes"
const LEGACY_OVERRIDE_FIELDS := ["detection_difficulty", "avoidance_difficulty", "disarm_difficulty", "avoidance_stat", "initial_state"]
const DEFINITIONS := {
	"spikes": preload("res://traps/spikes.tres"),
	"stone_slab": preload("res://traps/stone_slab.tres"),
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
	var hidden: Variant = source.get("hidden", definition.hidden_by_default)
	return {"hidden": hidden if typeof(hidden) == TYPE_BOOL else definition.hidden_by_default}


static func settings_overrides(definition: TrapDefinition, source: Dictionary) -> Dictionary:
	var values: Dictionary = normalize_settings(definition, source)
	return values if values["hidden"] != definition.hidden_by_default else {}


static func remove_legacy_overrides(properties: Dictionary) -> void:
	for field in LEGACY_OVERRIDE_FIELDS:
		properties.erase(field)


static func from_entity(entity: Dictionary) -> TrapDefinition:
	if str(entity.get("type", "")) != "trap":
		return null
	var definition: TrapDefinition = get_trap(DungeonMap.trap_id(entity))
	return definition if definition.can_attach_to("floor") else null


static func from_door(door: Dictionary) -> TrapDefinition:
	var trap_id: String = DungeonMap.door_trap_id(door)
	return get_trap(trap_id) if not trap_id.is_empty() else null
