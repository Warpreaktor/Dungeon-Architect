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
@export_range(1, 999, 1) var max_health: int = 1
## Вклад Силы в ближнюю атаку задают общие боевые правила.
@export_range(0, 999, 1) var strength: int = 0
## Вклад Ловкости в дальнюю атаку задают общие боевые правила.
@export_range(0, 999, 1) var agility: int = 0
## Base probability of avoiding an incoming attack. Status bonuses add percentage points.
@export_range(0, 100, 1) var base_dodge_percent: int = 0
## Дополнительные очки меткости сверх бонуса +1 за Ловкость.
@export_range(0, 999, 1) var accuracy_bonus: int = 0
## Legacy unused field, retained for old .tres compatibility; not passive block.
@export_range(0, 999, 1) var base_defense: int = 0
