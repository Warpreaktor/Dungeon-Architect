class_name GameNotice
extends CenterContainer

## Короткое сообщение о игровом событии. Состояние игры не хранит.

@onready var _panel: PanelContainer = %NoticePanel
@onready var _label: Label = %NoticeText
@onready var _timer: Timer = %NoticeTimer


func _ready() -> void:
	_panel.hide()
	_timer.timeout.connect(_panel.hide)


func show_message(message: String) -> void:
	_label.text = message
	_panel.show()
	_timer.start()


func clear() -> void:
	_timer.stop()
	_panel.hide()
