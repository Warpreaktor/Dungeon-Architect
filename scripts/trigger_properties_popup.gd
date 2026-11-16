class_name TriggerPropertiesPopup
extends MobileKeyboardPopup

## Служебный идентификатор события; сценарии и диалоги здесь не редактируются.
signal event_id_changed(trigger_id: String, event_id: String)

var _trigger_id: String = ""

@onready var _event_input: LineEdit = %EventInput


func _ready() -> void:
	%SaveButton.pressed.connect(_save)
	%CancelButton.pressed.connect(hide)
	%KeyboardDoneButton.pressed.connect(_finish_typing)
	%KeyboardDoneButton.visible = OS.has_feature("mobile")
	_event_input.text_submitted.connect(_on_text_submitted)


func configure(trigger_id: String, event_id: String) -> void:
	_trigger_id = trigger_id
	_event_input.text = event_id


func _on_text_submitted(_text: String) -> void:
	_finish_typing()


func _finish_typing() -> void:
	close_soft_keyboard(_event_input)


func _save() -> void:
	event_id_changed.emit(_trigger_id, _event_input.text)
	close_soft_keyboard(_event_input)
	hide()
