class_name BattleBondDefinition
extends Resource

@export var companion_monster_id: String = ""
@export var command_ability_id: String = ""
@export var marked_status_id: String = ""
@export var heal_ability_id: String = ""
@export var split_ability_id: String = ""
@export var ranged_ability_id: String = ""
@export var rejoin_ability_id: String = ""
@export var protect_ability_id: String = ""
@export var marked_accuracy_bonus: int = 0
@export_range(0.0, 10.0, 0.01) var counter_multiplier: float = 0.0
