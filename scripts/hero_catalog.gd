class_name HeroCatalog
extends RefCounted

const DEFAULT_HERO_ID := "volcha"
const DEFINITIONS := {
    "volcha": preload("res://heroes/volcha.tres"),
    "petushan": preload("res://heroes/petushan.tres")
}

static func get_hero(hero_id: String) -> HeroDefinition:
    var valid_id: String = hero_id if DEFINITIONS.has(hero_id) else DEFAULT_HERO_ID
    return DEFINITIONS[valid_id] as HeroDefinition
