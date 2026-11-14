class_name MonsterDefinition
extends Resource

## Статические характеристики противника. Состояние здоровья хранится в CombatSession.
@export var monster_id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
@export_range(1, 999, 1) var max_health: int = 1
@export_range(0, 999, 1) var attack_damage: int = 1
