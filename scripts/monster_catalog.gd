class_name MonsterCatalog
extends RefCounted

## Ресурсы монстров определяют характеристики и иконки, сущности карты хранят ID.
const DEFAULT_MONSTER_ID := "rabbit_symbiont"
const DEFINITIONS := {
	"rabbit_symbiont": preload("res://monsters/rabbit_symbiont.tres"),
	"hunter": preload("res://monsters/hunter.tres"),
	"giant_crab": preload("res://monsters/giant_crab.tres"),
	"lobar": preload("res://monsters/lobar.tres"),
	"kadavr": preload("res://monsters/kadavr.tres"),
	"skeleton": preload("res://monsters/skeleton.tres")
}

## Старые карты с прежними видами монстров продолжают загружаться.
const LEGACY_IDS := {
	"small_monster": "rabbit_symbiont",
	"skeleton_guard": "skeleton"
}


static func resolve_id(monster_id: String) -> String:
	var resolved: String = str(LEGACY_IDS.get(monster_id, monster_id))
	return resolved if DEFINITIONS.has(resolved) else DEFAULT_MONSTER_ID


static func get_monster(monster_id: String) -> MonsterDefinition:
	return DEFINITIONS[resolve_id(monster_id)] as MonsterDefinition


static func from_entity(entity: Dictionary) -> MonsterDefinition:
	var properties: Dictionary = entity.get("properties", {})
	return get_monster(str(properties.get("monster_id", DEFAULT_MONSTER_ID)))
