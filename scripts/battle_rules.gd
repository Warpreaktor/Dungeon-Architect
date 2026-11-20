class_name BattleRules
extends Resource

@export_range(0.0, 10.0, 0.01) var melee_strength_factor: float
@export_range(0.0, 10.0, 0.01) var ranged_agility_factor: float
@export_range(0, 100, 1) var base_accuracy_percent: int
@export_range(0, 999, 1) var unarmed_block_armor: int
@export_range(0, 1000, 1) var block_attack_bonus_percent: int
