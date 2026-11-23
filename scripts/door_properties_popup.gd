class_name DoorPropertiesPopup
extends PopupPanel

signal configuration_changed(door_id: String, lock_id: String, trap_message: String, remove_trap: bool)

var _door_id: String = ""
var _trap_id: String = ""
var _remove_trap: bool = false
var _selector: OptionButton
var _trap_title: Label
var _trap_message: TextEdit
var _remove_button: Button


func _ready() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.text = "Свойства двери"
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)

	var lock_label := Label.new()
	lock_label.text = "Замок"
	content.add_child(lock_label)

	_selector = OptionButton.new()
	_selector.custom_minimum_size = Vector2(0, 48)
	for lock_id in LockCatalog.LOCK_IDS:
		var item: ItemDefinition = ItemCatalog.get_item(lock_id)
		_selector.add_icon_item(item.icon, LockCatalog.label(lock_id))
		_selector.set_item_metadata(_selector.item_count - 1, lock_id)
	content.add_child(_selector)

	content.add_child(HSeparator.new())
	_trap_title = Label.new()
	content.add_child(_trap_title)

	_trap_message = TextEdit.new()
	_trap_message.custom_minimum_size = Vector2(0, 100)
	_trap_message.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(_trap_message)

	_remove_button = Button.new()
	_remove_button.text = "Снять ловушку"
	_remove_button.custom_minimum_size.y = 44
	_remove_button.pressed.connect(_mark_trap_for_removal)
	content.add_child(_remove_button)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(actions)
	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.custom_minimum_size = Vector2(110, 46)
	cancel.pressed.connect(hide)
	actions.add_child(cancel)
	var save := Button.new()
	save.text = "Сохранить"
	save.custom_minimum_size = Vector2(125, 46)
	save.pressed.connect(_save)
	actions.add_child(save)


func configure(door_id: String, lock_id: String, trap_id: String = "", trap_message: String = "") -> void:
	_door_id = door_id
	_trap_id = trap_id
	_remove_trap = false
	for index in range(_selector.item_count):
		if str(_selector.get_item_metadata(index)) == LockCatalog.normalize(lock_id):
			_selector.select(index)
			break
	_trap_message.text = trap_message
	_trap_message.placeholder_text = TrapCatalog.get_trap(trap_id).trigger_message if not trap_id.is_empty() else ""
	_refresh_trap_fields()


func _mark_trap_for_removal() -> void:
	_remove_trap = true
	_refresh_trap_fields()


func _refresh_trap_fields() -> void:
	if _trap_id.is_empty():
		_trap_title.text = "Ловушка: нет"
	elif _remove_trap:
		_trap_title.text = "Ловушка будет снята после сохранения"
	else:
		_trap_title.text = "%s · сообщение" % TrapCatalog.get_trap(_trap_id).display_name
	_trap_message.visible = not _trap_id.is_empty() and not _remove_trap
	_remove_button.visible = not _trap_id.is_empty() and not _remove_trap


func _save() -> void:
	configuration_changed.emit(_door_id, str(_selector.get_selected_metadata()), _trap_message.text, _remove_trap)
	hide()
