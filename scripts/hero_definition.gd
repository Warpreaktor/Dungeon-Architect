class_name HeroDefinition
extends Resource

## Параметры конкретного героя. Базовые значения можно менять в Inspector.
@export var hero_id: String = ""
@export var display_name: String = ""
@export var portrait: Texture2D
@export var map_icon: Texture2D
@export var personal_ability_ids: Array[String] = []
@export_range(1, 999, 1) var max_health: int = 40
@export_range(1, 999, 1) var base_attack: int = 6
@export_range(0, 999, 1) var base_defense: int = 0
