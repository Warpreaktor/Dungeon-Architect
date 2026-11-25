class_name MonsterFuryRules
extends Resource

@export_range(1, 999, 1) var maximum: int = 1
@export_range(0, 999, 1) var gain_on_health_damage: int = 0
@export_range(0, 999, 1) var gain_on_missed_action: int = 0
@export_range(0, 999, 1) var gain_on_blocked_action: int = 0
@export_range(0, 999, 1) var gain_on_guard_hit: int = 0
@export_range(0, 999, 1) var round_gain_cap: int = 0
@export_range(0.0, 10.0, 0.01) var physical_bonus: float = 0.0
@export_range(0.0, 10.0, 0.01) var incoming_health_bonus: float = 0.0
@export_range(0, 999, 1) var block_penalty: int = 0
