class_name MonsterCatalog
extends RefCounted

const DEFAULT_MONSTER_ID: String = "rabbit_symbiont"
const MONSTER_DIRECTORY: String = "res://monsters"
const LEGACY_IDS := {
	"small_monster": "rabbit_symbiont",
	"skeleton_guard": "hunter"
}


static func list_ids() -> Array[String]:
	return ResourceCatalog.list_ids(MONSTER_DIRECTORY)


static func has(monster_id: String) -> bool:
	return ResourceCatalog.load_by_id(MONSTER_DIRECTORY, monster_id) is MonsterDefinition


static func resolve_id(monster_id: String) -> String:
	var resolved: String = str(LEGACY_IDS.get(monster_id, monster_id))
	return resolved if has(resolved) else DEFAULT_MONSTER_ID


static func get_monster(monster_id: String) -> MonsterDefinition:
	return ResourceCatalog.load_by_id(MONSTER_DIRECTORY, resolve_id(monster_id)) as MonsterDefinition


static func from_entity(entity: Dictionary) -> MonsterDefinition:
	var properties: Dictionary = entity.get("properties", {})
	return get_monster(str(properties.get("monster_id", DEFAULT_MONSTER_ID)))
