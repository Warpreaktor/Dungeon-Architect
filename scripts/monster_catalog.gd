class_name MonsterCatalog
extends RefCounted

## Тип монстра хранится в properties объекта карты, сами параметры — в Resource.
const DEFAULT_MONSTER_ID := "small_monster"
const DEFINITIONS := {
	"small_monster": preload("res://monsters/small_monster.tres"),
	"skeleton_guard": preload("res://monsters/skeleton_guard.tres")
}


static func get_monster(monster_id: String) -> MonsterDefinition:
	return DEFINITIONS.get(monster_id, DEFINITIONS[DEFAULT_MONSTER_ID]) as MonsterDefinition


static func from_entity(entity: Dictionary) -> MonsterDefinition:
	var properties: Dictionary = entity.get("properties", {})
	return get_monster(str(properties.get("monster_id", DEFAULT_MONSTER_ID)))
