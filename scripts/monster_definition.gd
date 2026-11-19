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
## Урон атак задают сами приёмы и характеристики существа.
@export_range(0, 999, 1) var strength: int = 0
@export_range(0, 999, 1) var agility: int = 0
## Base probability of avoiding an attack, without active buffs.
@export_range(0, 100, 1) var base_dodge_percent: int = 0
## Дополнительные очки меткости сверх бонуса +1 за Ловкость.
@export_range(0, 999, 1) var accuracy_bonus: int = 0
## Legacy unused field; armor will be modeled independently.
@export_range(0, 999, 1) var defense: int = 0
