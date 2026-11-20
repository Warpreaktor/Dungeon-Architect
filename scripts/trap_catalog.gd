class_name TrapCatalog
extends RefCounted

const DEFAULT_TRAP_ID := "spikes"
const DEFINITIONS := {
	"spikes": preload("res://traps/spikes.tres")
}


static func list_ids() -> Array[String]:
	var ids: Array[String] = []
	for trap_id in DEFINITIONS:
		ids.append(str(trap_id))
	ids.sort()
	return ids


static func has(trap_id: String) -> bool:
	return DEFINITIONS.has(trap_id)


static func resolve_id(trap_id: String) -> String:
	return trap_id if DEFINITIONS.has(trap_id) else DEFAULT_TRAP_ID


static func get_trap(trap_id: String) -> TrapDefinition:
	return DEFINITIONS[resolve_id(trap_id)] as TrapDefinition


static func from_entity(entity: Dictionary) -> TrapDefinition:
	var properties: Dictionary = entity.get("properties", {})
	return get_trap(str(properties.get("trap_id", DEFAULT_TRAP_ID)))
