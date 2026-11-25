class_name MonsterDefinition
extends Resource

enum Rank { COMMON, ELITE, BOSS }

## Статические характеристики противника. Состояние здоровья хранится в CombatSession.
@export var monster_id: String = ""
@export var rank: Rank = Rank.COMMON
@export var display_name: String = ""
@export var portrait: Texture2D
@export var portrait_flip_h: bool = false
@export var icon: Texture2D
@export var battle_bond: BattleBondDefinition
@export var personal_ability_ids: Array[String] = []
@export var ai_profiles: Array[MonsterTacticProfile] = []
@export var reconsider_tactics_each_phase: bool = false
@export var intermission_actions: Array[MonsterIntermissionAction] = []
@export_range(0, 8, 1) var max_intermission_actions: int = 1
@export var starting_resources: Dictionary = {}
@export_range(0, 999, 1) var max_energy: int = 0
@export_range(0, 999, 1) var energy_restoration: int = 0
## Обязательные карты в колоде на бой (порядок фиксирован).
## Если не заданы, обязательная карта берётся из personal_ability_ids.
@export var guaranteed_card_ids: Array[String] = []
## Количество случайных карт из оставшегося пула.
## Суммарный размер ограничен base_action_slots.
@export_range(0, 8, 1) var random_card_count: int = 1
@export_range(0, 100, 1) var weapon_spawn_chance_percent: int = 0
@export var weapon_replaced_ability_id: String = ""
## Сколько действий в алгоритме доступно без артефактов и усилений.
@export_range(1, 8, 1) var base_action_slots: int = 3
@export_range(1, 999, 1) var max_health: int = 1
## Урон атак задают сами приёмы и характеристики существа.
@export_range(0, 999, 1) var strength: int = 0
@export_range(0, 999, 1) var agility: int = 0
## Base probability of avoiding an attack, without active buffs.
@export_range(0, 100, 1) var base_dodge_percent: int = 0
## Дополнительные очки меткости сверх вклада Ловкости.
@export_range(-100, 999, 1) var accuracy_bonus: int = 0
## Legacy unused field; armor will be modeled independently.
@export_range(0, 999, 1) var defense: int = 0
