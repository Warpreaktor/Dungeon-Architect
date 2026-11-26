class_name TrapPropertiesPopup
extends PopupPanel

signal configuration_changed(entity_id: String, settings: Dictionary)

var _entity_id: String = ""
var _title: Label
var _trap_fields: TrapConfigurationFields


func _ready() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 12)
	scroll.add_child(fields)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fields.add_child(_title)
	_trap_fields = TrapConfigurationFields.new()
	fields.add_child(_trap_fields)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	for caption in ["Отмена", "Сохранить"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size.y = 46
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(hide if caption == "Отмена" else _save)
		actions.add_child(button)


func configure(entity: Dictionary) -> void:
	_entity_id = str(entity["id"])
	var definition: TrapDefinition = TrapCatalog.get_trap(DungeonMap.trap_id(entity))
	_title.text = definition.display_name
	_trap_fields.configure(definition, TrapCatalog.settings(entity))


func _save() -> void:
	configuration_changed.emit(_entity_id, _trap_fields.values())
	hide()
