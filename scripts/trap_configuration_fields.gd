class_name TrapConfigurationFields
extends VBoxContainer

const LABELS := {
	"detection_difficulty": "Сложность обнаружения",
	"avoidance_difficulty": "Сложность преодоления",
	"disarm_difficulty": "Сложность обезвреживания"
}

var _difficulties: Dictionary = {}
var _stat: OptionButton
var _hidden: CheckButton
var _state: OptionButton
var _reset: Button
var _definition: TrapDefinition


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	for field in TrapCatalog.DIFFICULTY_FIELDS:
		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = 999
		spin.step = 1
		spin.custom_minimum_size.y = 44
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_add_field(LABELS[field], spin)
		_difficulties[field] = spin
	_stat = OptionButton.new()
	_stat.custom_minimum_size.y = 44
	for stat in TrapCatalog.STAT_IDS:
		_stat.add_item(str(CharacterStats.COMPARISON_LABELS[stat]))
		_stat.set_item_metadata(_stat.item_count - 1, stat)
	_add_field("Характеристика преодоления", _stat)
	_hidden = CheckButton.new()
	_hidden.text = "Скрытая ловушка"
	_hidden.custom_minimum_size.y = 44
	add_child(_hidden)
	_state = OptionButton.new()
	_state.custom_minimum_size.y = 44
	_add_field("Начальное состояние", _state)
	_reset = Button.new()
	_reset.text = "Значения по умолчанию"
	_reset.custom_minimum_size.y = 44
	_reset.pressed.connect(_reset_values)
	add_child(_reset)


func _add_field(caption: String, control: Control) -> void:
	var label := Label.new()
	label.text = caption
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	add_child(control)


func configure(definition: TrapDefinition, settings: Dictionary) -> void:
	_definition = definition
	visible = definition != null
	if definition == null:
		return
	_state.clear()
	var labels := {"armed": "Взведена", "disarmed": "Обезврежена", "discharged": "Разряжена"}
	for state in TrapCatalog.INITIAL_STATES:
		if state == "discharged" and not definition.disarm_on_trigger:
			continue
		_state.add_item(labels[state])
		_state.set_item_metadata(_state.item_count - 1, state)
	_set_values(TrapCatalog.normalize_settings(definition, settings))


func _select_metadata(selector: OptionButton, value: String) -> void:
	for index in range(selector.item_count):
		if str(selector.get_item_metadata(index)) == value:
			selector.select(index)
			return


func _set_values(values: Dictionary) -> void:
	for field in TrapCatalog.DIFFICULTY_FIELDS:
		(_difficulties[field] as SpinBox).value = int(values[field])
	_select_metadata(_stat, str(values["avoidance_stat"]))
	_hidden.button_pressed = bool(values["hidden"])
	_select_metadata(_state, str(values["initial_state"]))


func _reset_values() -> void:
	if _definition != null:
		_set_values(TrapCatalog.normalize_settings(_definition, {}))


func values() -> Dictionary:
	if _definition == null:
		return {}
	var result: Dictionary = {}
	for field in TrapCatalog.DIFFICULTY_FIELDS:
		var spin: SpinBox = _difficulties[field]
		spin.apply()
		result[field] = int(spin.value)
	result["avoidance_stat"] = str(_stat.get_selected_metadata())
	result["hidden"] = _hidden.button_pressed
	result["initial_state"] = str(_state.get_selected_metadata())
	return result
