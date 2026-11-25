class_name BattleRules
extends Resource

@export_range(0.0, 10.0, 0.01) var melee_strength_factor: float
@export_range(0.0, 10.0, 0.01) var ranged_agility_factor: float
@export_range(0, 100, 1) var base_accuracy_percent: int
@export_range(0, 999, 1) var passive_armor_reduction_per_point: int = 1
@export_range(0, 999, 1) var unarmed_block_armor: int
@export_range(0, 1000, 1) var block_attack_bonus_percent: int

@export_range(0.0, 1.0, 0.01) var energy_fatigue_threshold: float = 0.25
@export_range(0.0, 1.0, 0.01) var energy_fatigue_factor: float = 0.8
@export_range(0.0, 1.0, 0.01) var energy_zero_factor: float = 0.5
@export_range(0.0, 1.0, 0.01) var energy_negative_factor: float = 0.4
@export_range(0.0, 10.0, 0.01) var energy_debt_hp_factor: float = 0.5
