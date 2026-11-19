class_name HeroDefinition
extends Resource

## Параметры конкретного героя. Базовые значения можно менять в Inspector.
@export var hero_id: String = ""
@export var display_name: String = ""
@export var portrait: Texture2D
@export var map_icon: Texture2D
@export var personal_ability_ids: Array[String] = []
## Сколько действий в алгоритме доступно без артефактов и усилений.
@export_range(1, 8, 1) var base_action_slots: int = 3
@export_range(1, 999, 1) var max_health: int = 40
## Каждое очко силы добавляет 0,5 к урону ближних действий.
@export_range(0, 999, 1) var strength: int = 0
## Каждое очко ловкости добавляет 0,5 к урону дальних действий.
@export_range(0, 999, 1) var agility: int = 0
## Base probability of avoiding an incoming attack. Status bonuses add percentage points.
@export_range(0, 100, 1) var base_dodge_percent: int = 0
## Legacy unused field, retained for old .tres compatibility; not passive block.
@export_range(0, 999, 1) var base_defense: int = 0
