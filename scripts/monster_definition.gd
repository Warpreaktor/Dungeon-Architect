class_name MonsterDefinition
extends Resource

## Статические характеристики противника. Состояние здоровья хранится в CombatSession.
@export var monster_id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export var personal_ability_ids: Array[String] = []
## Сколько действий в алгоритме доступно без артефактов и усилений.
@export_range(1, 8, 1) var base_action_slots: int = 3
@export_range(1, 999, 1) var max_health: int = 1
@export_range(0, 999, 1) var attack_damage: int = 1
## Каждые две единицы силы добавляют 1 к урону ближних атак.
@export_range(0, 999, 1) var strength: int = 0
@export_range(0, 999, 1) var defense: int = 0
