class_name TriggerPropertiesPopup
extends PopupPanel

## Служебный идентификатор события; сценарии и диалоги здесь не редактируются.
signal event_id_changed(trigger_id: String, event_id: String)

var _trigger_id: String = ""

@onready var _event_input: LineEdit = %EventInput


func _ready() -> void:
	%SaveButton.pressed.connect(_save)
	%CancelButton.pressed.connect(hide)


func configure(trigger_id: String, event_id: String) -> void:
	_trigger_id = trigger_id
	_event_input.text = event_id


func _save() -> void:
	event_id_changed.emit(_trigger_id, _event_input.text)
	hide()
