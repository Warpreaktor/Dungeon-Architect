class_name TrapDefinition
extends Resource

## Ресурс одной ловушки. Карта хранит только ID, а поведение читается из каталога.

@export var trap_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(0, 9999, 1) var direct_damage: int = 0
@export var overworld_status_id: String = ""
@export var overworld_status_label: String = ""
@export_range(0, 9999, 1) var overworld_status_damage: int = 0
@export_range(0, 999, 1) var overworld_status_ticks: int = 0
@export_range(1, 999, 1) var overworld_status_interval_steps: int = 4
@export var disarm_on_trigger: bool = true
@export var blocks_path: bool = false


func applies_overworld_status() -> bool:
	return not overworld_status_id.is_empty() and overworld_status_damage > 0 and overworld_status_ticks > 0


func get_description() -> String:
	var values: Dictionary = DescriptionTemplate.numeric_values(self)
	values["status_duration_phases"] = DescriptionTemplate.phases(overworld_status_ticks)
	values["after_trigger"] = " Ловушка разряжается." if disarm_on_trigger else ""
	return DescriptionTemplate.render(description, values)
