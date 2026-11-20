class_name HeroCatalog
extends RefCounted

const DEFAULT_HERO_ID: String = "volcha"
const HERO_DIRECTORY: String = "res://heroes"


static func list_ids() -> Array[String]:
	return ResourceCatalog.list_ids(HERO_DIRECTORY)


static func has(hero_id: String) -> bool:
	return ResourceCatalog.load_by_id(HERO_DIRECTORY, hero_id) is HeroDefinition


static func get_hero(hero_id: String) -> HeroDefinition:
	var hero: HeroDefinition = ResourceCatalog.load_by_id(HERO_DIRECTORY, hero_id) as HeroDefinition
	if hero != null:
		return hero
	return ResourceCatalog.load_by_id(HERO_DIRECTORY, DEFAULT_HERO_ID) as HeroDefinition
