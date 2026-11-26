class_name TrapDefinition
extends Resource

## Определение типа ловушки.

@export var trap_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_enum("floor", "door") var placement: String = "floor"
@export_enum("any", "narrow_passage") var placement_constraint: String = "any"
@export_multiline var trigger_message: String = ""
@export_enum("immediate", "directional_escape") var hidden_entry_reaction: String = "immediate"
@export_enum("none", "falling_slab", "spike_burst", "crossbow_shot") var trigger_visual: String = "none"
@export var hidden_by_default: bool = true
@export_range(0, 999, 1) var detection_difficulty: int = 0
@export_range(0, 999, 1) var avoidance_difficulty: int = 0
@export_range(0, 999, 1) var disarm_difficulty: int = 0
@export_enum("agility", "strength", "perception") var avoidance_stat: String = "agility"
@export_enum("agility", "strength", "perception") var disarm_stat: String = "agility"
@export_range(2, 100, 1) var check_die_sides: int = 10
@export_range(0, 9999, 1) var direct_damage: int = 0
@export var overworld_status_id: String = ""
@export var overworld_status_label: String = ""
@export_range(0, 9999, 1) var overworld_status_damage: int = 0
@export_range(0, 999, 1) var overworld_status_ticks: int = 0
@export_range(1, 999, 1) var overworld_status_interval_steps: int = 4
@export var disarm_on_trigger: bool = true
@export var blocks_path: bool = false


func can_attach_to(kind: String) -> bool:
	return placement == kind


func applies_overworld_status() -> bool:
	return not overworld_status_id.is_empty() and overworld_status_damage > 0 and overworld_status_ticks > 0


func get_description() -> String:
	var values: Dictionary = DescriptionTemplate.numeric_values(self)
	values["status_duration_phases"] = DescriptionTemplate.phases(overworld_status_ticks)
	values["after_trigger"] = " Ловушка разряжается." if disarm_on_trigger else ""
	return DescriptionTemplate.render(description, values)


func avoidance_stat_label() -> String:
	return str(CharacterStats.COMPARISON_LABELS.get(avoidance_stat, avoidance_stat))


func check(member: HeroState, rng: RandomNumberGenerator, disarming: bool = false, bonus: int = 0) -> bool:
	var stat: String = disarm_stat if disarming else avoidance_stat
	var difficulty: int = disarm_difficulty if disarming else avoidance_difficulty
	var effective: int = int(CharacterStats.hero_values(member).get(stat, 0))
	var roll: int = rng.randi_range(1, check_die_sides)
	return (not disarming or roll > 1) and roll + effective + bonus >= difficulty
