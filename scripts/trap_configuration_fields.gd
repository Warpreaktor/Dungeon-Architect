class_name TrapConfigurationFields
extends VBoxContainer

var _visible: CheckButton
var _definition: TrapDefinition


func _ready() -> void:
	_visible = CheckButton.new()
	_visible.text = "Видимая ловушка"
	_visible.custom_minimum_size.y = 44
	add_child(_visible)


func configure(definition: TrapDefinition, settings: Dictionary) -> void:
	_definition = definition
	visible = definition != null
	if definition != null:
		_visible.button_pressed = not bool(TrapCatalog.normalize_settings(definition, settings)["hidden"])


func values() -> Dictionary:
	return {"hidden": not _visible.button_pressed} if _definition != null else {}
